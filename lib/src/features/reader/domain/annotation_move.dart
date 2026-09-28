import 'dart:math' as math;

import '../../library/domain/entities/zotero_annotation.dart';

/// Moving an annotation across the page it lives on.
///
/// A signature dropped in the wrong place used to be permanent: ink has no
/// rectangles in Zotero's format, so nothing could even be selected, let
/// alone moved. Filling in a form is exactly where being a few centimetres
/// off matters, so both are fixed here — the bounds come from the strokes
/// themselves, and the whole drawing shifts as one.
class AnnotationMove {
  const AnnotationMove._();

  /// Every rectangle the annotation occupies, in PDF page coordinates.
  ///
  /// For ink there are none stored, so one is derived from the strokes.
  static List<AnnotationRect> rectsOf(ZoteroAnnotation annotation) {
    if (annotation.rects.isNotEmpty) return annotation.rects;
    final bounds = boundsOfPaths(annotation.paths, padding: annotation.inkWidth);
    return bounds == null ? const <AnnotationRect>[] : <AnnotationRect>[bounds];
  }

  /// Box around a set of strokes, widened by half the pen width so the edge
  /// of a thick line is still inside it.
  static AnnotationRect? boundsOfPaths(List<InkPath> paths, {double padding = 0}) {
    double? left, bottom, right, top;
    for (final path in paths) {
      for (var i = 0; i < path.length; i++) {
        final x = path.xAt(i);
        final y = path.yAt(i);
        left = (left == null || x < left) ? x : left;
        right = (right == null || x > right) ? x : right;
        bottom = (bottom == null || y < bottom) ? y : bottom;
        top = (top == null || y > top) ? y : top;
      }
    }
    if (left == null || bottom == null || right == null || top == null) return null;
    final grow = padding / 2;
    return AnnotationRect(left - grow, bottom - grow, right + grow, top + grow);
  }

  /// The same annotation, shifted by [dx] and [dy] in PDF points.
  ///
  /// [dy] counts the way PDF does: upwards. Callers working in screen
  /// coordinates have to flip it themselves, which is the same flip they
  /// already do to draw.
  static ZoteroAnnotation shift(
    ZoteroAnnotation annotation, {
    required double dx,
    required double dy,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (dx == 0 && dy == 0) return annotation;

    // Kept on the page. A signature dragged past the edge is not "somewhere
    // else", it is gone — and getting it back means finding it in a list.
    final bounds = rectsOf(annotation).isEmpty ? null : _boundsOf(rectsOf(annotation));
    var moveX = dx;
    var moveY = dy;
    if (bounds != null) {
      if (bounds.left + moveX < 0) moveX = -bounds.left;
      if (bounds.right + moveX > pageWidth) moveX = pageWidth - bounds.right;
      if (bounds.bottom + moveY < 0) moveY = -bounds.bottom;
      if (bounds.top + moveY > pageHeight) moveY = pageHeight - bounds.top;
    }

    final rects = <AnnotationRect>[
      for (final rect in annotation.rects)
        AnnotationRect(
          rect.left + moveX,
          rect.bottom + moveY,
          rect.right + moveX,
          rect.top + moveY,
        ),
    ];

    final paths = <InkPath>[
      for (final path in annotation.paths)
        InkPath(<double>[
          for (var i = 0; i < path.length; i++) ...<double>[
            path.xAt(i) + moveX,
            path.yAt(i) + moveY,
          ],
        ]),
    ];

    // The sort index decides where the annotation appears in the sidebar, and
    // it is derived from how far down the page it sits — so moving it has to
    // rewrite it, or the list stops matching the page.
    final moved = annotation.copyWith(rects: rects, paths: paths);
    final top = _boundsOf(rectsOf(moved))?.top ?? 0;
    return moved.copyWith(
      sortIndex: ZoteroAnnotation.buildSortIndex(
        pageIndex: annotation.pageIndex,
        textOffset: 0,
        topFromPageTop: pageHeight - top,
      ),
    );
  }

  /// Anotasi yang diperbesar dan/atau diputar terhadap titik tengahnya.
  ///
  /// Hanya untuk tinta. Stabilo dan garis bawah disimpan Zotero sebagai
  /// kotak yang sejajar sumbu — memutarnya berarti menyimpan sesuatu yang
  /// tidak bisa dibaca kembali oleh Zotero, dan itu harga yang tidak
  /// sepadan untuk sebuah kemudahan.
  ///
  /// Titiknya ditulis ulang, karena format tinta Zotero memang hanya
  /// menyimpan titik — tidak ada tempat untuk sudut atau skala. Karena itu
  /// pemanggilnya menerapkan seluruh gerakan **sekali** dari anotasi
  /// aslinya, bukan sedikit demi sedikit: memutar seratus kali dengan satu
  /// derajat kehilangan ketelitian yang tidak bisa dikembalikan.
  static ZoteroAnnotation transform(
    ZoteroAnnotation annotation, {
    double scale = 1,
    double rotation = 0,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (annotation.paths.isEmpty) return annotation;
    if (scale == 1 && rotation == 0) return annotation;

    final bounds = _boundsOf(rectsOf(annotation));
    if (bounds == null) return annotation;

    // Batas bawah yang masuk akal: anotasi yang diperkecil sampai satu titik
    // tidak bisa dipegang lagi untuk dikembalikan.
    final safeScale = scale.clamp(0.15, 12.0);
    final cx = (bounds.left + bounds.right) / 2;
    final cy = (bounds.bottom + bounds.top) / 2;
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);

    double newX(double x, double y) => cx + ((x - cx) * cos - (y - cy) * sin) * safeScale;
    double newY(double x, double y) => cy + ((x - cx) * sin + (y - cy) * cos) * safeScale;

    final paths = <InkPath>[
      for (final path in annotation.paths)
        InkPath(<double>[
          for (var i = 0; i < path.length; i++) ...<double>[
            newX(path.xAt(i), path.yAt(i)),
            newY(path.xAt(i), path.yAt(i)),
          ],
        ]),
    ];

    // Tebal penanya ikut diperbesar: tanda tangan yang digandakan ukurannya
    // dengan garis setipis semula terlihat seperti gambar yang ditarik.
    final moved = annotation.copyWith(
      paths: paths,
      inkWidth: (annotation.inkWidth * safeScale).clamp(0.3, 40.0),
    );

    // Tetap di dalam halaman, sama seperti saat digeser.
    final after = _boundsOf(rectsOf(moved));
    if (after == null) return moved;
    var dx = 0.0;
    var dy = 0.0;
    if (after.left < 0) dx = -after.left;
    if (after.right + dx > pageWidth) dx = pageWidth - after.right;
    if (after.bottom < 0) dy = -after.bottom;
    if (after.top + dy > pageHeight) dy = pageHeight - after.top;

    return shift(moved, dx: dx, dy: dy, pageWidth: pageWidth, pageHeight: pageHeight);
  }

  static AnnotationRect? _boundsOf(List<AnnotationRect> rects) {
    if (rects.isEmpty) return null;
    var left = rects.first.left;
    var bottom = rects.first.bottom;
    var right = rects.first.right;
    var top = rects.first.top;
    for (final rect in rects.skip(1)) {
      if (rect.left < left) left = rect.left;
      if (rect.bottom < bottom) bottom = rect.bottom;
      if (rect.right > right) right = rect.right;
      if (rect.top > top) top = rect.top;
    }
    return AnnotationRect(left, bottom, right, top);
  }
}
