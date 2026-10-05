import 'dart:ffi';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/reader/data/pdf_page_editor.dart';

/// PDF beranotasi harus tetap PDF yang sama: teksnya tetap teks.
///
/// Dulu setiap halaman dirender jadi gambar JPEG: teks tidak bisa dicari atau
/// disalin, tabel jadi foto. Uji ini membuat PDF berisi teks sungguhan,
/// menambahkan anotasi, lalu membuka hasilnya lagi dengan pdfium.
void main() {
  final module = <String>[
    'build/native_assets/linux/libpdfium.so',
    '.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811/linux-x64/libpdfium.so',
  ].where((path) => File(path).existsSync()).firstOrNull;
  if (module == null) {
    test('ekspor anotasi', () {}, skip: 'libpdfium.so belum ada — jalankan flutter build dulu');
    return;
  }
  PdfPageEditor.modulePath = module;
  final lib = pdfium.getPdfium(modulePath: module)..FPDF_InitLibrary();

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('rp_anot_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Pointer<Uint16> wide(String s) {
    final out = calloc<Uint16>(s.length + 1);
    for (var i = 0; i < s.length; i++) {
      out[i] = s.codeUnitAt(i);
    }
    out[s.length] = 0;
    return out;
  }

  /// Satu halaman A4 berisi satu baris teks, ditulis pdfium sendiri.
  String textPdf() {
    final doc = lib.FPDF_CreateNewDocument();
    final page = lib.FPDFPage_New(doc, 0, 595, 842);
    final font = 'Helvetica'.toNativeUtf8();
    final text = lib.FPDFPageObj_NewTextObj(doc, font.cast(), 14);
    final words = wide('Quantum anomaly detection on ledgers');
    lib.FPDFText_SetText(text, words.cast());
    lib.FPDFPageObj_Transform(text, 1, 0, 0, 1, 72, 700);
    lib.FPDFPage_InsertObject(page, text);
    lib.FPDFPage_GenerateContent(page);
    lib.FPDF_ClosePage(page);
    final path = p.join(dir.path, 'asli.pdf');
    final out = File(path);
    // Disimpan lewat jalur yang sama dengan kode aplikasinya.
    out.writeAsBytesSync(
      PdfPageEditor.withAnnotations(source: _saveTemp(lib, doc, dir), annotationsFor: (_) => []),
    );
    malloc.free(font);
    calloc.free(words);
    lib.FPDF_CloseDocument(doc);
    return path;
  }

  ({String text, int images, int paths, int textObjects, int annots}) inspect(List<int> bytes) {
    final path = p.join(dir.path, 'hasil.pdf');
    File(path).writeAsBytesSync(bytes);
    final native = path.toNativeUtf8();
    final doc = lib.FPDF_LoadDocument(native.cast(), nullptr);
    malloc.free(native);
    final page = lib.FPDF_LoadPage(doc, 0);
    var images = 0, paths = 0, texts = 0;
    for (var i = 0; i < lib.FPDFPage_CountObjects(page); i++) {
      final type = lib.FPDFPageObj_GetType(lib.FPDFPage_GetObject(page, i));
      if (type == 3) images++;
      if (type == 2) paths++;
      if (type == 1) texts++;
    }
    final textPage = lib.FPDFText_LoadPage(page);
    final count = lib.FPDFText_CountChars(textPage);
    final buffer = calloc<Uint16>(count + 1);
    lib.FPDFText_GetText(textPage, 0, count, buffer.cast());
    final text = String.fromCharCodes(buffer.asTypedList(count));
    calloc.free(buffer);
    final annots = lib.FPDFPage_GetAnnotCount(page);
    lib.FPDFText_ClosePage(textPage);
    lib.FPDF_ClosePage(page);
    lib.FPDF_CloseDocument(doc);
    return (text: text, images: images, paths: paths, textObjects: texts, annots: annots);
  }

  test('teks tetap teks, coretan jadi vektor, komentar jadi catatan PDF', () {
    final source = textPdf();
    ZoteroAnnotation a(AnnotationType type, {String comment = '', Map<String, dynamic>? raw}) =>
        ZoteroAnnotation(
          key: 'K${type.name}',
          parentItemKey: 'P',
          type: type,
          color: '#ffd400',
          pageIndex: 0,
          rects: const <AnnotationRect>[AnnotationRect(70, 695, 330, 716)],
          paths: const <InkPath>[
            InkPath(<double>[100, 600, 150, 620, 200, 590]),
          ],
          inkWidth: 3,
          comment: comment,
          rawPosition: raw,
        );
    final bytes = PdfPageEditor.withAnnotations(
      source: source,
      annotationsFor: (page) => page == 1
          ? <ZoteroAnnotation>[
              a(AnnotationType.highlight, comment: 'Penting untuk bab 2'),
              a(AnnotationType.ink),
              a(
                AnnotationType.text,
                comment: 'Nama: Hendri',
                raw: <String, dynamic>{'fontSize': 11},
              ),
            ]
          : const <ZoteroAnnotation>[],
    );

    final result = inspect(bytes);
    expect(result.text, contains('Quantum anomaly detection'), reason: 'teks asli tetap teks');
    expect(result.text, contains('Nama: Hendri'), reason: 'isian Tt jadi teks PDF');
    expect(result.images, 0, reason: 'tidak ada halaman yang jadi gambar');
    expect(result.paths, greaterThanOrEqualTo(2), reason: 'stabilo dan coretan jadi vektor');
    expect(result.annots, 1, reason: 'komentar stabilo jadi catatan tempel PDF');
  });
}

String _saveTemp(pdfium.PDFium lib, pdfium.FPDF_DOCUMENT doc, Directory dir) {
  // Dokumen baru belum punya berkas; ditulis dulu lewat FPDF_SaveAsCopy.
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
  final path = p.join(dir.path, 'mentah.pdf');
  File(path).writeAsBytesSync(chunks);
  return path;
}
