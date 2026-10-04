import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/src/features/markdown/data/markdown_pdf.dart';
import 'package:readpaper/src/features/markdown/domain/markdown_doc.dart';
import 'package:readpaper/src/features/notebook/data/note_document_store.dart';
import 'package:readpaper/src/features/notebook/data/pdf_to_notebook.dart';
import 'package:readpaper/src/features/notebook/domain/note_document.dart';

void main() {
  final module = <String>[
    'build/native_assets/linux/libpdfium.so',
    '.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811/linux-x64/libpdfium.so',
  ].where((path) => File(path).existsSync()).firstOrNull;
  if (module == null) {
    test(
      'PDF jadi buku catatan',
      () {},
      skip: 'libpdfium.so belum ada — jalankan flutter build dulu',
    );
    return;
  }
  Pdfrx.pdfiumModulePath = module;

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('rp-pdf-buku-'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> samplePdf({int pages = 2}) async {
    final markdown = StringBuffer();
    for (var i = 1; i <= pages; i++) {
      markdown.writeln('# Halaman $i\n');
      // Cukup panjang supaya tiap tajuk mendarat di halamannya sendiri.
      for (var j = 0; j < 40; j++) {
        markdown.writeln('Baris $j di halaman $i yang isinya sekadar mengisi ruang.\n');
      }
    }
    final path = p.join(dir.path, 'dokumen.pdf');
    File(path).writeAsBytesSync(await MarkdownPdf.build(MarkdownDoc.parse(markdown.toString())));
    return path;
  }

  test('tiap halaman jadi satu lembar beralas gambar halamannya', () async {
    final pdf = await samplePdf();
    final notePath = await PdfToNotebook.convert(
      pdfPath: pdf,
      targetDir: dir.path,
      title: 'Dokumen Uji',
      extraPages: 1,
    );

    expect(NoteDocumentStore.isNoteDocument(notePath), isTrue);
    final document = await NoteDocumentStore.read(notePath);
    expect(document.title, 'Dokumen Uji');
    expect(document.pages.length, greaterThanOrEqualTo(3), reason: 'halaman PDF + lembar kosong');

    // Lembar terakhir kosong: itu yang sebenarnya diminta — tempat menulis
    // catatan tambahan tanpa mengotori halaman dokumennya.
    expect(document.pages.last.components, isEmpty);

    final first = document.pages.first.components.single as NoteImage;
    expect(first.alt, 'Halaman 1');
    final image = File(p.join(dir.path, first.file));
    expect(image.existsSync(), isTrue, reason: first.file);
    expect(image.lengthSync(), greaterThan(500));
    expect(image.readAsBytesSync().sublist(1, 4), <int>[0x50, 0x4E, 0x47], reason: 'PNG');
  });

  test('halamannya muat di lembar tanpa jadi gepeng', () async {
    final pdf = await samplePdf(pages: 1);
    final notePath = await PdfToNotebook.convert(pdfPath: pdf, targetDir: dir.path);
    final document = await NoteDocumentStore.read(notePath);
    final page = document.pages.first.components.single as NoteImage;

    expect(page.position.dx, greaterThanOrEqualTo(0));
    expect(page.position.dy, greaterThanOrEqualTo(0));
    expect(page.size.width, lessThanOrEqualTo(NoteSheet.width + 0.01));
    expect(page.size.height, lessThanOrEqualTo(NoteSheet.height + 0.01));
    // A4 ke A4: perbandingan sisinya tidak berubah.
    expect(page.size.width / page.size.height, closeTo(NoteSheet.width / NoteSheet.height, 0.02));
  });

  test('warnanya tidak tertukar jadi kebiruan', () async {
    // pdfium memberi BGRA sementara penulis PNG membaca RGBA; kalau tidak
    // ditukar, seluruh halaman putih keluar kebiruan.
    final pdf = await samplePdf(pages: 1);
    final notePath = await PdfToNotebook.convert(pdfPath: pdf, targetDir: dir.path);
    final document = await NoteDocumentStore.read(notePath);
    final file = File(p.join(dir.path, (document.pages.first.components.single as NoteImage).file));

    final decoded = img.decodePng(file.readAsBytesSync());
    expect(decoded, isNotNull);
    // Piksel sudut kiri atas halaman: latar putih.
    final pixel = decoded!.getPixel(1, 1);
    expect(pixel.r, greaterThan(200), reason: 'merah');
    expect(pixel.g, greaterThan(200), reason: 'hijau');
    expect(pixel.b, greaterThan(200), reason: 'biru');
  });

  test('berkas yang sudah ada tidak ditimpa', () async {
    final pdf = await samplePdf(pages: 1);
    final satu = await PdfToNotebook.convert(pdfPath: pdf, targetDir: dir.path, title: 'Sama');
    final dua = await PdfToNotebook.convert(pdfPath: pdf, targetDir: dir.path, title: 'Sama');
    expect(satu, isNot(dua));
    expect(File(satu).existsSync(), isTrue);
    expect(File(dua).existsSync(), isTrue);
  });

  test('halaman PDF bisa diambil sebagai lembar untuk disisipkan', () async {
    // Jalur yang dipakai "sisipkan halaman PDF" di dalam buku catatan: lembarnya
    // dikembalikan tanpa menulis berkas catatan apa pun.
    final pdf = await samplePdf(pages: 2);
    final pages = await PdfToNotebook.pagesOf(
      pdfPath: pdf,
      assetDir: p.join(dir.path, 'buku-berkas'),
      relativeDir: 'buku-berkas',
      prefix: 'sisipan',
    );

    expect(pages.length, greaterThanOrEqualTo(2));
    for (final page in pages) {
      final image = page.components.single as NoteImage;
      expect(image.file, startsWith('buku-berkas/sisipan-'));
      expect(File(p.join(dir.path, image.file)).existsSync(), isTrue, reason: image.file);
    }
    expect(Directory(p.join(dir.path, 'buku-berkas')).listSync().length, pages.length);
  });

  test('menyisipkan dua kali tidak menimpa gambar sisipan pertama', () async {
    final pdf = await samplePdf(pages: 1);
    final satu = await PdfToNotebook.pagesOf(
      pdfPath: pdf,
      assetDir: p.join(dir.path, 'berkas'),
      relativeDir: 'berkas',
      prefix: 'sama',
    );
    final dua = await PdfToNotebook.pagesOf(
      pdfPath: pdf,
      assetDir: p.join(dir.path, 'berkas'),
      relativeDir: 'berkas',
      prefix: 'sama',
    );
    // Berkas contohnya bisa lebih dari satu halaman; yang diperiksa halaman
    // pertamanya.
    final a = (satu.first.components.single as NoteImage).file;
    final b = (dua.first.components.single as NoteImage).file;
    expect(a, isNot(b));
    expect(File(p.join(dir.path, a)).existsSync(), isTrue);
    expect(File(p.join(dir.path, b)).existsSync(), isTrue);
  });
}
