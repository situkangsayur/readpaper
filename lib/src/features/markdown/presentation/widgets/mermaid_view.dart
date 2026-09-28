import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/mermaid_graph.dart';

/// Menggambar diagram Mermaid di layar.
///
/// Digambar sendiri, tanpa WebView dan tanpa mermaid.js: catatan harus terbuka
/// di pesawat dan di tablet tanpa jaringan, dan sebuah mesin JavaScript untuk
/// menggambar sepuluh kotak adalah harga yang tidak perlu dibayar.
class MermaidView extends StatelessWidget {
  const MermaidView({required this.source, this.onEdit, super.key});

  /// Isi blok ```mermaid apa adanya.
  final String source;

  /// Diketuk untuk menyunting sumber diagram ini.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final graph = MermaidGraph.parse(source);

    if (!graph.isDrawable) {
      // Sumbernya tetap ditampilkan: diagram yang belum bisa digambar masih
      // berguna sebagai teks, dan sebabnya disebut supaya tidak terlihat rusak.
      return _Frame(
        onEdit: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              graph.problem ?? 'Diagram ini belum bisa digambar.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 8),
            SelectableText(
              source.trim(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      );
    }

    final style = TextStyle(fontSize: 12.5, color: scheme.onSurface, height: 1.2);
    final layout = MermaidLayout.of(
      graph,
      measure: (line) => _measure(line, style),
      lineHeight: 17,
    );

    return _Frame(
      onEdit: onEdit,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(layout.width, 1),
          height: math.max(layout.height, 1),
          child: CustomPaint(
            painter: _MermaidPainter(
              layout: layout,
              style: style,
              line: scheme.onSurfaceVariant,
              fill: scheme.surfaceContainerHighest,
              border: scheme.primary,
              labelBackground: scheme.surface,
            ),
          ),
        ),
      ),
    );
  }

  static double _measure(String line, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: line, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.onEdit});

  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onEdit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
            color: scheme.surfaceContainerLow,
          ),
          child: Stack(
            children: <Widget>[
              child,
              if (onEdit != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(Icons.edit_outlined, size: 14, color: scheme.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MermaidPainter extends CustomPainter {
  _MermaidPainter({
    required this.layout,
    required this.style,
    required this.line,
    required this.fill,
    required this.border,
    required this.labelBackground,
  });

  final MermaidLayout layout;
  final TextStyle style;
  final Color line;
  final Color fill;
  final Color border;
  final Color labelBackground;

  @override
  void paint(Canvas canvas, Size size) {
    // Garis lebih dulu, supaya ujungnya tertutup kotak dan tidak ada goresan
    // yang tampak menembus.
    for (final edge in layout.edges) {
      _drawEdge(canvas, edge);
    }
    for (final node in layout.nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawEdge(Canvas canvas, MermaidPlacedEdge edge) {
    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = edge.edge.line == MermaidLine.thick ? 2.6 : 1.4;

    final from = Offset(edge.fromX, edge.fromY);
    final to = Offset(edge.toX, edge.toY);

    if (edge.edge.line == MermaidLine.dotted) {
      _dashed(canvas, from, to, paint);
    } else {
      canvas.drawLine(from, to, paint);
    }

    if (edge.edge.arrow) {
      final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
      const head = 8.0;
      final left = Offset(
        to.dx - head * math.cos(angle - 0.4),
        to.dy - head * math.sin(angle - 0.4),
      );
      final right = Offset(
        to.dx - head * math.cos(angle + 0.4),
        to.dy - head * math.sin(angle + 0.4),
      );
      canvas.drawPath(
        Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close(),
        Paint()..color = line,
      );
    }

    if (edge.edge.label.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(text: edge.edge.label, style: style.copyWith(fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(edge.labelX - painter.width / 2, edge.labelY - painter.height / 2);
    // Label ditulis di atas kotak sewarna latar, supaya tidak dibaca bersama
    // garis yang melintas di bawahnya.
    canvas.drawRect(
      Rect.fromLTWH(at.dx - 3, at.dy - 1, painter.width + 6, painter.height + 2),
      Paint()..color = labelBackground,
    );
    painter.paint(canvas, at);
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    final total = (to - from).distance;
    if (total <= 0) return;
    final step = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + 5, total);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
      travelled = end + 4;
    }
  }

  void _drawNode(Canvas canvas, MermaidPlacedNode node) {
    final rect = Rect.fromLTWH(node.left, node.top, node.width, node.height);
    final body = Paint()..color = fill;
    final outline = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    switch (node.node.shape) {
      case MermaidShape.box:
        canvas.drawRect(rect, body);
        canvas.drawRect(rect, outline);
      case MermaidShape.rounded:
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
        canvas.drawRRect(rrect, body);
        canvas.drawRRect(rrect, outline);
      case MermaidShape.stadium:
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(node.height / 2));
        canvas.drawRRect(rrect, body);
        canvas.drawRRect(rrect, outline);
      case MermaidShape.circle:
        canvas.drawOval(rect, body);
        canvas.drawOval(rect, outline);
      case MermaidShape.diamond:
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();
        canvas.drawPath(path, body);
        canvas.drawPath(path, outline);
    }

    final painter = TextPainter(
      text: TextSpan(text: node.lines.join('\n'), style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: node.width);
    painter.paint(
      canvas,
      Offset(
        node.left + (node.width - painter.width) / 2,
        node.top + (node.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_MermaidPainter old) =>
      old.layout != layout || old.style != style || old.fill != fill || old.line != line;
}
