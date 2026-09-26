import 'package:flutter/material.dart';

import '../../../library/domain/entities/zotero_annotation.dart';

/// Draw a signature once, large, then place it on the page.
///
/// Signing by drawing directly onto a page at its own scale is unpleasant:
/// the box is small, the stroke is shaky, and a mistake means undoing on the
/// document itself. Drawing it big on a clean sheet and shrinking it into
/// place is how signing actually works.
Future<List<InkPath>?> showSignaturePad(BuildContext context) => showDialog<List<InkPath>>(
  context: context,
  builder: (context) =>
      Dialog(insetPadding: const EdgeInsets.all(16), child: const _SignaturePad()),
);

class _SignaturePad extends StatefulWidget {
  const _SignaturePad();

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  /// Strokes in the pad's own coordinates, normalised on the way out.
  final List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset>? _live;
  Size _size = Size.zero;

  void _start(Offset p) => setState(() => _live = <Offset>[p]);

  void _extend(Offset p) {
    final live = _live;
    if (live == null) return;
    if (live.isNotEmpty && (live.last - p).distance < 1.2) return;
    setState(() => live.add(p));
  }

  void _end() {
    final live = _live;
    setState(() {
      if (live != null && live.length > 1) _strokes.add(live);
      _live = null;
    });
  }

  /// Strokes in a 0..1 box, so the caller can place them at any size.
  ///
  /// The drawing is trimmed to its own bounds first: the blank margin around
  /// a signature would otherwise become part of it and shrink the writing.
  List<InkPath>? _normalised() {
    if (_strokes.isEmpty) return null;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final stroke in _strokes) {
      for (final p in stroke) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    final width = (maxX - minX).abs();
    final height = (maxY - minY).abs();
    // A single dot or a straight line has no extent in one direction; a fixed
    // divisor keeps that from becoming a division by zero.
    final scale = (width > height ? width : height).clamp(1.0, double.infinity);

    return <InkPath>[
      for (final stroke in _strokes)
        InkPath(<double>[
          for (final p in stroke) ...<double>[(p.dx - minX) / scale, (p.dy - minY) / scale],
        ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Tanda tangan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tulis di sini, lalu ketuk halaman untuk menaruhnya.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _size = constraints.biggest;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _start(d.localPosition),
                      onPanUpdate: (d) => _extend(d.localPosition),
                      onPanEnd: (_) => _end(),
                      onPanCancel: _end,
                      child: CustomPaint(
                        size: _size,
                        painter: _SignaturePainter(
                          strokes: _strokes,
                          live: _live,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _strokes.isEmpty && _live == null
                      ? null
                      : () => setState(() {
                          _strokes.clear();
                          _live = null;
                        }),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Bersihkan'),
                ),
                TextButton.icon(
                  onPressed: _strokes.isEmpty ? null : () => setState(_strokes.removeLast),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Urungkan'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _strokes.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_normalised()),
                  child: const Text('Pakai'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.strokes, required this.live, required this.color});

  final List<List<Offset>> strokes;
  final List<Offset>? live;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void draw(List<Offset> points) {
      if (points.length < 2) return;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      draw(stroke);
    }
    final live = this.live;
    if (live != null) draw(live);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes.length != strokes.length || old.live?.length != live?.length;
}

/// Places a normalised signature on a page.
///
/// [topLeft] is in PDF coordinates and [width] is how wide the signature
/// should be; the height follows from its own proportions so it is never
/// stretched.
List<InkPath> placeSignature(
  List<InkPath> normalised, {
  required double x,
  required double y,
  required double width,
}) {
  var maxY = 0.0;
  for (final stroke in normalised) {
    for (var i = 0; i < stroke.length; i++) {
      final v = stroke.yAt(i);
      if (v > maxY) maxY = v;
    }
  }
  final height = maxY * width;

  return <InkPath>[
    for (final stroke in normalised)
      InkPath(<double>[
        for (var i = 0; i < stroke.length; i++) ...<double>[
          x + stroke.xAt(i) * width,
          // The pad counts downwards from the top; PDF counts up from the
          // bottom, so the signature has to be flipped as it is placed.
          y + height - stroke.yAt(i) * width,
        ],
      ]),
  ];
}
