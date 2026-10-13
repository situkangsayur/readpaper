import 'dart:typed_data';

import '../../files/domain/table_data.dart';
import 'compound_file.dart';

/// Membaca `.xls` (Excel 97–2003, juga Excel 5/95) menjadi lembar-lembar
/// tabel. Seperti `.xlsx`: nilai yang tersimpan, rumus tidak dihitung, dan
/// tanggal tampil sebagai nomor seri Excel.
///
/// Isi buku kerja adalah deretan rekaman BIFF di aliran `Workbook` (atau
/// `Book` untuk Excel 95): teks bersama (SST) di depan, lalu tiap lembar
/// dengan sel-selnya.
class XlsReader {
  XlsReader._(this._data) : _view = ByteData.sublistView(_data);

  final Uint8List _data;
  final ByteData _view;
  bool _biff8 = true;

  static List<TableSheet> read(Uint8List bytes) {
    final cfb = CompoundFile(bytes);
    if (cfb.has('EncryptedPackage')) {
      throw const FormatException('Buku kerja dilindungi kata sandi');
    }
    final stream = cfb.stream('Workbook') ?? cfb.stream('Book');
    if (stream == null) throw const FormatException('Bukan buku kerja Excel');
    return XlsReader._(stream)._read();
  }

  /// Aliran BIFF tanpa pembungkus OLE2, seperti yang ditulis sebagian
  /// aplikasi web dan Excel 2–4.
  static List<TableSheet> readBare(Uint8List bytes) {
    final reader = XlsReader._(bytes);
    final sheets = reader._read();
    if (sheets.isNotEmpty) return sheets;
    // Excel 2–4: satu lembar, tanpa BOUNDSHEET.
    return <TableSheet>[TableSheet(name: 'Lembar 1', rows: reader._sheet(0, const <String>[]))];
  }

  /// Rekaman BOF BIFF (0x0009, 0x0209, 0x0409, 0x0809) di awal berkas.
  static bool looksBare(Uint8List bytes) =>
      bytes.length > 8 && bytes[0] == 0x09 && (bytes[1] & 0xF1) == 0x00;

  int _u16(int o) => _view.getUint16(o, Endian.little);
  int _u32(int o) => _view.getUint32(o, Endian.little);

  List<TableSheet> _read() {
    final sst = <String>[];
    final sheets = <(String, int)>[];

    // Rekaman global: sampai EOF pertama.
    var pos = 0;
    var first = true;
    while (pos + 4 <= _data.length) {
      final type = _u16(pos);
      final length = _u16(pos + 2);
      final body = pos + 4;
      if (body + length > _data.length) break;
      switch (type) {
        case 0x0809: // BOF
          if (first) _biff8 = length >= 2 && _u16(body) >= 0x0600;
          first = false;
        case 0x002F: // FILEPASS
          throw const FormatException('Buku kerja dilindungi kata sandi');
        case 0x0085: // BOUNDSHEET
          final offset = _u32(body);
          final kind = _data[body + 5];
          final cch = _data[body + 6];
          final name = _biff8
              ? _string(body + 7, cch, _data[body + 7] & 1 != 0, skipFlag: true)
              : decodeCp1252(Uint8List.sublistView(_data, body + 7, body + 7 + cch));
          // 0 lembar kerja; bagan, makro, dan modul VB dilewati.
          if (kind == 0) sheets.add((name, offset));
        case 0x00FC: // SST
          _readSst(pos, sst);
        case 0x000A: // EOF
          pos = _data.length;
          continue;
      }
      pos = body + length;
    }

    return <TableSheet>[
      for (final (name, offset) in sheets) TableSheet(name: name, rows: _sheet(offset, sst)),
    ];
  }

  /// Teks `cch` karakter mulai [offset]. [skipFlag]: byte pertama adalah
  /// penanda lebar karakter (1 = UTF-16, 0 = 8-bit).
  String _string(int offset, int cch, bool wide, {bool skipFlag = false}) {
    final start = offset + (skipFlag ? 1 : 0);
    if (wide) return decodeUtf16le(_data, start, cch);
    final end = (start + cch).clamp(start, _data.length);
    return decodeCp1252(Uint8List.sublistView(_data, start, end));
  }

  /// SST: teks bersama yang dirujuk sel LABELSST. Teks boleh terpotong ke
  /// rekaman CONTINUE berikutnya, dan di setiap potongan penanda lebar
  /// karakternya diulang.
  void _readSst(int pos, List<String> out) {
    final segments = <(int, int)>[]; // (awal, akhir) data tiap rekaman
    var p = pos;
    var isFirst = true;
    while (p + 4 <= _data.length) {
      final type = _u16(p);
      final length = _u16(p + 2);
      if (!isFirst && type != 0x003C) break;
      segments.add((p + 4, p + 4 + length));
      isFirst = false;
      p += 4 + length;
    }
    final reader = _SegmentReader(_data, segments);
    reader.skip(4); // jumlah total
    final unique = reader.u32();
    for (var i = 0; i < unique && !reader.done; i++) {
      final cch = reader.u16();
      final flags = reader.u8();
      final rich = flags & 0x08 != 0;
      final ext = flags & 0x04 != 0;
      final runs = rich ? reader.u16() : 0;
      final extSize = ext ? reader.u32() : 0;
      out.add(reader.chars(cch, flags & 0x01 != 0));
      reader.skip(runs * 4 + extSize);
    }
  }

  List<List<String>> _sheet(int offset, List<String> sst) {
    final cells = <int, Map<int, String>>{};
    var pos = offset;
    var depth = 0;
    int? formulaRow;
    int? formulaCol;

    void put(int row, int col, String value) {
      if (row >= TableData.maxRows) return;
      (cells[row] ??= <int, String>{})[col] = value;
    }

    while (pos + 4 <= _data.length) {
      final type = _u16(pos);
      final length = _u16(pos + 2);
      final b = pos + 4;
      if (b + length > _data.length) break;
      pos = b + length;
      switch (type) {
        case 0x0809:
          depth++;
        case 0x000A:
          depth--;
          if (depth <= 0) pos = _data.length;
        case 0x00FD: // LABELSST
          final index = _u32(b + 6);
          put(_u16(b), _u16(b + 2), index < sst.length ? sst[index] : '');
        case 0x0204: // LABEL
          final cch = _u16(b + 6);
          put(
            _u16(b),
            _u16(b + 2),
            _biff8
                ? _string(b + 8, cch, _data[b + 8] & 1 != 0, skipFlag: true)
                : _string(b + 8, cch, false),
          );
        case 0x0203: // NUMBER
          put(_u16(b), _u16(b + 2), formatNumber(_view.getFloat64(b + 6, Endian.little)));
        case 0x027E: // RK
          put(_u16(b), _u16(b + 2), formatNumber(rk(_u32(b + 6))));
        case 0x00BD: // MULRK
          final row = _u16(b);
          final firstCol = _u16(b + 2);
          final count = (length - 6) ~/ 6;
          for (var i = 0; i < count; i++) {
            put(row, firstCol + i, formatNumber(rk(_u32(b + 4 + i * 6 + 2))));
          }
        case 0x0205: // BOOLERR
          final value = _data[b + 6];
          put(_u16(b), _u16(b + 2), _data[b + 7] == 0 ? (value != 0 ? 'TRUE' : 'FALSE') : '#ERR');
        case 0x0006: // FORMULA: hasil terakhir yang disimpan
          final row = _u16(b);
          final col = _u16(b + 2);
          if (_u16(b + 12) == 0xFFFF) {
            switch (_data[b + 6]) {
              case 0: // teks: menyusul di rekaman STRING
                formulaRow = row;
                formulaCol = col;
              case 1:
                put(row, col, _data[b + 8] != 0 ? 'TRUE' : 'FALSE');
              case 2:
                put(row, col, '#ERR');
            }
          } else {
            put(row, col, formatNumber(_view.getFloat64(b + 6, Endian.little)));
          }
        case 0x0207: // STRING
          if (formulaRow != null && formulaCol != null) {
            final cch = _u16(b);
            put(
              formulaRow,
              formulaCol,
              _biff8
                  ? _string(b + 2, cch, _data[b + 2] & 1 != 0, skipFlag: true)
                  : _string(b + 2, cch, false),
            );
          }
          formulaRow = null;
          formulaCol = null;
      }
    }

    if (cells.isEmpty) return const <List<String>>[];
    final lastRow = cells.keys.reduce((a, b) => a > b ? a : b);
    return <List<String>>[
      for (var r = 0; r <= lastRow; r++)
        () {
          final row = cells[r];
          if (row == null || row.isEmpty) return const <String>[];
          final lastCol = row.keys.reduce((a, b) => a > b ? a : b);
          return <String>[for (var c = 0; c <= lastCol; c++) row[c] ?? ''];
        }(),
    ];
  }

  /// Angka RK: 30 bit teratas sebagai bilangan bulat atau sebagai 32 bit
  /// teratas sebuah double, mungkin dikali 100.
  static double rk(int value) {
    final div100 = value & 0x01 != 0;
    final isInt = value & 0x02 != 0;
    double n;
    if (isInt) {
      n = (value.toSigned(32) >> 2).toDouble();
    } else {
      final bytes = ByteData(8)..setUint32(4, value & 0xFFFFFFFC, Endian.little);
      n = bytes.getFloat64(0, Endian.little);
    }
    return div100 ? n / 100 : n;
  }

  /// 12.0 → "12", 15.5 → "15.5".
  static String formatNumber(double n) {
    if (n == n.roundToDouble() && n.abs() < 1e15) return n.toInt().toString();
    final s = n.toString();
    return s.contains('e') ? s : double.parse(n.toStringAsPrecision(15)).toString();
  }
}

/// Membaca data yang terpotong-potong ke beberapa rekaman (SST + CONTINUE).
class _SegmentReader {
  _SegmentReader(this._data, this._segments) : _pos = _segments.isEmpty ? 0 : _segments.first.$1;

  final Uint8List _data;
  final List<(int, int)> _segments;
  int _segment = 0;
  int _pos;

  bool get done => _segment >= _segments.length;

  void _advance() {
    while (!done && _pos >= _segments[_segment].$2) {
      _segment++;
      if (!done) _pos = _segments[_segment].$1;
    }
  }

  int u8() {
    _advance();
    if (done) return 0;
    return _data[_pos++];
  }

  int u16() => u8() | (u8() << 8);
  int u32() => u16() | (u16() << 16);

  void skip(int n) {
    for (var i = 0; i < n && !done; i++) {
      u8();
    }
  }

  /// [count] karakter; bila potongannya habis di tengah, rekaman CONTINUE
  /// berikutnya dimulai dengan penanda lebar karakter yang baru.
  String chars(int count, bool wide) {
    final units = <int>[];
    while (units.length < count && !done) {
      _advance();
      if (done) break;
      final end = _segments[_segment].$2;
      while (units.length < count && _pos < end) {
        if (wide) {
          if (_pos + 1 >= end) {
            _pos = end;
            break;
          }
          units.add(_data[_pos] | (_data[_pos + 1] << 8));
          _pos += 2;
        } else {
          units.add(cp1252Unit(_data[_pos++]));
        }
      }
      if (units.length < count) {
        _segment++;
        if (done) break;
        _pos = _segments[_segment].$1;
        wide = _data[_pos++] & 1 != 0;
      }
    }
    return String.fromCharCodes(units);
  }
}
