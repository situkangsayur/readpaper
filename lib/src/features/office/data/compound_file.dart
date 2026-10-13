import 'dart:typed_data';

/// Berkas majemuk OLE2 (Compound File Binary): wadah `.doc`, `.xls`, dan
/// `.ppt` lama. Isinya sistem berkas kecil — sektor-sektor yang dirangkai
/// tabel alokasi (FAT) menjadi aliran (stream) bernama.
class CompoundFile {
  CompoundFile._(this._data, this._sectorSize, this._fat, this._miniFat, this._entries);

  final Uint8List _data;
  final int _sectorSize;
  final List<int> _fat;
  final List<int> _miniFat;
  final List<_Entry> _entries;
  Uint8List? _ministream;

  static const int _endOfChain = 0xFFFFFFFE;
  static const int _miniSectorSize = 64;
  static const int _miniCutoff = 4096;

  static bool looksLike(Uint8List bytes) =>
      bytes.length >= 512 &&
      bytes[0] == 0xD0 &&
      bytes[1] == 0xCF &&
      bytes[2] == 0x11 &&
      bytes[3] == 0xE0;

  factory CompoundFile(Uint8List data) {
    if (!looksLike(data)) {
      throw const FormatException('Bukan berkas Office lama (OLE2)');
    }
    final header = ByteData.sublistView(data);
    final sectorSize = 1 << header.getUint16(0x1E, Endian.little);
    final fatSectors = header.getUint32(0x2C, Endian.little);
    final firstDir = header.getUint32(0x30, Endian.little);
    final firstMiniFat = header.getUint32(0x3C, Endian.little);
    var difatSector = header.getUint32(0x44, Endian.little);

    int offsetOf(int sector) => (sector + 1) * sectorSize;
    int u32(int offset) =>
        offset + 4 <= data.length ? header.getUint32(offset, Endian.little) : _endOfChain;

    // Daftar sektor FAT: 109 pertama di kepala berkas, sisanya berantai
    // lewat sektor DIFAT.
    final fatList = <int>[];
    for (var i = 0; i < 109 && fatList.length < fatSectors; i++) {
      fatList.add(u32(0x4C + i * 4));
    }
    var guard = 0;
    while (fatList.length < fatSectors && difatSector < 0xFFFFFFFA && guard++ < 10000) {
      final base = offsetOf(difatSector);
      final perSector = sectorSize ~/ 4 - 1;
      for (var i = 0; i < perSector && fatList.length < fatSectors; i++) {
        fatList.add(u32(base + i * 4));
      }
      difatSector = u32(base + perSector * 4);
    }

    final fat = <int>[];
    for (final sector in fatList) {
      final base = offsetOf(sector);
      for (var i = 0; i < sectorSize ~/ 4; i++) {
        fat.add(u32(base + i * 4));
      }
    }

    final file = CompoundFile._(data, sectorSize, fat, <int>[], <_Entry>[]);
    if (firstMiniFat < 0xFFFFFFFA) {
      final bytes = file._read(firstMiniFat);
      final view = ByteData.sublistView(bytes);
      for (var i = 0; i + 4 <= bytes.length; i += 4) {
        file._miniFat.add(view.getUint32(i, Endian.little));
      }
    }

    final dir = file._read(firstDir);
    final dirView = ByteData.sublistView(dir);
    for (var off = 0; off + 128 <= dir.length; off += 128) {
      final nameLength = dirView.getUint16(off + 0x40, Endian.little);
      final type = dir[off + 0x42];
      final chars = <int>[];
      for (var i = 0; i + 2 < nameLength && i < 64; i += 2) {
        chars.add(dirView.getUint16(off + i, Endian.little));
      }
      file._entries.add(
        _Entry(
          name: String.fromCharCodes(chars),
          type: type,
          start: dirView.getUint32(off + 0x74, Endian.little),
          size: dirView.getUint32(off + 0x78, Endian.little),
        ),
      );
    }
    return file;
  }

  /// Rangkaian sektor mulai [start], disambung jadi satu.
  Uint8List _read(int start) {
    final out = BytesBuilder(copy: false);
    var s = start;
    var guard = 0;
    while (s < _fat.length && guard++ <= _fat.length) {
      final from = (s + 1) * _sectorSize;
      if (from >= _data.length) break;
      final to = from + _sectorSize;
      out.add(Uint8List.sublistView(_data, from, to > _data.length ? _data.length : to));
      s = _fat[s];
    }
    return out.takeBytes();
  }

  /// Nama semua aliran di dalam berkas.
  Iterable<String> get streamNames => _entries.where((e) => e.type == 2).map((e) => e.name);

  bool has(String name) => _entries.any((e) => e.type == 2 && e.name == name);

  /// Isi aliran bernama [name], atau null bila tidak ada.
  Uint8List? stream(String name) {
    final entry = _entries.where((e) => e.type == 2 && e.name == name).firstOrNull;
    if (entry == null) return null;
    if (entry.size < _miniCutoff) {
      final root = _entries.firstWhere((e) => e.type == 5);
      final mini = _ministream ??= _read(root.start);
      final out = BytesBuilder(copy: false);
      var s = entry.start;
      var guard = 0;
      while (s < _miniFat.length && guard++ <= _miniFat.length) {
        final from = s * _miniSectorSize;
        if (from >= mini.length) break;
        final to = from + _miniSectorSize;
        out.add(Uint8List.sublistView(mini, from, to > mini.length ? mini.length : to));
        s = _miniFat[s];
      }
      final bytes = out.takeBytes();
      return bytes.length > entry.size ? Uint8List.sublistView(bytes, 0, entry.size) : bytes;
    }
    final bytes = _read(entry.start);
    return bytes.length > entry.size ? Uint8List.sublistView(bytes, 0, entry.size) : bytes;
  }
}

class _Entry {
  const _Entry({required this.name, required this.type, required this.start, required this.size});

  final String name;

  /// 1 penyimpanan, 2 aliran, 5 akar.
  final int type;
  final int start;
  final int size;
}

/// Teks 8-bit Windows-1252, pengodean teks "terpadatkan" di berkas Office
/// lama. Hanya 0x80–0x9F yang berbeda dari Latin-1.
String decodeCp1252(List<int> bytes) => String.fromCharCodes(bytes.map(cp1252Unit));

/// Satu byte Windows-1252 → kode karakter Unicode.
int cp1252Unit(int b) {
  const high = <int>[
    0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F,
    0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
  ];
  return b >= 0x80 && b < 0xA0 ? high[b - 0x80] : b;
}

/// Teks UTF-16 little-endian.
String decodeUtf16le(Uint8List bytes, int offset, int length) {
  final view = ByteData.sublistView(bytes);
  final units = <int>[];
  for (var i = 0; i < length && offset + i * 2 + 1 < bytes.length; i++) {
    units.add(view.getUint16(offset + i * 2, Endian.little));
  }
  return String.fromCharCodes(units);
}
