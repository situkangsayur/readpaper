import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;

import '../../library/domain/entities/zotero_annotation.dart';
import 'page_picture.dart';

/// Menyusun ulang halaman sebuah PDF tanpa menggambar ulang isinya.
///
/// Menambahkan halaman kosong ke sebuah dokumen bisa dikerjakan dengan cara
/// yang mudah — merender semua halaman jadi gambar lalu menyusun PDF baru —
/// dan hasilnya adalah dokumen yang teksnya tidak bisa dicari, tidak bisa
/// disalin, dan besarnya berlipat. Untuk paper yang dibaca berulang kali itu
/// kerugian yang tidak sepadan.
///
/// Jadi yang dipakai adalah pdfium, mesin yang sama yang sudah memuat PDF-nya
/// di layar: halaman aslinya **disalin sebagai objek PDF**, bukan sebagai
/// gambar. Teks, tautan, dan vektornya utuh.
class PdfPageEditor {
  const PdfPageEditor._();

  /// Jalur pustaka pdfium, kalau harus disebutkan sendiri.
  ///
  /// Di aplikasi yang sudah berjalan, pustakanya sudah dimuat penampil PDF
  /// dan ini tidak perlu diisi. Di `flutter test` tidak ada yang memuatnya,
  /// jadi ujinya menunjuk ke berkas hasil unduhan build.
  static String? modulePath;

  static pdfium.PDFium _library() {
    final lib = pdfium.getPdfium(modulePath: modulePath);
    // Aman dipanggil lagi: pdfium menyiapkan keadaan globalnya sekali, dan
    // pemanggil lain (penampil di layar) mungkin sudah melakukannya.
    lib.FPDF_InitLibrary();
    return lib;
  }

  /// Ukuran A4 dalam titik PDF, dipakai kalau dokumennya tidak punya halaman
  /// yang bisa ditiru ukurannya.
  static const double a4Width = 595.276;
  static const double a4Height = 841.89;

  /// Menyalin [source] ke [target] dengan [count] halaman kosong disisipkan.
  ///
  /// [at] menentukan tempatnya: null berarti di akhir, 0 berarti di depan.
  /// Ukuran halaman barunya mengikuti halaman pertama dokumennya, supaya
  /// papan tulisnya tidak tiba-tiba berbeda ukuran dari papernya.
  static Future<void> addBlankPages({
    required String source,
    required String target,
    int count = 1,
    int? at,
  }) async {
    if (count < 1) throw ArgumentError.value(count, 'count', 'minimal satu halaman');
    if (!File(source).existsSync()) {
      throw FileSystemException('Berkas asalnya tidak ada', source);
    }

    final lib = _library();

    final sourcePath = source.toNativeUtf8();
    final srcDoc = lib.FPDF_LoadDocument(sourcePath.cast(), nullptr);
    calloc.free(sourcePath);
    if (srcDoc == nullptr) {
      throw const FormatException('PDF-nya tidak bisa dibaca');
    }

    final dstDoc = lib.FPDF_CreateNewDocument();
    try {
      // Pointer kosong berarti "semua halaman", sesuai dokumentasi pdfium.
      final imported = lib.FPDF_ImportPagesByIndex(dstDoc, srcDoc, nullptr, 0, 0);
      if (imported == 0) {
        throw const FormatException('Halaman aslinya tidak bisa disalin');
      }

      final pageCount = lib.FPDF_GetPageCount(dstDoc);
      var width = a4Width;
      var height = a4Height;
      if (pageCount > 0) {
        final first = lib.FPDF_LoadPage(dstDoc, 0);
        if (first != nullptr) {
          width = lib.FPDF_GetPageWidthF(first);
          height = lib.FPDF_GetPageHeightF(first);
          lib.FPDF_ClosePage(first);
        }
      }

      final start = at ?? pageCount;
      for (var i = 0; i < count; i++) {
        final page = lib.FPDFPage_New(dstDoc, start + i, width, height);
        if (page == nullptr) {
          throw const FormatException('Halaman kosongnya tidak bisa dibuat');
        }
        lib.FPDF_ClosePage(page);
      }

      await _save(lib, dstDoc, target);
    } finally {
      lib.FPDF_CloseDocument(dstDoc);
      lib.FPDF_CloseDocument(srcDoc);
    }
  }

  /// Menggabungkan beberapa PDF jadi satu, berurutan.
  ///
  /// Dipakai saat papan tulis yang berdiri sendiri ditempelkan ke sebuah
  /// paper, dan saat beberapa berkas disatukan sebelum dibagikan.
  static Future<void> merge({required List<String> sources, required String target}) async {
    if (sources.isEmpty) throw ArgumentError('tidak ada berkas untuk digabung');

    final lib = _library();
    final dstDoc = lib.FPDF_CreateNewDocument();

    try {
      for (final source in sources) {
        if (!File(source).existsSync()) {
          throw FileSystemException('Berkasnya tidak ada', source);
        }
        final path = source.toNativeUtf8();
        final doc = lib.FPDF_LoadDocument(path.cast(), nullptr);
        calloc.free(path);
        if (doc == nullptr) throw FormatException('Tidak bisa dibaca: $source');
        try {
          lib.FPDF_ImportPagesByIndex(dstDoc, doc, nullptr, 0, lib.FPDF_GetPageCount(dstDoc));
        } finally {
          lib.FPDF_CloseDocument(doc);
        }
      }
      await _save(lib, dstDoc, target);
    } finally {
      lib.FPDF_CloseDocument(dstDoc);
    }
  }

  /// Berapa halaman sebuah PDF, tanpa membuka penampil.
  static int pageCount(String path) {
    final lib = _library();
    final native = path.toNativeUtf8();
    final doc = lib.FPDF_LoadDocument(native.cast(), nullptr);
    calloc.free(native);
    if (doc == nullptr) return 0;
    final count = lib.FPDF_GetPageCount(doc);
    lib.FPDF_CloseDocument(doc);
    return count;
  }

  /// Menulis dokumen ke berkas lewat FPDF_SaveAsCopy.
  ///
  /// pdfium tidak menulis ke berkas sendiri: ia memanggil balik sebuah fungsi
  /// untuk tiap potongan. Potongannya dikumpulkan di memori lalu ditulis
  /// sekali, karena panggilan baliknya berjalan di tengah pemanggilan pdfium
  /// dan menulis berkas dari sana mengundang kesulitan yang tidak perlu.
  static Future<void> _save(pdfium.PDFium lib, pdfium.FPDF_DOCUMENT doc, String target) async {
    final file = File(target);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(_bytes(lib, doc), flush: true);
  }

  static Uint8List _bytes(pdfium.PDFium lib, pdfium.FPDF_DOCUMENT doc) {
    final chunks = BytesBuilder(copy: false);

    late final NativeCallable<
      Int Function(Pointer<pdfium.FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
    >
    callback;
    callback =
        NativeCallable<
          Int Function(Pointer<pdfium.FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
        >.isolateLocal((Pointer<pdfium.FPDF_FILEWRITE> _, Pointer<Void> data, int size) {
          chunks.add(Uint8List.fromList(data.cast<Uint8>().asTypedList(size)));
          return 1;
        }, exceptionalReturn: 0);

    final writer = calloc<pdfium.FPDF_FILEWRITE>();
    try {
      writer.ref.version = 1;
      writer.ref.WriteBlock = callback.nativeFunction;

      // 0 berarti "salinan biasa"; tanpa penulisan bertahap yang menyisakan
      // sisa dokumen lama di dalam berkasnya.
      final ok = lib.FPDF_SaveAsCopy(doc, writer, 0);
      if (ok == 0) throw const FormatException('PDF-nya gagal ditulis');
      return chunks.takeBytes();
    } finally {
      calloc.free(writer);
      callback.close();
    }
  }

  // ------------------------------------------------------- anotasi ke halaman

  /// [source] dengan anotasinya digambar di atas halaman aslinya.
  ///
  /// Dulu PDF beranotasi dibuat dengan merender setiap halaman jadi gambar:
  /// teks tidak bisa dicari atau disalin lagi, tabel jadi foto, dan berkasnya
  /// membengkak. Sekarang halaman aslinya dibiarkan apa adanya — teks, tabel,
  /// tautan, dan vektornya utuh — dan hanya anotasinya yang ditambahkan,
  /// sebagai objek vektor PDF:
  ///
  /// - stabilo: kotak transparan dengan campuran *multiply*, jadi teks di
  ///   bawahnya tetap terbaca dan tetap bisa dipilih;
  /// - garis bawah: garis tipis;
  /// - coretan: jalur bergaris bulat, setebal di layar;
  /// - isian teks (Tt): teks PDF sungguhan, bukan gambar teks;
  /// - komentar: catatan tempel PDF, yang dibuka dengan mengetuknya di
  ///   pembaca PDF mana pun.
  static Uint8List withAnnotations({
    required String source,
    required List<ZoteroAnnotation> Function(int pageNumber) annotationsFor,
    Map<String, Uint8List> pictures = const <String, Uint8List>{},
  }) {
    final lib = _library();
    final path = source.toNativeUtf8();
    final doc = lib.FPDF_LoadDocument(path.cast(), nullptr);
    malloc.free(path);
    if (doc == nullptr) throw FileSystemException('PDF-nya tidak bisa dibuka', source);
    try {
      final count = lib.FPDF_GetPageCount(doc);
      for (var i = 0; i < count; i++) {
        final annotations = annotationsFor(i + 1);
        if (annotations.isEmpty) continue;
        final page = lib.FPDF_LoadPage(doc, i);
        if (page == nullptr) continue;
        try {
          for (final annotation in annotations) {
            final file = PagePicture.fileOf(annotation);
            if (PagePicture.isPicture(annotation)) {
              final bytes = pictures[file];
              if (bytes != null) _drawPicture(lib, doc, page, annotation, bytes);
              continue;
            }
            _drawAnnotation(lib, doc, page, annotation);
          }
          if (lib.FPDFPage_GenerateContent(page) == 0) {
            throw const FormatException('Isi halaman gagal ditulis ulang');
          }
        } finally {
          lib.FPDF_ClosePage(page);
        }
      }
      return _bytes(lib, doc);
    } finally {
      lib.FPDF_CloseDocument(doc);
    }
  }

  static const int _fillNone = 0;
  static const int _fillAlternate = 1;
  static const int _capRound = 1;
  static const int _joinRound = 1;
  static const int _annotText = 1;

  /// Gambar tempelan sebagai objek gambar PDF di kotaknya. Bagian yang
  /// transparan tetap transparan: pdfium membuat topeng alfanya sendiri dari
  /// bitmap BGRA.
  static void _drawPicture(
    pdfium.PDFium lib,
    pdfium.FPDF_DOCUMENT doc,
    pdfium.FPDF_PAGE page,
    ZoteroAnnotation annotation,
    Uint8List encoded,
  ) {
    if (annotation.rects.isEmpty) return;
    img.Image? decoded;
    try {
      decoded = img.decodeImage(encoded);
    } on Object {
      return;
    }
    if (decoded == null) return;
    final w = decoded.width;
    final h = decoded.height;
    final pixels = decoded.convert(numChannels: 4).getBytes(order: img.ChannelOrder.bgra);
    // BGRA hanya bila memang ada transparansi: pdfium selalu menambahkan
    // topeng alfa untuk BGRA, dan foto JPEG tidak perlu membawanya.
    var transparent = false;
    for (var i = 3; i < pixels.length; i += 4) {
      if (pixels[i] != 255) {
        transparent = true;
        break;
      }
    }
    const bgrx = 3;
    const bgra = 4;
    final bitmap = lib.FPDFBitmap_CreateEx(w, h, transparent ? bgra : bgrx, nullptr, 0);
    if (bitmap == nullptr) return;
    try {
      final stride = lib.FPDFBitmap_GetStride(bitmap);
      final buffer = lib.FPDFBitmap_GetBuffer(bitmap).cast<Uint8>().asTypedList(stride * h);
      for (var y = 0; y < h; y++) {
        buffer.setRange(y * stride, y * stride + w * 4, pixels, y * w * 4);
      }
      final object = lib.FPDFPageObj_NewImageObj(doc);
      if (lib.FPDFImageObj_SetBitmap(nullptr, 0, object, bitmap) == 0) {
        lib.FPDFPageObj_Destroy(object);
        return;
      }
      final box = annotation.rects.first;
      lib.FPDFImageObj_SetMatrix(object, box.width, 0, 0, box.height, box.left, box.bottom);
      lib.FPDFPage_InsertObject(page, object);
    } finally {
      lib.FPDFBitmap_Destroy(bitmap);
    }
  }

  static void _drawAnnotation(
    pdfium.PDFium lib,
    pdfium.FPDF_DOCUMENT doc,
    pdfium.FPDF_PAGE page,
    ZoteroAnnotation annotation,
  ) {
    final (r, g, b) = _rgb(annotation.color);
    switch (annotation.type) {
      case AnnotationType.highlight:
        for (final rect in annotation.rects) {
          final box = lib.FPDFPageObj_CreateNewRect(
            rect.left,
            rect.bottom,
            rect.width,
            rect.height,
          );
          lib.FPDFPageObj_SetFillColor(box, r, g, b, 110);
          lib.FPDFPath_SetDrawMode(box, _fillAlternate, 0);
          _blend(lib, box, 'Multiply');
          lib.FPDFPage_InsertObject(page, box);
        }
      case AnnotationType.underline:
        for (final rect in annotation.rects) {
          final line = lib.FPDFPageObj_CreateNewRect(rect.left, rect.bottom, rect.width, 1.6);
          lib.FPDFPageObj_SetFillColor(line, r, g, b, 230);
          lib.FPDFPath_SetDrawMode(line, _fillAlternate, 0);
          lib.FPDFPage_InsertObject(page, line);
        }
      case AnnotationType.ink:
        for (final stroke in annotation.paths) {
          if (stroke.length == 0) continue;
          final path = lib.FPDFPageObj_CreateNewPath(stroke.xAt(0), stroke.yAt(0));
          if (stroke.length == 1) {
            // Satu ketukan adalah titik; garis sepanjang nol tidak tergambar
            // tanpa ujung bulat, jadi diberi panjang sekecil mungkin.
            lib.FPDFPath_LineTo(path, stroke.xAt(0) + 0.01, stroke.yAt(0));
          }
          for (var i = 1; i < stroke.length; i++) {
            lib.FPDFPath_LineTo(path, stroke.xAt(i), stroke.yAt(i));
          }
          lib.FPDFPageObj_SetStrokeColor(path, r, g, b, 235);
          lib.FPDFPageObj_SetStrokeWidth(path, annotation.inkWidth);
          lib.FPDFPageObj_SetLineCap(path, _capRound);
          lib.FPDFPageObj_SetLineJoin(path, _joinRound);
          lib.FPDFPath_SetDrawMode(path, _fillNone, 1);
          lib.FPDFPage_InsertObject(page, path);
        }
      case AnnotationType.image:
        for (final rect in annotation.rects) {
          final box = lib.FPDFPageObj_CreateNewRect(
            rect.left,
            rect.bottom,
            rect.width,
            rect.height,
          );
          lib.FPDFPageObj_SetStrokeColor(box, r, g, b, 255);
          lib.FPDFPageObj_SetStrokeWidth(box, 1.5);
          lib.FPDFPath_SetDrawMode(box, _fillNone, 1);
          lib.FPDFPage_InsertObject(page, box);
        }
      case AnnotationType.text:
        final content = annotation.comment.trim();
        if (content.isNotEmpty && annotation.rects.isNotEmpty) {
          _drawText(lib, doc, page, annotation, content, (r, g, b));
          return; // kata-katanya sudah di halaman; tidak perlu catatan tempel
        }
      case AnnotationType.note:
        break;
    }

    // Komentar — dari catatan, atau yang menempel pada stabilo dan coretan —
    // jadi catatan tempel PDF di sudut kiri atas anotasinya.
    final comment = annotation.comment.trim();
    final anchor = _topLeft(annotation);
    if (comment.isEmpty || anchor == null) return;
    final note = lib.FPDFPage_CreateAnnot(page, _annotText);
    if (note == nullptr) return;
    final rect = calloc<pdfium.FS_RECTF>();
    try {
      rect.ref
        ..left = anchor.$1
        ..top = anchor.$2
        ..right = anchor.$1 + 18
        ..bottom = anchor.$2 - 18;
      lib.FPDFAnnot_SetRect(note, rect);
      lib.FPDFAnnot_SetColor(
        note,
        pdfium.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
        r,
        g,
        b,
        255,
      );
      _setString(lib, note, 'Contents', comment);
      _setString(
        lib,
        note,
        'T',
        annotation.authorName.isEmpty ? 'ReadPaper' : annotation.authorName,
      );
    } finally {
      calloc.free(rect);
      lib.FPDFPage_CloseAnnot(note);
    }
  }

  /// Isian teks (alat Tt) sebagai teks PDF sungguhan.
  ///
  /// Huruf standar Helvetica, yang dikenal setiap pembaca PDF tanpa harus
  /// disematkan. Baris dibungkus kira-kira selebar kotaknya, seperti di layar.
  static void _drawText(
    pdfium.PDFium lib,
    pdfium.FPDF_DOCUMENT doc,
    pdfium.FPDF_PAGE page,
    ZoteroAnnotation annotation,
    String content,
    (int, int, int) color,
  ) {
    final size = (annotation.rawPosition?['fontSize'] as num?)?.toDouble() ?? 12;
    var left = annotation.rects.first.left;
    var top = annotation.rects.first.top;
    var width = annotation.rects.first.width;
    for (final rect in annotation.rects.skip(1)) {
      left = math.min(left, rect.left);
      top = math.max(top, rect.top);
      width = math.max(width, rect.right - left);
    }
    final perLine = width <= 1 ? 1 << 20 : math.max(1, (width / (size * 0.5)).floor());
    final lines = <String>[
      for (final paragraph in content.split('\n')) ..._wrap(paragraph, perLine),
    ];
    final font = 'Helvetica'.toNativeUtf8();
    try {
      for (var i = 0; i < lines.length; i++) {
        final text = lib.FPDFPageObj_NewTextObj(doc, font.cast(), size);
        if (text == nullptr) continue;
        final wide = _wide(lines[i]);
        lib.FPDFText_SetText(text, wide.cast());
        calloc.free(wide);
        lib.FPDFPageObj_SetFillColor(text, color.$1, color.$2, color.$3, 255);
        lib.FPDFPageObj_Transform(text, 1, 0, 0, 1, left, top - size * (1 + i * 1.15));
        lib.FPDFPage_InsertObject(page, text);
      }
    } finally {
      malloc.free(font);
    }
  }

  static List<String> _wrap(String paragraph, int perLine) {
    if (paragraph.length <= perLine) return <String>[paragraph];
    final out = <String>[];
    var line = StringBuffer();
    for (final word in paragraph.split(' ')) {
      if (line.isNotEmpty && line.length + 1 + word.length > perLine) {
        out.add(line.toString());
        line = StringBuffer();
      }
      if (line.isNotEmpty) line.write(' ');
      line.write(word);
    }
    if (line.isNotEmpty) out.add(line.toString());
    return out;
  }

  static (double, double)? _topLeft(ZoteroAnnotation annotation) {
    if (annotation.rects.isNotEmpty) {
      return (
        annotation.rects.map((r) => r.left).reduce(math.min),
        annotation.rects.map((r) => r.top).reduce(math.max),
      );
    }
    final points = annotation.paths.where((p) => p.length > 0).toList();
    if (points.isEmpty) return null;
    var x = double.infinity;
    var y = -double.infinity;
    for (final stroke in points) {
      for (var i = 0; i < stroke.length; i++) {
        x = math.min(x, stroke.xAt(i));
        y = math.max(y, stroke.yAt(i));
      }
    }
    return (x, y);
  }

  static void _blend(pdfium.PDFium lib, pdfium.FPDF_PAGEOBJECT object, String mode) {
    final native = mode.toNativeUtf8();
    lib.FPDFPageObj_SetBlendMode(object, native.cast());
    malloc.free(native);
  }

  static void _setString(
    pdfium.PDFium lib,
    pdfium.FPDF_ANNOTATION annot,
    String key,
    String value,
  ) {
    final k = key.toNativeUtf8();
    final v = _wide(value);
    lib.FPDFAnnot_SetStringValue(annot, k.cast(), v.cast());
    malloc.free(k);
    calloc.free(v);
  }

  /// UTF-16LE berakhiran nol, bentuk string yang diminta pdfium.
  static Pointer<Uint16> _wide(String value) {
    final units = value.codeUnits;
    final out = calloc<Uint16>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      out[i] = units[i];
    }
    out[units.length] = 0;
    return out;
  }

  static (int, int, int) _rgb(String hex) {
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean.length == 6 ? clean : 'ffd400', radix: 16) ?? 0xffd400;
    return ((value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff);
  }
}
