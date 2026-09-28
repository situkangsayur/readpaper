import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/notebook/data/note_export.dart';
import 'package:readpaper/src/features/notebook/domain/note_document.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('rp-ekspor-'));
  tearDown(() => dir.deleteSync(recursive: true));

  NoteInk ink({double x = 20, double y = 30}) => NoteInk(
    id: 'i1',
    position: Offset(x, y),
    size: const Size(120, 60),
    strokes: <NoteStroke>[
      NoteStroke(points: const <Offset>[Offset(0, 0), Offset(60, 30), Offset(120, 60)], width: 3),
    ],
  );

  NoteText text(String body, {double y = 100}) => NoteText(
    id: 't-$y',
    position: Offset(40, y),
    size: const Size(400, 40),
    text: body,
  );

  String textOf(List<int> bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final out = StringBuffer(raw);
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
      try {
        out.write(latin1.decode(ZLibCodec().decode(bytes.sublist(from, end)), allowInvalid: true));
      } on Object {
        // Aliran yang bukan Deflate dilewati.
      }
      at = end + 1;
    }
    return out.toString();
  }

  group('Markdown', () {
    test('urutannya urutan baca, bukan urutan menulis', () async {
      // Catatan ditulis melompat-lompat; Markdown yang mengikuti urutan
      // menulis akan terbaca acak.
      final document = NoteDocument(
        pages: <NotePage>[
          NotePage(
            components: <NoteComponent>[
              text('Ini ditulis belakangan tapi ada di bawah', y: 400),
              text('Ini ditulis duluan dan ada di atas', y: 100),
            ],
          ),
        ],
      );
      final md = await NoteExport.toMarkdown(document, assetDir: dir.path);
      expect(md.indexOf('ada di atas'), lessThan(md.indexOf('ada di bawah')));
    });

    test('diagram jadi blok mermaid, gambar jadi rujukan gambar', () async {
      final document = NoteDocument(
        title: 'Rapat',
        pages: <NotePage>[
          NotePage(
            components: <NoteComponent>[
              const NoteDiagram(
                id: 'd1',
                position: Offset(20, 60),
                size: Size(200, 150),
                source: 'graph TD\n  A --> B',
              ),
              const NoteImage(
                id: 'g1',
                position: Offset(20, 300),
                size: Size(100, 80),
                file: 'papan.png',
                alt: 'papan tulis',
              ),
            ],
          ),
        ],
      );
      final md = await NoteExport.toMarkdown(document, assetDir: dir.path);
      expect(md, startsWith('# Rapat'));
      expect(md, contains('```mermaid'));
      expect(md, contains('graph TD'));
      expect(md, contains('![papan tulis](papan.png)'));
    });

    test('tinta tidak dibuang: digambar jadi PNG dan dirujuk', () async {
      // Konversi yang menghilangkan coretan adalah konversi yang merusak.
      final document = NoteDocument(pages: <NotePage>[
        NotePage(components: <NoteComponent>[ink()]),
      ]);
      final md = await NoteExport.toMarkdown(document, assetDir: dir.path);

      expect(md, contains('![tulisan tangan](tinta-1-1.png)'));
      final png = File(p.join(dir.path, 'tinta-1-1.png'));
      expect(png.existsSync(), isTrue);
      expect(png.lengthSync(), greaterThan(100));
      expect(png.readAsBytesSync().sublist(1, 4), <int>[0x50, 0x4E, 0x47]);
    });

    test('tiap lembar dipisah garis', () async {
      final document = NoteDocument(
        pages: <NotePage>[
          NotePage(components: <NoteComponent>[text('lembar satu')]),
          NotePage(components: <NoteComponent>[text('lembar dua')]),
        ],
      );
      final md = await NoteExport.toMarkdown(document, assetDir: dir.path);
      expect(md, contains('lembar satu'));
      expect(md, contains('\n---\n'));
      expect(md.indexOf('---'), lessThan(md.indexOf('lembar dua')));
    });
  });

  group('PDF', () {
    test('satu lembar catatan jadi satu halaman, seukuran lembarnya', () async {
      final document = NoteDocument(
        pages: <NotePage>[
          NotePage(components: <NoteComponent>[text('halaman satu')]),
          NotePage(components: <NoteComponent>[text('halaman dua')]),
        ],
      );
      final bytes = await NoteExport.toPdf(document);
      final raw = textOf(bytes);
      expect(latin1.decode(bytes.sublist(0, 8)), startsWith('%PDF-'));
      expect('/Type /Page'.allMatches(raw).length + '/Type/Page'.allMatches(raw).length,
          greaterThanOrEqualTo(2));
      expect(raw, contains('595'));
      expect(raw, contains('842'));
    });

    test('teksnya tetap teks, jadi masih bisa dicari', () async {
      final bytes = await NoteExport.toPdf(
        NoteDocument(pages: <NotePage>[
          NotePage(components: <NoteComponent>[text('Rapat mulai pukul sembilan')]),
        ]),
      );
      final raw = textOf(bytes);
      expect(raw, contains('Rapat'));
      expect(raw, contains('sembilan'));
      expect(raw.contains('/DCTDecode'), isFalse, reason: 'bukan gambar');
    });

    test('tinta digambar sebagai garis vektor, bukan gambar', () async {
      // Vektor tetap tajam diperbesar sejauh apa pun, dan berkasnya jauh lebih
      // kecil daripada raster.
      final bytes = await NoteExport.toPdf(
        NoteDocument(pages: <NotePage>[NotePage(components: <NoteComponent>[ink()])]),
      );
      final raw = textOf(bytes);
      expect(raw.contains('/DCTDecode'), isFalse);
      expect(raw.contains('/FlateDecode') || raw.contains('stream'), isTrue);
      // Operator garis PDF: `m` pindah, `l` tarik, `S` gores.
      expect(RegExp(r'\d+(\.\d+)? \d+(\.\d+)? m').hasMatch(raw), isTrue);
      expect(RegExp(r'\d+(\.\d+)? \d+(\.\d+)? l').hasMatch(raw), isTrue);
    });

    test('gambar yang hilang disebutkan, bukan dilewati diam-diam', () async {
      final bytes = await NoteExport.toPdf(
        NoteDocument(pages: <NotePage>[
          NotePage(components: <NoteComponent>[
            const NoteImage(
              id: 'g1',
              position: Offset(20, 20),
              size: Size(100, 80),
              file: 'tidak-ada.png',
            ),
          ]),
        ]),
        baseDir: dir.path,
      );
      expect(textOf(bytes), contains('ditemukan'));
    });

    test('diagram ikut tergambar beserta labelnya', () async {
      final bytes = await NoteExport.toPdf(
        NoteDocument(pages: <NotePage>[
          NotePage(components: <NoteComponent>[
            const NoteDiagram(
              id: 'd1',
              position: Offset(30, 40),
              size: Size(300, 220),
              source: 'graph TD\n  A[Mulai] --> B[Selesai]',
            ),
          ]),
        ]),
      );
      final raw = textOf(bytes);
      expect(raw, contains('Mulai'));
      expect(raw, contains('Selesai'));
    });
  });
}
