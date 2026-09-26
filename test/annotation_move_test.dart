import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/reader/domain/annotation_geometry.dart';
import 'package:readpaper/src/features/reader/domain/annotation_move.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  /// Tanda tangan sederhana: satu goresan mendatar.
  ZoteroAnnotation ink({double x = 100, double y = 200}) => ZoteroAnnotation(
    key: 'ABCD1234',
    parentItemKey: 'PARENT01',
    type: AnnotationType.ink,
    color: '#000000',
    pageIndex: 0,
    paths: <InkPath>[
      InkPath(<double>[x, y, x + 40, y + 10]),
    ],
    inkWidth: 2,
    sortIndex: '00000|000000|00000',
    authorName: '',
    dateAdded: DateTime(2026),
    dateModified: DateTime(2026),
  );

  ZoteroAnnotation highlight() => ZoteroAnnotation(
    key: 'EFGH5678',
    parentItemKey: 'PARENT01',
    type: AnnotationType.highlight,
    color: '#ffd400',
    pageIndex: 0,
    rects: <AnnotationRect>[const AnnotationRect(50, 100, 150, 120)],
    sortIndex: '00000|000000|00000',
    authorName: '',
    dateAdded: DateTime(2026),
    dateModified: DateTime(2026),
  );

  group('batas anotasi', () {
    test('tinta punya batas walau tidak menyimpan rects', () {
      // Inilah sebab tanda tangan tidak pernah bisa dipilih: Zotero tidak
      // menyimpan rects untuk tinta, dan uji ketuknya hanya melihat rects.
      expect(ink().rects, isEmpty);

      final rects = AnnotationMove.rectsOf(ink());
      expect(rects, hasLength(1));
      expect(rects.single.left, lessThanOrEqualTo(100));
      expect(rects.single.right, greaterThanOrEqualTo(140));
    });

    test('ketukan di atas tanda tangan mengenainya', () {
      expect(
        AnnotationGeometry.hitTest(annotation: ink(), point: const PdfPoint(120, 205)),
        isTrue,
      );
      expect(
        AnnotationGeometry.hitTest(annotation: ink(), point: const PdfPoint(400, 400)),
        isFalse,
      );
    });
  });

  group('memindahkan', () {
    test('goresan bergeser utuh', () {
      final moved = AnnotationMove.shift(
        ink(),
        dx: 30,
        dy: -50,
        pageWidth: 595,
        pageHeight: 842,
      );
      final path = moved.paths.single;
      expect(path.xAt(0), 130);
      expect(path.yAt(0), 150);
      expect(path.xAt(1), 170);
      expect(path.yAt(1), 160);
    });

    test('rects ikut bergeser untuk stabilo', () {
      final moved = AnnotationMove.shift(
        highlight(),
        dx: 10,
        dy: 5,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect(moved.rects.single.left, 60);
      expect(moved.rects.single.bottom, 105);
      expect(moved.rects.single.right, 160);
      expect(moved.rects.single.top, 125);
    });

    test('tidak bisa didorong keluar halaman', () {
      // Yang terdorong keluar bukan "di tempat lain", melainkan hilang.
      final moved = AnnotationMove.shift(
        ink(),
        dx: -500,
        dy: 0,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect(moved.paths.single.xAt(0), greaterThanOrEqualTo(0));
    });

    test('urutan di daftar samping ikut diperbarui', () {
      final before = ink();
      final moved = AnnotationMove.shift(
        before,
        dx: 0,
        dy: -300,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect(moved.sortIndex, isNot(before.sortIndex));
    });

    test('geseran nol mengembalikan yang sama persis', () {
      final before = ink();
      expect(
        identical(AnnotationMove.shift(before, dx: 0, dy: 0, pageWidth: 595, pageHeight: 842),
            before),
        isTrue,
      );
    });
  });
}
