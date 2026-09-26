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
    final bounds = rectsOf(annotation).isEmpty
        ? null
        : _boundsOf(rectsOf(annotation));
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
