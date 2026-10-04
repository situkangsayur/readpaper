import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../markdown/domain/mermaid_graph.dart';
import '../../../markdown/presentation/widgets/mermaid_view.dart';
import '../../data/note_export.dart';
import '../../domain/note_document.dart';
import '../../../../core/utils/shape_geometry.dart';

/// Menggambar satu lembar catatan beserta seluruh komponennya.
///
/// Kanvasnya selalu berukuran lembar A4 dalam titik PDF, lalu diperkecil atau
/// diperbesar utuh ke layar. Dengan begitu satu koordinat berlaku di mana
/// saja — di layar ponsel, di tablet, dan di dalam PDF — dan catatan yang
/// ditulis di layar kecil tidak berpindah tempat saat dibuka di layar besar.
class NoteCanvas extends StatelessWidget {
  const NoteCanvas({
    required this.page,
    required this.scale,
    this.baseDir,
    this.liveStroke,
    this.liveColor = const Color(0xFF000000),
    this.liveWidth = 2.5,
    this.selectedId,
    this.pickedIds = const <String>{},
    this.marquee,
    this.eraserAt,
    this.eraserRadius = 12,
    this.previewShape,
    this.connectFromId,
    super.key,
  });

  final NotePage page;

  /// Berapa piksel layar untuk satu titik lembar.
  final double scale;

  /// Folder dokumennya, acuan untuk gambar berjalur relatif.
  final String? baseDir;

  /// Goresan yang sedang ditarik jarinya, belum jadi komponen.
  final NoteStroke? liveStroke;
  final Color liveColor;
  final double liveWidth;

  final String? selectedId;

  /// Benda-benda yang terpilih lewat kotak pilih.
  final Set<String> pickedIds;

  /// Kotak pilih yang sedang ditarik, dalam koordinat lembar.
  final Rect? marquee;

  /// Tempat penghapus sedang berada, untuk lingkaran penunjuknya.
  final Offset? eraserAt;
  final double eraserRadius;

  /// Bangun yang sedang ditarik jarinya, belum jadi komponen.
  final ({ShapeKind kind, Offset from, Offset to})? previewShape;

  /// Benda pertama yang sudah diketuk dengan alat penghubung, untuk disorot —
  /// tanpa sorotan, yang menghubungkan tidak tahu ketukan pertamanya masuk.
  final String? connectFromId;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: page.size.width * scale,
    height: page.size.height * scale,
    child: ClipRect(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _SheetPainter(page: page, scale: scale),
            ),
          ),
          // Tinta, bangun, dan penghubung digambar sebagai satu lapisan dalam
          // koordinat lembar: penghubung membentang antara dua benda, jadi
          // tidak bisa tinggal di dalam salah satunya.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DrawingPainter(page: page, scale: scale),
              ),
            ),
          ),
          for (final component in page.components)
            if (component is NoteText || component is NoteImage || component is NoteDiagram)
              _placed(component),
          if (selectedId != null)
            for (final component in page.components)
              if (component.id == selectedId &&
                  (component is NoteInk || component is NoteShape || component is NoteConnector))
                _selectionBox(component),
          for (final component in page.components)
            if (pickedIds.contains(component.id)) _pickedBox(component),
          if (marquee != null)
            Positioned(
              left: marquee!.left * scale,
              top: marquee!.top * scale,
              width: marquee!.width * scale,
              height: marquee!.height * scale,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1565C0), width: 1.2),
                    color: const Color(0x141565C0),
                  ),
                ),
              ),
            ),
          if (connectFromId != null)
            for (final component in page.components)
              if (component.id == connectFromId) _connectHighlight(component),
          if (previewShape != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PreviewShapePainter(
                    preview: previewShape!,
                    color: liveColor,
                    width: liveWidth,
                    scale: scale,
                  ),
                ),
              ),
            ),
          if (liveStroke != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _StrokePainter(
                    strokes: <NoteStroke>[liveStroke!],
                    color: liveColor,
                    opacity: 1,
                    scale: scale,
                  ),
                ),
              ),
            ),
          if (eraserAt != null)
            Positioned(
              left: (eraserAt!.dx - eraserRadius) * scale,
              top: (eraserAt!.dy - eraserRadius) * scale,
              width: eraserRadius * 2 * scale,
              height: eraserRadius * 2 * scale,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.error, width: 1.2),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _placed(NoteComponent component) {
    final selected = component.id == selectedId;
    final body = Opacity(
      opacity: component.opacity.clamp(0.0, 1.0),
      child: SizedBox(
        width: component.size.width * scale,
        height: component.size.height * scale,
        child: _body(component),
      ),
    );

    return Positioned(
      left: component.position.dx * scale,
      top: component.position.dy * scale,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: component.rotation,
          child: selected
              ? DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0x552196F3))),
                  child: body,
                )
              : body,
        ),
      ),
    );
  }

  /// Penanda benda yang terpilih lewat kotak pilih.
  Widget _pickedBox(NoteComponent component) {
    final box = component is NoteConnector
        ? () {
            final ends = page.endsOf(component);
            return ends == null ? null : Rect.fromPoints(ends.$1, ends.$2).inflate(4);
          }()
        : component.bounds;
    if (box == null) return const SizedBox.shrink();
    return Positioned(
      left: box.left * scale,
      top: box.top * scale,
      width: box.width * scale,
      height: box.height * scale,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1565C0), width: 1.4),
            color: const Color(0x1A1565C0),
          ),
        ),
      ),
    );
  }

  Widget _connectHighlight(NoteComponent component) => Positioned(
    left: component.bounds.left * scale,
    top: component.bounds.top * scale,
    width: component.bounds.width * scale,
    height: component.bounds.height * scale,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF2E7D32), width: 2),
          color: const Color(0x222E7D32),
        ),
      ),
    ),
  );

  /// Bingkai tipis penanda benda gambar yang terpilih.
  ///
  /// Bendanya sendiri sudah tergambar di lapisan gambar, jadi yang diletakkan
  /// di sini hanya penandanya.
  Widget _selectionBox(NoteComponent component) {
    final box = component is NoteConnector
        ? () {
            final ends = page.endsOf(component);
            return ends == null ? null : Rect.fromPoints(ends.$1, ends.$2).inflate(6);
          }()
        : component.bounds;
    if (box == null) return const SizedBox.shrink();
    return Positioned(
      left: box.left * scale,
      top: box.top * scale,
      width: box.width * scale,
      height: box.height * scale,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: component is NoteConnector ? 0 : component.rotation,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: const Color(0x552196F3))),
          ),
        ),
      ),
    );
  }

  Widget _body(NoteComponent component) => switch (component) {
    // Benda gambar sudah tergambar di lapisannya sendiri.
    NoteInk() || NoteShape() || NoteConnector() => const SizedBox.shrink(),
    NoteText() => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: component.size.width,
        child: Text(
          component.text,
          style: TextStyle(
            fontSize: component.fontSize,
            color: Color(component.color),
            height: 1.3,
          ),
        ),
      ),
    ),
    NoteImage() => _Picture(component: component, baseDir: baseDir),
    NoteDiagram() => MermaidPicture(graph: MermaidGraph.parse(component.source), fit: true),
  };
}

class _Picture extends StatelessWidget {
  const _Picture({required this.component, this.baseDir});

  final NoteImage component;
  final String? baseDir;

  @override
  Widget build(BuildContext context) {
    final path = component.file;
    final file = p.isAbsolute(path) || baseDir == null ? File(path) : File(p.join(baseDir!, path));
    if (path.isEmpty || !file.existsSync()) {
      return DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline)),
        child: Center(
          child: Text(
            'gambar hilang',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Image.file(file, fit: BoxFit.contain);
  }
}

/// Latar lembar beserta garis bantunya.
class _SheetPainter extends CustomPainter {
  const _SheetPainter({required this.page, required this.scale});

  final NotePage page;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(page.background));
    if (page.rule == NotePageRule.polos) return;

    final line = Paint()
      ..color = const Color(0xFF90A4AE).withValues(alpha: 0.5)
      ..strokeWidth = 0.7;
    const step = 28.0;
    for (var y = step; y < page.size.height; y += step) {
      canvas.drawLine(Offset(0, y * scale), Offset(size.width, y * scale), line);
    }
    if (page.rule != NotePageRule.kotak) return;
    for (var x = step; x < page.size.width; x += step) {
      canvas.drawLine(Offset(x * scale, 0), Offset(x * scale, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.page != page || old.scale != scale;
}

/// Bangun yang sedang ditarik, digambar dengan perhitungan yang sama dengan
/// bangun yang sudah jadi — supaya yang terlihat saat menarik sama dengan yang
/// mendarat saat jarinya diangkat.
class _PreviewShapePainter extends CustomPainter {
  const _PreviewShapePainter({
    required this.preview,
    required this.color,
    required this.width,
    required this.scale,
  });

  final ({ShapeKind kind, Offset from, Offset to}) preview;
  final Color color;
  final double width;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final berarah = preview.kind == ShapeKind.garis || preview.kind == ShapeKind.panah;
    final box = Rect.fromPoints(preview.from, preview.to);
    final origin = berarah ? preview.from : box.topLeft;
    final extent = berarah
        ? Size(preview.to.dx - preview.from.dx, preview.to.dy - preview.from.dy)
        : box.size;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..save()
      ..scale(scale)
      ..translate(origin.dx, origin.dy);
    for (final line in ShapeGeometry.outline(preview.kind, extent)) {
      if (line.length < 2) continue;
      final path = Path()..moveTo(line.first.dx, line.first.dy);
      for (final point in line.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint..strokeWidth = width);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewShapePainter old) =>
      old.preview != preview || old.color != color || old.scale != scale;
}

/// Lapisan gambar satu lembar: tinta, bangun, dan penghubung.
class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({required this.page, required this.scale});

  final NotePage page;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    // Penggambarnya dipakai bersama dengan ekspor PNG, jadi yang terlihat di
    // layar dan yang tersimpan tidak bisa berbeda.
    NoteExport.paintDrawing(canvas, page);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => old.page != page || old.scale != scale;
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter({
    required this.strokes,
    required this.color,
    required this.opacity,
    required this.scale,
  });

  final List<NoteStroke> strokes;
  final Color color;
  final double opacity;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      paint.strokeWidth = stroke.width * scale;
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first * scale, stroke.width * scale / 2, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.points.first.dx * scale, stroke.points.first.dy * scale);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx * scale, point.dy * scale);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.strokes != strokes || old.color != color || old.scale != scale;
}
