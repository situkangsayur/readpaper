import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../markdown/domain/mermaid_graph.dart';
import '../../../markdown/presentation/widgets/mermaid_view.dart';
import '../../domain/note_document.dart';

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
    this.eraserAt,
    this.eraserRadius = 12,
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

  /// Tempat penghapus sedang berada, untuk lingkaran penunjuknya.
  final Offset? eraserAt;
  final double eraserRadius;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: NoteSheet.width * scale,
    height: NoteSheet.height * scale,
    child: ClipRect(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(painter: _SheetPainter(page: page, scale: scale)),
          ),
          for (final component in page.components) _placed(component),
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
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0x552196F3)),
                  ),
                  child: body,
                )
              : body,
        ),
      ),
    );
  }

  Widget _body(NoteComponent component) => switch (component) {
    NoteInk() => CustomPaint(
      painter: _StrokePainter(
        strokes: component.strokes,
        color: Color(component.color),
        opacity: 1,
        scale: scale,
      ),
    ),
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
    final file = p.isAbsolute(path) || baseDir == null
        ? File(path)
        : File(p.join(baseDir!, path));
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
    for (var y = step; y < NoteSheet.height; y += step) {
      canvas.drawLine(Offset(0, y * scale), Offset(size.width, y * scale), line);
    }
    if (page.rule != NotePageRule.kotak) return;
    for (var x = step; x < NoteSheet.width; x += step) {
      canvas.drawLine(Offset(x * scale, 0), Offset(x * scale, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.page != page || old.scale != scale;
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
