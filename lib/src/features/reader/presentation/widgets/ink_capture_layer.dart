import 'package:flutter/material.dart';

import '../../../library/domain/entities/zotero_annotation.dart';

/// Catches freehand strokes drawn over one rendered page.
///
/// It is laid over the page rectangle exactly, so a point on this canvas maps
/// onto a PDF point by a scale and a vertical flip — PDF counts from the
/// bottom-left, Flutter from the top-left.
///
/// Strokes are collected here and only become an annotation when the pen is
/// put away, because Zotero stores a whole drawing as one `ink` annotation
/// with many paths, not one annotation per stroke.
class InkCaptureLayer extends StatefulWidget {
  const InkCaptureLayer({
    required this.pageWidth,
    required this.pageHeight,
    required this.color,
    required this.strokeWidth,
    required this.strokes,
    required this.onStrokeFinished,
    super.key,
  });

  final double pageWidth;
  final double pageHeight;
  final Color color;

  /// Width in PDF points, the same unit Zotero stores.
  final double strokeWidth;

  /// Strokes already committed on this page, in PDF coordinates.
  final List<InkPath> strokes;

  final ValueChanged<InkPath> onStrokeFinished;

  @override
  State<InkCaptureLayer> createState() => _InkCaptureLayerState();
}

class _InkCaptureLayerState extends State<InkCaptureLayer> {
  /// The stroke being drawn, in canvas coordinates so it follows the finger
  /// exactly while the page is being drawn on.
  final List<Offset> _live = <Offset>[];

  Size _size = Size.zero;

  void _add(Offset local) {
    // Points closer together than this add nothing but file size; a 400-page
    // scribble is still going into someone's git repository.
    if (_live.isNotEmpty && (_live.last - local).distance < 1.5) return;
    setState(() => _live.add(local));
  }

  void _finish() {
    if (_live.length < 2 || _size.isEmpty) {
      setState(_live.clear);
      return;
    }
    final scaleX = _size.width / widget.pageWidth;
    final scaleY = _size.height / widget.pageHeight;
    final points = <double>[];
    for (final p in _live) {
      points
        ..add(p.dx / scaleX)
        ..add(widget.pageHeight - p.dy / scaleY);
    }
    widget.onStrokeFinished(InkPath(points));
    setState(_live.clear);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _add(d.localPosition),
        onPanUpdate: (d) => _add(d.localPosition),
        onPanEnd: (_) => _finish(),
        onPanCancel: _finish,
        child: CustomPaint(
          size: _size,
          painter: _InkPainter(
            live: _live,
            strokes: widget.strokes,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            pageWidth: widget.pageWidth,
            pageHeight: widget.pageHeight,
          ),
        ),
      );
    },
  );
}

class _InkPainter extends CustomPainter {
  const _InkPainter({
    required this.live,
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    required this.pageWidth,
    required this.pageHeight,
  });

  final List<Offset> live;
  final List<InkPath> strokes;
  final Color color;
  final double strokeWidth;
  final double pageWidth;
  final double pageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (pageWidth <= 0 || pageHeight <= 0) return;
    final scaleX = size.width / pageWidth;
    final scaleY = size.height / pageHeight;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth * scaleX
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Strokes already put down in this session. The saved ones are drawn by
    // AnnotationOverlayPainter instead; these have not been saved yet.
    for (final stroke in strokes) {
      final path = Path();
      for (var i = 0; i < stroke.length; i++) {
        final x = stroke.xAt(i) * scaleX;
        final y = (pageHeight - stroke.yAt(i)) * scaleY;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    if (live.length > 1) {
      final path = Path()..moveTo(live.first.dx, live.first.dy);
      for (final p in live.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) =>
      old.live.length != live.length ||
      old.strokes.length != strokes.length ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
