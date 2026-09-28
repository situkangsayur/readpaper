import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/markdown/data/pdf_to_markdown.dart';

void main() {
  /// Satu baris pada halaman A4: y menghitung dari bawah, seperti di PDF.
  PdfTextLine line(
    String text, {
    int page = 1,
    required double y,
    double size = 10,
    double left = 72,
    double right = 523,
  }) => PdfTextLine(
    page: page,
    text: text,
    top: y + size,
    bottom: y,
    left: left,
    right: right,
  );

  group('paragraf', () {
    test('baris berdekatan digabung jadi satu paragraf', () {
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Kalimat ini dimulai di baris pertama', y: 700),
        line('dan selesai di baris kedua.', y: 686),
      ]);
      expect(md.trim(), 'Kalimat ini dimulai di baris pertama dan selesai di baris kedua.');
    });

    test('baris berjauhan jadi paragraf terpisah', () {
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Paragraf pertama.', y: 700),
        line('Paragraf kedua, jauh di bawah.', y: 640),
      ]);
      expect(md.trim().split('\n\n'), hasLength(2));
    });

    test('kata yang terpotong tanda hubung disambung tanpa spasi', () {
      // Ini yang paling terasa kalau salah: "pembel- ajaran" bukan kata.
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Metode pembel-', y: 700),
        line('ajaran ini dipakai.', y: 686),
      ]);
      expect(md, contains('pembelajaran'));
      expect(md.contains('pembel- ajaran'), isFalse);
    });

    test('halaman berganti tidak memutus paragraf', () {
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Kalimat yang menyambung', y: 90, page: 1),
        line('ke halaman berikutnya.', y: 740, page: 2),
      ]);
      expect(md.trim(), 'Kalimat yang menyambung ke halaman berikutnya.');
    });
  });

  group('tajuk', () {
    test('huruf yang lebih besar jadi tajuk, bertingkat menurut ukurannya', () {
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Judul Utama', y: 740, size: 20),
        line('Isi badan teks yang biasa saja.', y: 700),
        line('Sub Bagian', y: 660, size: 14),
        line('Isi lagi.', y: 640),
      ]);
      expect(md, contains('# Judul Utama'));
      expect(md, contains('## Sub Bagian'));
      expect(md, contains('Isi badan teks yang biasa saja.'));
    });

    test('hanya satu tajuk tingkat satu; berikutnya turun tingkat', () {
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Judul', y: 740, size: 20),
        line('Isi badan teks yang panjangnya wajar untuk sebuah paragraf.', y: 700),
        line('Masih badan teks yang sama panjangnya dengan yang di atas.', y: 686),
        line('Judul Kedua', y: 640, size: 20),
      ]);
      expect(RegExp(r'^# ', multiLine: true).allMatches(md), hasLength(1));
      expect(md, contains('## Judul Kedua'));
    });

    test('baris panjang berhuruf besar bukan tajuk', () {
      // Kutipan yang dicetak besar bukan tajuk; tajuk tidak sepanjang paragraf.
      final panjang = 'Kalimat yang sangat panjang ' * 5;
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line(panjang.trim(), y: 700, size: 20),
        line('Badan teks biasa yang jadi patokan ukuran hurufnya.', y: 660),
      ]);
      expect(md.contains('# Kalimat'), isFalse);
    });

    test('judul dari luar dipakai kalau dokumennya tidak punya tajuk', () {
      final md = PdfToMarkdown.fromLines(
        <PdfTextLine>[line('Hanya badan teks.', y: 700)],
        title: 'Berkas Pindaian',
      );
      expect(md, startsWith('# Berkas Pindaian'));
    });

    test('judul dari luar tidak ditambahkan kalau sudah ada tajuknya', () {
      final md = PdfToMarkdown.fromLines(
        <PdfTextLine>[
          line('Judulnya Sendiri', y: 740, size: 20),
          line('Badan teks yang panjangnya wajar, supaya ada patokan ukuran.', y: 700),
        ],
        title: 'Nama Berkas',
      );
      expect(md.contains('Nama Berkas'), isFalse);
    });
  });

  group('daftar', () {
    test('butir dan nomor jadi daftar Markdown', () {
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('• pertama', y: 700),
        line('• kedua', y: 686),
        line('1. satu', y: 660),
        line('2) dua', y: 646),
      ]);
      expect(md, contains('- pertama'));
      expect(md, contains('- kedua'));
      expect(md, contains('1. satu'));
      expect(md, contains('2. dua'));
    });

    test('daftar tidak ikut tergabung ke paragraf sebelumnya', () {
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Syaratnya:', y: 700),
        line('• pertama', y: 686),
      ]);
      expect(md, contains('Syaratnya:\n'));
      expect(md, contains('- pertama'));
    });
  });

  group('kepala dan kaki halaman', () {
    test('nomor halaman dibuang', () {
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Isi halaman.', y: 700),
        line('7', y: 40, left: 300, right: 310),
      ]);
      expect(md.trim(), 'Isi halaman.');
    });

    test('kaki halaman yang berulang dibuang, isinya tidak', () {
      final lines = <PdfTextLine>[];
      for (var page = 1; page <= 4; page++) {
        lines.add(line('Isi halaman $page.', y: 700, page: page));
        lines.add(line('Baris kedua di halaman yang sama.', y: 686, page: page));
        lines.add(line('Disertasi Hendri Karisma · $page', y: 40, page: page));
      }
      final md = PdfToMarkdown.fromLines(lines);
      expect(md.contains('Disertasi'), isFalse);
      expect(md, contains('Isi halaman 1.'));
      expect(md, contains('Isi halaman 4.'));
    });

    test('baris yang mirip kaki halaman tidak dibuang kalau dokumennya pendek', () {
      // Dua halaman bukan bukti yang cukup; menghapus isi karena tebakan yang
      // lemah lebih merugikan daripada meninggalkan satu baris berlebih.
      final md = PdfToMarkdown.fromLines(<PdfTextLine>[
        line('Catatan Rapat', y: 700, page: 1),
        line('Catatan Rapat', y: 700, page: 2),
      ]);
      expect(md, contains('Catatan Rapat'));
    });

    test('dokumen tanpa teks sama sekali menghasilkan judulnya saja', () {
      expect(PdfToMarkdown.fromLines(const <PdfTextLine>[], title: 'Pindaian'), '# Pindaian\n');
      expect(PdfToMarkdown.fromLines(const <PdfTextLine>[]), '');
    });
  });
}
