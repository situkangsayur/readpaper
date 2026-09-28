import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../domain/note_document.dart';
import 'note_document_store.dart';

/// Mengubah sebuah PDF jadi buku catatan yang bisa disunting.
///
/// Inilah jalan dari "saya mau menambah lembar catatan di dokumen ini" ke
/// sesuatu yang benar-benar bisa disunting lagi besok: tiap halaman PDF jadi
/// satu lembar berisi gambar halaman itu, lalu di atasnya bisa ditulis,
/// digambar, ditempeli teks, bangun, dan penghubung — semuanya sebagai
/// komponen yang masih bisa dipindahkan satu per satu.
///
/// Halamannya memang jadi gambar, dan itu memang harga yang dibayar: teks PDF
/// tidak bisa ikut jadi komponen teks tanpa pengenalan tata letak yang belum
/// ada. Yang tidak hilang adalah **tampilannya** — dan untuk dokumen yang
/// dipakai sebagai alas catatan, itu yang dibutuhkan. Yang mau teksnya ikut
/// terbaca memakai "Ubah ke Markdown".
class PdfToNotebook {
  const PdfToNotebook._();

  /// Berapa titik per inci halaman PDF dirender.
  ///
  /// 144 (2×) membuat tulisan di halaman tetap tajam saat diperbesar di layar
  /// tablet, tanpa membuat berkasnya tidak masuk akal.
  static const double dpi = 144;

  /// Menulis buku catatan baru dari [pdfPath] ke dalam [targetDir].
  ///
  /// Mengembalikan jalur berkas `.catatan.json`-nya.
  static Future<String> convert({
    required String pdfPath,
    required String targetDir,
    String? title,
    int extraPages = 1,
    int? maxPages,
  }) async {
    final stem = _stem(title ?? p.basenameWithoutExtension(pdfPath));
    var notePath = p.join(targetDir, '$stem${NoteDocumentStore.extension}');
    for (var n = 2; File(notePath).existsSync() && n < 100; n++) {
      notePath = p.join(targetDir, '$stem-$n${NoteDocumentStore.extension}');
    }
    final assetDir = Directory(
      p.join(targetDir, '${NoteDocumentStore.stemOf(notePath)}-berkas'),
    );
    await assetDir.create(recursive: true);

    final document = await PdfDocument.openFile(pdfPath);
    final pages = <NotePage>[];
    try {
      final count = maxPages == null
          ? document.pages.length
          : math.min(maxPages, document.pages.length);
      for (var i = 0; i < count; i++) {
        final page = document.pages[i];
        final scale = dpi / 72;
        final rendered = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) continue;
        try {
          final name = 'halaman-${i + 1}.png';
          await File(p.join(assetDir.path, name)).writeAsBytes(
            _png(rendered),
            flush: true,
          );

          // Halamannya dimuat ke dalam lembar A4 dengan mempertahankan
          // perbandingan sisinya: halaman lebar tidak boleh jadi gepeng, dan
          // halaman panjang tidak boleh terpotong.
          final box = _fit(Size(page.width, page.height));
          pages.add(
            NotePage(
              components: <NoteComponent>[
                NoteImage(
                  id: 'halaman-${i + 1}',
                  position: box.topLeft,
                  size: box.size,
                  file: '${assetDir.path.split(Platform.pathSeparator).last}/$name',
                  alt: 'Halaman ${i + 1}',
                ),
              ],
            ),
          );
        } finally {
          rendered.dispose();
        }
      }
    } finally {
      await document.dispose();
    }

    // Lembar kosong di belakang: itu yang sebenarnya diminta — tempat menulis
    // catatan tambahan tanpa mengotori halaman dokumennya.
    for (var i = 0; i < math.max(0, extraPages); i++) {
      pages.add(const NotePage());
    }
    if (pages.isEmpty) pages.add(const NotePage());

    await NoteDocumentStore.write(
      notePath,
      NoteDocument(title: title ?? p.basenameWithoutExtension(pdfPath), pages: pages),
    );
    return notePath;
  }

  /// Kotak tempat halaman berukuran [source] duduk di dalam lembar A4.
  static Rect _fit(Size source) {
    final scale = math.min(
      NoteSheet.width / math.max(source.width, 1),
      NoteSheet.height / math.max(source.height, 1),
    );
    final size = Size(source.width * scale, source.height * scale);
    return Rect.fromLTWH(
      (NoteSheet.width - size.width) / 2,
      (NoteSheet.height - size.height) / 2,
      size.width,
      size.height,
    );
  }

  /// PNG dari piksel yang diserahkan pdfium.
  ///
  /// pdfium memberi BGRA; `package:image` membaca RGBA, jadi dua salurannya
  /// ditukar — kalau tidak, seluruh halaman keluar kebiruan.
  static List<int> _png(PdfImage rendered) {
    final pixels = Uint8List.fromList(rendered.pixels);
    for (var i = 0; i + 2 < pixels.length; i += 4) {
      final b = pixels[i];
      pixels[i] = pixels[i + 2];
      pixels[i + 2] = b;
    }
    return img.encodePng(
      img.Image.fromBytes(
        width: rendered.width,
        height: rendered.height,
        bytes: pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      ),
    );
  }

  static String _stem(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
    return cleaned.isEmpty ? 'catatan' : cleaned;
  }
}
