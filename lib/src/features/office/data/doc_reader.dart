import 'dart:typed_data';

import '../domain/office_document.dart';
import 'compound_file.dart';

/// Membaca teks `.doc` (Word 97–2003): paragraf dan tabel, tanpa gaya.
///
/// Teks Word lama tersimpan berkeping-keping di aliran `WordDocument`; urutan
/// kepingnya ada di tabel keping (piece table) di aliran `0Table`/`1Table`.
/// Gambar, gaya huruf, dan judul bagian tidak dibaca — membacanya berarti
/// mengurai format biner Word seluruhnya. Untuk tampilan persis, buka di
/// aplikasi Office atau, di desktop, lewat LibreOffice.
class DocReader {
  const DocReader._();

  static OfficeDocument read(Uint8List bytes) {
    final cfb = CompoundFile(bytes);
    final word = cfb.stream('WordDocument');
    if (word == null || word.length < 0x1AA) {
      throw const FormatException('Bukan dokumen Word');
    }
    final fib = ByteData.sublistView(word);
    if (fib.getUint16(0, Endian.little) != 0xA5EC) {
      throw const FormatException('Bukan dokumen Word');
    }
    final flags = fib.getUint16(0x0A, Endian.little);
    if (flags & 0x0100 != 0) {
      throw const FormatException('Dokumen dilindungi kata sandi');
    }
    final nFib = fib.getUint16(2, Endian.little);
    final String text;
    if (nFib < 0xC1) {
      // Word 6/95: teks 8-bit utuh di antara fcMin dan fcMac.
      final from = fib.getUint32(0x18, Endian.little);
      final to = fib.getUint32(0x1C, Endian.little);
      if (from >= to || to > word.length) throw const FormatException('Dokumen Word rusak');
      text = decodeCp1252(Uint8List.sublistView(word, from, to));
    } else {
      final table = cfb.stream(flags & 0x0200 != 0 ? '1Table' : '0Table');
      if (table == null) throw const FormatException('Tabel teks Word tidak ada');
      final ccpText = fib.getInt32(0x4C, Endian.little);
      text = _pieces(
        word,
        table,
        fib.getUint32(0x1A2, Endian.little),
        fib.getUint32(0x1A6, Endian.little),
        ccpText,
      );
    }
    return OfficeDocument(blocks: blocksFromText(text));
  }

  /// Menyambung keping teks menurut tabel keping di dalam CLX.
  static String _pieces(Uint8List word, Uint8List table, int fcClx, int lcbClx, int limit) {
    final view = ByteData.sublistView(table);
    var i = fcClx;
    final end = fcClx + lcbClx;
    // Lewati Prc (perubahan format), cari Pcdt (0x02).
    while (i < end && i < table.length && table[i] == 0x01) {
      i += 3 + view.getUint16(i + 1, Endian.little);
    }
    if (i >= table.length || table[i] != 0x02) throw const FormatException('Tabel keping rusak');
    final lcb = view.getUint32(i + 1, Endian.little);
    final plc = i + 5;
    final n = (lcb - 4) ~/ 12;
    final out = StringBuffer();
    for (var k = 0; k < n; k++) {
      final cpStart = view.getUint32(plc + k * 4, Endian.little);
      final cpEnd = view.getUint32(plc + (k + 1) * 4, Endian.little);
      if (cpStart >= limit) break;
      final count = (cpEnd < limit ? cpEnd : limit) - cpStart;
      final pcd = plc + (n + 1) * 4 + k * 8;
      final fc = view.getUint32(pcd + 2, Endian.little);
      if (fc & 0x40000000 != 0) {
        final from = (fc & 0x3FFFFFFF) ~/ 2;
        final to = from + count;
        if (to > word.length) break;
        out.write(decodeCp1252(Uint8List.sublistView(word, from, to)));
      } else {
        out.write(decodeUtf16le(word, fc, count));
      }
    }
    return out.toString();
  }

  /// Teks Word mentah → paragraf dan tabel. `\r` mengakhiri paragraf, `\x07`
  /// mengakhiri sel, dan `\x07` kedua berturut-turut mengakhiri baris tabel.
  /// Kode isian (`\x13 kode \x14 hasil \x15`) hanya hasilnya yang dibaca.
  static List<OfficeBlock> blocksFromText(String text) {
    final blocks = <OfficeBlock>[];
    final buf = StringBuffer();
    final cellParagraphs = <OfficeParagraph>[];
    var row = <List<OfficeParagraph>>[];
    var rows = <List<List<OfficeParagraph>>>[];
    var lastWasCellEnd = false;
    final fields = <bool>[]; // true: sudah di bagian hasil

    OfficeParagraph para(String s) => OfficeParagraph(runs: <OfficeRun>[OfficeRun(s)]);

    void flushTable() {
      if (row.isNotEmpty) rows.add(row);
      if (rows.isNotEmpty) blocks.add(OfficeTable(rows));
      rows = <List<List<OfficeParagraph>>>[];
      row = <List<OfficeParagraph>>[];
    }

    for (final unit in text.codeUnits) {
      if (unit == 0x13) {
        fields.add(false);
        continue;
      }
      if (unit == 0x14) {
        if (fields.isNotEmpty) fields[fields.length - 1] = true;
        continue;
      }
      if (unit == 0x15) {
        if (fields.isNotEmpty) fields.removeLast();
        continue;
      }
      if (fields.any((inResult) => !inResult)) continue;

      switch (unit) {
        case 0x0D || 0x0C || 0x0E:
          final s = buf.toString();
          buf.clear();
          if (row.isNotEmpty) {
            cellParagraphs.add(para(s));
          } else {
            flushTable();
            blocks.add(para(s));
          }
          lastWasCellEnd = false;
        case 0x07:
          if (buf.isEmpty && cellParagraphs.isEmpty && lastWasCellEnd) {
            rows.add(row);
            row = <List<OfficeParagraph>>[];
            lastWasCellEnd = false;
          } else {
            row.add(<OfficeParagraph>[...cellParagraphs, para(buf.toString())]);
            cellParagraphs.clear();
            buf.clear();
            lastWasCellEnd = true;
          }
        case 0x0B:
          buf.write('\n');
        case 0x09:
          buf.write('\t');
        case 0x1E:
          buf.write('-');
        default:
          if (unit >= 0x20) buf.write(String.fromCharCode(unit));
      }
    }
    if (buf.isNotEmpty) {
      flushTable();
      blocks.add(para(buf.toString()));
    }
    flushTable();
    // Paragraf kosong berderet hanyalah jarak; satu cukup.
    final out = <OfficeBlock>[];
    for (final b in blocks) {
      if (b is OfficeParagraph &&
          b.isEmpty &&
          out.isNotEmpty &&
          out.last is OfficeParagraph &&
          (out.last as OfficeParagraph).isEmpty) {
        continue;
      }
      out.add(b);
    }
    return out;
  }
}
