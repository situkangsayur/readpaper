import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../library/domain/entities/zotero_annotation.dart';

/// Gambar yang ditempel di halaman PDF — dari papan klip atau dari berkas.
///
/// Di memori ia anotasi biasa berjenis `image` dengan satu kotak, supaya
/// menggeser, mengubah ukuran, menyalin, memindah halaman, dan urungkan
/// berlaku tanpa jalur kedua. Bedanya hanya penanda [marker] di posisinya,
/// yang menunjuk ke berkas gambarnya.
///
/// Gambar ini **tidak pernah** ditulis ke ekspor Zotero. Anotasi `image`
/// Zotero adalah tangkapan wilayah halaman, bukan gambar tempelan — menaruh
/// yang ini di sana membuat Zotero menampilkan kotak kosong yang tidak bisa
/// dijelaskan. Untuk paper library ia disimpan di `catatan/gambar-halaman/`
/// ([PagePictureStore]); untuk PDF lepas ia hidup di memori sampai PDF-nya
/// disimpan, dan saat itu dilebur ke halaman.
class PagePicture {
  const PagePicture._();

  static const String marker = 'readpaperImage';

  static bool isPicture(ZoteroAnnotation annotation) =>
      annotation.type == AnnotationType.image && fileOf(annotation) != null;

  static String? fileOf(ZoteroAnnotation annotation) {
    final value = annotation.rawPosition?[marker];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// Sisi terpanjang setelah diperkecil. Cukup tajam dicetak selebar halaman
  /// A4, dan menjaga repositori dari foto 12 megapiksel yang ditempel apa
  /// adanya.
  static const int maxSide = 2000;

  /// Gambar yang siap disimpan: diperkecil bila perlu, PNG bila punya bagian
  /// transparan, selain itu JPEG — tangkapan layar tetap tajam, foto tetap
  /// kecil. Null bila bukan gambar yang bisa dibaca.
  static PreparedPicture? prepare(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on Object {
      // Pengurai gambar melempar untuk isi yang rusak atau bukan gambar.
      return null;
    }
    if (decoded == null || decoded.width == 0 || decoded.height == 0) return null;
    var image = decoded;
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
    }
    final transparent = image.hasAlpha && _anyTransparent(image);
    final out = transparent
        ? img.encodePng(image, level: 6)
        : img.encodeJpg(image.hasAlpha ? image.convert(numChannels: 3) : image, quality: 88);
    return PreparedPicture(
      bytes: Uint8List.fromList(out),
      extension: transparent ? '.png' : '.jpg',
      width: image.width,
      height: image.height,
    );
  }

  static bool _anyTransparent(img.Image image) {
    // Dicuplik, bukan diperiksa seluruhnya: gambar 2000×2000 punya empat juta
    // piksel, dan tepi tangkapan layar yang transparan pasti kena cuplikan.
    final stepX = (image.width / 64).ceil().clamp(1, image.width);
    final stepY = (image.height / 64).ceil().clamp(1, image.height);
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        if (image.getPixel(x, y).a < image.maxChannelValue) return true;
      }
    }
    return false;
  }

  /// Kotak gambar di tengah halaman: selebar setengah halaman paling besar,
  /// tidak diperbesar melebihi ukuran aslinya (96 dpi), rasio tetap.
  static AnnotationRect placeCentered({
    required int width,
    required int height,
    required double pageWidth,
    required double pageHeight,
    double? centerX,
    double? centerY,
  }) {
    var w = width * 72 / 96;
    var h = height * 72 / 96;
    final maxW = pageWidth * 0.5;
    final maxH = pageHeight * 0.5;
    final shrink = [1.0, maxW / w, maxH / h].reduce((a, b) => a < b ? a : b);
    w *= shrink;
    h *= shrink;
    // Di titik tengah yang diminta — biasanya tengah bagian halaman yang
    // sedang terlihat — tetapi tetap utuh di dalam halaman.
    final cx = centerX ?? pageWidth / 2;
    final cy = centerY ?? pageHeight / 2;
    final left = (cx - w / 2).clamp(0.0, pageWidth - w);
    final bottom = (cy - h / 2).clamp(0.0, pageHeight - h);
    return AnnotationRect(left, bottom, left + w, bottom + h);
  }

  /// Anotasi baru untuk gambar [file] di kotak [rect].
  static ZoteroAnnotation create({
    required String key,
    required String parentItemKey,
    required int pageIndex,
    required AnnotationRect rect,
    required String file,
    required double pageHeight,
  }) {
    final now = DateTime.now();
    return ZoteroAnnotation(
      key: key,
      parentItemKey: parentItemKey,
      type: AnnotationType.image,
      color: '#aaaaaa',
      pageIndex: pageIndex,
      rects: <AnnotationRect>[rect],
      pageLabel: '${pageIndex + 1}',
      sortIndex: ZoteroAnnotation.buildSortIndex(
        pageIndex: pageIndex,
        textOffset: 0,
        topFromPageTop: pageHeight - rect.top,
      ),
      rawPosition: <String, dynamic>{marker: file},
      dateAdded: now,
      dateModified: now,
    );
  }
}

class PreparedPicture {
  const PreparedPicture({
    required this.bytes,
    required this.extension,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String extension;
  final int width;
  final int height;
}

/// Gambar halaman sebuah lampiran di repositori:
///
/// ```
/// <repo>/catatan/gambar-halaman/<KUNCI LAMPIRAN>/
///   gambar.json      daftar anotasi gambar, bentuknya sama dengan anotasi Zotero
///   <berkas>.png|jpg isinya
/// ```
///
/// Di luar `zotero/`, sama seperti catatan lain: plugin sinkronisasi menjaga
/// struktur itu byte demi byte.
class PagePictureStore {
  const PagePictureStore(this.directory);

  static const String dirName = 'gambar-halaman';

  static String directoryFor({required String repoRoot, required String attachmentKey}) =>
      p.join(repoRoot, 'catatan', dirName, attachmentKey);

  final String directory;

  File get _index => File(p.join(directory, 'gambar.json'));

  Future<List<ZoteroAnnotation>> load() async {
    final file = _index;
    if (!file.existsSync()) return const <ZoteroAnnotation>[];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const <ZoteroAnnotation>[];
      return <ZoteroAnnotation>[
        for (final entry in decoded)
          if (entry is Map) ZoteroAnnotation.fromJson(entry.cast<String, dynamic>()),
      ].where(PagePicture.isPicture).toList();
    } on FormatException {
      return const <ZoteroAnnotation>[];
    }
  }

  Future<Uint8List?> bytes(String fileName) async {
    final file = File(p.join(directory, p.basename(fileName)));
    return file.existsSync() ? file.readAsBytes() : null;
  }

  /// Menambah atau mengganti [annotation]; [bytes] ditulis bila berkasnya
  /// belum ada.
  Future<void> put(ZoteroAnnotation annotation, {Uint8List? bytes}) async {
    final fileName = PagePicture.fileOf(annotation);
    if (fileName == null) throw ArgumentError('Bukan anotasi gambar');
    await Directory(directory).create(recursive: true);
    final target = File(p.join(directory, p.basename(fileName)));
    if (bytes != null && !target.existsSync()) await target.writeAsBytes(bytes, flush: true);
    final all = <ZoteroAnnotation>[
      for (final a in await load())
        if (a.key != annotation.key) a,
      annotation,
    ];
    await _write(all);
  }

  /// Membuang anotasi [key], dan berkas gambarnya bila tidak dipakai lagi.
  Future<void> remove(String key) async {
    final all = await load();
    final gone = all.where((a) => a.key == key).firstOrNull;
    if (gone == null) return;
    final rest = all.where((a) => a.key != key).toList();
    await _write(rest);
    final fileName = PagePicture.fileOf(gone)!;
    if (!rest.any((a) => PagePicture.fileOf(a) == fileName)) {
      final file = File(p.join(directory, p.basename(fileName)));
      if (file.existsSync()) await file.delete();
    }
    if (rest.isEmpty) {
      if (_index.existsSync()) await _index.delete();
      final dir = Directory(directory);
      if (dir.existsSync() && dir.listSync().isEmpty) await dir.delete();
    }
  }

  Future<void> _write(List<ZoteroAnnotation> all) async {
    if (all.isEmpty) {
      if (_index.existsSync()) await _index.delete();
      return;
    }
    all.sort((a, b) => a.key.compareTo(b.key));
    const encoder = JsonEncoder.withIndent('\t');
    await _index.writeAsString('${encoder.convert(all.map((a) => a.toJson()).toList())}\n');
  }
}
