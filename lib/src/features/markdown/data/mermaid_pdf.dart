import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/mermaid_graph.dart';

/// Menggambar diagram Mermaid ke dalam PDF.
///
/// Dipakai dua tempat — ekspor Markdown dan ekspor catatan — dan itu memang
/// alasannya berdiri sendiri: dua penggambar yang terpisah akan berbeda
/// perlahan-lahan, dan diagram yang sama akan tercetak tidak sama dari dua
/// jalan yang berbeda.
///
/// Bentuknya digambar ke kanvas, tetapi **labelnya tetap widget teks**, supaya
/// isi diagram di dalam PDF masih bisa dicari dan disalin.
class MermaidPdf {
  const MermaidPdf._();

  /// Pemanggilnya boleh menyerahkan penukar huruf yang tidak ada di font
  /// bawaan PDF; kalau tidak, teksnya dipakai apa adanya.
  static String _pass(String Function(String)? safe, String text) =>
      safe == null ? text : safe(text);

  /// Menggambar diagram mermaid ke dalam PDF.
  static List<pw.Widget> widgets(String source, {String Function(String)? safe}) {
    final graph = MermaidGraph.parse(source);
    if (!graph.isDrawable) {
      return <pw.Widget>[
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.grey200,
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                graph.problem ?? 'Diagram ini belum bisa digambar.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _pass(safe, source.trim()),
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
              ),
            ],
          ),
        ),
      ];
    }

    // Lebar huruf Helvetica ditaksir dari jumlah hurufnya. Tidak seteliti
    // pengukur di layar, tetapi cukup: yang penting kotaknya tidak pernah
    // lebih sempit dari isinya.
    final layout = MermaidLayout.of(
      graph,
      measure: (line) => line.length * 6.1,
      lineHeight: 14,
    );
    // Bentuknya digambar ke kanvas, tetapi **labelnya tetap widget teks** —
    // supaya isi diagram di dalam PDF masih bisa dicari dan disalin, bukan
    // sekadar garis.
    return <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.SizedBox(
          width: layout.width,
          height: layout.height,
          child: pw.Stack(
            children: <pw.Widget>[
              pw.CustomPaint(
                size: PdfPoint(layout.width, layout.height),
                painter: (canvas, size) => paint(canvas, layout, size.y),
              ),
              for (final node in layout.nodes)
                pw.Positioned(
                  left: node.left,
                  top: node.top,
                  child: pw.SizedBox(
                    width: node.width,
                    height: node.height,
                    child: pw.Center(
                      child: pw.Text(
                        _pass(safe, node.lines.join('\n')),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
                      ),
                    ),
                  ),
                ),
              for (final edge in layout.edges)
                if (edge.edge.label.isNotEmpty)
                  pw.Positioned(
                    left: edge.labelX - 30,
                    top: edge.labelY - 6,
                    child: pw.SizedBox(
                      width: 60,
                      child: pw.Center(
                        child: pw.Container(
                          color: PdfColors.white,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                          child: pw.Text(
                            _pass(safe, edge.edge.label),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Menggambar tata letaknya ke kanvas PDF.
  ///
  /// Sumbu y PDF menghitung dari bawah, sementara tata letaknya dari atas,
  /// jadi tiap titik dibalik lewat [flip].
  static void paint(PdfGraphics canvas, MermaidLayout layout, double height) {
    double flip(double y) => height - y;

    for (final edge in layout.edges) {
      canvas
        ..setStrokeColor(PdfColors.blueGrey700)
        ..setLineWidth(edge.edge.line == MermaidLine.thick ? 2.0 : 1.0);
      if (edge.edge.line == MermaidLine.dotted) {
        // Putus-putus digambar sebagai potongan pendek; `setLineDashPattern`
        // tidak ada di semua versi pustaka ini.
        final total = math.sqrt(
          math.pow(edge.toX - edge.fromX, 2) + math.pow(edge.toY - edge.fromY, 2),
        );
        if (total > 0) {
          final stepX = (edge.toX - edge.fromX) / total;
          final stepY = (edge.toY - edge.fromY) / total;
          var travelled = 0.0;
          while (travelled < total) {
            final end = math.min(travelled + 4, total);
            canvas
              ..moveTo(edge.fromX + stepX * travelled, flip(edge.fromY + stepY * travelled))
              ..lineTo(edge.fromX + stepX * end, flip(edge.fromY + stepY * end))
              ..strokePath();
            travelled = end + 3;
          }
        }
      } else {
        canvas
          ..moveTo(edge.fromX, flip(edge.fromY))
          ..lineTo(edge.toX, flip(edge.toY))
          ..strokePath();
      }

      if (edge.edge.arrow) {
        final angle = math.atan2(edge.toY - edge.fromY, edge.toX - edge.fromX);
        const head = 7.0;
        canvas
          ..setFillColor(PdfColors.blueGrey700)
          ..moveTo(edge.toX, flip(edge.toY))
          ..lineTo(
            edge.toX - head * math.cos(angle - 0.4),
            flip(edge.toY - head * math.sin(angle - 0.4)),
          )
          ..lineTo(
            edge.toX - head * math.cos(angle + 0.4),
            flip(edge.toY - head * math.sin(angle + 0.4)),
          )
          ..fillPath();
      }

    }

    for (final node in layout.nodes) {
      final top = flip(node.top);
      final bottom = flip(node.bottom);
      canvas
        ..setFillColor(PdfColors.grey200)
        ..setStrokeColor(PdfColors.blue700)
        ..setLineWidth(1.0);

      switch (node.node.shape) {
        case MermaidShape.diamond:
          canvas
            ..moveTo(node.centerX, top)
            ..lineTo(node.right, flip(node.centerY))
            ..lineTo(node.centerX, bottom)
            ..lineTo(node.left, flip(node.centerY))
            ..closePath()
            ..fillAndStrokePath();
        case MermaidShape.circle:
          canvas
            ..drawEllipse(
              node.centerX,
              flip(node.centerY),
              node.width / 2,
              node.height / 2,
            )
            ..fillAndStrokePath();
        case MermaidShape.rounded || MermaidShape.stadium:
          final radius = node.node.shape == MermaidShape.stadium
              ? node.height / 2
              : math.min(7.0, node.height / 2);
          canvas
            ..drawRRect(node.left, bottom, node.width, node.height, radius, radius)
            ..fillAndStrokePath();
        case MermaidShape.box:
          canvas
            ..drawRect(node.left, bottom, node.width, node.height)
            ..fillAndStrokePath();
      }

    }
  }
}
