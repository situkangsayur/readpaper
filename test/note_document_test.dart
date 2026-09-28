import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/notebook/data/note_document_store.dart';
import 'package:readpaper/src/features/notebook/domain/note_document.dart';
import 'package:readpaper/src/features/notebook/domain/note_history.dart';

void main() {
  NoteInk ink({String id = 'i1', double x = 20, double y = 30}) => NoteInk(
    id: id,
    position: Offset(x, y),
    size: const Size(100, 40),
    strokes: <NoteStroke>[
      NoteStroke(points: const <Offset>[Offset(0, 0), Offset(50, 20), Offset(100, 40)], width: 2.5),
    ],
  );

  NoteText text({String id = 't1'}) => NoteText(
    id: id,
    position: const Offset(40, 200),
    size: const Size(300, 60),
    text: 'Rapat mulai pukul sembilan',
    fontSize: 18,
  );

  NoteDiagram diagram({String id = 'd1'}) => NoteDiagram(
    id: id,
    position: const Offset(60, 320),
    size: const Size(260, 180),
    source: 'graph TD\n  A[Mulai] --> B[Selesai]',
  );

  group('komponen', () {
    test('sudut, skala, dan kepekatan adalah sifat, bukan titik yang ditulis ulang', () {
      // Memutar dua kali dengan menulis ulang titik akan kehilangan ketelitian
      // sedikit demi sedikit; menyimpannya sebagai sifat membuat memutar
      // bolak-balik kembali persis.
      final asal = ink();
      final diputar = asal.copyWith(rotation: math.pi / 3);
      final kembali = diputar.copyWith(rotation: 0);

      expect(diputar.strokes.first.points, asal.strokes.first.points);
      expect(kembali.strokes.first.points, asal.strokes.first.points);
      expect(diputar.rotation, closeTo(math.pi / 3, 1e-12));
    });

    test('setiap komponen bisa digeser, diubah ukuran, diputar, diwarnai, dan dipudarkan', () {
      final semua = <NoteComponent>[ink(), text(), diagram()];
      for (final component in semua) {
        final ubah = component.copyWith(
          position: const Offset(1, 2),
          size: const Size(11, 12),
          rotation: 0.5,
          opacity: 0.4,
          color: 0xFF112233,
        );
        expect(ubah.position, const Offset(1, 2), reason: '${component.kind}');
        expect(ubah.size, const Size(11, 12), reason: '${component.kind}');
        expect(ubah.rotation, 0.5, reason: '${component.kind}');
        expect(ubah.opacity, 0.4, reason: '${component.kind}');
        expect(ubah.color, 0xFF112233, reason: '${component.kind}');
        expect(ubah.id, component.id, reason: 'jati dirinya tidak ikut berubah');
      }
    });

    test('yang paling atas yang terkena ketukan', () {
      final page = NotePage(
        components: <NoteComponent>[
          ink(id: 'bawah', x: 0, y: 0),
          ink(id: 'atas', x: 10, y: 10),
        ],
      );
      expect(page.hitTest(const Offset(50, 30))?.id, 'atas');
      expect(page.hitTest(const Offset(500, 700)), isNull);
    });

    test('uji ketuk ikut memperhitungkan sudut putarnya', () {
      // Kotak 100×40 yang diputar seperempat lingkaran jadi jangkung; titik di
      // bawah titik tengahnya sekarang kena, padahal sebelumnya tidak.
      final tegak = ink(id: 'putar', x: 100, y: 100).copyWith(rotation: math.pi / 2);
      final page = NotePage(components: <NoteComponent>[tegak]);
      expect(page.hitTest(const Offset(150, 150)), isNotNull);
      expect(page.hitTest(const Offset(151, 90)), isNotNull);
    });
  });

  group('goresan', () {
    test('jarak diukur ke garisnya, bukan ke titik-titiknya', () {
      // Goresan cepat hanya menyimpan titik berjauhan; penghapus yang mengukur
      // ke titik akan meleset di tengah garis.
      const stroke = NoteStroke(points: <Offset>[Offset(0, 0), Offset(100, 0)], width: 2);
      expect(stroke.distanceTo(const Offset(50, 3)), closeTo(3, 0.01));
      expect(stroke.distanceTo(const Offset(50, 0)), closeTo(0, 0.01));
    });

    test('penghapus sebagian membelah goresan jadi dua', () {
      const stroke = NoteStroke(
        points: <Offset>[Offset(0, 0), Offset(20, 0), Offset(40, 0), Offset(60, 0), Offset(80, 0)],
        width: 2,
      );
      final sisa = stroke.erase(const Offset(40, 0), 10);
      expect(sisa, hasLength(2));
      // Potongannya berhenti tepat di luar lubangnya — di mana persis
      // tergantung kerapatan titiknya, dan itu bukan janji apa pun.
      expect(sisa.first.points.last.dx, lessThanOrEqualTo(30));
      expect(sisa.last.points.first.dx, greaterThanOrEqualTo(50));
    });

    test('menghapus di antara dua titik yang berjauhan tetap memotong', () {
      // Goresan cepat hanya menyimpan titik berjauhan; penghapus yang mendarat
      // di tengah ruas harus tetap membelahnya, bukan melewatkannya utuh.
      const stroke = NoteStroke(points: <Offset>[Offset(0, 0), Offset(200, 0)], width: 2);
      final sisa = stroke.erase(const Offset(100, 0), 10);
      expect(sisa, hasLength(2));
      expect(sisa.first.points.last.dx, lessThan(95));
      expect(sisa.last.points.first.dx, greaterThan(105));
    });

    test('penghapus yang melewati ujung hanya memendekkan', () {
      const stroke = NoteStroke(
        points: <Offset>[Offset(0, 0), Offset(20, 0), Offset(40, 0), Offset(60, 0)],
        width: 2,
      );
      final sisa = stroke.erase(const Offset(0, 0), 10);
      expect(sisa, hasLength(1));
      expect(sisa.single.points.first.dx, greaterThanOrEqualTo(10));
      expect(sisa.single.points.last.dx, 60, reason: 'ujung yang lain utuh');
    });

    test('potongan sisa mewarisi ketebalannya', () {
      const stroke = NoteStroke(
        points: <Offset>[Offset(0, 0), Offset(20, 0), Offset(40, 0), Offset(60, 0)],
        width: 7.5,
      );
      expect(stroke.erase(const Offset(0, 0), 10).single.width, 7.5);
    });

    test('batas goresan memperhitungkan tebal penanya', () {
      const stroke = NoteStroke(points: <Offset>[Offset(10, 10), Offset(20, 20)], width: 4);
      expect(stroke.bounds.left, 8);
      expect(stroke.bounds.bottom, 22);
    });
  });

  group('berkas yang bisa disunting lagi', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('rp-catatan-'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('bolak-balik tanpa kehilangan apa pun', () async {
      final document = NoteDocument(
        title: 'Rapat Senin',
        pages: <NotePage>[
          NotePage(
            rule: NotePageRule.bergaris,
            components: <NoteComponent>[
              ink().copyWith(rotation: 0.35, opacity: 0.6, color: 0xFF2255AA),
              text(),
              diagram(),
              const NoteImage(
                id: 'g1',
                position: Offset(300, 500),
                size: Size(120, 90),
                file: 'gambar/papan.png',
                alt: 'papan tulis',
              ),
            ],
          ),
          const NotePage(rule: NotePageRule.kotak),
        ],
      );

      final path = p.join(dir.path, 'rapat${NoteDocumentStore.extension}');
      await NoteDocumentStore.write(path, document);
      final kembali = await NoteDocumentStore.read(path);

      expect(kembali.title, 'Rapat Senin');
      expect(kembali.pages, hasLength(2));
      expect(kembali.pages.last.rule, NotePageRule.kotak);

      final ulang = kembali.pages.first.components;
      expect(ulang.map((c) => c.kind), <NoteComponentKind>[
        NoteComponentKind.ink,
        NoteComponentKind.text,
        NoteComponentKind.diagram,
        NoteComponentKind.image,
      ]);

      final tinta = ulang.first as NoteInk;
      expect(tinta.rotation, closeTo(0.35, 1e-6));
      expect(tinta.opacity, closeTo(0.6, 1e-6));
      expect(tinta.color, 0xFF2255AA);
      expect(tinta.strokes.single.points, hasLength(3));
      expect(tinta.strokes.single.width, 2.5);

      expect((ulang[1] as NoteText).text, 'Rapat mulai pukul sembilan');
      expect((ulang[1] as NoteText).fontSize, 18);
      expect((ulang[2] as NoteDiagram).source, contains('graph TD'));
      expect((ulang[3] as NoteImage).file, 'gambar/papan.png');
      expect((ulang[3] as NoteImage).alt, 'papan tulis');
    });

    test('ditulis sebagai JSON beridentasi tab dengan kunci terurut', () {
      // Catatan ini hidup di dalam repositori git: diff-nya harus terbaca.
      final raw = NoteDocumentStore.encode(NoteDocument.blank(title: 'A'));
      expect(raw, contains('\n\t"'));
      expect(raw.endsWith('\n'), isTrue);
      final keys = (jsonDecode(raw) as Map).keys.toList();
      expect(keys, List<String>.from(keys)..sort());
    });

    test('berkas dari versi yang lebih baru ditolak dengan jelas', () async {
      // Membaca setengah-setengah lalu menyimpan balik akan merusak isinya.
      final path = p.join(dir.path, 'masa-depan${NoteDocumentStore.extension}');
      File(path).writeAsStringSync(jsonEncode(<String, dynamic>{'version': 99, 'pages': <dynamic>[]}));
      await expectLater(
        NoteDocumentStore.read(path),
        throwsA(
          predicate((Object e) => e.toString().contains('lebih baru'), 'menyebut sebabnya'),
        ),
      );
    });

    test('nama ekspornya diturunkan dari nama berkasnya', () {
      expect(NoteDocumentStore.stemOf('/a/b/rapat.catatan.json'), 'rapat');
      expect(NoteDocumentStore.isNoteDocument('/a/rapat.catatan.json'), isTrue);
      expect(NoteDocumentStore.isNoteDocument('/a/rapat.md'), isFalse);
    });
  });

  group('urungkan', () {
    test('menyimpan keadaan, jadi apa pun bisa diurungkan', () {
      final history = NoteHistory(NoteDocument.blank());
      expect(history.canUndo, isFalse);

      final satu = NoteDocument(pages: <NotePage>[NotePage(components: <NoteComponent>[ink()])]);
      history.push(satu);
      final dua = satu.replacePage(
        0,
        satu.pages.first.copyWith(components: <NoteComponent>[ink(), text()]),
      );
      history.push(dua);

      expect(history.current.pages.first.components, hasLength(2));
      expect(history.undo().pages.first.components, hasLength(1));
      expect(history.undo().pages.first.components, isEmpty);
      expect(history.canUndo, isFalse);
      expect(history.redo().pages.first.components, hasLength(1));
    });

    test('menulis sesuatu yang baru membuang yang sudah diurungkan', () {
      final history = NoteHistory(NoteDocument.blank())
        ..push(NoteDocument(pages: <NotePage>[NotePage(components: <NoteComponent>[ink()])]));
      history.undo();
      history.push(NoteDocument(pages: <NotePage>[NotePage(components: <NoteComponent>[text()])]));

      expect(history.canRedo, isFalse);
      expect((history.current.pages.first.components.single as NoteText).id, 't1');
    });

    test('riwayatnya dibatasi, tidak tumbuh selamanya', () {
      final history = NoteHistory(NoteDocument.blank(), limit: 5);
      for (var i = 0; i < 20; i++) {
        history.push(NoteDocument(pages: <NotePage>[NotePage(components: <NoteComponent>[ink(id: 'i$i')])]));
      }
      var langkah = 0;
      while (history.canUndo) {
        history.undo();
        langkah++;
      }
      expect(langkah, lessThanOrEqualTo(5));
    });
  });
}
