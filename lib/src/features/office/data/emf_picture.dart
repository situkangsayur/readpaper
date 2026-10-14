import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

/// Gambar EMF (Windows Enhanced Metafile) yang digambar sendiri.
///
/// Flutter tidak bisa menampilkan EMF, padahal PowerPoint dan Word menyimpan
/// rumus (MathType, Equation Editor) dan banyak diagram sebagai EMF — tanpa
/// ini rumus dan matriksnya hilang dari slide. Yang dibaca: jalur (garis,
/// kurva bezier, poligon, persegi, elips), kuas dan pena, pemetaan
/// window/viewport, transformasi dunia, teks sederhana, dan bitmap DIB.
/// Kliping diabaikan; rumus dan diagram tidak bergantung padanya.
class EmfPicture {
  EmfPicture._(this.bounds, this.ops);

  /// Bingkai gambar dalam satuan perangkat EMF.
  final Rect bounds;
  final List<EmfOp> ops;

  static bool looksLike(Uint8List bytes) =>
      bytes.length > 88 &&
      ByteData.sublistView(bytes).getUint32(0, Endian.little) == 1 &&
      ByteData.sublistView(bytes).getUint32(40, Endian.little) == 0x464D4520;

  static final Expando<EmfPicture> _cache = Expando<EmfPicture>();

  /// Hasil baca [bytes], disimpan per objek byte; null bila bukan EMF atau rusak.
  static EmfPicture? of(Uint8List bytes) {
    if (!looksLike(bytes)) return null;
    final cached = _cache[bytes];
    if (cached != null) return cached;
    try {
      final picture = _EmfParser(bytes).parse();
      _cache[bytes] = picture;
      return picture;
    } on Object {
      return null;
    }
  }

  /// Menggambar ke [canvas] memenuhi [size].
  void paint(Canvas canvas, Size size) {
    if (bounds.width <= 0 || bounds.height <= 0) return;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..scale(size.width / bounds.width, size.height / bounds.height)
      ..translate(-bounds.left, -bounds.top);
    for (final op in ops) {
      op.paint(canvas);
    }
    canvas.restore();
  }

  /// PNG selebar [width] piksel, untuk tempat yang hanya menerima gambar
  /// biasa (ekspor PDF).
  Future<Uint8List?> toPng({double width = 1600}) async {
    if (bounds.width <= 0 || bounds.height <= 0) return null;
    final size = Size(width, width * bounds.height / bounds.width);
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(size.width.ceil(), size.height.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }
}

sealed class EmfOp {
  void paint(Canvas canvas);
}

class EmfPathOp extends EmfOp {
  EmfPathOp(this.path, this.paint_);

  final Path path;
  final Paint paint_;

  @override
  void paint(Canvas canvas) => canvas.drawPath(path, paint_);
}

class EmfTextOp extends EmfOp {
  EmfTextOp(this.painter, this.offset, this.angle);

  final TextPainter painter;
  final Offset offset;
  final double angle;

  @override
  void paint(Canvas canvas) {
    if (angle == 0) {
      painter.paint(canvas, offset);
      return;
    }
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..rotate(angle)
      ..translate(-offset.dx, -offset.dy);
    painter.paint(canvas, offset);
    canvas.restore();
  }
}

class EmfImageOp extends EmfOp {
  EmfImageOp(this.pixels, this.width, this.height, this.dest);

  final Uint8List pixels;
  final int width;
  final int height;
  final Rect dest;
  ui.Image? image;

  @override
  void paint(Canvas canvas) {
    final ready = image;
    if (ready == null) return;
    canvas.drawImageRect(
      ready,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      dest,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

/// Menyiapkan bitmap di dalam [picture] (bila ada) supaya bisa digambar.
Future<void> prepareEmfImages(EmfPicture picture) async {
  for (final op in picture.ops.whereType<EmfImageOp>()) {
    if (op.image != null) continue;
    final buffer = await ui.ImmutableBuffer.fromUint8List(op.pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: op.width,
      height: op.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    op.image = (await codec.getNextFrame()).image;
  }
}

class _Brush {
  const _Brush(this.color);
  final Color? color;
}

class _Pen {
  const _Pen(this.color, this.width);
  final Color? color;
  final double width;
}

class _Font {
  const _Font(this.height, this.weight, this.italic, this.face, this.escapement);
  final double height;
  final int weight;
  final bool italic;
  final String face;
  final double escapement;
}

class _State {
  _State();

  _State.copy(_State o)
    : brush = o.brush,
      pen = o.pen,
      font = o.font,
      textColor = o.textColor,
      textAlign = o.textAlign,
      fillType = o.fillType,
      mapMode = o.mapMode,
      winOrg = o.winOrg,
      winExt = o.winExt,
      vpOrg = o.vpOrg,
      vpExt = o.vpExt,
      world = Float64List.fromList(o.world),
      current = o.current;

  _Brush? brush = const _Brush(Color(0xFFFFFFFF));
  _Pen? pen = const _Pen(Color(0xFF000000), 1);
  _Font? font;
  Color textColor = const Color(0xFF000000);
  int textAlign = 0;
  PathFillType fillType = PathFillType.evenOdd;
  int mapMode = 1;
  Offset winOrg = Offset.zero;
  Size winExt = const Size(1, 1);
  Offset vpOrg = Offset.zero;
  Size vpExt = const Size(1, 1);

  /// eM11, eM12, eM21, eM22, eDx, eDy.
  Float64List world = Float64List.fromList(<double>[1, 0, 0, 1, 0, 0]);
  Offset current = Offset.zero;
}

class _EmfParser {
  _EmfParser(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;
  final ops = <EmfOp>[];
  final objects = <int, Object>{};
  var state = _State();
  final saved = <_State>[];

  /// Jalur yang sedang dibangun antara BEGINPATH dan ENDPATH; null di luar itu.
  Path? building;
  Path? finished;

  int i32(int o) => data.getInt32(o, Endian.little);
  int u32(int o) => data.getUint32(o, Endian.little);
  int i16(int o) => data.getInt16(o, Endian.little);
  double f32(int o) => data.getFloat32(o, Endian.little);
  Color colorRef(int o) => Color.fromARGB(255, bytes[o], bytes[o + 1], bytes[o + 2]);

  /// Logis → perangkat: transformasi dunia, lalu window → viewport.
  Offset map(double x, double y) {
    final w = state.world;
    final wx = x * w[0] + y * w[2] + w[4];
    final wy = x * w[1] + y * w[3] + w[5];
    if (state.mapMode == 1) return Offset(wx, wy);
    final sx = state.vpExt.width / (state.winExt.width == 0 ? 1 : state.winExt.width);
    final sy = state.vpExt.height / (state.winExt.height == 0 ? 1 : state.winExt.height);
    return Offset(
      (wx - state.winOrg.dx) * sx + state.vpOrg.dx,
      (wy - state.winOrg.dy) * sy + state.vpOrg.dy,
    );
  }

  /// Skala rata-rata logis → perangkat, untuk tebal pena dan ukuran huruf.
  double get scale {
    final a = map(0, 0);
    final b = map(1, 0);
    final c = map(0, 1);
    return ((b - a).distance + (c - a).distance) / 2;
  }

  EmfPicture parse() {
    // Bingkai dalam 0,01 mm → satuan perangkat.
    final frame = Rect.fromLTRB(
      i32(24).toDouble(),
      i32(28).toDouble(),
      i32(32).toDouble(),
      i32(36).toDouble(),
    );
    final devW = i32(72), devH = i32(76), mmW = i32(80), mmH = i32(84);
    Rect bounds;
    if (frame.width > 0 && frame.height > 0 && mmW > 0 && mmH > 0) {
      final kx = devW / (mmW * 100), ky = devH / (mmH * 100);
      bounds = Rect.fromLTRB(frame.left * kx, frame.top * ky, frame.right * kx, frame.bottom * ky);
    } else {
      bounds = Rect.fromLTRB(i32(8).toDouble(), i32(12).toDouble(), i32(16) + 1.0, i32(20) + 1.0);
    }

    var o = 0;
    while (o + 8 <= bytes.length) {
      final type = u32(o);
      final size = u32(o + 4);
      if (size < 8 || o + size > bytes.length) break;
      _record(type, o, size);
      if (type == 14) break;
      o += size;
    }
    return EmfPicture._(bounds, ops);
  }

  void _record(int type, int o, int size) {
    switch (type) {
      case 9: // SETWINDOWEXTEX
        state.winExt = Size(i32(o + 8).toDouble(), i32(o + 12).toDouble());
      case 10: // SETWINDOWORGEX
        state.winOrg = Offset(i32(o + 8).toDouble(), i32(o + 12).toDouble());
      case 11: // SETVIEWPORTEXTEX
        state.vpExt = Size(i32(o + 8).toDouble(), i32(o + 12).toDouble());
      case 12: // SETVIEWPORTORGEX
        state.vpOrg = Offset(i32(o + 8).toDouble(), i32(o + 12).toDouble());
      case 17: // SETMAPMODE
        state.mapMode = u32(o + 8);
      case 19: // SETPOLYFILLMODE
        state.fillType = u32(o + 8) == 2 ? PathFillType.nonZero : PathFillType.evenOdd;
      case 22: // SETTEXTALIGN
        state.textAlign = u32(o + 8);
      case 24: // SETTEXTCOLOR
        state.textColor = colorRef(o + 8);
      case 27: // MOVETOEX
        _moveTo(map(i32(o + 8).toDouble(), i32(o + 12).toDouble()));
      case 54: // LINETO
        _lineTo(map(i32(o + 8).toDouble(), i32(o + 12).toDouble()));
      case 33: // SAVEDC
        saved.add(_State.copy(state));
      case 34: // RESTOREDC
        final n = i32(o + 8);
        final back = n < 0 ? -n : saved.length - n;
        for (var k = 1; k < back && saved.isNotEmpty; k++) {
          saved.removeLast();
        }
        if (saved.isNotEmpty) state = saved.removeLast();
      case 35: // SETWORLDTRANSFORM
        state.world = Float64List.fromList(<double>[
          for (var k = 0; k < 6; k++) f32(o + 8 + k * 4),
        ]);
      case 36: // MODIFYWORLDTRANSFORM
        final m = <double>[for (var k = 0; k < 6; k++) f32(o + 8 + k * 4)];
        final mode = u32(o + 32);
        if (mode == 1) {
          state.world = Float64List.fromList(<double>[1, 0, 0, 1, 0, 0]);
        } else if (mode == 2) {
          state.world = _multiply(m, state.world);
        } else if (mode == 3) {
          state.world = _multiply(state.world, m);
        } else if (mode == 4) {
          state.world = Float64List.fromList(m);
        }
      case 37: // SELECTOBJECT
        _select(u32(o + 8));
      case 38: // CREATEPEN
        final style = u32(o + 12);
        objects[u32(o + 8)] = _Pen(
          (style & 0xF) == 5 ? null : colorRef(o + 20),
          i32(o + 16).toDouble(),
        );
      case 95: // EXTCREATEPEN: ihPen, offBmi, cbBmi, offBits, cbBits, LOGPENEX
        final style = u32(o + 28);
        objects[u32(o + 8)] = _Pen(
          (style & 0xF) == 5 || u32(o + 36) == 1 ? null : colorRef(o + 40),
          u32(o + 32).toDouble(),
        );
      case 39: // CREATEBRUSHINDIRECT
        objects[u32(o + 8)] = _Brush(u32(o + 12) == 1 ? null : colorRef(o + 16));
      case 82: // EXTCREATEFONTINDIRECTW
        final lf = o + 12;
        final faceChars = <int>[];
        for (var k = 0; k < 32; k++) {
          final c = data.getUint16(lf + 28 + k * 2, Endian.little);
          if (c == 0) break;
          faceChars.add(c);
        }
        objects[u32(o + 8)] = _Font(
          i32(lf).abs().toDouble(),
          i32(lf + 16),
          bytes[lf + 20] != 0,
          String.fromCharCodes(faceChars),
          i32(lf + 8) / 10,
        );
      case 40: // DELETEOBJECT
        objects.remove(u32(o + 8));
      case 59: // BEGINPATH
        building = Path();
      case 60: // ENDPATH
        finished = building;
        building = null;
      case 61: // CLOSEFIGURE
        building?.close();
      case 67: // SELECTCLIPPATH: jalurnya terpakai sebagai kliping (diabaikan).
        finished = null;
      case 68: // ABORTPATH
        building = null;
        finished = null;
      case 62: // FILLPATH
        _fillStroke(finished, fill: true, stroke: false);
        finished = null;
      case 63: // STROKEANDFILLPATH
        _fillStroke(finished, fill: true, stroke: true);
        finished = null;
      case 64: // STROKEPATH
        _fillStroke(finished, fill: false, stroke: true);
        finished = null;
      case 42 || 43: // ELLIPSE, RECTANGLE
        final a = map(i32(o + 8).toDouble(), i32(o + 12).toDouble());
        final b = map(i32(o + 16).toDouble(), i32(o + 20).toDouble());
        final rect = Rect.fromPoints(a, b);
        final path = Path();
        type == 42 ? path.addOval(rect) : path.addRect(rect);
        _shape(path, fill: true, stroke: true);
      case 2 || 85: // POLYBEZIER
        _poly(o, type == 85, (pts) {
          final path = Path()..moveTo(pts[0].dx, pts[0].dy);
          _beziers(path, pts, 1);
          _shape(path, fill: false, stroke: true);
        });
      case 3 || 86: // POLYGON
        _poly(o, type == 86, (pts) {
          _shape(Path()..addPolygon(pts, true), fill: true, stroke: true);
        });
      case 4 || 87: // POLYLINE
        _poly(o, type == 87, (pts) {
          _shape(Path()..addPolygon(pts, false), fill: false, stroke: true);
        });
      case 5 || 88: // POLYBEZIERTO
        _poly(o, type == 88, (pts) {
          final path = building;
          if (path != null) {
            _beziers(path, <Offset>[state.current, ...pts], 1);
          } else {
            final p = Path()..moveTo(state.current.dx, state.current.dy);
            _beziers(p, <Offset>[state.current, ...pts], 1);
            _shape(p, fill: false, stroke: true);
          }
          state.current = pts.last;
        });
      case 6 || 89: // POLYLINETO
        _poly(o, type == 89, (pts) {
          for (final p in pts) {
            _lineTo(p);
          }
        });
      case 7 || 8 || 90 || 91: // POLYPOLYLINE, POLYPOLYGON
        final small = type >= 90;
        final polys = u32(o + 24);
        final count = u32(o + 28);
        var at = o + 32 + polys * 4;
        final path = Path();
        for (var k = 0; k < polys; k++) {
          final n = u32(o + 32 + k * 4);
          final pts = <Offset>[];
          for (var j = 0; j < n; j++) {
            pts.add(_point(at, small));
            at += small ? 4 : 8;
          }
          if (pts.isNotEmpty) path.addPolygon(pts, type == 8 || type == 91);
        }
        if (count > 0) {
          final polygon = type == 8 || type == 91;
          _shape(path, fill: polygon, stroke: true);
        }
      case 84: // EXTTEXTOUTW
        _text(o);
      case 81: // STRETCHDIBITS
        _dib(o);
    }
  }

  Offset _point(int at, bool small) => small
      ? map(i16(at).toDouble(), i16(at + 2).toDouble())
      : map(i32(at).toDouble(), i32(at + 4).toDouble());

  void _poly(int o, bool small, void Function(List<Offset>) use) {
    final count = u32(o + 24);
    if (count == 0) return;
    final pts = <Offset>[
      for (var k = 0; k < count; k++) _point(o + 28 + k * (small ? 4 : 8), small),
    ];
    use(pts);
  }

  void _beziers(Path path, List<Offset> pts, int from) {
    for (var k = from; k + 2 < pts.length; k += 3) {
      path.cubicTo(
        pts[k].dx,
        pts[k].dy,
        pts[k + 1].dx,
        pts[k + 1].dy,
        pts[k + 2].dx,
        pts[k + 2].dy,
      );
    }
  }

  void _moveTo(Offset p) {
    building?.moveTo(p.dx, p.dy);
    state.current = p;
  }

  void _lineTo(Offset p) {
    final path = building;
    if (path != null) {
      path.lineTo(p.dx, p.dy);
    } else {
      _shape(
        Path()
          ..moveTo(state.current.dx, state.current.dy)
          ..lineTo(p.dx, p.dy),
        fill: false,
        stroke: true,
      );
    }
    state.current = p;
  }

  /// Bentuk lepas (di luar BEGINPATH): bagian dari jalur bila sedang
  /// membangun, atau digambar langsung.
  void _shape(Path path, {required bool fill, required bool stroke}) {
    final building = this.building;
    if (building != null) {
      building.addPath(path, Offset.zero);
      return;
    }
    _fillStroke(path, fill: fill, stroke: stroke);
  }

  void _fillStroke(Path? path, {required bool fill, required bool stroke}) {
    if (path == null) return;
    path.fillType = state.fillType;
    final brush = state.brush?.color;
    if (fill && brush != null) {
      ops.add(EmfPathOp(path, Paint()..color = brush));
    }
    final pen = state.pen;
    if (stroke && pen != null && pen.color != null) {
      ops.add(
        EmfPathOp(
          path,
          Paint()
            ..color = pen.color!
            ..style = PaintingStyle.stroke
            ..strokeWidth = pen.width <= 0 ? 1 : pen.width * scale,
        ),
      );
    }
  }

  void _select(int handle) {
    if (handle & 0x80000000 != 0) {
      switch (handle & 0x7FFFFFFF) {
        case 0:
          state.brush = const _Brush(Color(0xFFFFFFFF));
        case 1:
          state.brush = const _Brush(Color(0xFFC0C0C0));
        case 2:
          state.brush = const _Brush(Color(0xFF808080));
        case 3:
          state.brush = const _Brush(Color(0xFF404040));
        case 4:
          state.brush = const _Brush(Color(0xFF000000));
        case 5:
          state.brush = const _Brush(null);
        case 6:
          state.pen = const _Pen(Color(0xFFFFFFFF), 1);
        case 7:
          state.pen = const _Pen(Color(0xFF000000), 1);
        case 8:
          state.pen = const _Pen(null, 1);
      }
      return;
    }
    switch (objects[handle]) {
      case final _Brush brush:
        state.brush = brush;
      case final _Pen pen:
        state.pen = pen;
      case final _Font font:
        state.font = font;
    }
  }

  void _text(int o) {
    final emrText = o + 36;
    final ref = map(i32(emrText).toDouble(), i32(emrText + 4).toDouble());
    final chars = u32(emrText + 8);
    final offString = u32(emrText + 12);
    if (chars == 0 || o + offString + chars * 2 > bytes.length) return;
    final text = String.fromCharCodes(<int>[
      for (var k = 0; k < chars; k++) data.getUint16(o + offString + k * 2, Endian.little),
    ]);
    final font = state.font;
    final height = (font?.height ?? 12) * scale;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: state.textColor,
          fontSize: height <= 0 ? 12 : height,
          height: 1,
          fontWeight: (font?.weight ?? 400) >= 600 ? FontWeight.bold : FontWeight.normal,
          fontStyle: font?.italic ?? false ? FontStyle.italic : FontStyle.normal,
          fontFamily: font?.face,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final align = state.textAlign;
    var dx = ref.dx;
    if (align & 6 == 6) {
      dx -= painter.width / 2;
    } else if (align & 2 == 2) {
      dx -= painter.width;
    }
    var dy = ref.dy;
    if (align & 24 == 24) {
      dy -= painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    } else if (align & 8 == 8) {
      dy -= painter.height;
    }
    ops.add(EmfTextOp(painter, Offset(dx, dy), -(font?.escapement ?? 0) * 3.1415926 / 180));
  }

  void _dib(int o) {
    final dest = Rect.fromPoints(
      map(i32(o + 24).toDouble(), i32(o + 28).toDouble()),
      map((i32(o + 24) + i32(o + 64)).toDouble(), (i32(o + 28) + i32(o + 68)).toDouble()),
    );
    final offBmi = u32(o + 48), cbBmi = u32(o + 52);
    final offBits = u32(o + 56), cbBits = u32(o + 60);
    if (cbBmi == 0 || cbBits == 0) return;
    // BITMAPFILEHEADER + header DIB + piksel = BMP yang bisa dibaca paket image.
    final file = BytesBuilder()
      ..add(<int>[0x42, 0x4D])
      ..add(_le32(14 + cbBmi + cbBits))
      ..add(_le32(0))
      ..add(_le32(14 + cbBmi))
      ..add(bytes.sublist(o + offBmi, o + offBmi + cbBmi))
      ..add(bytes.sublist(o + offBits, o + offBits + cbBits));
    final decoded = img.decodeBmp(file.toBytes());
    if (decoded == null) return;
    final rgba = decoded.convert(numChannels: 4);
    ops.add(EmfImageOp(rgba.getBytes(order: img.ChannelOrder.rgba), rgba.width, rgba.height, dest));
  }

  static List<int> _le32(int v) => <int>[v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255];

  /// a × b untuk matriks XFORM (titik baris): x' = x·a lalu ·b.
  static Float64List _multiply(List<double> a, List<double> b) => Float64List.fromList(<double>[
    a[0] * b[0] + a[1] * b[2],
    a[0] * b[1] + a[1] * b[3],
    a[2] * b[0] + a[3] * b[2],
    a[2] * b[1] + a[3] * b[3],
    a[4] * b[0] + a[5] * b[2] + b[4],
    a[4] * b[1] + a[5] * b[3] + b[5],
  ]);
}

/// Widget gambar EMF yang memenuhi ruangnya.
class EmfImage extends StatefulWidget {
  const EmfImage(this.picture, {super.key});

  final EmfPicture picture;

  @override
  State<EmfImage> createState() => _EmfImageState();
}

class _EmfImageState extends State<EmfImage> {
  @override
  void initState() {
    super.initState();
    if (widget.picture.ops.any((op) => op is EmfImageOp && op.image == null)) {
      prepareEmfImages(widget.picture).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _EmfPainter(widget.picture), child: const SizedBox.expand());
}

class _EmfPainter extends CustomPainter {
  _EmfPainter(this.picture);

  final EmfPicture picture;

  @override
  void paint(Canvas canvas, Size size) => picture.paint(canvas, size);

  @override
  bool shouldRepaint(_EmfPainter old) => old.picture != picture;
}
