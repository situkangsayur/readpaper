import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/whiteboard/domain/board.dart';

void main() {
  BoardStroke stroke(List<Offset> points) =>
      BoardStroke(points: points, color: const Color(0xFF000000), width: 2);

  group('jarak ke goresan', () {
    test('diukur ke garisnya, bukan ke kotak pembatasnya', () {
      // Sebuah "L": kotak pembatasnya mencakup sudut kanan atas, padahal
      // garisnya jauh dari sana. Penghapus yang memakai kotak akan menghapus
      // coretan yang tidak disentuh.
      final l = stroke(<Offset>[const Offset(0, 0), const Offset(0, 100), const Offset(100, 100)]);
      expect(l.distanceTo(const Offset(2, 50)), lessThan(3));
      expect(l.distanceTo(const Offset(90, 10)), greaterThan(80));
    });

    test('titik di atas garis berjarak nol', () {
      final line = stroke(<Offset>[const Offset(0, 0), const Offset(100, 0)]);
      expect(line.distanceTo(const Offset(50, 0)), closeTo(0, 0.001));
    });
  });

  group('penghapus per goresan', () {
    test('hanya yang tersentuh yang hilang', () {
      final page = BoardPage(
        background: BoardBackgrounds.white,
        strokes: <BoardStroke>[
          stroke(<Offset>[const Offset(0, 0), const Offset(50, 0)]),
          stroke(<Offset>[const Offset(0, 300), const Offset(50, 300)]),
        ],
      );

      final after = page.erasedAt(const Offset(25, 2), 6);
      expect(after.strokes, hasLength(1));
      expect(after.strokes.single.points.first.dy, 300);
    });

    test('menyentuh tempat kosong tidak menghapus apa pun', () {
      final page = BoardPage(
        background: BoardBackgrounds.white,
        strokes: <BoardStroke>[
          stroke(<Offset>[const Offset(0, 0), const Offset(50, 0)]),
        ],
      );
      expect(page.erasedAt(const Offset(400, 400), 6).strokes, hasLength(1));
    });
  });

  group('warna pena mengikuti latar', () {
    test('papan gelap mendapat pena terang, dan sebaliknya', () {
      // Pena hitam di atas papan hitam adalah cara tercepat membuat orang
      // mengira aplikasinya rusak.
      expect(
        BoardBackgrounds.penFor(BoardBackgrounds.black).computeLuminance(),
        greaterThan(0.5),
      );
      expect(
        BoardBackgrounds.penFor(BoardBackgrounds.white).computeLuminance(),
        lessThan(0.5),
      );
      expect(
        BoardBackgrounds.penFor(BoardBackgrounds.green).computeLuminance(),
        greaterThan(0.5),
      );
    });
  });

  group('lembar', () {
    test('menambah goresan tidak mengubah lembar yang lama', () {
      const page = BoardPage(background: BoardBackgrounds.white);
      final after = page.withStroke(stroke(<Offset>[Offset.zero, const Offset(10, 10)]));
      expect(page.strokes, isEmpty, reason: 'lembarnya tidak berubah, yang baru yang berisi');
      expect(after.strokes, hasLength(1));
    });

    test('ukurannya A4 dalam titik PDF', () {
      // Supaya papan yang dicetak atau digabung dengan paper tidak berbeda
      // ukuran.
      expect(BoardSize.width, closeTo(595.28, 0.01));
      expect(BoardSize.height, closeTo(841.89, 0.01));
    });
  });
}
