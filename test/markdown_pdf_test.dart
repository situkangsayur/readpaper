import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/markdown/data/markdown_pdf.dart';
import 'package:readpaper/src/features/markdown/domain/markdown_doc.dart';

void main() {
  /// Teks yang ada di dalam PDF.
  ///
  /// Aliran isinya dipadatkan dengan Deflate, jadi dibuka dulu. Yang keluar
  /// adalah operator gambar PDF — teks yang benar-benar ditulis ada di dalam
  /// `(…) Tj`, dan itulah yang membuktikan hasilnya bukan gambar.
  String textOf(List<int> bytes) {
    final out = StringBuffer(latin1.decode(bytes.take(16).toList()));
    final raw = latin1.decode(bytes, allowInvalid: true);
    var at = 0;
    while (true) {
      final start = raw.indexOf('stream', at);
      if (start < 0) break;
      final end = raw.indexOf('endstream', start);
      if (end < 0) break;
      var from = start + 'stream'.length;
      while (from < end && (raw.codeUnitAt(from) == 13 || raw.codeUnitAt(from) == 10)) {
        from++;
      }
      final chunk = bytes.sublist(from, end);
      try {
        out.write(latin1.decode(ZLibCodec().decode(chunk), allowInvalid: true));
      } on Object {
        // Aliran yang bukan Deflate — misalnya gambar — dilewati.
        out.write(latin1.decode(chunk, allowInvalid: true));
      }
      at = end + 1;
    }
    // Bagian yang tidak dipadatkan (kamus objek, nama font) ikut, supaya
    // pemeriksaan seperti "/DCTDecode" tetap berlaku.
    out.write(raw);
    return out.toString();
  }

  test('menghasilkan PDF yang sah', () async {
    final bytes = await MarkdownPdf.build(MarkdownDoc.parse('# Judul\n\nIsi.\n'));
    expect(bytes.length, greaterThan(400));
    expect(latin1.decode(bytes.sublist(0, 8)), startsWith('%PDF-'));
    expect(latin1.decode(bytes.sublist(bytes.length - 8)), contains('%%EOF'));
  });

  test('teksnya masuk sebagai teks, bukan gambar', () async {
    // Ini janji utamanya: hasil cetakannya masih bisa dicari dan disalin.
    final bytes = await MarkdownPdf.build(
      MarkdownDoc.parse('# Rencana\n\nHal yang **penting** sekali.\n'),
    );
    final raw = textOf(bytes);
    expect(raw, contains('Rencana'));
    expect(raw, contains('penting'));
    // Tanpa gambar berarti tanpa aliran DCTDecode.
    expect(raw.contains('/DCTDecode'), isFalse);
  });

  test('dokumen kosong tetap jadi satu halaman, bukan galat', () async {
    final bytes = await MarkdownPdf.build(MarkdownDoc.empty);
    expect(bytes.length, greaterThan(400));
    expect(textOf(bytes), contains('/Page'));
  });

  test('diagram mermaid ikut, dan labelnya tetap teks', () async {
    final bytes = await MarkdownPdf.build(
      MarkdownDoc.parse(
        '```mermaid\ngraph TD\nA[Mulai] --> B{Sudah?}\nB -->|ya| C(Selesai)\n```\n',
      ),
    );
    final raw = textOf(bytes);
    expect(raw, contains('Mulai'));
    expect(raw, contains('Sudah?'));
    expect(raw, contains('Selesai'));
    expect(raw, contains('ya'), reason: 'label panah ikut tertulis');
  });

  test('diagram yang belum didukung dicetak sebagai sumbernya', () async {
    final bytes = await MarkdownPdf.build(
      MarkdownDoc.parse('```mermaid\nsequenceDiagram\nA->>B: hai\n```\n'),
    );
    final raw = textOf(bytes);
    expect(raw, contains('sequenceDiagram'));
  });

  test('tabel, daftar, kutipan, dan kode semuanya ikut', () async {
    final bytes = await MarkdownPdf.build(
      MarkdownDoc.parse('''
| Kolom | Nilai |
| --- | --- |
| satu | 1 |

- butir pertama
- [x] sudah dikerjakan

> kutipan penting

```dart
final x = 1;
```
'''),
    );
    final raw = textOf(bytes);
    // Diperiksa per kata: PDF memecah sebaris teks jadi beberapa operator
    // gambar, dan di mana potongannya jatuh bukan janji apa pun.
    for (final wanted in <String>[
      'Kolom',
      'satu',
      'butir',
      'pertama',
      'dikerjakan',
      'kutipan',
      'final',
    ]) {
      expect(raw, contains(wanted), reason: wanted);
    }
  });

  test('tanda baca yang tidak ada di font bawaan ditukar, bukan dihilangkan', () async {
    // Font baku PDF tidak punya tanda pisah panjang maupun kutip melengkung,
    // dan yang terjadi kalau dibiarkan bukan kotak kosong melainkan hilang
    // tanpa jejak — kalimatnya keluar dari cetakan dengan kata berdempetan.
    final bytes = await MarkdownPdf.build(
      MarkdownDoc.parse('Kata — sambung, kutip “begini”, lalu titik…\n\n- butir\n'),
    );
    final raw = textOf(bytes);
    expect(raw, contains('--'));
    expect(raw, contains('"begini"'), reason: 'kutipnya jadi kutip lurus');
    expect(raw, contains('...'));
    expect(raw, contains('butir'));
    expect(raw.contains('—'), isFalse);
    expect(raw.contains('“'), isFalse);
  });

  group('gambar', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('readpaper-md-pdf-'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('gambar berjalur relatif diambil dari folder dokumennya', () async {
      // PNG 1×1 yang sah.
      final png = <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ];
      File(p.join(dir.path, 'titik.png')).writeAsBytesSync(png);
      final bytes = await MarkdownPdf.build(
        MarkdownDoc.parse('![titik](titik.png)\n'),
        baseDir: dir.path,
      );
      expect(bytes.length, greaterThan(400));
    });

    test('gambar yang hilang disebutkan, tidak dihilangkan diam-diam', () async {
      final bytes = await MarkdownPdf.build(
        MarkdownDoc.parse('![hilang](tidak-ada.png)\n'),
        baseDir: dir.path,
      );
      expect(textOf(bytes), contains('ditemukan'));
    });
  });
}
