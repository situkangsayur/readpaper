import 'dart:io';

import 'package:collection/collection.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/utils/simple_pdf_writer.dart';
import 'package:readpaper/src/features/reader/data/pdf_page_editor.dart';

void main() {
  late Directory dir;

  // `flutter test` tidak memuat aset native, jadi pdfium ditunjuk sendiri ke
  // berkas yang sudah diunduh saat aplikasinya dibangun. Kalau belum ada,
  // ujinya dilewati dengan alasan yang jelas — bukan gagal seolah kodenya
  // yang salah.
  final candidates = <String>[
    'build/native_assets/linux/libpdfium.so',
    '.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811/linux-x64/libpdfium.so',
  ];
  final module = candidates.where((path) => File(path).existsSync()).firstOrNull;
  if (module == null) {
    test('penyunting halaman PDF', () {}, skip: 'libpdfium.so belum ada — jalankan flutter build dulu');
    return;
  }
  PdfPageEditor.modulePath = module;

  setUp(() => dir = Directory.systemTemp.createTempSync('rp_pdfedit_'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// PDF kecil berisi [pages] halaman, dibuat dari gambar polos.
  String makePdf(String name, int pages) {
    final page = img.Image(width: 60, height: 80)..clear(img.ColorRgb8(255, 255, 255));
    final jpg = Uint8List.fromList(img.encodeJpg(page, quality: 70));
    final bytes = writeImagePdf(<PdfImagePage>[
      for (var i = 0; i < pages; i++)
        PdfImagePage(
          jpeg: jpg,
          pixelWidth: 60,
          pixelHeight: 80,
          widthPt: 300,
          heightPt: 400,
        ),
    ]);
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  test('halaman kosong ditambahkan di akhir', () async {
    final source = makePdf('asal.pdf', 2);
    final target = p.join(dir.path, 'hasil.pdf');

    await PdfPageEditor.addBlankPages(source: source, target: target, count: 3);

    expect(PdfPageEditor.pageCount(source), 2, reason: 'asalnya tidak boleh berubah');
    expect(PdfPageEditor.pageCount(target), 5);
  });

  test('halaman kosong bisa disisipkan di depan', () async {
    final source = makePdf('asal.pdf', 2);
    final target = p.join(dir.path, 'hasil.pdf');

    await PdfPageEditor.addBlankPages(source: source, target: target, at: 0);

    expect(PdfPageEditor.pageCount(target), 3);
  });

  test('menggabungkan beberapa berkas', () async {
    final satu = makePdf('satu.pdf', 1);
    final dua = makePdf('dua.pdf', 3);
    final target = p.join(dir.path, 'gabung.pdf');

    await PdfPageEditor.merge(sources: <String>[satu, dua], target: target);

    expect(PdfPageEditor.pageCount(target), 4);
  });

  test('berkas asal yang tidak ada dilaporkan, bukan didiamkan', () async {
    expect(
      () => PdfPageEditor.addBlankPages(
        source: p.join(dir.path, 'entah.pdf'),
        target: p.join(dir.path, 'hasil.pdf'),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('meminta nol halaman ditolak', () async {
    final source = makePdf('asal.pdf', 1);
    expect(
      () => PdfPageEditor.addBlankPages(
        source: source,
        target: p.join(dir.path, 'hasil.pdf'),
        count: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('hasilnya bukan gambar: berkasnya tidak membengkak', () async {
    // Cara mudah menambah halaman adalah merender ulang semuanya jadi gambar,
    // dan itu membuat berkasnya berlipat sekaligus menghilangkan teksnya.
    // Ukuran yang tetap sebanding adalah tanda halamannya disalin apa adanya.
    final source = makePdf('asal.pdf', 4);
    final target = p.join(dir.path, 'hasil.pdf');

    await PdfPageEditor.addBlankPages(source: source, target: target);

    final before = File(source).lengthSync();
    final after = File(target).lengthSync();
    expect(after, lessThan(before * 2));
  });
}
