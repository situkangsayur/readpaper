import 'dart:convert';
import 'dart:io' as io show ZLibDecoder;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import '../../office/data/compound_file.dart';
import '../../office/data/text_formats.dart';
import '../../office/data/xls_reader.dart';

/// Satu lembar tabel: nama dan baris-barisnya, semuanya teks.
class TableSheet {
  const TableSheet({required this.name, required this.rows});

  final String name;
  final List<List<String>> rows;

  int get columnCount => rows.fold(0, (m, r) => r.length > m ? r.length : m);
}

/// Membaca CSV, TSV, Excel (`.xlsx`, juga `.xls` lama), dan lembar kerja
/// OpenDocument (`.ods`) untuk ditampilkan.
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
    // Isinya yang menentukan: banyak ".xls" sebenarnya .xlsx yang diganti
    // nama, HTML, atau BIFF tanpa pembungkus — ekspor aplikasi web.
    if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final content = archive.findFile('content.xml');
      if (content != null && archive.findFile('mimetype') != null) return ods(content);
      return xlsx(bytes);
    }
    if (CompoundFile.looksLike(bytes)) return XlsReader.read(bytes);
    if (lower.endsWith('.xls') && XlsReader.looksBare(bytes)) return XlsReader.readBare(bytes);
    if (TextFormats.isHtml(bytes)) {
      return <TableSheet>[
        for (final (name, rows) in TextFormats.htmlTables(bytes))
          TableSheet(name: name, rows: rows),
      ];
    }
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
  ///
  /// Lembar dan daftar teksnya dibaca **mengalir**: isinya di-inflate sedikit
  /// demi sedikit, diurai sebagai rangkaian event XML, dan pembacaan lembar
  /// berhenti begitu [maxRows] baris terkumpul. Dulu seluruh XML-nya dibangun
  /// menjadi pohon lebih dulu — terbukti pada ekspor transaksi 36 MB yang
  /// berisi 300 MB XML: hampir satu menit di desktop, dan di tablet tidak
  /// pernah terbuka, padahal yang ditampilkan hanya lima ribu baris pertama.
  static List<TableSheet> xlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? entry(String path) =>
        archive.findFile(path) ??
        // Nama di dalam zip kadang berbeda huruf besar-kecilnya dari relasinya.
        archive.files.where((f) => f.name.toLowerCase() == path.toLowerCase()).firstOrNull;
    String? text(String path) {
      final file = entry(path);
      if (file == null) return null;
      return utf8.decode(file.content, allowMalformed: true);
    }

    final shared = <String>[];
    final sharedFile = entry('xl/sharedStrings.xml');
    if (sharedFile != null) _readShared(sharedFile, shared);

    // Nama lembar dari workbook.xml, berkasnya dari relasinya.
    final rels = <String, String>{};
    final relsXml = text('xl/_rels/workbook.xml.rels');
    if (relsXml != null) {
      for (final rel in XmlDocument.parse(relsXml).findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id == null || target == null) continue;
        rels[id] = target.startsWith('/') ? target.substring(1) : p.posix.normalize('xl/$target');
      }
    }
    final sheets = <TableSheet>[];
    final workbook = text('xl/workbook.xml');
    if (workbook == null) {
      // Zip yang terpotong atau bukan buku kerja: lebih jujur dikatakan
      // daripada menampilkan tabel kosong.
      throw const FormatException('Berkas Excel rusak atau terpotong');
    }
    for (final sheet in XmlDocument.parse(
      workbook,
    ).descendants.whereType<XmlElement>().where((e) => e.name.local == 'sheet')) {
      final name = sheet.getAttribute('name') ?? 'Lembar ${sheets.length + 1}';
      final id = sheet.attributes
          .where((a) => a.name.local == 'id' && a.name.prefix != null)
          .map((a) => a.value)
          .firstOrNull;
      final path = (id == null ? null : rels[id]) ?? 'xl/worksheets/sheet${sheets.length + 1}.xml';
      final file = entry(path);
      sheets.add(
        TableSheet(
          name: name,
          rows: file == null ? const <List<String>>[] : _sheetRows(file, shared),
        ),
      );
    }
    return sheets;
  }

  /// Semua lembar `.ods` (LibreOffice Calc), dibaca mengalir dari
  /// `content.xml` seperti lembar xlsx.
  ///
  /// Calc menulis baris dan kolom kosong di ujung lembar sebagai satu baris
  /// yang "diulang" sampai sejuta kali; yang kosong di ujung dibuang, dan
  /// pengulangan kosong di tengah baru dibentangkan bila diikuti isi.
  static List<TableSheet> ods(ArchiveFile content) {
    final sheets = <TableSheet>[];
    String? sheetName;
    var rows = <List<String>>[];
    var pendingRows = 0;
    var rowRepeat = 1;
    List<String>? cells;
    var pendingCells = 0;
    var cellRepeat = 1;
    StringBuffer? cell;
    var paragraphs = 0;
    var inParagraph = false;
    var tableDepth = 0;
    var skip = 0;

    void endCell() {
      final row = cells;
      final text = cell?.toString() ?? '';
      cell = null;
      if (row == null) return;
      if (text.isEmpty) {
        pendingCells += cellRepeat;
        return;
      }
      for (var i = 0; i < pendingCells && row.length < 16384; i++) {
        row.add('');
      }
      pendingCells = 0;
      for (var i = 0; i < cellRepeat && row.length < 16384; i++) {
        row.add(text);
      }
    }

    void endRow() {
      final row = cells ?? <String>[];
      cells = null;
      if (row.isEmpty) {
        pendingRows += rowRepeat;
        return;
      }
      for (var i = 0; i < pendingRows && rows.length < maxRows; i++) {
        rows.add(const <String>[]);
      }
      pendingRows = 0;
      for (var i = 0; i < rowRepeat && rows.length < maxRows; i++) {
        rows.add(row);
      }
    }

    _streamXml(content, (events) {
      for (final event in events) {
        if (event is XmlStartElementEvent) {
          final name = _local(event.name);
          if (skip > 0) {
            if (!event.isSelfClosing) skip++;
            continue;
          }
          switch (name) {
            case 'table':
              tableDepth++;
              if (tableDepth == 1) {
                sheetName = _attribute(event, 'name') ?? 'Lembar ${sheets.length + 1}';
                rows = <List<String>>[];
                pendingRows = 0;
              }
              if (event.isSelfClosing) tableDepth--;
            case 'table-row' when tableDepth == 1:
              rowRepeat = int.tryParse(_attribute(event, 'number-rows-repeated') ?? '') ?? 1;
              cells = <String>[];
              pendingCells = 0;
              if (event.isSelfClosing) endRow();
            case 'table-cell' || 'covered-table-cell' when tableDepth == 1 && cells != null:
              cellRepeat = int.tryParse(_attribute(event, 'number-columns-repeated') ?? '') ?? 1;
              cell = StringBuffer();
              paragraphs = 0;
              if (event.isSelfClosing) endCell();
            case 'p' || 'h' when cell != null:
              if (paragraphs++ > 0) cell!.write('\n');
              inParagraph = !event.isSelfClosing;
            case 's' when cell != null:
              cell!.write(' ' * (int.tryParse(_attribute(event, 'c') ?? '') ?? 1));
            case 'tab' when cell != null:
              cell!.write('\t');
            case 'line-break' when cell != null:
              cell!.write('\n');
            // Komentar sel tidak ikut isi selnya.
            case 'annotation' || 'note-body':
              if (!event.isSelfClosing) skip = 1;
          }
        } else if (event is XmlEndElementEvent) {
          if (skip > 0) {
            skip--;
            continue;
          }
          switch (_local(event.name)) {
            case 'table':
              if (tableDepth == 1) {
                sheets.add(
                  TableSheet(name: sheetName ?? 'Lembar ${sheets.length + 1}', rows: rows),
                );
              }
              tableDepth--;
            case 'table-row' when tableDepth == 1:
              endRow();
            case 'table-cell' || 'covered-table-cell' when tableDepth == 1 && cells != null:
              endCell();
            case 'p' || 'h':
              inParagraph = false;
          }
        } else if (skip == 0 && inParagraph && cell != null) {
          if (event is XmlTextEvent) cell!.write(event.value);
          if (event is XmlCDATAEvent) cell!.write(event.value);
        }
      }
    }, () => false);
    if (sheets.isEmpty) throw const FormatException('Bukan lembar kerja OpenDocument');
    return sheets;
  }

  /// Menyuapkan isi [file] (sudah di-inflate) ke [onEvents] sedikit demi
  /// sedikit, sampai habis atau sampai [stop] bernilai benar.
  static void _streamXml(
    ArchiveFile file,
    void Function(List<XmlEvent> events) onEvents,
    bool Function() stop,
  ) {
    final events = XmlEventDecoder().startChunkedConversion(_EventSink(onEvents));
    final text = const Utf8Decoder(allowMalformed: true).startChunkedConversion(events);
    final raw = file.rawContent?.getStream(decompress: false).toUint8List();
    const step = 64 * 1024;
    if (raw == null || file.compression == CompressionType.none || raw.isEmpty) {
      final plain = raw ?? file.content;
      for (var i = 0; i < plain.length && !stop(); i += step) {
        text.add(plain.sublist(i, i + step > plain.length ? plain.length : i + step));
      }
    } else {
      final inflate = io.ZLibDecoder(raw: true).startChunkedConversion(_ByteSink(text.add));
      for (var i = 0; i < raw.length && !stop(); i += step) {
        inflate.add(Uint8List.sublistView(raw, i, i + step > raw.length ? raw.length : i + step));
      }
      if (!stop()) inflate.close();
    }
    if (!stop()) text.close();
  }

  static String _local(String qualified) {
    final colon = qualified.indexOf(':');
    return colon < 0 ? qualified : qualified.substring(colon + 1);
  }

  static void _readShared(ArchiveFile file, List<String> shared) {
    StringBuffer? current;
    var inText = false;
    var phonetic = 0;
    _streamXml(file, (events) {
      for (final event in events) {
        if (event is XmlStartElementEvent) {
          switch (_local(event.name)) {
            case 'si':
              current = StringBuffer();
              if (event.isSelfClosing) {
                shared.add('');
                current = null;
              }
            case 't':
              inText = !event.isSelfClosing;
            // Teks kaya (<r><t>…</t></r>) disambung; <rPh> (furigana) dilewati.
            case 'rPh':
              if (!event.isSelfClosing) phonetic++;
          }
        } else if (event is XmlEndElementEvent) {
          switch (_local(event.name)) {
            case 'si':
              shared.add(current?.toString() ?? '');
              current = null;
            case 't':
              inText = false;
            case 'rPh':
              phonetic--;
          }
        } else if (inText && phonetic == 0) {
          if (event is XmlTextEvent) current?.write(event.value);
          if (event is XmlCDATAEvent) current?.write(event.value);
        }
      }
    }, () => false);
  }

  static List<List<String>> _sheetRows(ArchiveFile file, List<String> shared) {
    final rows = <List<String>>[];
    List<String>? cells;
    int? rowNumber;
    int? column;
    String? type;
    final value = StringBuffer();
    final inline = StringBuffer();
    var inValue = false;
    var inInline = false;
    var inInlineText = false;
    var phonetic = 0;
    var done = false;

    void endCell() {
      final row = cells;
      if (row == null) return;
      // Sel kosong tidak ditulis Excel; kolomnya dibaca dari alamatnya (B7).
      while (column != null && row.length < column!) {
        row.add('');
      }
      final v = value.toString();
      row.add(switch (type) {
        's' => () {
          final i = int.tryParse(v.trim());
          return i != null && i >= 0 && i < shared.length ? shared[i] : '';
        }(),
        'inlineStr' => inline.toString(),
        'b' => v == '1' ? 'TRUE' : 'FALSE',
        _ => v,
      });
    }

    void endRow() {
      final row = cells ?? <String>[];
      while (rowNumber != null && rows.length < rowNumber! - 1) {
        rows.add(const <String>[]);
      }
      rows.add(row);
      cells = null;
      if (rows.length >= maxRows) done = true;
    }

    _streamXml(file, (events) {
      for (final event in events) {
        if (done) return;
        if (event is XmlStartElementEvent) {
          switch (_local(event.name)) {
            case 'row':
              cells = <String>[];
              rowNumber = int.tryParse(_attribute(event, 'r') ?? '');
              if (event.isSelfClosing) endRow();
            case 'c':
              cells ??= <String>[];
              column = _columnIndex(_attribute(event, 'r'));
              type = _attribute(event, 't');
              value.clear();
              inline.clear();
              if (event.isSelfClosing) endCell();
            case 'v':
              inValue = !event.isSelfClosing;
            case 'is':
              inInline = !event.isSelfClosing;
            case 't':
              inInlineText = inInline && !event.isSelfClosing;
            case 'rPh':
              if (!event.isSelfClosing) phonetic++;
          }
        } else if (event is XmlEndElementEvent) {
          switch (_local(event.name)) {
            case 'row':
              endRow();
            case 'c':
              endCell();
            case 'v':
              inValue = false;
            case 'is':
              inInline = false;
            case 't':
              inInlineText = false;
            case 'rPh':
              phonetic--;
          }
        } else if (event is XmlTextEvent || event is XmlCDATAEvent) {
          final text = event is XmlTextEvent ? event.value : (event as XmlCDATAEvent).value;
          if (inValue) value.write(text);
          if (inInlineText && phonetic == 0) inline.write(text);
        }
      }
    }, () => done);
    return rows;
  }

  static String? _attribute(XmlStartElementEvent event, String name) =>
      event.attributes.where((a) => _local(a.name) == name).map((a) => a.value).firstOrNull;

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

class _EventSink implements Sink<List<XmlEvent>> {
  _EventSink(this._onEvents);

  final void Function(List<XmlEvent>) _onEvents;

  @override
  void add(List<XmlEvent> data) => _onEvents(data);

  @override
  void close() {}
}

class _ByteSink implements Sink<List<int>> {
  _ByteSink(this._onBytes);

  final void Function(List<int>) _onBytes;

  @override
  void add(List<int> data) => _onBytes(data);

  @override
  void close() {}
}
