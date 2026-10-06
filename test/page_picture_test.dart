import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/reader/data/page_picture.dart';
import 'package:readpaper/src/features/reader/domain/annotation_move.dart';
import 'package:readpaper/src/features/reader/presentation/widgets/save_as_dialog.dart';

Uint8List png(int w, int h, {bool transparent = false}) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(200, 30, 30, transparent ? 0 : 255));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('menyiapkan gambar', () {
    test('foto besar diperkecil dan jadi JPEG', () {
      final prepared = PagePicture.prepare(png(4000, 1000))!;
      expect(prepared.width, PagePicture.maxSide);
      expect(prepared.height, 500);
      expect(prepared.extension, '.jpg');
    });

    test('gambar transparan tetap PNG', () {
      final prepared = PagePicture.prepare(png(100, 50, transparent: true))!;
      expect(prepared.extension, '.png');
      expect(prepared.width, 100);
    });

    test('bukan gambar → null', () {
      expect(PagePicture.prepare(Uint8List.fromList(<int>[1, 2, 3, 4])), isNull);
    });

    test('ditaruh di tengah, paling lebar setengah halaman, rasio tetap', () {
      final rect = PagePicture.placeCentered(
        width: 1600,
        height: 800,
        pageWidth: 600,
        pageHeight: 800,
      );
      expect(rect.width, closeTo(300, 0.01));
      expect(rect.height, closeTo(150, 0.01));
      expect((rect.left + rect.right) / 2, closeTo(300, 0.01));
    });
  });

  test('ditaruh di tengah bagian yang terlihat, tetap di dalam halaman', () {
    final rect = PagePicture.placeCentered(
      width: 400,
      height: 400,
      pageWidth: 600,
      pageHeight: 800,
      centerX: 300,
      centerY: 700,
    );
    expect((rect.bottom + rect.top) / 2, closeTo(650, 0.01), reason: 'ditahan di tepi atas');
    expect(rect.top, lessThanOrEqualTo(800));
  });

  group('mengubah ukuran gambar', () {
    final picture = PagePicture.create(
      key: 'PIC00001',
      parentItemKey: 'ATT00001',
      pageIndex: 0,
      rect: const AnnotationRect(100, 100, 300, 200),
      file: 'a.png',
      pageHeight: 800,
    );

    test('diperbesar dari tengah, rasio tetap', () {
      final big = AnnotationMove.transform(picture, scale: 1.5, pageWidth: 600, pageHeight: 800);
      final r = big.rects.single;
      expect(r.width, closeTo(300, 0.01));
      expect(r.height, closeTo(150, 0.01));
      expect((r.left + r.right) / 2, closeTo(200, 0.01));
      expect(PagePicture.fileOf(big), 'a.png');
    });

    test('tidak melebihi halaman', () {
      final huge = AnnotationMove.transform(picture, scale: 10, pageWidth: 600, pageHeight: 800);
      final r = huge.rects.single;
      expect(r.width, lessThanOrEqualTo(600.01));
      expect(r.left, greaterThanOrEqualTo(-0.01));
      expect(r.right, lessThanOrEqualTo(600.01));
    });
  });

  group('penyimpanan di catatan/', () {
    late Directory repo;
    setUp(() => repo = Directory.systemTemp.createTempSync('gambar'));
    tearDown(() => repo.deleteSync(recursive: true));

    test('simpan, baca ulang, salinan berbagi berkas, hapus bersih', () async {
      final dir = PagePictureStore.directoryFor(repoRoot: repo.path, attachmentKey: 'ATT00001');
      expect(dir, p.join(repo.path, 'catatan', 'gambar-halaman', 'ATT00001'));
      final store = PagePictureStore(dir);
      final first = PagePicture.create(
        key: 'PIC00001',
        parentItemKey: 'ATT00001',
        pageIndex: 2,
        rect: const AnnotationRect(10, 10, 110, 60),
        file: 'gambar1.png',
        pageHeight: 800,
      );
      final bytes = png(20, 10);
      await store.put(first, bytes: bytes);
      final second = AnnotationMove.duplicate(first, key: 'PIC00002');
      await store.put(second);

      final loaded = await store.load();
      expect(loaded.map((a) => a.key), <String>['PIC00001', 'PIC00002']);
      expect(loaded.first.pageIndex, 2);
      expect(PagePicture.isPicture(loaded.first), isTrue);
      expect(await store.bytes('gambar1.png'), bytes);

      await store.remove('PIC00001');
      expect(File(p.join(dir, 'gambar1.png')).existsSync(), isTrue, reason: 'masih dipakai');
      await store.remove('PIC00002');
      expect(Directory(dir).existsSync(), isFalse);
    });

    test('anotasi gambar tidak pernah menyentuh folder zotero', () async {
      final store = PagePictureStore(
        PagePictureStore.directoryFor(repoRoot: repo.path, attachmentKey: 'ATT00001'),
      );
      await store.put(
        PagePicture.create(
          key: 'PIC00001',
          parentItemKey: 'ATT00001',
          pageIndex: 0,
          rect: const AnnotationRect(0, 0, 10, 10),
          file: 'x.png',
          pageHeight: 800,
        ),
        bytes: png(2, 2),
      );
      expect(Directory(p.join(repo.path, 'zotero')).existsSync(), isFalse);
    });
  });

  group('nama Simpan sebagai', () {
    test('akhiran .pdf ditambahkan sekali dan tanda terlarang dibuang', () {
      expect(SaveAsNames.fileName('laporan'), 'laporan.pdf');
      expect(SaveAsNames.fileName('laporan.PDF'), 'laporan.pdf');
      expect(SaveAsNames.fileName(' a/b:c? '), 'abc.pdf');
      expect(SaveAsNames.fileName('   '), isNull);
      expect(SaveAsNames.fileName('..'), isNull);
    });

    test('jalur yang sama dikenali walau ditulis berbeda', () {
      expect(SaveAsNames.samePath('/tmp/a/../b.pdf', '/tmp/b.pdf'), isTrue);
      expect(SaveAsNames.samePath('/tmp/a.pdf', '/tmp/b.pdf'), isFalse);
    });
  });
}
