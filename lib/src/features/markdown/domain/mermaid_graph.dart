import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Arah aliran diagram.
enum MermaidDirection {
  topDown,
  bottomUp,
  leftRight,
  rightLeft;

  bool get isVertical => this == topDown || this == bottomUp;

  static MermaidDirection parse(String raw) => switch (raw.toUpperCase()) {
    'TD' || 'TB' => MermaidDirection.topDown,
    'BT' => MermaidDirection.bottomUp,
    'RL' => MermaidDirection.rightLeft,
    _ => MermaidDirection.leftRight,
  };
}

/// Bentuk sebuah simpul, dari tanda pengapitnya di sumber.
enum MermaidShape {
  /// `A[Teks]`
  box,

  /// `A(Teks)`
  rounded,

  /// `A([Teks])`
  stadium,

  /// `A{Teks}`
  diamond,

  /// `A((Teks))`
  circle;

  static MermaidShape of(String open) => switch (open) {
    '[' => MermaidShape.box,
    '([' => MermaidShape.stadium,
    '((' => MermaidShape.circle,
    '(' => MermaidShape.rounded,
    '{' => MermaidShape.diamond,
    _ => MermaidShape.box,
  };
}

/// Gaya garis panah.
enum MermaidLine { solid, dotted, thick }

@immutable
class MermaidNode {
  const MermaidNode({required this.id, required this.label, this.shape = MermaidShape.box});

  final String id;
  final String label;
  final MermaidShape shape;
}

@immutable
class MermaidEdge {
  const MermaidEdge({
    required this.from,
    required this.to,
    this.label = '',
    this.line = MermaidLine.solid,
    this.arrow = true,
  });

  final String from;
  final String to;
  final String label;
  final MermaidLine line;

  /// `---` menghubungkan tanpa mata panah.
  final bool arrow;
}

/// Diagram alir Mermaid yang sudah dibaca.
///
/// Hanya `graph`/`flowchart` yang dikenali, dan itu disengaja: itulah bentuk
/// yang dipakai di catatan — kotak, panah, dan belah ketupat untuk syarat.
/// Sisanya (sequence, gantt, class) dibiarkan tampil sebagai teks apa adanya,
/// karena diagram yang salah gambar lebih menyesatkan daripada kode yang
/// terbaca jujur.
@immutable
class MermaidGraph {
  const MermaidGraph({
    required this.direction,
    required this.nodes,
    required this.edges,
    this.problem,
  });

  final MermaidDirection direction;
  final List<MermaidNode> nodes;
  final List<MermaidEdge> edges;

  /// Kenapa sumbernya tidak bisa digambar, kalau memang tidak bisa.
  final String? problem;

  bool get isDrawable => problem == null && nodes.isNotEmpty;

  static MermaidGraph unsupported(String why) => MermaidGraph(
    direction: MermaidDirection.topDown,
    nodes: const <MermaidNode>[],
    edges: const <MermaidEdge>[],
    problem: why,
  );

  /// Membaca sumber sebuah blok ```mermaid.
  static MermaidGraph parse(String source) {
    final lines = <String>[
      for (final raw in source.split('\n'))
        if (raw.trim().isNotEmpty && !raw.trim().startsWith('%%')) raw.trim(),
    ];
    if (lines.isEmpty) return unsupported('Diagram kosong.');

    final header = RegExp(
      r'^(graph|flowchart)\s+([A-Za-z]{2})?',
      caseSensitive: false,
    ).firstMatch(lines.first);
    if (header == null) {
      final kind = lines.first.split(RegExp(r'\s')).first;
      return unsupported(
        'Jenis diagram "$kind" belum digambar — yang sudah: graph dan flowchart. '
        'Sumbernya tetap ditampilkan apa adanya.',
      );
    }

    final direction = MermaidDirection.parse(header.group(2) ?? 'TD');
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];

    void remember(String id, String? open, String? label) {
      final trimmedId = id.trim();
      if (trimmedId.isEmpty) return;
      final existing = nodes[trimmedId];
      // Label yang disebut belakangan tidak menimpa label yang sudah ada:
      // di Mermaid, simpul biasanya diberi nama sekali lalu dirujuk saja.
      if (existing != null && (label == null || label.isEmpty)) return;
      nodes[trimmedId] = MermaidNode(
        id: trimmedId,
        label: _clean(label ?? existing?.label ?? trimmedId),
        shape: open == null ? (existing?.shape ?? MermaidShape.box) : MermaidShape.of(open),
      );
    }

    // Satu simpul: id, lalu label berkurung kalau ada.
    const node = r'([A-Za-z0-9_.-]+)\s*(\(\(|\(\[|\[|\(|\{)?([^\]\)\}]*)?(?:\]\)|\)\)|\]|\)|\})?';
    // Panah: solid, tebal, atau putus-putus, dengan label opsional.
    const arrow = r'(-{2,}>|-{3,}|={2,}>|={3,}|-\.-+>|-\.-+)';
    final edgeExp = RegExp('^$node\\s*$arrow\\s*(?:\\|([^|]*)\\|)?\\s*$node');
    final loneExp = RegExp('^$node\\s*;?\$');

    for (final line in lines.skip(1)) {
      final body = line.replaceAll(RegExp(r';$'), '').trim();
      if (body.isEmpty) continue;
      // Baris pengaturan yang tidak menggambar apa pun dilewati diam-diam.
      if (RegExp(
        r'^(subgraph|end|style|classDef|class|linkStyle|click|direction)\b',
      ).hasMatch(body)) {
        continue;
      }

      final edge = edgeExp.firstMatch(body);
      if (edge != null) {
        // Nomor grupnya: 1 id, 2 kurung, 3 label, 4 panah, 5 label panah,
        // lalu 6/7/8 untuk simpul di ujung kanan.
        remember(edge.group(1)!, edge.group(2), edge.group(3));
        remember(edge.group(6)!, edge.group(7), edge.group(8));
        final marker = edge.group(4)!;
        edges.add(
          MermaidEdge(
            from: edge.group(1)!.trim(),
            to: edge.group(6)!.trim(),
            label: _clean(edge.group(5) ?? ''),
            line: marker.contains('.')
                ? MermaidLine.dotted
                : (marker.startsWith('=') ? MermaidLine.thick : MermaidLine.solid),
            arrow: marker.endsWith('>'),
          ),
        );
        continue;
      }

      final lone = loneExp.firstMatch(body);
      if (lone != null) remember(lone.group(1)!, lone.group(2), lone.group(3));
    }

    if (nodes.isEmpty) {
      return unsupported('Tidak ada simpul yang bisa dibaca dari diagram ini.');
    }
    return MermaidGraph(
      direction: direction,
      nodes: nodes.values.toList(growable: false),
      edges: edges,
      problem: null,
    );
  }

  static String _clean(String label) {
    var text = label.trim();
    if (text.length >= 2 &&
        ((text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith("'") && text.endsWith("'")))) {
      text = text.substring(1, text.length - 1);
    }
    return text.replaceAll('<br/>', '\n').replaceAll('<br>', '\n').trim();
  }
}

/// Satu simpul yang sudah punya tempat dan ukuran.
@immutable
class MermaidPlacedNode {
  const MermaidPlacedNode({
    required this.node,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.lines,
  });

  final MermaidNode node;
  final double left;
  final double top;
  final double width;
  final double height;

  /// Label yang sudah dipecah per baris.
  final List<String> lines;

  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
  double get right => left + width;
  double get bottom => top + height;
}

@immutable
class MermaidPlacedEdge {
  const MermaidPlacedEdge({
    required this.edge,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
  });

  final MermaidEdge edge;
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;

  double get labelX => (fromX + toX) / 2;
  double get labelY => (fromY + toY) / 2;
}

/// Tata letak diagram: ukuran dan posisi tiap simpul dan garis.
///
/// Dihitung sekali dan dipakai dua kali — oleh pelukis di layar dan oleh
/// penulis PDF. Kalau keduanya menghitung sendiri, diagram di layar dan di
/// berkas cetakannya akan berbeda, dan yang mencetak tidak akan tahu mana yang
/// benar.
@immutable
class MermaidLayout {
  const MermaidLayout({
    required this.nodes,
    required this.edges,
    required this.width,
    required this.height,
  });

  final List<MermaidPlacedNode> nodes;
  final List<MermaidPlacedEdge> edges;
  final double width;
  final double height;

  static const double gapAcross = 28;
  static const double gapAlong = 56;
  static const double padding = 12;
  static const double minNodeWidth = 64;

  /// Menyusun [graph]. [measure] mengukur selebar apa satu baris label —
  /// pemanggilnya yang tahu fontnya, jadi ukurannya datang dari luar.
  static MermaidLayout of(
    MermaidGraph graph, {
    required double Function(String line) measure,
    double lineHeight = 18,
  }) {
    if (!graph.isDrawable) {
      return const MermaidLayout(
        nodes: <MermaidPlacedNode>[],
        edges: <MermaidPlacedEdge>[],
        width: 0,
        height: 0,
      );
    }

    final byId = <String, MermaidNode>{for (final n in graph.nodes) n.id: n};
    final ranks = _rank(graph, byId.keys.toList());

    // Ukuran tiap simpul dari labelnya.
    final labels = <String, List<String>>{};
    final sizes = <String, (double, double)>{};
    for (final node in graph.nodes) {
      final lines = node.label.isEmpty ? <String>[node.id] : node.label.split('\n');
      labels[node.id] = lines;
      final textWidth = lines.fold<double>(0, (w, line) => math.max(w, measure(line)));
      // Belah ketupat dan bulatan butuh ruang lebih: teksnya duduk di bagian
      // tersempit bentuknya.
      final padX = switch (node.shape) {
        MermaidShape.diamond => 34.0,
        MermaidShape.circle => 26.0,
        _ => 18.0,
      };
      final padY = switch (node.shape) {
        MermaidShape.diamond => 20.0,
        MermaidShape.circle => 16.0,
        _ => 10.0,
      };
      sizes[node.id] = (
        math.max(minNodeWidth, textWidth + padX * 2),
        lines.length * lineHeight + padY * 2,
      );
    }

    // Simpul dikelompokkan per tingkat, urut seperti di sumbernya.
    final levels = <int, List<String>>{};
    for (final node in graph.nodes) {
      levels.putIfAbsent(ranks[node.id] ?? 0, () => <String>[]).add(node.id);
    }
    final ordered = levels.keys.toList()..sort();

    final vertical = graph.direction.isVertical;
    final placed = <String, MermaidPlacedNode>{};

    // Panjang tiap tingkat melintang, untuk menengahkan yang lebih pendek.
    double acrossOf(String id) => vertical ? sizes[id]!.$1 : sizes[id]!.$2;
    double alongOf(String id) => vertical ? sizes[id]!.$2 : sizes[id]!.$1;

    var widest = 0.0;
    for (final level in ordered) {
      final row = levels[level]!;
      final span =
          row.fold<double>(0, (sum, id) => sum + acrossOf(id)) + gapAcross * (row.length - 1);
      widest = math.max(widest, span);
    }

    var along = padding;
    final alongOfLevel = <int, double>{};
    for (final level in ordered) {
      final row = levels[level]!;
      final span =
          row.fold<double>(0, (sum, id) => sum + acrossOf(id)) + gapAcross * (row.length - 1);
      var across = padding + (widest - span) / 2;
      var tallest = 0.0;
      for (final id in row) {
        final size = sizes[id]!;
        final node = byId[id]!;
        placed[id] = MermaidPlacedNode(
          node: node,
          left: vertical ? across : along,
          top: vertical ? along : across,
          width: size.$1,
          height: size.$2,
          lines: labels[id]!,
        );
        across += acrossOf(id) + gapAcross;
        tallest = math.max(tallest, alongOf(id));
      }
      alongOfLevel[level] = tallest;
      along += tallest + gapAlong;
    }

    // Arah terbalik (BT, RL) dicerminkan setelah semuanya ditempatkan: lebih
    // sederhana dan hasilnya sama.
    final totalAlong = along - gapAlong + padding;
    final totalAcross = widest + padding * 2;
    final flip =
        graph.direction == MermaidDirection.bottomUp ||
        graph.direction == MermaidDirection.rightLeft;

    final nodes = <MermaidPlacedNode>[
      for (final node in graph.nodes)
        if (placed[node.id] != null)
          if (!flip)
            placed[node.id]!
          else if (vertical)
            MermaidPlacedNode(
              node: node,
              left: placed[node.id]!.left,
              top: totalAlong - placed[node.id]!.bottom,
              width: placed[node.id]!.width,
              height: placed[node.id]!.height,
              lines: placed[node.id]!.lines,
            )
          else
            MermaidPlacedNode(
              node: node,
              left: totalAlong - placed[node.id]!.right,
              top: placed[node.id]!.top,
              width: placed[node.id]!.width,
              height: placed[node.id]!.height,
              lines: placed[node.id]!.lines,
            ),
    ];
    final finalById = <String, MermaidPlacedNode>{for (final n in nodes) n.node.id: n};

    final drawnEdges = <MermaidPlacedEdge>[];
    for (final edge in graph.edges) {
      final from = finalById[edge.from];
      final to = finalById[edge.to];
      if (from == null || to == null) continue;
      final ends = _connect(from, to);
      drawnEdges.add(
        MermaidPlacedEdge(edge: edge, fromX: ends.$1, fromY: ends.$2, toX: ends.$3, toY: ends.$4),
      );
    }

    return MermaidLayout(
      nodes: nodes,
      edges: drawnEdges,
      width: vertical ? totalAcross : totalAlong,
      height: vertical ? totalAlong : totalAcross,
    );
  }

  /// Tingkat tiap simpul: sepanjang mungkin dari simpul tanpa masukan, supaya
  /// panah selalu mengarah ke depan.
  static Map<String, int> _rank(MermaidGraph graph, List<String> ids) {
    final outgoing = <String, List<String>>{for (final id in ids) id: <String>[]};
    final incoming = <String, int>{for (final id in ids) id: 0};
    for (final edge in graph.edges) {
      if (!outgoing.containsKey(edge.from) || !incoming.containsKey(edge.to)) continue;
      if (edge.from == edge.to) continue;
      outgoing[edge.from]!.add(edge.to);
      incoming[edge.to] = incoming[edge.to]! + 1;
    }

    final rank = <String, int>{for (final id in ids) id: 0};
    final queue = <String>[
      for (final id in ids)
        if (incoming[id] == 0) id,
    ];
    // Lingkaran penuh tanpa simpul awal: mulai dari yang pertama disebut,
    // supaya diagram tetap tergambar walau susunannya tidak sempurna.
    if (queue.isEmpty && ids.isNotEmpty) queue.add(ids.first);

    final left = <String, int>{...incoming};
    var guard = 0;
    while (queue.isNotEmpty && guard++ < ids.length * 8) {
      final id = queue.removeAt(0);
      for (final next in outgoing[id]!) {
        rank[next] = math.max(rank[next]!, rank[id]! + 1);
        left[next] = (left[next] ?? 1) - 1;
        if (left[next]! <= 0) queue.add(next);
      }
    }
    return rank;
  }

  /// Titik keluar dan masuk sebuah garis: dari tepi kotak yang saling
  /// berhadapan, bukan dari titik tengahnya, supaya panahnya tidak menembus.
  static (double, double, double, double) _connect(MermaidPlacedNode from, MermaidPlacedNode to) {
    final dx = to.centerX - from.centerX;
    final dy = to.centerY - from.centerY;
    if (dy.abs() >= dx.abs()) {
      return dy >= 0
          ? (from.centerX, from.bottom, to.centerX, to.top)
          : (from.centerX, from.top, to.centerX, to.bottom);
    }
    return dx >= 0
        ? (from.right, from.centerY, to.left, to.centerY)
        : (from.left, from.centerY, to.right, to.centerY);
  }
}
