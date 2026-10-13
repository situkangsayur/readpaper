import 'dart:typed_data';

import '../domain/office_document.dart';
import 'compound_file.dart';

/// Membaca teks `.ppt` (PowerPoint 97–2003) per slide: judul dan isinya,
/// berurutan seperti di presentasinya. Posisi, gambar, dan warna tidak
/// dibaca.
///
/// Urutan slide ada di daftar `SlideListWithText` milik dokumen; tiap slide
/// dirujuk lewat nomor persist, yang dipetakan ke letak rekamannya oleh
/// direktori persist (dicari dari aliran `Current User`). Teks slide ada di
/// daftar itu sendiri (berkas lama) atau di kotak teks slidenya (berkas
/// yang disimpan PowerPoint baru) — keduanya dibaca.
class PptReader {
  PptReader._(this._data) : _view = ByteData.sublistView(_data);

  final Uint8List _data;
  final ByteData _view;

  static const int _document = 0x03E8;
  static const int _slide = 0x03EE;
  static const int _slideListWithText = 0x0FF0;
  static const int _slidePersistAtom = 0x03F3;
  static const int _textHeaderAtom = 0x0F9F;
  static const int _textCharsAtom = 0x0FA0;
  static const int _textBytesAtom = 0x0FA8;
  static const int _userEditAtom = 0x0FF5;
  static const int _persistDirectoryAtom = 0x1772;

  static OfficeDocument read(Uint8List bytes) {
    final cfb = CompoundFile(bytes);
    final stream = cfb.stream('PowerPoint Document');
    if (stream == null) throw const FormatException('Bukan presentasi PowerPoint');
    if (cfb.has('EncryptedSummary')) {
      throw const FormatException('Presentasi dilindungi kata sandi');
    }
    final reader = PptReader._(stream);
    return reader._read(cfb.stream('Current User'));
  }

  int _type(int at) => _view.getUint16(at + 2, Endian.little);
  int _length(int at) => _view.getUint32(at + 4, Endian.little);
  int _instance(int at) => _view.getUint16(at, Endian.little) >> 4;
  bool _isContainer(int at) => _view.getUint16(at, Endian.little) & 0x0F == 0x0F;
  bool _fits(int at) => at + 8 <= _data.length && at + 8 + _length(at) <= _data.length;

  /// Rekaman anak langsung dari wadah di [at].
  Iterable<int> _children(int at) sync* {
    final end = at + 8 + _length(at);
    var p = at + 8;
    while (p + 8 <= end && _fits(p)) {
      yield p;
      p += 8 + _length(p);
    }
  }

  OfficeDocument _read(Uint8List? currentUser) {
    final persist = _persistDirectory(currentUser);
    final documentAt = _findDocument(persist);

    // Slide berurutan: nomor persist dan teks yang ditulis di daftarnya.
    final order = <int>[];
    final listTexts = <int, List<(int, String)>>{};
    if (documentAt != null) {
      for (final c in _children(documentAt)) {
        if (_type(c) != _slideListWithText || _instance(c) != 0) continue;
        int? current;
        var kind = 4;
        for (final r in _children(c)) {
          switch (_type(r)) {
            case _slidePersistAtom:
              current = _view.getUint32(r + 8, Endian.little);
              order.add(current);
            case _textHeaderAtom:
              kind = _view.getUint32(r + 8, Endian.little);
            case _textCharsAtom || _textBytesAtom:
              if (current != null) (listTexts[current] ??= <(int, String)>[]).add((kind, _text(r)));
          }
        }
      }
    }

    final slides = <OfficeSlide>[];
    if (order.isNotEmpty) {
      for (final id in order) {
        final texts = <(int, String)>[...?listTexts[id]];
        final at = persist[id];
        if (at != null && at + 8 <= _data.length && _type(at) == _slide) {
          _collectTexts(at, texts);
        }
        slides.add(_slideFrom(slides.length + 1, texts));
      }
    } else {
      // Tanpa direktori persist: semua wadah slide sesuai urutan di berkas.
      for (final at in _all(0, _data.length, _slide)) {
        final texts = <(int, String)>[];
        _collectTexts(at, texts);
        slides.add(_slideFrom(slides.length + 1, texts));
      }
    }
    if (slides.isEmpty) throw const FormatException('Tidak ada slide yang terbaca');
    return OfficeDocument(slides: slides);
  }

  OfficeSlide _slideFrom(int number, List<(int, String)> texts) {
    final shapes = <OfficeShape>[];
    final seen = <String>{};
    for (final (kind, text) in texts) {
      final clean = text.replaceAll('\r', '\n').replaceAll('\u000B', '\n').trim();
      // Teks yang sama bisa ada di daftar dan di kotak teksnya.
      if (clean.isEmpty || !seen.add(clean)) continue;
      // 0 judul, 6 judul tengah; selain itu isi.
      final isTitle = kind == 0 || kind == 6;
      final isBody = kind == 1 || kind == 5 || kind == 7 || kind == 8;
      final lines = clean.split('\n');
      shapes.add(
        OfficeShape(
          isTitle: isTitle,
          paragraphs: <OfficeParagraph>[
            for (final line in lines)
              if (line.trim().isNotEmpty)
                OfficeParagraph(
                  runs: <OfficeRun>[OfficeRun(line, bold: isTitle, size: isTitle ? 32 : 20)],
                  bullet: isBody && lines.length > 1 ? '•' : null,
                ),
          ],
        ),
      );
    }
    // Judul di atas, apa pun urutannya di berkas.
    shapes.sort((a, b) => (a.isTitle ? 0 : 1) - (b.isTitle ? 0 : 1));
    return OfficeSlide(number: number, shapes: shapes);
  }

  void _collectTexts(int at, List<(int, String)> out) {
    var kind = 4;
    void walk(int container) {
      for (final c in _children(container)) {
        final type = _type(c);
        if (type == _textHeaderAtom) {
          kind = _view.getUint32(c + 8, Endian.little);
        } else if (type == _textCharsAtom || type == _textBytesAtom) {
          out.add((kind, _text(c)));
        } else if (_isContainer(c)) {
          walk(c);
        }
      }
    }

    walk(at);
  }

  String _text(int at) {
    final length = _length(at);
    if (_type(at) == _textCharsAtom) return decodeUtf16le(_data, at + 8, length ~/ 2);
    return decodeCp1252(Uint8List.sublistView(_data, at + 8, at + 8 + length));
  }

  /// Semua rekaman bertipe [type] di antara [from] dan [to], menelusuri wadah.
  Iterable<int> _all(int from, int to, int type) sync* {
    var p = from;
    while (p + 8 <= to && _fits(p)) {
      if (_type(p) == type) {
        yield p;
      } else if (_isContainer(p)) {
        yield* _all(p + 8, p + 8 + _length(p), type);
      }
      p += 8 + _length(p);
    }
  }

  /// Nomor persist → letak rekaman. Suntingan terbaru menang.
  Map<int, int> _persistDirectory(Uint8List? currentUser) {
    final map = <int, int>{};
    if (currentUser == null || currentUser.length < 20) return map;
    var edit = ByteData.sublistView(currentUser).getUint32(16, Endian.little);
    var guard = 0;
    while (edit > 0 && edit + 28 <= _data.length && guard++ < 1000) {
      if (_type(edit) != _userEditAtom) break;
      final dir = _view.getUint32(edit + 8 + 12, Endian.little);
      if (dir + 8 <= _data.length && _type(dir) == _persistDirectoryAtom) {
        final end = dir + 8 + _length(dir);
        var p = dir + 8;
        while (p + 4 <= end) {
          final head = _view.getUint32(p, Endian.little);
          final first = head & 0xFFFFF;
          final count = head >> 20;
          p += 4;
          for (var i = 0; i < count && p + 4 <= end; i++) {
            map.putIfAbsent(first + i, () => _view.getUint32(p, Endian.little));
            p += 4;
          }
        }
      }
      if (_documentRef == null) {
        final ref = _view.getUint32(edit + 8 + 16, Endian.little);
        _documentRef = ref;
      }
      edit = _view.getUint32(edit + 8 + 8, Endian.little);
    }
    return map;
  }

  int? _documentRef;

  int? _findDocument(Map<int, int> persist) {
    final ref = _documentRef;
    final at = ref == null ? null : persist[ref];
    if (at != null && at + 8 <= _data.length && _type(at) == _document) return at;
    return _all(0, _data.length, _document).firstOrNull;
  }
}
