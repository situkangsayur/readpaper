import 'package:flutter/material.dart';

import '../../../../core/utils/formatting.dart';
import '../../../library/domain/entities/zotero_annotation.dart';

/// Paints the markers of one page over the rendered PDF page.
///
/// The canvas is exactly the page rectangle, so PDF points map onto it by a
/// simple scale plus a vertical flip (PDF's origin is bottom-left).
class AnnotationOverlayPainter extends CustomPainter {
  const AnnotationOverlayPainter({
    required this.annotations,
    required this.pageWidth,
    required this.pageHeight,
    this.selectedKey,
  });

  final List<ZoteroAnnotation> annotations;
  final double pageWidth;
  final double pageHeight;
  final String? selectedKey;

  @override
  void paint(Canvas canvas, Size size) {
    if (pageWidth <= 0 || pageHeight <= 0 || annotations.isEmpty) return;
    final scaleX = size.width / pageWidth;
    final scaleY = size.height / pageHeight;

    for (final annotation in annotations) {
      final color = colorFromHex(annotation.color);
      final isSelected = annotation.key == selectedKey;

      switch (annotation.type) {
        case AnnotationType.highlight:
          final paint = Paint()
            ..color = color.withValues(alpha: isSelected ? 0.55 : 0.35)
            ..style = PaintingStyle.fill;
          for (final rect in annotation.rects) {
            canvas.drawRect(_toLocal(rect, scaleX, scaleY), paint);
          }
        case AnnotationType.underline:
          final paint = Paint()
            ..color = color.withValues(alpha: isSelected ? 1 : 0.85)
            ..strokeWidth = (isSelected ? 2.6 : 1.8) * scaleY
            ..style = PaintingStyle.stroke;
          for (final rect in annotation.rects) {
            final local = _toLocal(rect, scaleX, scaleY);
            canvas.drawLine(
              Offset(local.left, local.bottom - 1),
              Offset(local.right, local.bottom - 1),
              paint,
            );
          }
        case AnnotationType.note || AnnotationType.text:
          for (final rect in annotation.rects) {
            final local = _toLocal(rect, scaleX, scaleY);
            final box = RRect.fromRectAndRadius(local.inflate(1), Radius.circular(2 * scaleX));
            canvas.drawRRect(box, Paint()..color = color.withValues(alpha: 0.28));
            canvas.drawRRect(
              box,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = (isSelected ? 2 : 1) * scaleX,
            );
          }
        case AnnotationType.image || AnnotationType.ink:
          for (final rect in annotation.rects) {
            canvas.drawRect(
              _toLocal(rect, scaleX, scaleY),
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5 * scaleX,
            );
          }
      }

      if (isSelected) {
        final bounds = _boundsOf(annotation, scaleX, scaleY);
        if (bounds != null) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(bounds.inflate(2), const Radius.circular(3)),
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  Rect _toLocal(AnnotationRect rect, double scaleX, double scaleY) => Rect.fromLTRB(
    rect.left * scaleX,
    (pageHeight - rect.top) * scaleY,
    rect.right * scaleX,
    (pageHeight - rect.bottom) * scaleY,
  );

  Rect? _boundsOf(ZoteroAnnotation annotation, double scaleX, double scaleY) {
    if (annotation.rects.isEmpty) return null;
    var result = _toLocal(annotation.rects.first, scaleX, scaleY);
    for (final rect in annotation.rects.skip(1)) {
      result = result.expandToInclude(_toLocal(rect, scaleX, scaleY));
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant AnnotationOverlayPainter old) =>
      old.annotations != annotations ||
      old.selectedKey != selectedKey ||
      old.pageWidth != pageWidth ||
      old.pageHeight != pageHeight;
}
