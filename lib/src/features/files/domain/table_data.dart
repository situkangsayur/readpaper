import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Satu lembar tabel: nama dan baris-barisnya, semuanya teks.
class TableSheet {
  const TableSheet({required this.name, required this.rows});

  final String name;
  final List<List<String>> rows;

  int get columnCount => rows.fold(0, (m, r) => r.length > m ? r.length : m);
}

/// Membaca CSV, TSV, dan Excel (`.xlsx`) untuk ditampilkan.
///
/// Hanya untuk dilihat: rumus tidak dihitung, yang ditampilkan nilai
/// terakhir yang disimpan Excel di berkasnya. Paket `excel` tidak bisa dipakai
/// karena terikat `xml` versi lama; xlsx sendiri hanyalah zip berisi XML, jadi
/// dibaca langsung.
class TableData {
  const TableData._();

  /// Baris lembar terlalu banyak membuat tampilan tidak berguna dan memori
  /// habis; yang lebih dari ini dipotong, dan pemotongannya diberitahukan.
  static const int maxRows = 5000;

  static List<TableSheet> read(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xlsm')) return xlsx(bytes);
    final text = utf8.decode(bytes, allowMalformed: true);
    final separator = lower.endsWith('.tsv') ? '\t' : _guessSeparator(text);
    return <TableSheet>[
      TableSheet(
        name: 'Lembar 1',
        rows: csv(text, separator: separator),
      ),
    ];
  }

  /// `,` kecuali baris pertama jelas memakai `;` atau tab — CSV dari Excel
  /// berbahasa Indonesia memakai titik koma, karena koma adalah tanda desimal.
  static String _guessSeparator(String text) {
    final firstLine = text.split('\n').first;
    final counts = <String, int>{
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
    };
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// CSV menurut RFC 4180: tanda kutip ganda, kutip di dalam kutip ditulis
  /// dua kali, dan baris baru di dalam kutip tetap satu sel.
  static List<List<String>> csv(String text, {String separator = ','}) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    var i = 0;
    if (text.startsWith('﻿')) i = 1;
    while (i < text.length) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i += 2;
            continue;
          }
          quoted = false;
        } else {
          cell.write(ch);
        }
      } else if (ch == '"' && cell.isEmpty) {
        quoted = true;
      } else if (ch == separator) {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n' || ch == '\r') {
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
        if (rows.length >= maxRows) return rows;
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      } else {
        cell.write(ch);
      }
      i++;
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  /// Semua lembar sebuah `.xlsx`, sesuai urutan di buku kerjanya.
  static List<TableSheet> xlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String? text(String path) {
      final file = archive.findFile(path);
      if (file == null) return null;
      return utf8.decode(file.content as List<int>, allowMalformed: true);
    }

    final shared = <String>[];
    final sharedXml = text('xl/sharedStrings.xml');
    if (sharedXml != null) {
      for (final si in XmlDocument.parse(sharedXml).findAllElements('si')) {
        // Teks kaya (<r><t>…</t></r>) disambung; <rPh> (furigana) dilewati.
        shared.add(
          si.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't' && e.parentElement?.name.local != 'rPh')
              .map((e) => e.innerText)
              .join(),
        );
      }
    }

    // Nama lembar dari workbook.xml, berkasnya dari relasinya.
    final rels = <String, String>{};
    final relsXml = text('xl/_rels/workbook.xml.rels');
    if (relsXml != null) {
      for (final rel in XmlDocument.parse(relsXml).findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id == null || target == null) continue;
        rels[id] = target.startsWith('/') ? target.substring(1) : 'xl/$target';
      }
    }
    final sheets = <TableSheet>[];
    final workbook = text('xl/workbook.xml');
    if (workbook == null) return sheets;
    for (final sheet in XmlDocument.parse(workbook).findAllElements('sheet')) {
      final name = sheet.getAttribute('name') ?? 'Lembar ${sheets.length + 1}';
      final id = sheet.attributes
          .where((a) => a.name.local == 'id' && a.name.prefix == 'r')
          .map((a) => a.value)
          .firstOrNull;
      final path = (id == null ? null : rels[id]) ?? 'xl/worksheets/sheet${sheets.length + 1}.xml';
      final xml = text(path);
      sheets.add(
        TableSheet(
          name: name,
          rows: xml == null ? const <List<String>>[] : _sheetRows(xml, shared),
        ),
      );
    }
    return sheets;
  }

  static List<List<String>> _sheetRows(String xml, List<String> shared) {
    final rows = <List<String>>[];
    for (final row in XmlDocument.parse(xml).findAllElements('row')) {
      final cells = <String>[];
      for (final c in row.findElements('c')) {
        // Sel kosong tidak ditulis Excel; kolomnya dibaca dari alamatnya (B7).
        final column = _columnIndex(c.getAttribute('r'));
        while (column != null && cells.length < column) {
          cells.add('');
        }
        final type = c.getAttribute('t');
        final value = c.getElement('v')?.innerText ?? '';
        cells.add(switch (type) {
          's' =>
            int.tryParse(value) != null && int.parse(value) < shared.length
                ? shared[int.parse(value)]
                : '',
          'inlineStr' => c.getElement('is')?.innerText ?? '',
          'b' => value == '1' ? 'TRUE' : 'FALSE',
          _ => value,
        });
      }
      final number = int.tryParse(row.getAttribute('r') ?? '');
      while (number != null && rows.length < number - 1) {
        rows.add(const <String>[]);
      }
      rows.add(cells);
      if (rows.length >= maxRows) break;
    }
    return rows;
  }

  /// `B7` → 1, `AA3` → 26.
  static int? _columnIndex(String? reference) {
    if (reference == null) return null;
    final letters = RegExp('^[A-Z]+').firstMatch(reference)?.group(0);
    if (letters == null) return null;
    var index = 0;
    for (final unit in letters.codeUnits) {
      index = index * 26 + (unit - 64);
    }
    return index - 1;
  }
}
