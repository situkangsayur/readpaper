import 'dart:math' as math;
import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../core/utils/shape_geometry.dart';

/// Ukuran kertas yang ditawarkan, dalam titik PDF.
///
/// Seri A, sama dengan kertas yang keluar dari pencetak: A5 untuk catatan
/// saku, A4 untuk catatan biasa, dan A3 ke atas untuk bagan yang butuh ruang —
/// yang terakhir memang tidak akan dicetak di pencetak rumah, tetapi tetap
/// masuk akal sebagai kanvas dan tetap tercetak benar di tempat cetak.
enum NotePaper {
  a5('A5', 419.528, 595.276),
  a4('A4', 595.276, 841.89),
  a3('A3', 841.89, 1190.551),
  a2('A2', 1190.551, 1683.78),
  a1('A1', 1683.78, 2383.937);

  const NotePaper(this.label, this.shortSide, this.longSide);

  final String label;
  final double shortSide;
  final double longSide;

  Size sizeFor(NoteOrientation orientation) => orientation == NoteOrientation.tegak
      ? Size(shortSide, longSide)
      : Size(longSide, shortSide);

  static NotePaper parse(String name) =>
      values.firstWhere((v) => v.name == name, orElse: () => NotePaper.a4);

  /// Kertas seri A yang paling dekat dengan [size], beserta arahnya.
  ///
  /// Dipakai saat sebuah PDF dijadikan buku catatan: halaman A4 mendatar harus
  /// mendarat di kertas A4 mendatar, bukan dipaksa tegak lalu menyisakan dua
  /// pita kosong di atas dan di bawah.
  static ({NotePaper paper, NoteOrientation orientation}) closestTo(Size size) {
    final orientation =
        size.width > size.height ? NoteOrientation.mendatar : NoteOrientation.tegak;
    final short = math.min(size.width, size.height);
    final long = math.max(size.width, size.height);
    var best = NotePaper.a4;
    var bestGap = double.infinity;
    for (final paper in values) {
      final gap = (paper.shortSide - short).abs() + (paper.longSide - long).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = paper;
      }
    }
    return (paper: best, orientation: orientation);
  }
}

/// Arah kertas lembar catatan.
enum NoteOrientation {
  tegak('Tegak'),
  mendatar('Mendatar');

  const NoteOrientation(this.label);

  final String label;

  NoteOrientation get lain => this == tegak ? mendatar : tegak;

  static NoteOrientation parse(String name) =>
      values.firstWhere((v) => v.name == name, orElse: () => NoteOrientation.tegak);
}

/// Ukuran lembar bawaan — A4 tegak, dalam titik PDF.
class NoteSheet {
  const NoteSheet._();

  static const double width = 595.276;
  static const double height = 841.89;
}

/// Satu goresan tinta, dalam koordinat lokal komponennya.
@immutable
class NoteStroke {
  const NoteStroke({required this.points, required this.width});

  factory NoteStroke.fromJson(Map<String, dynamic> json) => NoteStroke(
    points: <Offset>[
      for (final pair in (json['points'] as List? ?? const <dynamic>[]))
        if (pair is List && pair.length >= 2)
          Offset((pair[0] as num).toDouble(), (pair[1] as num).toDouble()),
    ],
    width: (json['width'] as num?)?.toDouble() ?? 2,
  );

  final List<Offset> points;
  final double width;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'points': <dynamic>[
      for (final point in points) <double>[_round(point.dx), _round(point.dy)],
    ],
    'width': _round(width),
  };

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var left = points.first.dx, right = left, top = points.first.dy, bottom = top;
    for (final point in points) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom).inflate(width / 2);
  }

  /// Jarak terpendek dari [point] ke goresan ini.
  ///
  /// Dihitung ke ruas garisnya, bukan ke titik-titiknya: goresan cepat hanya
  /// menyimpan sedikit titik yang berjauhan, dan penghapus yang mengukur ke
  /// titik akan meleset di tengah-tengah garis.
  double distanceTo(Offset point) {
    if (points.isEmpty) return double.infinity;
    if (points.length == 1) return (points.first - point).distance;
    var best = double.infinity;
    for (var i = 1; i < points.length; i++) {
      best = math.min(best, _toSegment(point, points[i - 1], points[i]));
    }
    return best;
  }

  static double _toSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }

  /// Memotong goresan ini di tempat yang disentuh penghapus sebagian.
  ///
  /// Hasilnya bisa nol, satu, atau dua potongan — menghapus di tengah sebuah
  /// garis memang membelahnya jadi dua, dan itu yang dilakukan penghapus
  /// sungguhan.
  List<NoteStroke> erase(Offset at, double radius) {
    // Goresan cepat hanya menyimpan titik berjauhan, dan penghapus sering
    // mendarat **di antara** dua titik: kalau yang diperiksa hanya titiknya,
    // goresannya lolos utuh padahal penghapusnya jelas melewatinya. Jadi ruas
    // yang tersentuh dirapatkan dulu — hanya yang tersentuh, supaya sisa
    // goresannya tetap sehemat semula.
    final dense = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      dense.add(points[i]);
      if (i + 1 >= points.length) continue;
      final a = points[i];
      final b = points[i + 1];
      if (_toSegment(at, a, b) > radius) continue;
      final steps = ((b - a).distance / math.max(radius / 2, 1)).ceil();
      for (var s = 1; s < steps; s++) {
        dense.add(Offset.lerp(a, b, s / steps)!);
      }
    }

    final kept = <List<Offset>>[];
    var current = <Offset>[];
    for (final point in dense) {
      if ((point - at).distance <= radius) {
        if (current.length > 1) kept.add(current);
        current = <Offset>[];
        continue;
      }
      current.add(point);
    }
    if (current.length > 1) kept.add(current);
    return <NoteStroke>[for (final piece in kept) NoteStroke(points: piece, width: width)];
  }

  static double _round(double value) => (value * 100).roundToDouble() / 100;
}

/// Jenis komponen, dipakai saat membaca berkas.
enum NoteComponentKind { ink, text, image, diagram, shape, connector }

/// Satu benda di atas lembar: tinta, teks, gambar, atau diagram.
///
/// Sudut, skala, dan kepekatan adalah **sifat komponen**, bukan sesuatu yang
/// ditulis balik ke titik-titiknya. Memutar dua kali dengan menulis ulang titik
/// akan kehilangan ketelitian sedikit demi sedikit sampai tulisannya berubah
/// bentuk; menyimpannya sebagai sifat membuat memutar bolak-balik selalu
/// kembali persis ke asalnya.
@immutable
sealed class NoteComponent {
  const NoteComponent({
    required this.id,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.opacity = 1,
    this.color = 0xFF000000,
  });

  final String id;

  /// Sudut kiri atas komponen pada lembar.
  final Offset position;

  /// Ukurannya pada lembar, sebelum diputar.
  final Size size;

  /// Sudut putar dalam radian, berporos di titik tengahnya.
  final double rotation;

  final double opacity;

  /// Warna utamanya sebagai ARGB.
  final int color;

  NoteComponentKind get kind;

  Rect get bounds => position & size;

  NoteComponent copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    double? opacity,
    int? color,
  });

  Map<String, dynamic> toJson();

  Map<String, dynamic> get _base => <String, dynamic>{
    'id': id,
    'x': _r(position.dx),
    'y': _r(position.dy),
    'w': _r(size.width),
    'h': _r(size.height),
    'rotation': _r(rotation),
    'opacity': _r(opacity),
    'color': color,
    'kind': kind.name,
  };

  static double _r(double value) => (value * 1000).roundToDouble() / 1000;

  static NoteComponent fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final position = Offset(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
    );
    final size = Size(
      (json['w'] as num?)?.toDouble() ?? 1,
      (json['h'] as num?)?.toDouble() ?? 1,
    );
    final rotation = (json['rotation'] as num?)?.toDouble() ?? 0;
    final opacity = (json['opacity'] as num?)?.toDouble() ?? 1;
    final color = (json['color'] as num?)?.toInt() ?? 0xFF000000;

    return switch (json['kind'] as String? ?? 'ink') {
      'text' => NoteText(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        opacity: opacity,
        color: color,
        text: json['text'] as String? ?? '',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      ),
      'image' => NoteImage(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        opacity: opacity,
        color: color,
        file: json['file'] as String? ?? '',
        alt: json['alt'] as String? ?? '',
      ),
      'diagram' => NoteDiagram(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        opacity: opacity,
        color: color,
        source: json['source'] as String? ?? '',
      ),
      'shape' => NoteShape(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        opacity: opacity,
        color: color,
        shape: ShapeKind.parse(json['shape'] as String? ?? 'kotak'),
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2,
      ),
      'connector' => NoteConnector(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        opacity: opacity,
        color: color,
        fromId: json['fromId'] as String? ?? '',
        toId: json['toId'] as String? ?? '',
        arrow: json['arrow'] as bool? ?? true,
      ),
      _ => NoteInk(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        opacity: opacity,
        color: color,
        strokes: <NoteStroke>[
          for (final stroke in (json['strokes'] as List? ?? const <dynamic>[]))
            if (stroke is Map) NoteStroke.fromJson(stroke.cast<String, dynamic>()),
        ],
      ),
    };
  }
}

/// Tulisan tangan yang belum — atau tidak akan — dikenali.
///
/// Yang tidak dikenali tetap tinta, tidak dibuang: konversi yang
/// menghilangkan coretan adalah konversi yang merusak.
@immutable
class NoteInk extends NoteComponent {
  const NoteInk({
    required super.id,
    required super.position,
    required super.size,
    required this.strokes,
    super.rotation,
    super.opacity,
    super.color,
  });

  final List<NoteStroke> strokes;

  @override
  NoteComponentKind get kind => NoteComponentKind.ink;

  @override
  NoteInk copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    double? opacity,
    int? color,
    List<NoteStroke>? strokes,
  }) => NoteInk(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    color: color ?? this.color,
    strokes: strokes ?? this.strokes,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._base,
    'strokes': <dynamic>[for (final stroke in strokes) stroke.toJson()],
  };
}

/// Bangun dua dimensi: kotak, bulat, belah ketupat, segitiga, garis, panah.
@immutable
class NoteShape extends NoteComponent {
  const NoteShape({
    required super.id,
    required super.position,
    required super.size,
    required this.shape,
    this.strokeWidth = 2,
    super.rotation,
    super.opacity,
    super.color,
  });

  final ShapeKind shape;
  final double strokeWidth;

  @override
  NoteComponentKind get kind => NoteComponentKind.shape;

  /// Garis-garisnya dalam koordinat lokal, dihitung dari ukuran sekarang.
  ///
  /// Tidak disimpan: bangun yang diubah ukurannya harus tetap rapi, dan itu
  /// hanya mungkin kalau bentuknya dihitung ulang dari ukurannya — bukan
  /// titik-titik lama yang ditarik melar.
  List<List<Offset>> get outline => ShapeGeometry.outline(shape, size);

  @override
  NoteShape copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    double? opacity,
    int? color,
    ShapeKind? shape,
    double? strokeWidth,
  }) => NoteShape(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    color: color ?? this.color,
    shape: shape ?? this.shape,
    strokeWidth: strokeWidth ?? this.strokeWidth,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._base,
    'shape': shape.name,
    'strokeWidth': NoteComponent._r(strokeWidth),
  };
}

/// Garis yang **menghubungkan dua komponen**.
///
/// Yang disimpan adalah kedua ujungnya sebagai rujukan, bukan koordinat:
/// menyimpan koordinat berarti garisnya tertinggal di tempat lama begitu
/// bendanya digeser, dan penghubung yang tidak mengikuti bukan penghubung.
@immutable
class NoteConnector extends NoteComponent {
  const NoteConnector({
    required super.id,
    required this.fromId,
    required this.toId,
    this.arrow = true,
    this.strokeWidth = 1.8,
    super.position = Offset.zero,
    super.size = const Size(1, 1),
    super.rotation,
    super.opacity,
    super.color,
  });

  final String fromId;
  final String toId;

  /// Bermata panah di ujung tujuannya.
  final bool arrow;

  final double strokeWidth;

  @override
  NoteComponentKind get kind => NoteComponentKind.connector;

  @override
  NoteConnector copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    double? opacity,
    int? color,
    String? fromId,
    String? toId,
    bool? arrow,
    double? strokeWidth,
  }) => NoteConnector(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    color: color ?? this.color,
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    arrow: arrow ?? this.arrow,
    strokeWidth: strokeWidth ?? this.strokeWidth,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._base,
    'fromId': fromId,
    'toId': toId,
    'arrow': arrow,
    'strokeWidth': NoteComponent._r(strokeWidth),
  };
}

@immutable
class NoteText extends NoteComponent {
  const NoteText({
    required super.id,
    required super.position,
    required super.size,
    required this.text,
    this.fontSize = 16,
    super.rotation,
    super.opacity,
    super.color,
  });

  final String text;
  final double fontSize;

  @override
  NoteComponentKind get kind => NoteComponentKind.text;

  @override
  NoteText copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    double? opacity,
    int? color,
    String? text,
    double? fontSize,
  }) => NoteText(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    color: color ?? this.color,
    text: text ?? this.text,
    fontSize: fontSize ?? this.fontSize,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._base,
    'text': text,
    'fontSize': NoteComponent._r(fontSize),
  };
}

@immutable
class NoteImage extends NoteComponent {
  const NoteImage({
    required super.id,
    required super.position,
    required super.size,
    required this.file,
    this.alt = '',
    super.rotation,
    super.opacity,
    super.color,
  });

  /// Jalur berkasnya relatif terhadap folder dokumen — supaya catatan yang
  /// dipindahkan atau disinkronkan tetap menemukan gambarnya.
  final String file;

  final String alt;

  @override
  NoteComponentKind get kind => NoteComponentKind.image;

  @override
  NoteImage copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    double? opacity,
    int? color,
    String? file,
    String? alt,
  }) => NoteImage(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    color: color ?? this.color,
    file: file ?? this.file,
    alt: alt ?? this.alt,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{..._base, 'file': file, 'alt': alt};
}

/// Diagram sebagai objek, bukan gambar mati: sumbernya Mermaid, jadi masih
/// bisa disunting dan digambar ulang kapan saja.
@immutable
class NoteDiagram extends NoteComponent {
  const NoteDiagram({
    required super.id,
    required super.position,
    required super.size,
    required this.source,
    super.rotation,
    super.opacity,
    super.color,
  });

  final String source;

  @override
  NoteComponentKind get kind => NoteComponentKind.diagram;

  @override
  NoteDiagram copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    double? opacity,
    int? color,
    String? source,
  }) => NoteDiagram(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    color: color ?? this.color,
    source: source ?? this.source,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{..._base, 'source': source};
}

/// Satu lembar catatan.
@immutable
class NotePage {
  const NotePage({
    this.components = const <NoteComponent>[],
    this.background = 0xFFFFFFFF,
    this.rule = NotePageRule.polos,
    this.paper = NotePaper.a4,
    this.orientation = NoteOrientation.tegak,
  });

  factory NotePage.fromJson(Map<String, dynamic> json) => NotePage(
    background: (json['background'] as num?)?.toInt() ?? 0xFFFFFFFF,
    rule: NotePageRule.values.firstWhere(
      (r) => r.name == (json['rule'] as String? ?? 'polos'),
      orElse: () => NotePageRule.polos,
    ),
    paper: NotePaper.parse(json['paper'] as String? ?? 'a4'),
    orientation: NoteOrientation.parse(json['orientation'] as String? ?? 'tegak'),
    components: _pruned(<NoteComponent>[
      for (final entry in (json['components'] as List? ?? const <dynamic>[]))
        if (entry is Map) NoteComponent.fromJson(entry.cast<String, dynamic>()),
    ]),
  );

  /// Membuang penghubung yang salah satu ujungnya tidak ada di berkasnya.
  ///
  /// Bisa terjadi setelah dua orang menyunting catatan yang sama lalu
  /// hasilnya digabung: benda yang dirujuk hilang, garisnya tertinggal.
  static List<NoteComponent> _pruned(List<NoteComponent> components) {
    final ids = <String>{for (final component in components) component.id};
    return <NoteComponent>[
      for (final component in components)
        if (component is! NoteConnector ||
            (ids.contains(component.fromId) && ids.contains(component.toId)))
          component,
    ];
  }

  /// Urutannya juga urutan gambarnya: yang belakangan ada di atas.
  final List<NoteComponent> components;

  final int background;
  final NotePageRule rule;

  /// Ukuran dan arah kertas lembar **ini**, bukan seluruh buku: satu buku boleh
  /// mencampur, karena satu catatan bisa berisi halaman tulisan A5 dan satu
  /// bagan A3 yang butuh ruang.
  final NotePaper paper;
  final NoteOrientation orientation;

  Size get size => paper.sizeFor(orientation);

  NotePage copyWith({
    List<NoteComponent>? components,
    int? background,
    NotePageRule? rule,
    NotePaper? paper,
    NoteOrientation? orientation,
  }) => NotePage(
    components: components ?? this.components,
    background: background ?? this.background,
    rule: rule ?? this.rule,
    paper: paper ?? this.paper,
    orientation: orientation ?? this.orientation,
  );

  /// Memutar kertas seperempat putaran, **beserta isinya**.
  ///
  /// Memutar kertas tanpa memutar isinya berarti benda yang tadinya di dalam
  /// kertas mendadak keluar dari tepi. Yang dikerjakan di sini hanya memindah
  /// dan menambah sudut komponennya — titik tintanya sendiri tidak pernah
  /// ditulis ulang, jadi memutar empat kali kembali persis.
  NotePage turned() {
    final from = size;
    return copyWith(
      orientation: orientation.lain,
      components: <NoteComponent>[
        for (final component in components)
          component.copyWith(
            // Searah jarum jam: sudut kiri atas pindah ke kanan atas.
            position: Offset(
              from.height - component.position.dy - component.size.height,
              component.position.dx,
            ),
            size: Size(component.size.height, component.size.width),
            rotation: component.rotation + math.pi / 2,
          ),
      ],
    );
  }

  /// Komponen yang keluar dari kertas sekarang.
  ///
  /// Dipakai untuk memberi tahu saat kertas diperkecil: memindahkan bendanya
  /// sendiri akan mengacaukan tata letak yang sudah diatur, jadi yang
  /// dilakukan memberitahu, bukan merapikan diam-diam.
  int get outsidePaper {
    final sheet = Rect.fromLTWH(0, 0, size.width, size.height);
    return components
        .where((component) => !sheet.inflate(1).contains(component.bounds.bottomRight))
        .length;
  }

  NoteComponent? byId(String id) {
    for (final component in components) {
      if (component.id == id) return component;
    }
    return null;
  }

  /// Kedua ujung sebuah penghubung, dihitung dari kotak benda yang
  /// dihubungkannya. Null kalau salah satu ujungnya sudah tidak ada.
  (Offset, Offset)? endsOf(NoteConnector connector) {
    final from = byId(connector.fromId);
    final to = byId(connector.toId);
    if (from == null || to == null) return null;
    return ShapeGeometry.between(from.bounds, to.bounds);
  }

  /// Tanpa komponen [id], **beserta penghubung yang menempel padanya**.
  ///
  /// Penghubung yang salah satu ujungnya hilang bukan penghubung lagi; yang
  /// tertinggal hanya garis menggantung yang tidak bisa dijelaskan.
  NotePage without(String id) => copyWith(
    components: <NoteComponent>[
      for (final component in components)
        if (component.id != id &&
            !(component is NoteConnector &&
                (component.fromId == id || component.toId == id)))
          component,
    ],
  );

  /// Komponen paling atas yang kena di [point].
  NoteComponent? hitTest(Offset point) {
    for (final component in components.reversed) {
      // Penghubung diuji ke garisnya, bukan ke kotaknya: kotaknya semu dan
      // selalu 1×1, jadi tidak pernah kena.
      if (component is NoteConnector) {
        final ends = endsOf(component);
        if (ends != null && _nearSegment(point, ends.$1, ends.$2) <= 8) return component;
        continue;
      }
      if (_inside(component, point)) return component;
    }
    return null;
  }

  static double _nearSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }

  /// Uji kena yang ikut memperhitungkan sudut putar komponennya: titiknya
  /// diputar balik ke ruang komponen, lalu diuji ke kotaknya yang lurus.
  static bool _inside(NoteComponent component, Offset point) {
    final centre = component.bounds.center;
    final local = component.rotation == 0
        ? point
        : _rotate(point - centre, -component.rotation) + centre;
    return component.bounds.inflate(4).contains(local);
  }

  static Offset _rotate(Offset offset, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(offset.dx * cos - offset.dy * sin, offset.dx * sin + offset.dy * cos);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'background': background,
    'orientation': orientation.name,
    'paper': paper.name,
    'rule': rule.name,
    'components': <dynamic>[for (final component in components) component.toJson()],
  };
}

/// Garis bantu di lembarnya, seperti buku tulis.
enum NotePageRule { polos, bergaris, kotak }

/// Sebuah buku catatan: berlembar-lembar, isinya komponen.
@immutable
class NoteDocument {
  const NoteDocument({required this.pages, this.title = ''});

  factory NoteDocument.fromJson(Map<String, dynamic> json) => NoteDocument(
    title: json['title'] as String? ?? '',
    pages: <NotePage>[
      for (final entry in (json['pages'] as List? ?? const <dynamic>[]))
        if (entry is Map) NotePage.fromJson(entry.cast<String, dynamic>()),
    ],
  );

  static NoteDocument blank({String title = ''}) =>
      NoteDocument(title: title, pages: const <NotePage>[NotePage()]);

  final List<NotePage> pages;
  final String title;

  /// Nomor versi berkasnya, supaya pembaca yang lebih tua bisa menolak dengan
  /// jelas alih-alih salah membaca.
  static const int formatVersion = 1;

  NoteDocument copyWith({List<NotePage>? pages, String? title}) =>
      NoteDocument(pages: pages ?? this.pages, title: title ?? this.title);

  NoteDocument replacePage(int index, NotePage page) => copyWith(
    pages: <NotePage>[
      for (var i = 0; i < pages.length; i++)
        if (i == index) page else pages[i],
    ],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': formatVersion,
    'title': title,
    'pages': <dynamic>[for (final page in pages) page.toJson()],
  };
}
