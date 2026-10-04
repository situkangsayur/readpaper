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
      expect(BoardBackgrounds.penFor(BoardBackgrounds.black).computeLuminance(), greaterThan(0.5));
      expect(BoardBackgrounds.penFor(BoardBackgrounds.white).computeLuminance(), lessThan(0.5));
      expect(BoardBackgrounds.penFor(BoardBackgrounds.green).computeLuminance(), greaterThan(0.5));
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

  group('arah kertas', () {
    test('mendatar menukar sisi panjang dan pendeknya', () {
      expect(BoardOrientation.tegak.size.width, closeTo(595.28, 0.01));
      expect(BoardOrientation.tegak.size.height, closeTo(841.89, 0.01));
      expect(BoardOrientation.mendatar.size.width, closeTo(841.89, 0.01));
      expect(BoardOrientation.mendatar.size.height, closeTo(595.28, 0.01));
      expect(BoardOrientation.tegak.lain, BoardOrientation.mendatar);
    });

    test('memutar kertas membawa coretannya, tidak ada yang keluar tepi', () {
      // Memutar kertas tanpa memutar isinya berarti coretan yang tadinya di
      // dalam kertas mendadak keluar dari tepi — hilang tanpa pernah dihapus.
      const page = BoardPage(
        background: Color(0xFFFFFFFF),
        strokes: <BoardStroke>[
          BoardStroke(
            points: <Offset>[Offset(10, 800), Offset(100, 820)],
            color: Color(0xFF000000),
            width: 2,
          ),
        ],
      );

      final turned = page.turned();
      expect(turned.orientation, BoardOrientation.mendatar);
      for (final point in turned.strokes.single.points) {
        expect(point.dx, inInclusiveRange(0, turned.size.width));
        expect(point.dy, inInclusiveRange(0, turned.size.height));
      }
    });

    test('memutar empat kali kembali persis ke asalnya', () {
      const page = BoardPage(
        background: Color(0xFFFFFFFF),
        strokes: <BoardStroke>[
          BoardStroke(
            points: <Offset>[Offset(12.5, 33.25), Offset(400, 700)],
            color: Color(0xFF000000),
            width: 3,
          ),
        ],
      );

      var turned = page;
      for (var i = 0; i < 4; i++) {
        turned = turned.turned();
      }
      expect(turned.orientation, page.orientation);
      for (var i = 0; i < page.strokes.single.points.length; i++) {
        expect(turned.strokes.single.points[i].dx, closeTo(page.strokes.single.points[i].dx, 1e-9));
        expect(turned.strokes.single.points[i].dy, closeTo(page.strokes.single.points[i].dy, 1e-9));
      }
    });

    test('bentuk goresan tidak berubah saat kertasnya diputar', () {
      const page = BoardPage(
        background: Color(0xFFFFFFFF),
        strokes: <BoardStroke>[
          BoardStroke(
            points: <Offset>[Offset(100, 100), Offset(200, 100), Offset(200, 160)],
            color: Color(0xFF000000),
            width: 2,
          ),
        ],
      );
      final before = page.strokes.single.points;
      final after = page.turned().strokes.single.points;
      for (var i = 1; i < before.length; i++) {
        expect(
          (after[i] - after[i - 1]).distance,
          closeTo((before[i] - before[i - 1]).distance, 1e-9),
        );
      }
    });

    test('warna dan tebal goresan ikut utuh', () {
      const page = BoardPage(
        background: Color(0xFF12372A),
        strokes: <BoardStroke>[
          BoardStroke(
            points: <Offset>[Offset(10, 10), Offset(20, 20)],
            color: Color(0xFFE53935),
            width: 4.5,
          ),
        ],
      );
      final turned = page.turned();
      expect(turned.background, const Color(0xFF12372A));
      expect(turned.strokes.single.color, const Color(0xFFE53935));
      expect(turned.strokes.single.width, 4.5);
    });
  });
}
