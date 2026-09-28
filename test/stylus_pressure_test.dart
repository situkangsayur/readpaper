import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/utils/ink_smoothing.dart';
import 'package:readpaper/src/features/notebook/data/note_document_store.dart';
import 'package:readpaper/src/features/notebook/domain/note_document.dart';
import 'package:readpaper/src/features/whiteboard/domain/board.dart';

void main() {
  group('tekanan jadi tebal', () {
    test('tekanan menulis biasa menghasilkan tebal pena yang dipilih', () {
      // Separuh tekanan adalah tekanan menulis biasa: di situlah tebalnya sama
      // dengan yang dipilih, supaya angka di menu berarti sesuatu.
      expect(InkSmoothing.widthFor(3, 0.5), closeTo(3, 0.01));
    });

    test('menekan menebalkan, menyentuh ringan menipiskan', () {
      final ringan = InkSmoothing.widthFor(3, 0);
      final biasa = InkSmoothing.widthFor(3, 0.5);
      final keras = InkSmoothing.widthFor(3, 1);
      expect(ringan, lessThan(biasa));
      expect(keras, greaterThan(biasa));
    });

    test('tidak pernah nol — pena yang hilang terasa rusak', () {
      expect(InkSmoothing.widthFor(3, 0), greaterThan(0.5));
      expect(InkSmoothing.widthFor(3, -5), greaterThan(0.5), reason: 'tekanan aneh dijepit');
      expect(InkSmoothing.widthFor(3, 9), lessThan(InkSmoothing.widthFor(3, 1) + 0.01));
    });
  });

  group('goresan bertebal berubah', () {
    NoteStroke stroke({List<double>? widths}) => NoteStroke(
      points: const <Offset>[Offset(0, 0), Offset(20, 0), Offset(40, 0), Offset(60, 0)],
      width: 3,
      widths: widths,
    );

    test('tebal per titik bertahan setelah disimpan dan dibaca ulang', () {
      final document = NoteDocument(
        pages: <NotePage>[
          NotePage(
            components: <NoteComponent>[
              NoteInk(
                id: 'i1',
                position: Offset.zero,
                size: const Size(60, 4),
                strokes: <NoteStroke>[stroke(widths: const <double>[1.5, 2.5, 4, 2])],
              ),
            ],
          ),
        ],
      );
      final kembali = NoteDocumentStore.decodeSync(NoteDocumentStore.encode(document));
      final ink = kembali.pages.single.components.single as NoteInk;
      expect(ink.strokes.single.widths, <double>[1.5, 2.5, 4, 2]);
      expect(ink.strokes.single.width, 3);
    });

    test('goresan bertebal tetap tidak menyimpan daftar tebal', () {
      // Daftar yang isinya angka sama semua hanya menggandakan besar berkasnya.
      final raw = stroke().toJson();
      expect(raw.containsKey('widths'), isFalse);
      expect(NoteStroke.fromJson(raw).widths, isNull);
    });

    test('penghapus sebagian membawa tebalnya ke potongan yang tersisa', () {
      final sisa = stroke(widths: const <double>[1, 2, 3, 4]).erase(const Offset(30, 0), 8);
      expect(sisa.length, greaterThanOrEqualTo(2));
      for (final piece in sisa) {
        expect(piece.widths, isNotNull, reason: 'tebalnya tidak hilang saat dipotong');
        expect(piece.widths, hasLength(piece.points.length));
        for (final w in piece.widths!) {
          expect(w, inInclusiveRange(1, 4));
        }
      }
    });

    test('potongan goresan bertebal tetap tetap tanpa daftar tebal', () {
      final sisa = stroke().erase(const Offset(30, 0), 8);
      expect(sisa, isNotEmpty);
      for (final piece in sisa) {
        expect(piece.widths, isNull);
      }
    });

    test('papan tulis: tebal per titik ikut saat kertasnya diputar', () {
      const page = BoardPage(
        background: Color(0xFFFFFFFF),
        strokes: <BoardStroke>[
          BoardStroke(
            points: <Offset>[Offset(10, 10), Offset(50, 50)],
            color: Color(0xFF000000),
            width: 3,
            widths: <double>[1.8, 4.2],
          ),
        ],
      );
      final turned = page.turned();
      expect(turned.strokes.single.widths, <double>[1.8, 4.2]);
    });
  });
}
