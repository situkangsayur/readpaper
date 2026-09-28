import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/markdown_doc.dart';
import '../domain/mermaid_graph.dart';

/// Mengubah dokumen Markdown jadi PDF dengan **teks sungguhan**.
///
/// Bukan tangkapan layar halamannya: yang keluar dari sini masih bisa dicari,
/// disalin, dan dibaca pembaca layar. Diagram mermaid digambar ulang dengan
/// tata letak yang sama seperti di layar — perhitungannya satu, di
/// [MermaidLayout], jadi cetakannya tidak pernah berbeda dari pratinjaunya.
class MarkdownPdf {
  const MarkdownPdf._();

  static const double _base = 11;

  /// Huruf yang tidak bisa digambar font bawaan PDF, beserta penggantinya.
  ///
  /// Font baku PDF (Helvetica dan kawan-kawan) tidak punya blok tanda baca
  /// "pintar" — tanda pisah panjang, kutip melengkung, titik-titik, dan butir
  /// bulat. Yang terjadi kalau dibiarkan bukan kotak kosong melainkan
  /// **hilang tanpa jejak**: kalimat yang memakai tanda pisah keluar dari
  /// cetakan dengan dua kata yang berdempetan. Jadi ditukar dengan padanan
  /// ASCII-nya, yang terbaca, tercari, dan tersalin.
  static const Map<String, String> _substitutes = <String, String>{
    '—': '--',
    '–': '-',
    '‐': '-',
    '‑': '-',
    '•': '-',
    '·': '-',
    '“': '"',
    '”': '"',
    '„': '"',
    '‘': "'",
    '’': "'",
    '‚': "'",
    '…': '...',
    '™': '(TM)',
    '‰': '%%',
    '†': '*',
    '‡': '**',
    '€': 'EUR',
    '‹': '<',
    '›': '>',
    '˜': '~',
    'ˆ': '^',
  };

  /// Menyiapkan teks supaya tidak ada huruf yang hilang diam-diam.
  static String _safe(String text) {
    var out = text;
    for (final entry in _substitutes.entries) {
      if (out.contains(entry.key)) out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }

  /// Menulis [doc] sebagai PDF A4.
  ///
  /// [baseDir] dipakai untuk mencari gambar berjalur relatif.
  static Future<Uint8List> build(MarkdownDoc doc, {String? baseDir}) async {
    final pdf = pw.Document();
    final children = <pw.Widget>[];

    for (final block in doc.blocks) {
      children.addAll(await _block(block, baseDir));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
        build: (context) => children.isEmpty
            ? <pw.Widget>[pw.Text('(dokumen kosong)')]
            : children,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ),
    );
    return pdf.save();
  }

  static Future<List<pw.Widget>> _block(MdBlock block, String? baseDir) async {
    switch (block) {
      case MdHeading():
        final size = switch (block.level) {
          1 => 21.0,
          2 => 17.0,
          3 => 14.5,
          4 => 12.5,
          _ => 11.5,
        };
        return <pw.Widget>[
          pw.Padding(
            padding: pw.EdgeInsets.only(top: block.level <= 2 ? 14 : 10, bottom: 5),
            child: pw.Text(
              _safe(MarkdownDoc.plain(block.spans)),
              style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ];

      case MdParagraph():
        return <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.RichText(text: _spans(block.spans)),
          ),
        ];

      case MdList():
        return <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                for (var i = 0; i < block.items.length; i++)
                  pw.Padding(
                    padding: pw.EdgeInsets.only(
                      left: 6 + block.items[i].depth * 14.0,
                      bottom: 2,
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        pw.SizedBox(
                          width: 20,
                          child: pw.Text(
                            switch (block.items[i].checked) {
                              true => '[x]',
                              false => '[ ]',
                              // Butir ditulis dengan tanda hubung, bukan
                              // bulatan: bulatannya tidak ada di font bawaan.
                              null => block.ordered ? '${i + 1}.' : '-',
                            },
                            style: const pw.TextStyle(fontSize: _base),
                          ),
                        ),
                        pw.Expanded(child: pw.RichText(text: _spans(block.items[i].spans))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ];

      case MdQuote():
        return <pw.Widget>[
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 6),
            padding: const pw.EdgeInsets.fromLTRB(10, 6, 6, 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: PdfColors.blueGrey400, width: 2.5)),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                for (final line in block.lines)
                  pw.Text(
                    _safe(MarkdownDoc.plain(line)),
                    style: pw.TextStyle(fontSize: _base, fontStyle: pw.FontStyle.italic),
                  ),
              ],
            ),
          ),
        ];

      case MdCode():
        if (block.isMermaid) return _mermaid(block.text);
        return <pw.Widget>[
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 6),
            padding: const pw.EdgeInsets.all(8),
            color: PdfColors.grey200,
            width: double.infinity,
            child: pw.Text(
              _safe(block.text),
              style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
            ),
          ),
        ];

      case MdRule():
        return <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(height: 1, color: PdfColors.grey500),
          ),
        ];

      case MdTable():
        return <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.TableHelper.fromTextArray(
              headers: <String>[for (final cell in block.header) _safe(cell)],
              data: <List<String>>[
                for (final row in block.rows) <String>[for (final cell in row) _safe(cell)],
              ],
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            ),
          ),
        ];

      case MdImage():
        final file = p.isAbsolute(block.path) || baseDir == null
            ? File(block.path)
            : File(p.join(baseDir, block.path));
        if (!file.existsSync()) {
          // Gambar yang hilang disebutkan, tidak dihilangkan diam-diam:
          // yang mencetak perlu tahu ada yang tidak ikut.
          return <pw.Widget>[
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Text(
                '[gambar tidak ditemukan: ${block.path}]',
                style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600),
              ),
            ),
          ];
        }
        final image = pw.MemoryImage(await file.readAsBytes());
        return <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Image(image, fit: pw.BoxFit.contain),
                if (block.alt.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(
                      _safe(block.alt),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ),
              ],
            ),
          ),
        ];
    }
  }

  static pw.TextSpan _spans(List<MdSpan> spans) => pw.TextSpan(
    style: const pw.TextStyle(fontSize: _base, lineSpacing: 2.5),
    children: <pw.InlineSpan>[
      for (final span in spans)
        pw.TextSpan(
          text: _safe(span.text),
          style: pw.TextStyle(
            fontSize: span.code ? 10 : _base,
            fontWeight: span.bold ? pw.FontWeight.bold : null,
            fontStyle: span.italic ? pw.FontStyle.italic : null,
            decoration: span.strike
                ? pw.TextDecoration.lineThrough
                : (span.link != null ? pw.TextDecoration.underline : null),
            color: span.link != null ? PdfColors.blue800 : null,
          ),
        ),
    ],
  );

  /// Menggambar diagram mermaid ke dalam PDF.
  static List<pw.Widget> _mermaid(String source) {
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
                _safe(source.trim()),
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
                painter: (canvas, size) => _paint(canvas, layout, size.y),
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
                        _safe(node.lines.join('\n')),
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
                            _safe(edge.edge.label),
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
  static void _paint(PdfGraphics canvas, MermaidLayout layout, double height) {
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
