import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../markdown/data/mermaid_pdf.dart';
import '../domain/note_document.dart';

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
      var ink = 0;
      for (final component in inReadingOrder(document.pages[pageIndex])) {
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
            final name = '$assetPrefix-${pageIndex + 1}-${++ink}.png';
            final bytes = await inkToPng(component);
            if (bytes == null) break;
            final file = File(p.join(assetDir, name));
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes, flush: true);
            out
              ..writeln('![tulisan tangan](${p.basename(name)})')
              ..writeln();
        }
      }
    }
    final text = out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.endsWith('\n') ? text : '$text\n';
  }

  /// Menggambar satu komponen tinta jadi PNG dengan latar tembus pandang.
  static Future<Uint8List?> inkToPng(NoteInk component, {double scale = 2}) async {
    if (component.strokes.isEmpty) return null;
    final width = math.max(1.0, component.size.width);
    final height = math.max(1.0, component.size.height);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    final paint = Paint()
      ..color = Color(component.color).withValues(alpha: component.opacity)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in component.strokes) {
      if (stroke.points.isEmpty) continue;
      paint.strokeWidth = stroke.width;
      if (stroke.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke.points, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    final image = await recorder.endRecording().toImage(
      (width * scale).ceil(),
      (height * scale).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
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
          pageFormat: const PdfPageFormat(NoteSheet.width, NoteSheet.height),
          build: (context) => pw.Stack(
            children: <pw.Widget>[
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.Container(
                  width: NoteSheet.width,
                  height: NoteSheet.height,
                  color: PdfColor.fromInt(page.background),
                ),
              ),
              for (final component in page.components) _component(component, images),
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

  /// Sumbu y PDF menghitung dari bawah, tinta dari atas, jadi dibalik.
  static void _paintInk(PdfGraphics canvas, NoteInk component, double height) {
    canvas
      ..setStrokeColor(PdfColor.fromInt(component.color))
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round);
    for (final stroke in component.strokes) {
      if (stroke.points.length < 2) continue;
      canvas
        ..setLineWidth(stroke.width)
        ..moveTo(stroke.points.first.dx, height - stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        canvas.lineTo(point.dx, height - point.dy);
      }
      canvas.strokePath();
    }
  }
}
