import 'dart:ui';

import 'package:pdfrx/pdfrx.dart';

import '../../library/domain/entities/zotero_annotation.dart';

/// Conversions between Zotero annotation coordinates and pdfrx/Flutter ones.
///
/// Zotero stores rectangles as `[x1, y1, x2, y2]` in PDF points with the origin
/// at the bottom-left of the page — exactly what pdfrx exposes as [PdfRect], so
/// no unit conversion is needed, only an axis flip when painting.
class AnnotationGeometry {
  const AnnotationGeometry._();

  static AnnotationRect fromPdfRect(PdfRect rect) =>
      AnnotationRect(rect.left, rect.bottom, rect.right, rect.top);

  static PdfRect toPdfRect(AnnotationRect rect) =>
      PdfRect(rect.left, rect.top, rect.right, rect.bottom);

  /// Maps a page-space rectangle onto the canvas rectangle of a rendered page.
  static Rect toCanvas({
    required AnnotationRect rect,
    required Rect pageRect,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (pageWidth <= 0 || pageHeight <= 0) return Rect.zero;
    final scaleX = pageRect.width / pageWidth;
    final scaleY = pageRect.height / pageHeight;
    return Rect.fromLTRB(
      pageRect.left + rect.left * scaleX,
      pageRect.top + (pageHeight - rect.top) * scaleY,
      pageRect.left + rect.right * scaleX,
      pageRect.top + (pageHeight - rect.bottom) * scaleY,
    );
  }

  /// True when a tap at [point] (PDF page coordinates) lands on [annotation].
  static bool hitTest({
    required ZoteroAnnotation annotation,
    required PdfPoint point,
    double margin = 2,
  }) {
    for (final rect in annotation.rects) {
      if (point.x >= rect.left - margin &&
          point.x <= rect.right + margin &&
          point.y >= rect.bottom - margin &&
          point.y <= rect.top + margin) {
        return true;
      }
    }
    return false;
  }

  /// Line rectangles of a text selection, one per text fragment, merged when
  /// they sit on the same baseline — this mirrors how Zotero stores highlights.
  static List<AnnotationRect> rectsForSelection(PdfPageTextRange range) {
    final rects = <AnnotationRect>[];
    for (final fragment in range.enumerateFragmentBoundingRects()) {
      final bounds = fragment.bounds;
      if (bounds.isEmpty) continue;
      final candidate = fromPdfRect(bounds);
      final last = rects.isEmpty ? null : rects.last;
      if (last != null && _sameLine(last, candidate)) {
        rects[rects.length - 1] = AnnotationRect(
          last.left < candidate.left ? last.left : candidate.left,
          last.bottom < candidate.bottom ? last.bottom : candidate.bottom,
          last.right > candidate.right ? last.right : candidate.right,
          last.top > candidate.top ? last.top : candidate.top,
        );
      } else {
        rects.add(candidate);
      }
    }
    return rects;
  }

  static bool _sameLine(AnnotationRect a, AnnotationRect b) {
    final overlap = (a.top < b.top ? a.top : b.top) - (a.bottom > b.bottom ? a.bottom : b.bottom);
    final smaller = a.height < b.height ? a.height : b.height;
    return smaller > 0 && overlap > smaller * 0.5;
  }

  /// Bounding box of a list of rectangles.
  static AnnotationRect? boundsOf(List<AnnotationRect> rects) {
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
