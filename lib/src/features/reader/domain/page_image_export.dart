import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../../library/domain/entities/zotero_annotation.dart';
import '../presentation/widgets/annotation_overlay_painter.dart';

/// What a page is saved as.
enum PageImageFormat {
  png('PNG', 'png', 'image/png'),
  jpg('JPG', 'jpg', 'image/jpeg');

  const PageImageFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;
}

/// Renders one page, draws its markers and ink on top, and encodes it.
///
/// The markers are painted with the same painter the reader uses, so what is
/// saved is what was on screen — a second implementation would drift from it
/// the first time a colour or a stroke width changed.
///
/// [scale] is a multiple of the page's natural size at 72 dpi, so 2 gives
/// roughly 144 dpi and 4 roughly 288 dpi.
Future<Uint8List> exportPageImage({
  required PdfPage page,
  required List<ZoteroAnnotation> annotations,
  required PageImageFormat format,
  double scale = 2,
  int jpegQuality = 92,
}) async {
  final width = (page.width * scale).round();
  final height = (page.height * scale).round();
  if (width <= 0 || height <= 0) {
    throw StateError('Ukuran halaman tidak masuk akal: ${page.width}x${page.height}');
  }

  final rendered = await page.render(fullWidth: width.toDouble(), fullHeight: height.toDouble());
  if (rendered == null) throw StateError('Halaman gagal dirender');

  ui.Image base;
  try {
    base = await _imageFromBgra(rendered.pixels, rendered.width, rendered.height);
  } finally {
    rendered.dispose();
  }

  ui.Image composed;
  try {
    composed = await _drawAnnotations(
      base: base,
      annotations: annotations,
      pageWidth: page.width,
      pageHeight: page.height,
      width: width,
      height: height,
    );
  } finally {
    base.dispose();
  }

  try {
    return switch (format) {
      PageImageFormat.png => await _encodePng(composed),
      PageImageFormat.jpg => await _encodeJpg(composed, jpegQuality),
    };
  } finally {
    composed.dispose();
  }
}

Future<ui.Image> _imageFromBgra(Uint8List pixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.bgra8888, completer.complete);
  return completer.future;
}

Future<ui.Image> _drawAnnotations({
  required ui.Image base,
  required List<ZoteroAnnotation> annotations,
  required double pageWidth,
  required double pageHeight,
  required int width,
  required int height,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());

  // A page with transparency would come out with a black background in JPG.
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  canvas.drawImageRect(
    base,
    Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.high,
  );

  AnnotationOverlayPainter(
    annotations: annotations,
    pageWidth: pageWidth,
    pageHeight: pageHeight,
  ).paint(canvas, size);

  return recorder.endRecording().toImage(width, height);
}

Future<Uint8List> _encodePng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw StateError('PNG gagal dikodekan');
  return data.buffer.asUint8List();
}

Future<Uint8List> _encodeJpg(ui.Image image, int quality) async {
  // dart:ui cannot write JPEG, so the raw pixels go through the image package.
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
