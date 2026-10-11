import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/formatting.dart';
import '../../../library/domain/entities/zotero_annotation.dart';
import '../../data/page_picture.dart';

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
    this.pictures = const <String, ui.Image>{},
  });

  /// Gambar tempelan yang sudah dibaca, per nama berkas. Yang belum ada
  /// digambar sebagai kotak abu-abu sampai selesai dimuat.
  final Map<String, ui.Image> pictures;

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
        case AnnotationType.note:
          // Catatan gaya Zotero: penanda kecil di halaman. Isinya dibuka
          // dengan mengetuknya (balon catatan digambar sebagai widget).
          for (final rect in annotation.rects) {
            _drawNoteIcon(canvas, _toLocal(rect, scaleX, scaleY), color, isSelected);
          }
        case AnnotationType.text:
          for (final rect in annotation.rects) {
            final local = _toLocal(rect, scaleX, scaleY);
            final content = annotation.comment.trim();

            // A `text` annotation carrying words is someone filling in a form
            // or labelling a figure, so the words are drawn. An empty one is
            // a sticky note, and stays a coloured marker.
            if (content.isNotEmpty) {
              _drawText(canvas, content, local, annotation, color, scaleX, scaleY, isSelected);
              continue;
            }

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
        case AnnotationType.ink:
          final paint = Paint()
            ..color = color.withValues(alpha: isSelected ? 1 : 0.9)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = annotation.inkWidth * scaleX;
          for (final stroke in annotation.paths) {
            if (stroke.length == 0) continue;
            final path = Path()
              ..moveTo(stroke.xAt(0) * scaleX, (pageHeight - stroke.yAt(0)) * scaleY);
            for (var i = 1; i < stroke.length; i++) {
              path.lineTo(stroke.xAt(i) * scaleX, (pageHeight - stroke.yAt(i)) * scaleY);
            }
            // A single tap is a dot, which lineTo alone would not draw.
            if (stroke.length == 1) {
              canvas.drawCircle(
                Offset(stroke.xAt(0) * scaleX, (pageHeight - stroke.yAt(0)) * scaleY),
                annotation.inkWidth * scaleX / 2,
                Paint()..color = paint.color,
              );
            } else {
              canvas.drawPath(path, paint);
            }
          }

        case AnnotationType.image when PagePicture.isPicture(annotation):
          final picture = pictures[PagePicture.fileOf(annotation)];
          for (final rect in annotation.rects) {
            final target = _toLocal(rect, scaleX, scaleY);
            if (picture == null) {
              canvas.drawRect(target, Paint()..color = const Color(0x22808080));
              continue;
            }
            canvas.drawImageRect(
              picture,
              Rect.fromLTWH(0, 0, picture.width.toDouble(), picture.height.toDouble()),
              target,
              Paint()..filterQuality = FilterQuality.medium,
            );
          }
        case AnnotationType.image:
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

      final drawsOwnOutline =
          annotation.type == AnnotationType.note ||
          (annotation.type == AnnotationType.text && annotation.hasComment);
      if (isSelected && annotation.rects.isNotEmpty && !drawsOwnOutline) {
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

  /// Paints the words of a filled-in text box onto the page.
  ///
  /// The font size is the one stored with the annotation, scaled the same way
  /// the page is, so what is on screen is what lands in an exported PDF.
  void _drawText(
    Canvas canvas,
    String content,
    Rect local,
    ZoteroAnnotation annotation,
    Color color,
    double scaleX,
    double scaleY,
    bool isSelected,
  ) {
    final fontSize = annotation.fontSize * scaleY;

    // Diputar di sekitar titik tengah kotaknya. Sudutnya berlawanan jarum jam
    // di koordinat PDF, yang di layar (sumbu y ke bawah) berarti negatif.
    canvas.save();
    if (annotation.rotation != 0) {
      canvas
        ..translate(local.center.dx, local.center.dy)
        ..rotate(-annotation.rotation * math.pi / 180)
        ..translate(-local.center.dx, -local.center.dy);
    }

    // Only a hint of a box: a form that has been filled in should read as
    // filled in, not as covered in stickers.
    if (isSelected) {
      canvas.drawRect(
        local.inflate(2),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scaleX,
      );
    }

    final painter = TextPainter(
      text: TextSpan(
        text: content,
        style: TextStyle(color: color, fontSize: fontSize, height: 1.15),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: local.width <= 1 ? double.infinity : local.width);

    painter.paint(canvas, Offset(local.left, local.top));
    canvas.restore();
  }

  /// Ikon catatan tempel: kertas berwarna dengan sudut terlipat dan tiga
  /// garis tulisan, seperti penanda catatan di Zotero.
  void _drawNoteIcon(Canvas canvas, Rect local, Color color, bool isSelected) {
    final r = local.shortestSide * 0.12;
    final fold = local.shortestSide * 0.32;
    final body = Path()
      ..moveTo(local.left + r, local.top)
      ..lineTo(local.right - fold, local.top)
      ..lineTo(local.right, local.top + fold)
      ..lineTo(local.right, local.bottom - r)
      ..quadraticBezierTo(local.right, local.bottom, local.right - r, local.bottom)
      ..lineTo(local.left + r, local.bottom)
      ..quadraticBezierTo(local.left, local.bottom, local.left, local.bottom - r)
      ..lineTo(local.left, local.top + r)
      ..quadraticBezierTo(local.left, local.top, local.left + r, local.top)
      ..close();
    canvas.drawShadow(body, Colors.black, 1.5, false);
    canvas.drawPath(body, Paint()..color = color);
    // Lipatan sudut.
    canvas.drawPath(
      Path()
        ..moveTo(local.right - fold, local.top)
        ..lineTo(local.right - fold, local.top + fold)
        ..lineTo(local.right, local.top + fold)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = math.max(1, local.height * 0.06)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = local.top + local.height * (0.42 + i * 0.17);
      final right = i == 2 ? local.left + local.width * 0.55 : local.right - local.width * 0.2;
      canvas.drawLine(Offset(local.left + local.width * 0.2, y), Offset(right, y), line);
    }
    if (isSelected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(local.inflate(3), Radius.circular(r + 3)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationOverlayPainter old) =>
      old.annotations != annotations ||
      old.selectedKey != selectedKey ||
      old.pageWidth != pageWidth ||
      old.pageHeight != pageHeight ||
      old.pictures.length != pictures.length;
}
