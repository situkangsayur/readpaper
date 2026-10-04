import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/utils/ink_palette.dart';
import 'package:readpaper/src/core/utils/ink_smoothing.dart';
import 'package:readpaper/src/core/utils/shape_geometry.dart';
import 'package:readpaper/src/features/notebook/data/note_document_store.dart';
import 'package:readpaper/src/features/notebook/domain/note_document.dart';

void main() {
  group('bangun dua dimensi', () {
    test('setiap bangun menghasilkan garis di dalam kotaknya', () {
      for (final kind in ShapeKind.values) {
        final lines = ShapeGeometry.outline(kind, const Size(100, 60));
        expect(lines, isNotEmpty, reason: kind.name);
        for (final line in lines) {
          expect(line.length, greaterThanOrEqualTo(2), reason: kind.name);
          for (final point in line) {
            // Panah punya mata panah yang sedikit menjorok ke dalam, jadi
            // batasnya diberi kelonggaran kecil.
            expect(point.dx, inInclusiveRange(-1, 101), reason: kind.name);
            expect(point.dy, inInclusiveRange(-1, 61), reason: kind.name);
          }
        }
      }
    });

    test('kotak tertutup, garis tidak', () {
      final kotak = ShapeGeometry.outline(ShapeKind.kotak, const Size(50, 40)).single;
      expect(kotak.first, kotak.last, reason: 'kembali ke titik awal');

      final garis = ShapeGeometry.outline(ShapeKind.garis, const Size(50, 40)).single;
      expect(garis, hasLength(2));
      expect(garis.first, Offset.zero);
      expect(garis.last, const Offset(50, 40));
    });

    test('bulat melengkung, bukan bersudut', () {
      final bulat = ShapeGeometry.outline(ShapeKind.bulat, const Size(100, 100)).single;
      expect(bulat.length, greaterThan(24));
      for (final point in bulat) {
        // Semua titiknya berjarak sama dari pusatnya.
        expect((point - const Offset(50, 50)).distance, closeTo(50, 0.5));
      }
    });

    test('panah punya mata panah di ujungnya', () {
      final lines = ShapeGeometry.outline(ShapeKind.panah, const Size(100, 0));
      expect(lines, hasLength(2), reason: 'batang dan mata panahnya');
      final head = lines.last;
      expect(head, hasLength(3));
      // Ujung panahnya ada di ujung batangnya.
      expect(head[1], lines.first.last);
      // Kedua sayapnya berada di belakang ujungnya.
      expect(head.first.dx, lessThan(head[1].dx));
      expect(head.last.dx, lessThan(head[1].dx));
    });

    test('mata panah mengikuti arah garisnya', () {
      final head = ShapeGeometry.arrowHead(tip: const Offset(0, 100), from: Offset.zero);
      // Menunjuk ke bawah: sayapnya di atas ujungnya.
      for (final wing in <Offset>[head.first, head.last]) {
        expect(wing.dy, lessThan(100));
      }
    });

    test('bangun tidak menyimpan titik: diubah ukurannya tetap rapi', () {
      // Bangun yang titiknya disimpan lalu ditarik melar akan punya garis
      // setebal berbeda di tiap sisi. Dihitung ulang dari kotaknya, tidak.
      const kecil = NoteShape(
        id: 's1',
        position: Offset.zero,
        size: Size(20, 20),
        shape: ShapeKind.kotak,
      );
      final besar = kecil.copyWith(size: const Size(200, 120));
      expect(besar.outline.single.last, const Offset(0, 0));
      expect(besar.outline.single[1], const Offset(200, 0));
      expect(besar.outline.single[2], const Offset(200, 120));
    });
  });

  group('penghubung antar objek', () {
    NoteShape box(String id, Offset at) =>
        NoteShape(id: id, position: at, size: const Size(80, 50), shape: ShapeKind.kotak);

    test('ujungnya berhenti di tepi kedua benda, bukan di tengahnya', () {
      final page = NotePage(
        components: <NoteComponent>[
          box('a', const Offset(100, 100)),
          box('b', const Offset(100, 300)),
          const NoteConnector(id: 'c1', fromId: 'a', toId: 'b'),
        ],
      );
      final ends = page.endsOf(page.components.last as NoteConnector)!;
      expect(ends.$1.dy, 150, reason: 'tepi bawah benda pertama');
      expect(ends.$2.dy, 300, reason: 'tepi atas benda kedua');
      expect(ends.$1.dx, 140);
    });

    test('mengikuti saat bendanya digeser', () {
      // Penghubung yang tidak mengikuti bukan penghubung: yang disimpan adalah
      // rujukan ke kedua benda, bukan koordinat.
      var page = NotePage(
        components: <NoteComponent>[
          box('a', const Offset(100, 100)),
          box('b', const Offset(100, 300)),
          const NoteConnector(id: 'c1', fromId: 'a', toId: 'b'),
        ],
      );
      final sebelum = page.endsOf(page.components.last as NoteConnector)!;

      page = page.copyWith(
        components: <NoteComponent>[
          box('a', const Offset(100, 100)),
          box('b', const Offset(400, 300)),
          const NoteConnector(id: 'c1', fromId: 'a', toId: 'b'),
        ],
      );
      final sesudah = page.endsOf(page.components.last as NoteConnector)!;
      expect(sesudah.$2, isNot(sebelum.$2));
      expect(sesudah.$2.dx, 400, reason: 'menempel di tepi kiri benda yang baru');
    });

    test('membuang bendanya ikut membuang penghubungnya', () {
      final page = NotePage(
        components: <NoteComponent>[
          box('a', const Offset(100, 100)),
          box('b', const Offset(100, 300)),
          const NoteConnector(id: 'c1', fromId: 'a', toId: 'b'),
        ],
      );
      final after = page.without('b');
      expect(after.components.map((c) => c.id), <String>['a']);
    });

    test('penghubung yang ujungnya tidak ada dibuang saat dibaca', () async {
      // Bisa terjadi setelah dua orang menyunting catatan yang sama lalu
      // hasilnya digabung.
      final json = <String, dynamic>{
        'version': 1,
        'pages': <dynamic>[
          <String, dynamic>{
            'components': <dynamic>[
              box('a', const Offset(10, 10)).toJson(),
              const NoteConnector(id: 'c1', fromId: 'a', toId: 'hilang').toJson(),
            ],
          },
        ],
      };
      final document = NoteDocument.fromJson(json);
      expect(document.pages.single.components.map((c) => c.id), <String>['a']);
    });

    test('diketuk pada garisnya, bukan pada kotaknya', () {
      final page = NotePage(
        components: <NoteComponent>[
          box('a', const Offset(100, 100)),
          box('b', const Offset(100, 300)),
          const NoteConnector(id: 'c1', fromId: 'a', toId: 'b'),
        ],
      );
      expect(page.hitTest(const Offset(140, 220))?.id, 'c1');
      expect(page.hitTest(const Offset(300, 220)), isNull);
    });

    test('bertahan setelah disimpan dan dibaca ulang', () {
      final document = NoteDocument(
        pages: <NotePage>[
          NotePage(
            components: <NoteComponent>[
              box('a', const Offset(10, 10)),
              box('b', const Offset(10, 200)),
              const NoteConnector(
                id: 'c1',
                fromId: 'a',
                toId: 'b',
                arrow: false,
                color: 0xFFC62828,
              ),
            ],
          ),
        ],
      );
      final kembali = NoteDocumentStore.decodeSync(NoteDocumentStore.encode(document));
      final connector = kembali.pages.single.components.last as NoteConnector;
      expect(connector.fromId, 'a');
      expect(connector.toId, 'b');
      expect(connector.arrow, isFalse);
      expect(connector.color, 0xFFC62828);

      final shape = kembali.pages.single.components.first as NoteShape;
      expect(shape.shape, ShapeKind.kotak);
    });
  });

  group('penghalus tinta', () {
    test('kurva melewati titik tengah dan berakhir di titik terakhir', () {
      const points = <Offset>[Offset(0, 0), Offset(10, 0), Offset(20, 10), Offset(30, 10)];
      final quads = InkSmoothing.quads(points);
      expect(quads, isNotEmpty);
      expect(quads.last.end, points.last, reason: 'berhenti di tempat jarinya diangkat');
      for (final quad in quads) {
        expect(points, contains(quad.control), reason: 'titik aslinya jadi kendali');
      }
    });

    test('dua titik tetap jadi satu ruas', () {
      final quads = InkSmoothing.quads(const <Offset>[Offset(0, 0), Offset(10, 10)]);
      expect(quads, hasLength(1));
      expect(quads.single.end, const Offset(10, 10));
    });

    test('satu titik tidak menghasilkan kurva', () {
      expect(InkSmoothing.quads(const <Offset>[Offset(1, 1)]), isEmpty);
    });

    test('kuadratik jadi kubik menggambarkan kurva yang sama', () {
      // Kendali kubiknya harus berada dua-pertiga jalan menuju kendali
      // kuadratiknya — itu perubahan bentuk yang persis nol.
      final cubic = InkSmoothing.toCubic(Offset.zero, const Offset(30, 0), const Offset(60, 0));
      expect(cubic.c1.dx, closeTo(20, 1e-9));
      expect(cubic.c2.dx, closeTo(40, 1e-9));
      expect(cubic.end, const Offset(60, 0));
    });
  });

  group('palet', () {
    test('warnanya bernama dan tidak ada yang kembar', () {
      expect(InkPalette.all.length, greaterThanOrEqualTo(12));
      final names = InkPalette.all.map((c) => c.name).toSet();
      final colors = InkPalette.all.map((c) => c.color).toSet();
      expect(names, hasLength(InkPalette.all.length));
      expect(colors, hasLength(InkPalette.all.length));
      for (final option in InkPalette.all) {
        expect(option.name.trim(), isNotEmpty);
      }
    });
  });
}
