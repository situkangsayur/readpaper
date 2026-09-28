import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/ink_smoothing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../markdown/data/mermaid_pdf.dart';
import '../domain/note_document.dart';
import '../../../core/utils/shape_geometry.dart';

/// Mengeluarkan buku catatan sebagai Markdown atau PDF.
///
/// Keduanya kehilangan sesuatu, dan itu memang sifatnya: Markdown kehilangan
/// posisi, PDF kehilangan kemampuan disunting. Karena itu keduanya bukan
/// pengganti berkas `.catatan.json`, melainkan cara membagikannya.
class NoteExport {
  const NoteExport._();

  /// Urutan baca: dari atas ke bawah, lalu kiri ke kanan.
  ///
  /// Yang dipakai bukan urutan menulis — catatan ditulis melompat-lompat,
  /// dan Markdown yang mengikuti urutan menulis akan terbaca acak.
  static List<NoteComponent> inReadingOrder(NotePage page) {
    final sorted = <NoteComponent>[...page.components];
    sorted.sort((a, b) {
      // Dua benda yang tingginya berdekatan dianggap sebaris.
      final sameLine = (a.position.dy - b.position.dy).abs() < 24;
      if (sameLine) return a.position.dx.compareTo(b.position.dx);
      return a.position.dy.compareTo(b.position.dy);
    });
    return sorted;
  }

  /// Menulis dokumen sebagai Markdown.
  ///
  /// Tinta tidak bisa jadi teks, jadi tiap komponen tinta digambar ke PNG di
  /// sebelah berkasnya dan dirujuk sebagai gambar — dibuang akan berarti
  /// catatannya hilang sebagian, dan itu lebih buruk daripada Markdown yang
  /// memuat gambar.
  static Future<String> toMarkdown(
    NoteDocument document, {
    required String assetDir,
    String assetPrefix = 'tinta',
  }) async {
    final out = StringBuffer();
    if (document.title.trim().isNotEmpty) {
      out
        ..writeln('# ${document.title.trim()}')
        ..writeln();
    }

    for (var pageIndex = 0; pageIndex < document.pages.length; pageIndex++) {
      if (pageIndex > 0) {
        out
          ..writeln('---')
          ..writeln();
      }
      final page = document.pages[pageIndex];

      // Tinta, bangun, dan penghubung tidak bisa jadi teks. Ketiganya digambar
      // sebagai **satu** PNG per lembar, bukan satu per benda: penghubung
      // membentang antara dua benda, jadi memotongnya per benda akan
      // memutus garisnya. Dan membuangnya sama sekali berarti catatannya
      // hilang sebagian — itu konversi yang merusak.
      final drawing = await drawingToPng(page);
      var written = false;

      for (final component in inReadingOrder(page)) {
        switch (component) {
          case NoteText():
            if (component.text.trim().isEmpty) break;
            out
              ..writeln(component.text.trim())
              ..writeln();
          case NoteDiagram():
            out
              ..writeln('```mermaid')
              ..writeln(component.source.trim())
              ..writeln('```')
              ..writeln();
          case NoteImage():
            out
              ..writeln('![${component.alt}](${component.file})')
              ..writeln();
          case NoteInk():
          case NoteShape():
          case NoteConnector():
            // Gambarnya ditulis sekali, pada tempat benda gambar pertama
            // dalam urutan baca.
            if (written || drawing == null) break;
            written = true;
            final name = '$assetPrefix-${pageIndex + 1}.png';
            final file = File(p.join(assetDir, name));
            await file.parent.create(recursive: true);
            await file.writeAsBytes(drawing, flush: true);
            out
              ..writeln('![tulisan tangan](${p.basename(name)})')
              ..writeln();
        }
      }
    }
    final text = out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.endsWith('\n') ? text : '$text\n';
  }

  /// Benda yang tergambar, bukan tertulis: tinta, bangun, dan penghubung.
  static List<NoteComponent> drawnOf(NotePage page) => <NoteComponent>[
    for (final component in page.components)
      if (component is NoteInk || component is NoteShape || component is NoteConnector)
        component,
  ];

  /// Menggambar seluruh lapisan gambar satu lembar jadi PNG berlatar tembus
  /// pandang, dipotong seukuran gambarnya.
  ///
  /// Dipotong karena lembar A4 yang isinya satu kata di sudut akan jadi
  /// gambar raksasa yang hampir seluruhnya kosong.
  static Future<Uint8List?> drawingToPng(NotePage page, {double scale = 2}) async {
    final drawn = drawnOf(page);
    if (drawn.isEmpty) return null;

    Rect? box;
    for (final component in drawn) {
      final bounds = component is NoteConnector
          ? () {
              final ends = page.endsOf(component);
              return ends == null
                  ? null
                  : Rect.fromPoints(ends.$1, ends.$2).inflate(component.strokeWidth * 2);
            }()
          : component.bounds;
      if (bounds == null) continue;
      box = box == null ? bounds : box.expandToInclude(bounds);
    }
    if (box == null) return null;
    box = box.inflate(4);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(scale)
      ..translate(-box.left, -box.top);
    paintDrawing(canvas, page);

    final image = await recorder.endRecording().toImage(
      math.max(1, (box.width * scale).ceil()),
      math.max(1, (box.height * scale).ceil()),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// Menggambar tinta, bangun, dan penghubung sebuah lembar ke [canvas],
  /// dalam koordinat lembar.
  ///
  /// Satu penggambar untuk layar, PNG, dan — lewat perhitungan yang sama —
  /// PDF. Dua penggambar akan berbeda perlahan-lahan.
  static void paintDrawing(Canvas canvas, NotePage page) {
    for (final component in page.components) {
      final paint = Paint()
        ..color = Color(component.color).withValues(alpha: component.opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      switch (component) {
        case NoteInk():
          canvas.save();
          _applyTransform(canvas, component);
          for (final stroke in component.strokes) {
            if (stroke.points.isEmpty) continue;
            paint.strokeWidth = stroke.width;
            canvas.drawPath(_pathOf(stroke.points, smooth: true), paint);
          }
          canvas.restore();

        case NoteShape():
          canvas.save();
          _applyTransform(canvas, component);
          paint.strokeWidth = component.strokeWidth;
          for (final line in component.outline) {
            canvas.drawPath(_pathOf(line), paint);
          }
          canvas.restore();

        case NoteConnector():
          final ends = page.endsOf(component);
          if (ends == null) continue;
          paint.strokeWidth = component.strokeWidth;
          canvas.drawLine(ends.$1, ends.$2, paint);
          if (!component.arrow) continue;
          canvas.drawPath(
            _pathOf(ShapeGeometry.arrowHead(tip: ends.$2, from: ends.$1)),
            paint,
          );

        case NoteText():
        case NoteImage():
        case NoteDiagram():
          break;
      }
    }
  }

  static void _applyTransform(Canvas canvas, NoteComponent component) {
    final centre = component.bounds.center;
    canvas
      ..translate(centre.dx, centre.dy)
      ..rotate(component.rotation)
      ..translate(-centre.dx, -centre.dy)
      ..translate(component.position.dx, component.position.dy);
  }

  /// Garis tinta dihaluskan; bangun tidak.
  ///
  /// Kotak yang dihaluskan bukan kotak lagi — sudutnya ikut melengkung — jadi
  /// hanya tulisan tangan yang lewat penghalus.
  static Path _pathOf(List<Offset> points, {bool smooth = false}) {
    if (smooth) return InkSmoothing.path(points);
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  /// Menulis dokumen sebagai PDF, **satu lembar catatan jadi satu halaman**.
  ///
  /// Tintanya digambar sebagai garis vektor, bukan gambar: hasilnya tetap
  /// tajam diperbesar sejauh apa pun dan berkasnya jauh lebih kecil. Teks
  /// tetap teks, jadi masih bisa dicari dan disalin.
  static Future<Uint8List> toPdf(NoteDocument document, {String? baseDir}) async {
    final pdf = pw.Document();
    final images = <String, pw.MemoryImage>{};
    for (final page in document.pages) {
      for (final component in page.components) {
        if (component is! NoteImage || images.containsKey(component.file)) continue;
        final file = p.isAbsolute(component.file) || baseDir == null
            ? File(component.file)
            : File(p.join(baseDir, component.file));
        if (file.existsSync()) images[component.file] = pw.MemoryImage(await file.readAsBytes());
      }
    }

    for (final page in document.pages) {
      pdf.addPage(
        pw.Page(
          // Seukuran lembarnya masing-masing: satu buku boleh mencampur A5
          // tegak dan A3 mendatar, dan PDF memang mengizinkan tiap halaman
          // punya ukurannya sendiri.
          pageFormat: PdfPageFormat(page.size.width, page.size.height),
          build: (context) => pw.Stack(
            children: <pw.Widget>[
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.Container(
                  width: page.size.width,
                  height: page.size.height,
                  color: PdfColor.fromInt(page.background),
                ),
              ),
              for (final component in page.components) _component(component, images),
              // Penghubung membentang antara dua benda, jadi tempatnya bukan
              // di dalam salah satunya: digambar sebagai satu lapisan
              // selembar di atas semuanya.
              if (page.components.any((c) => c is NoteConnector))
                pw.Positioned(
                  left: 0,
                  top: 0,
                  child: pw.SizedBox(
                    width: page.size.width,
                    height: page.size.height,
                    child: pw.CustomPaint(
                      size: PdfPoint(page.size.width, page.size.height),
                      painter: (canvas, size) => _paintConnectors(canvas, page, size.y),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return pdf.save();
  }

  static pw.Widget _component(NoteComponent component, Map<String, pw.MemoryImage> images) {
    final body = switch (component) {
      NoteText() => pw.Text(
        component.text,
        style: pw.TextStyle(
          fontSize: component.fontSize,
          color: PdfColor.fromInt(component.color).shade(1),
        ),
      ),
      NoteImage() => images[component.file] == null
          ? pw.Text(
              '[gambar tidak ditemukan: ${component.file}]',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            )
          : pw.Image(images[component.file]!, fit: pw.BoxFit.contain),
      NoteDiagram() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: MermaidPdf.widgets(component.source),
      ),
      NoteInk() => pw.CustomPaint(
        size: PdfPoint(component.size.width, component.size.height),
        painter: (canvas, size) => _paintInk(canvas, component, size.y),
      ),
      // Bangun digambar sebagai garis vektor, bukan gambar: tetap tajam
      // diperbesar, dan ukurannya dihitung ulang dari kotaknya jadi tidak
      // pernah terlihat ditarik melar.
      NoteShape() => pw.CustomPaint(
        size: PdfPoint(component.size.width, component.size.height),
        painter: (canvas, size) => _paintLines(
          canvas,
          component.outline,
          <double>[for (final _ in component.outline) component.strokeWidth],
          component.color,
          size.y,
        ),
      ),
      // Penghubung tidak digambar di sini — lihat lapisan selembar di atas.
      NoteConnector() => pw.SizedBox(),
    };

    final sized = pw.SizedBox(
      width: component.size.width,
      height: component.size.height,
      child: pw.Opacity(opacity: component.opacity.clamp(0.0, 1.0), child: body),
    );

    return pw.Positioned(
      left: component.position.dx,
      top: component.position.dy,
      // Sudutnya sifat komponen, jadi diputar di sini — titik tintanya sendiri
      // tidak pernah ditulis ulang.
      child: component.rotation == 0
          ? sized
          : pw.Transform.rotateBox(angle: -component.rotation, child: sized),
    );
  }

  /// Menggambar sekumpulan garis. Sumbu y PDF menghitung dari bawah,
  /// koordinat catatan dari atas, jadi tiap titik dibalik.
  static void _paintLines(
    PdfGraphics canvas,
    List<List<Offset>> lines,
    List<double> widths,
    int color,
    double height,
  ) {
    canvas
      ..setStrokeColor(PdfColor.fromInt(color))
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round);
    for (var i = 0; i < lines.length; i++) {
      final points = lines[i];
      if (points.length < 2) continue;
      canvas
        ..setLineWidth(i < widths.length ? widths[i] : 1.5)
        ..moveTo(points.first.dx, height - points.first.dy);
      for (final point in points.skip(1)) {
        canvas.lineTo(point.dx, height - point.dy);
      }
      canvas.strokePath();
    }
  }

  /// Tinta sebagai kurva, bukan garis patah — kurva yang sama dengan yang
  /// terlihat di layar, jadi cetakannya tidak pernah berbeda.
  static void _paintInk(PdfGraphics canvas, NoteInk component, double height) {
    canvas
      ..setStrokeColor(PdfColor.fromInt(component.color))
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round);
    for (final stroke in component.strokes) {
      final points = stroke.points;
      if (points.length < 2) continue;
      canvas
        ..setLineWidth(stroke.width)
        ..moveTo(points.first.dx, height - points.first.dy);
      var from = points.first;
      for (final quad in InkSmoothing.quads(points)) {
        final cubic = InkSmoothing.toCubic(from, quad.control, quad.end);
        canvas.curveTo(
          cubic.c1.dx,
          height - cubic.c1.dy,
          cubic.c2.dx,
          height - cubic.c2.dy,
          cubic.end.dx,
          height - cubic.end.dy,
        );
        from = quad.end;
      }
      canvas.strokePath();
    }
  }

  /// Seluruh penghubung satu lembar, digambar dalam koordinat lembar.
  static void _paintConnectors(PdfGraphics canvas, NotePage page, double height) {
    for (final component in page.components) {
      if (component is! NoteConnector) continue;
      final ends = page.endsOf(component);
      if (ends == null) continue;
      _paintLines(
        canvas,
        <List<Offset>>[
          <Offset>[ends.$1, ends.$2],
          if (component.arrow) ShapeGeometry.arrowHead(tip: ends.$2, from: ends.$1),
        ],
        <double>[component.strokeWidth, component.strokeWidth],
        component.color,
        height,
      );
    }
  }
}
