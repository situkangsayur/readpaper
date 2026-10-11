import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/l10n.dart';
import '../../../core/utils/formatting.dart';
import '../../library/domain/entities/zotero_annotation.dart';
import '../../reader/presentation/widgets/annotation_overlay_painter.dart';
import '../../reader/presentation/widgets/page_tint.dart';
import '../domain/audience_state.dart';
import 'laser_pointer.dart';

/// Layar audiens: satu halaman sepenuh layar di atas latar hitam, dengan
/// semua yang digambar presenter — anotasi, coretan yang belum tersimpan, dan
/// goresan yang sedang ditarik. Tidak ada tombol, tidak ada catatan presenter.
class AudienceView extends StatefulWidget {
  const AudienceView({required this.state, required this.pictures, this.pointer, super.key});

  final ValueListenable<AudienceState> state;

  /// Gambar tempelan yang sudah didekode, per nama berkas.
  final ValueListenable<Map<String, ui.Image>> pictures;

  /// Penunjuk presenter; null bila tidak dipakai.
  final LaserPointer? pointer;

  @override
  State<AudienceView> createState() => _AudienceViewState();
}

class _AudienceViewState extends State<AudienceView> {
  /// Dokumen yang sedang ditampilkan, dipegang selama berkasnya sama.
  ///
  /// Wajib dipegang di sini, bukan dibuat ulang setiap kali status berubah:
  /// goresan yang sedang ditarik mengubah status puluhan kali sedetik, dan
  /// referensi dokumen baru di setiap susun ulang membuat PDF-nya dibuka
  /// ulang terus-menerus — terbukti di tablet, layar audiens jadi kosong
  /// selama presenter menulis.
  PdfDocumentRef? _document;
  String? _documentPath;

  PdfDocumentRef? _documentFor(String path) {
    if (path != _documentPath) {
      _documentPath = path;
      _document = PdfDocumentRefFile(path);
    }
    return _document;
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: ValueListenableBuilder<AudienceState>(
      valueListenable: widget.state,
      builder: (context, s, _) {
        if (s.blank) return const SizedBox.expand();
        final path = s.path;
        if (path == null) {
          return Center(
            child: Text(
              context.l10n.presenterAudienceWaiting,
              style: const TextStyle(color: Colors.white54, fontSize: 18),
            ),
          );
        }
        return PdfDocumentViewBuilder(
          documentRef: _documentFor(path)!,
          builder: (context, document) {
            if (document == null) return const SizedBox.expand();
            return _page(document, s);
          },
        );
      },
    ),
  );

  Widget _page(PdfDocument document, AudienceState s) {
    final tint = PageTint.values.where((t) => t.name == s.tint).firstOrNull ?? PageTint.none;
    final page = s.page.clamp(1, document.pages.length);
    return PdfPageView(
      key: ValueKey<String>('${s.path}#$page'),
      document: document,
      pageNumber: page,
      maximumDpi: 400,
      backgroundColor: Colors.black,
      decorationBuilder: (context, pageSize, pdfPage, image) {
        final content = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (image != null) image else const ColoredBox(color: Colors.white),
            ValueListenableBuilder<Map<String, ui.Image>>(
              valueListenable: widget.pictures,
              builder: (context, images, _) => CustomPaint(
                painter: AnnotationOverlayPainter(
                  annotations: s.annotations,
                  pictures: images,
                  pageWidth: pdfPage.width,
                  pageHeight: pdfPage.height,
                ),
              ),
            ),
            CustomPaint(
              painter: AudienceInkPainter(
                pending: s.pending,
                pendingColor: colorFromHex(s.pendingColor),
                pendingWidth: s.pendingWidth,
                live: s.live,
                liveColor: colorFromHex(s.liveColor),
                liveWidth: s.liveWidth,
                pageWidth: pdfPage.width,
                pageHeight: pdfPage.height,
              ),
            ),
            if (widget.pointer case final pointer?)
              LaserPointerLayer(pointer: pointer, pageNumber: page),
          ],
        );
        final filter = tint.filter;
        return SizedBox.fromSize(
          size: pageSize,
          child: filter == null ? content : ColorFiltered(colorFilter: filter, child: content),
        );
      },
    );
  }
}

/// Coretan yang belum menjadi anotasi: goresan yang sudah selesai ditarik
/// dan goresan yang sedang ditarik, dalam koordinat PDF.
class AudienceInkPainter extends CustomPainter {
  const AudienceInkPainter({
    required this.pending,
    required this.pendingColor,
    required this.pendingWidth,
    required this.live,
    required this.liveColor,
    required this.liveWidth,
    required this.pageWidth,
    required this.pageHeight,
  });

  final List<InkPath> pending;
  final Color pendingColor;
  final double pendingWidth;
  final List<double> live;
  final Color liveColor;
  final double liveWidth;
  final double pageWidth;
  final double pageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (pageWidth <= 0 || pageHeight <= 0) return;
    final sx = size.width / pageWidth;
    final sy = size.height / pageHeight;
    Offset at(double x, double y) => Offset(x * sx, (pageHeight - y) * sy);

    void stroke(List<double> points, Color color, double width) {
      if (points.length < 2) return;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * sx;
      if (points.length < 4) {
        canvas.drawCircle(at(points[0], points[1]), width * sx / 2, Paint()..color = color);
        return;
      }
      final path = Path()..moveTo(at(points[0], points[1]).dx, at(points[0], points[1]).dy);
      for (var i = 2; i + 1 < points.length; i += 2) {
        final o = at(points[i], points[i + 1]);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in pending) {
      stroke(s.points, pendingColor, pendingWidth);
    }
    stroke(live, liveColor, liveWidth);
  }

  @override
  bool shouldRepaint(covariant AudienceInkPainter old) =>
      old.pending != pending || old.live != live || old.liveColor != liveColor;
}
