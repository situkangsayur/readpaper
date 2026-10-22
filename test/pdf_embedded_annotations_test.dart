import 'dart:ffi';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/reader/data/pdf_embedded_annotations.dart';

/// Anotasi yang tertanam di PDF — dari Acrobat, Okular, skrip — terbaca:
/// jenisnya, letaknya, komentarnya, penulisnya, dan teks yang distabilo.
/// Zotero membacanya; ReadPaper dulu tidak.
void main() {
  final module = <String>[
    'build/native_assets/linux/libpdfium.so',
    '.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811/linux-x64/libpdfium.so',
  ].where((path) => File(path).existsSync()).firstOrNull;
  if (module == null) {
    test('anotasi tertanam', () {}, skip: 'libpdfium.so belum ada — jalankan flutter build dulu');
    return;
  }
  final lib = pdfium.getPdfium(modulePath: module)..FPDF_InitLibrary();

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('rp_tertanam_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Pointer<Uint16> wide(String s) {
    final out = calloc<Uint16>(s.length + 1);
    for (var i = 0; i < s.length; i++) {
      out[i] = s.codeUnitAt(i);
    }
    out[s.length] = 0;
    return out;
  }

  void setString(pdfium.FPDF_ANNOTATION annot, String key, String value) {
    final k = key.toNativeUtf8();
    final v = wide(value);
    lib.FPDFAnnot_SetStringValue(annot, k.cast(), v.cast());
    malloc.free(k);
    calloc.free(v);
  }

  List<ZoteroAnnotation> readBack(pdfium.FPDF_DOCUMENT doc) {
    // Disimpan lalu dibuka lagi, supaya yang dibaca benar-benar isi berkas.
    final chunks = <int>[];
    final callback =
        NativeCallable<
          Int Function(Pointer<pdfium.FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
        >.isolateLocal((Pointer<pdfium.FPDF_FILEWRITE> _, Pointer<Void> data, int size) {
          chunks.addAll(data.cast<Uint8>().asTypedList(size));
          return 1;
        }, exceptionalReturn: 0);
    final writer = calloc<pdfium.FPDF_FILEWRITE>();
    writer.ref.version = 1;
    writer.ref.WriteBlock = callback.nativeFunction;
    lib.FPDF_SaveAsCopy(doc, writer, 0);
    calloc.free(writer);
    callback.close();
    final path = p.join(dir.path, 'beranotasi.pdf');
    File(path).writeAsBytesSync(chunks);
    final native = path.toNativeUtf8();
    final reopened = lib.FPDF_LoadDocument(native.cast(), nullptr);
    malloc.free(native);
    try {
      return PdfEmbeddedAnnotations.readDocument(lib, reopened);
    } finally {
      lib.FPDF_CloseDocument(reopened);
    }
  }

  test('stabilo dengan komentar dan catatan tempel dari aplikasi lain terbaca', () {
    final doc = lib.FPDF_CreateNewDocument();
    final page = lib.FPDFPage_New(doc, 0, 595, 842);
    final font = 'Helvetica'.toNativeUtf8();
    final text = lib.FPDFPageObj_NewTextObj(doc, font.cast(), 14);
    final words = wide('Quantum anomaly detection on ledgers');
    lib.FPDFText_SetText(text, words.cast());
    lib.FPDFPageObj_Transform(text, 1, 0, 0, 1, 72, 700);
    lib.FPDFPage_InsertObject(page, text);
    lib.FPDFPage_GenerateContent(page);

    // Stabilo kuning di atas baris teksnya, dengan komentar dan penulis.
    final highlight = lib.FPDFPage_CreateAnnot(page, 9);
    final quad = calloc<pdfium.FS_QUADPOINTSF>();
    quad.ref
      ..x1 = 70
      ..y1 = 716
      ..x2 = 330
      ..y2 = 716
      ..x3 = 70
      ..y3 = 696
      ..x4 = 330
      ..y4 = 696;
    lib.FPDFAnnot_AppendAttachmentPoints(highlight, quad);
    calloc.free(quad);
    lib.FPDFAnnot_SetColor(
      highlight,
      pdfium.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
      255,
      212,
      0,
      255,
    );
    setString(highlight, 'Contents', 'Definisi deteksi anomali.\r\nBaris kedua.');
    setString(highlight, 'T', 'Hendri Karisma');
    lib.FPDFPage_CloseAnnot(highlight);

    // Catatan tempel di pojok kiri atas.
    final note = lib.FPDFPage_CreateAnnot(page, 1);
    final rect = calloc<pdfium.FS_RECTF>();
    rect.ref
      ..left = 20
      ..bottom = 800
      ..right = 42
      ..top = 822;
    lib.FPDFAnnot_SetRect(note, rect);
    calloc.free(rect);
    setString(note, 'Contents', 'RINGKASAN: SLR atas 74 studi.');
    lib.FPDFPage_CloseAnnot(note);

    lib.FPDF_ClosePage(page);
    malloc.free(font);
    calloc.free(words);
    final found = readBack(doc);
    lib.FPDF_CloseDocument(doc);

    expect(found, hasLength(2));
    final h = found.firstWhere((a) => a.type == AnnotationType.highlight);
    expect(h.comment, 'Definisi deteksi anomali.\nBaris kedua.');
    expect(h.authorName, 'Hendri Karisma');
    expect(h.color, '#ffd400');
    expect(h.text, contains('Quantum anomaly detection'));
    expect(h.rects.single.left, closeTo(70, 0.5));
    expect(h.rects.single.top, closeTo(716, 0.5));
    expect(PdfEmbeddedAnnotations.isEmbedded(h), isTrue);

    final n = found.firstWhere((a) => a.type == AnnotationType.note);
    expect(n.comment, 'RINGKASAN: SLR atas 74 studi.');
    expect(n.pageIndex, 0);
    // Catatan di atas halaman diurutkan lebih dulu daripada stabilonya.
    expect(n.sortIndex.compareTo(h.sortIndex), lessThan(0));
  });

  // PDF sungguhan dari laporan: 185 stabilo dan 186 catatan tempel, terbaca
  // Zotero. Hanya bila berkasnya ada di mesin ini.
  final kamath = Platform.environment['RP_KAMATH_PDF'];
  test(
    'PDF Kamath dkk.: semua anotasinya terbaca',
    () {
      final native = kamath!.toNativeUtf8();
      final doc = lib.FPDF_LoadDocument(native.cast(), nullptr);
      malloc.free(native);
      final found = PdfEmbeddedAnnotations.readDocument(lib, doc);
      lib.FPDF_CloseDocument(doc);
      expect(found.where((a) => a.type == AnnotationType.highlight), hasLength(185));
      expect(found.where((a) => a.type == AnnotationType.note), hasLength(186));
      expect(found.where((a) => a.hasComment).length, greaterThan(180));
      expect(found.any((a) => a.comment.startsWith('RINGKASAN')), isTrue);
    },
    skip: kamath == null || !File(kamath).existsSync() ? 'RP_KAMATH_PDF tidak diisi' : false,
  );
}
