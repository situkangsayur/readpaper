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
    this.liveColor,
    this.liveWidth,
    this.stylusOnly = false,
    this.liveStroke,
    this.liveRepaint,
    super.key,
  });

  /// Hanya stylus yang boleh menggambar.
  ///
  /// Penolak telapak tangan yang sebenarnya: tangan yang bertumpu di layar
  /// tidak meninggalkan garis. Di mode ini goresan dibaca dari **peristiwa
  /// pointer mentah**, bukan lewat `GestureDetector`, dan itu bukan selera:
  /// `GestureDetector` ikut menghalangi sentuhan jari sampai ke pembaca PDF di
  /// belakangnya — terbukti di tablet — walaupun pengenalnya sudah dibatasi ke
  /// stylus saja. Akibatnya dokumen terasa beku: tidak bisa digeser sama sekali
  /// selama pena aktif. `Listener` tidak ikut arena gerakan, jadi jari tetap
  /// milik halaman.
  final bool stylusOnly;

  /// Goresan yang sedang ditarik, dalam koordinat kanvas halaman.
  ///
  /// Diisi pemanggilnya saat goresannya ditangkap di atas viewer (mode stylus
  /// saja); null berarti lapisan ini yang menangkapnya sendiri.
  final List<Offset>? liveStroke;

  /// Memberi tahu kanvas bahwa [liveStroke] bertambah satu titik.
  ///
  /// Goresan stylus datang seratus kali sedetik, dan membangun ulang layar
  /// pembaca sebanyak itu terasa tersendat persis di saat kelancaran paling
  /// dibutuhkan. Lewat jalur ini yang terjadi hanya satu pengecatan ulang.
  final Listenable? liveRepaint;

  final double pageWidth;
  final double pageHeight;
  final Color color;

  /// Width in PDF points, the same unit Zotero stores.
  final double strokeWidth;

  /// Rupa goresan yang sedang ditarik, bila berbeda dari [color] — penghapus
  /// digambar abu-abu tebal transparan, supaya terlihat apa yang disapu
  /// tanpa ikut mewarnai goresan yang ada.
  final Color? liveColor;
  final double? liveWidth;

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
      final canvas = CustomPaint(
        size: _size,
        painter: _InkPainter(
          repaint: widget.liveRepaint,
          live: widget.liveStroke ?? _live,
          strokes: widget.strokes,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
          liveColor: widget.liveColor,
          liveWidth: widget.liveWidth,
          pageWidth: widget.pageWidth,
          pageHeight: widget.pageHeight,
        ),
      );

      // Saat hanya stylus yang menggambar, lapisan ini **tidak menyentuh
      // pointer sama sekali**: goresannya ditangkap di atas viewer, dan yang
      // tersisa di sini hanya melukis. Percobaan di tablet membuktikan
      // sebabnya harus begitu — `GestureDetector` maupun `Listener` di posisi
      // ini sama-sama membuat pembaca PDF berhenti menanggapi jari, jadi
      // dokumennya tidak bisa digeser selama pena aktif.
      if (widget.stylusOnly) return IgnorePointer(child: canvas);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _add(d.localPosition),
        onPanUpdate: (d) => _add(d.localPosition),
        onPanEnd: (_) => _finish(),
        onPanCancel: _finish,
        child: canvas,
      );
    },
  );
}

class _InkPainter extends CustomPainter {
  _InkPainter({
    super.repaint,
    required this.live,
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    this.liveColor,
    this.liveWidth,
    required this.pageWidth,
    required this.pageHeight,
  });

  final List<Offset> live;
  final List<InkPath> strokes;
  final Color color;
  final double strokeWidth;
  final Color? liveColor;
  final double? liveWidth;
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
      canvas.drawPath(
        path,
        liveColor == null && liveWidth == null
            ? paint
            : (Paint()
                ..color = liveColor ?? color
                ..strokeWidth = (liveWidth ?? strokeWidth) * scaleX
                ..style = PaintingStyle.stroke
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round),
      );
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) =>
      old.live.length != live.length ||
      old.strokes.length != strokes.length ||
      old.color != color ||
      old.liveColor != liveColor ||
      old.strokeWidth != strokeWidth;
}
