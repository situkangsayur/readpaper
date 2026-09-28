import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../../../core/utils/simple_pdf_writer.dart';
import '../domain/board.dart';

/// Menggambar papan tulis dan menuliskannya sebagai PDF atau gambar.
///
/// Papan tulis memang gambar, jadi keluarannya raster tanpa kehilangan apa
/// pun — berbeda dengan paper, yang teksnya akan hilang kalau dijadikan
/// gambar.
class BoardExport {
  const BoardExport._();

  /// Berapa kali lipat titik PDF dirender jadi piksel.
  ///
  /// 2× membuat garis tetap mulus saat dicetak atau diperbesar, tanpa
  /// membuat berkasnya tidak masuk akal.
  static const double scale = 2;

  /// Menggambar satu lembar menjadi gambar.
  static Future<ui.Image> render(BoardPage page) async {
    final width = (BoardSize.width * scale).round();
    final height = (BoardSize.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = page.background,
    );

    for (final stroke in page.strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < stroke.points.length; i++) {
        final point = stroke.points[i] * scale;
        i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width * scale
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    return recorder.endRecording().toImage(width, height);
  }

  /// Seluruh papan sebagai satu PDF, satu lembar per halaman.
  static Future<Uint8List> toPdf(List<BoardPage> pages, {int quality = 85}) async {
    final out = <PdfImagePage>[];
    for (final page in pages) {
      final image = await render(page);
      out.add(
        PdfImagePage(
          jpeg: await _jpeg(image, quality),
          pixelWidth: image.width,
          pixelHeight: image.height,
          widthPt: BoardSize.width,
          heightPt: BoardSize.height,
        ),
      );
      image.dispose();
    }
    return writeImagePdf(out);
  }

  /// Satu lembar sebagai PNG.
  static Future<Uint8List> toPng(BoardPage page) async {
    final image = await render(page);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG gagal dikodekan');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static Future<Uint8List> _jpeg(ui.Image image, int quality) async {
    // dart:ui tidak bisa menulis JPEG, jadi pikselnya lewat paket image.
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw StateError('Piksel gagal dibaca');
    final raw = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: data.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodeJpg(raw, quality: quality);
  }
}
