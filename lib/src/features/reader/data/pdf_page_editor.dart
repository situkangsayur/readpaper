import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;

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
    final chunks = <int>[];

    late final NativeCallable<
      Int Function(Pointer<pdfium.FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
    >
    callback;
    callback =
        NativeCallable<
          Int Function(Pointer<pdfium.FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
        >.isolateLocal((Pointer<pdfium.FPDF_FILEWRITE> _, Pointer<Void> data, int size) {
          chunks.addAll(data.cast<Uint8>().asTypedList(size));
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

      final file = File(target);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(chunks, flush: true);
    } finally {
      calloc.free(writer);
      callback.close();
    }
  }
}
