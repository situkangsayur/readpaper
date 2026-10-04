import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/src/features/markdown/data/markdown_pdf.dart';
import 'package:readpaper/src/features/markdown/data/pdf_to_markdown.dart';
import 'package:readpaper/src/features/markdown/domain/markdown_doc.dart';

/// Bolak-balik pada berkas sungguhan: Markdown → PDF → Markdown.
///
/// Dua arah konversinya diuji terpisah dengan data buatan; yang ini menguji
/// keduanya bertemu pada PDF betulan yang dibaca pdfium. Kalau salah satu
/// arahnya meleset — huruf tajuk tidak lebih besar, paragraf tidak tersambung —
/// yang kembali bukan dokumen yang sama.
void main() {
  // `flutter test` tidak memuat aset native, jadi pdfium ditunjuk sendiri ke
  // berkas yang sudah diunduh saat aplikasinya dibangun.
  final candidates = <String>[
    'build/native_assets/linux/libpdfium.so',
    '.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811/linux-x64/libpdfium.so',
  ];
  final module = candidates.where((path) => File(path).existsSync()).firstOrNull;
  if (module == null) {
    test(
      'bolak-balik Markdown → PDF → Markdown',
      () {},
      skip: 'libpdfium.so belum ada — jalankan flutter build dulu',
    );
    return;
  }
  Pdfrx.pdfiumModulePath = module;

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('rp_md_pdf_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('teks, tajuk, dan paragraf kembali utuh', () async {
    const source = '''
# Catatan Rapat Mingguan

Rapat membahas jadwal rilis dan siapa yang mengerjakan bagian mana, supaya
tidak ada pekerjaan yang dikerjakan dua kali oleh orang berbeda.

## Keputusan

Rilis berikutnya dikerjakan setelah pengujian selesai, bukan sebelumnya.
''';

    final pdfPath = p.join(dir.path, 'rapat.pdf');
    File(pdfPath).writeAsBytesSync(await MarkdownPdf.build(MarkdownDoc.parse(source)));

    final back = await PdfToMarkdown.fromFile(pdfPath, title: 'rapat');

    expect(back, contains('# Catatan Rapat Mingguan'));
    expect(back, contains('## Keputusan'));
    // Paragraf yang dibungkus di PDF harus tersambung lagi jadi satu baris.
    expect(back, contains('supaya tidak ada pekerjaan'));
    expect(back, contains('setelah pengujian selesai'));
  });

  test('nomor halaman tidak ikut kembali', () async {
    // `MarkdownPdf` menulis nomor halaman di kaki tiap halaman; yang dibaca
    // ulang tidak boleh menyisipkan angka itu ke dalam teks.
    final panjang = StringBuffer('# Panjang\n\n');
    for (var i = 0; i < 60; i++) {
      panjang.writeln('Paragraf nomor $i yang isinya cukup untuk memenuhi halaman.\n');
    }
    final pdfPath = p.join(dir.path, 'panjang.pdf');
    File(pdfPath).writeAsBytesSync(await MarkdownPdf.build(MarkdownDoc.parse(panjang.toString())));

    final back = await PdfToMarkdown.fromFile(pdfPath);
    expect(back, contains('Paragraf nomor 0'));
    expect(back, contains('Paragraf nomor 59'));
    expect(
      RegExp(r'^\s*\d{1,2}\s*$', multiLine: true).hasMatch(back),
      isFalse,
      reason: 'nomor halaman dibuang',
    );
  });

  test('daftar tetap jadi daftar', () async {
    final pdfPath = p.join(dir.path, 'daftar.pdf');
    File(pdfPath).writeAsBytesSync(
      await MarkdownPdf.build(
        MarkdownDoc.parse('# Belanja\n\n- gula pasir satu kilogram\n- teh melati satu kotak\n'),
      ),
    );

    final back = await PdfToMarkdown.fromFile(pdfPath);
    expect(back, contains('- gula pasir satu kilogram'));
    expect(back, contains('- teh melati satu kotak'));
  });
}
