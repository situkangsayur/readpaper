import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/markdown/domain/mermaid_graph.dart';

void main() {
  /// Pengukur yang bisa diduga: tiap huruf tujuh titik.
  double measure(String line) => line.length * 7.0;

  group('membaca sumber', () {
    test('graph TD dengan label dan bentuk', () {
      final graph = MermaidGraph.parse('''
graph TD
  A[Mulai] --> B{Sudah?}
  B -->|ya| C(Selesai)
  B -->|belum| A
''');
      expect(graph.isDrawable, isTrue);
      expect(graph.direction, MermaidDirection.topDown);
      expect(graph.nodes.map((n) => n.id).toSet(), <String>{'A', 'B', 'C'});

      final a = graph.nodes.firstWhere((n) => n.id == 'A');
      final b = graph.nodes.firstWhere((n) => n.id == 'B');
      final c = graph.nodes.firstWhere((n) => n.id == 'C');
      expect(a.label, 'Mulai');
      expect(a.shape, MermaidShape.box);
      expect(b.shape, MermaidShape.diamond);
      expect(c.shape, MermaidShape.rounded);

      expect(graph.edges, hasLength(3));
      expect(graph.edges[1].label, 'ya');
      expect(graph.edges.last.to, 'A', reason: 'panah balik tetap terbaca');
    });

    test('label yang sudah disebut tidak tertimpa rujukan berikutnya', () {
      final graph = MermaidGraph.parse('graph LR\nA[Mulai] --> B\nB --> A\n');
      expect(graph.nodes.firstWhere((n) => n.id == 'A').label, 'Mulai');
    });

    test('arah dibaca dari kepalanya', () {
      expect(MermaidGraph.parse('graph LR\nA-->B').direction, MermaidDirection.leftRight);
      expect(MermaidGraph.parse('flowchart BT\nA-->B').direction, MermaidDirection.bottomUp);
      expect(MermaidGraph.parse('graph RL\nA-->B').direction, MermaidDirection.rightLeft);
      expect(MermaidGraph.parse('graph TB\nA-->B').direction, MermaidDirection.topDown);
    });

    test('gaya garis: putus-putus, tebal, dan tanpa panah', () {
      final graph = MermaidGraph.parse('''
graph TD
  A -.-> B
  B ==> C
  C --- D
''');
      expect(graph.edges[0].line, MermaidLine.dotted);
      expect(graph.edges[1].line, MermaidLine.thick);
      expect(graph.edges[2].arrow, isFalse);
    });

    test('bentuk bulat dan stadion', () {
      final graph = MermaidGraph.parse('graph TD\nA((Bulat)) --> B([Stadion])\n');
      expect(graph.nodes.first.shape, MermaidShape.circle);
      expect(graph.nodes.last.shape, MermaidShape.stadium);
    });

    test('komentar dan baris pengaturan dilewati', () {
      final graph = MermaidGraph.parse('''
graph TD
  %% ini komentar
  classDef merah fill:#f00
  style A fill:#eee
  A --> B
''');
      expect(graph.nodes, hasLength(2));
      expect(graph.edges, hasLength(1));
    });

    test('kutip di label dan <br/> jadi baris baru', () {
      final graph = MermaidGraph.parse('graph TD\nA["Dua<br/>baris"] --> B\n');
      expect(graph.nodes.first.label, 'Dua\nbaris');
    });

    test('jenis diagram lain ditolak dengan sebab, bukan digambar salah', () {
      // Diagram yang salah gambar lebih menyesatkan daripada kode yang
      // terbaca jujur.
      final graph = MermaidGraph.parse('sequenceDiagram\n  A->>B: hai\n');
      expect(graph.isDrawable, isFalse);
      expect(graph.problem, contains('sequenceDiagram'));
      expect(graph.problem, contains('graph'));
    });

    test('kosong ditolak', () {
      expect(MermaidGraph.parse('   \n').isDrawable, isFalse);
    });
  });

  group('tata letak', () {
    MermaidLayout layout(String source) =>
        MermaidLayout.of(MermaidGraph.parse(source), measure: measure);

    test('simpul tanpa masukan ada di tingkat pertama', () {
      final l = layout('graph TD\nA-->B\nB-->C\n');
      final a = l.nodes.firstWhere((n) => n.node.id == 'A');
      final b = l.nodes.firstWhere((n) => n.node.id == 'B');
      final c = l.nodes.firstWhere((n) => n.node.id == 'C');
      expect(a.top, lessThan(b.top));
      expect(b.top, lessThan(c.top));
      expect(a.left, closeTo(b.left, 20), reason: 'satu jalur lurus, ditengahkan');
    });

    test('cabang berjajar di tingkat yang sama', () {
      final l = layout('graph TD\nA-->B\nA-->C\n');
      final b = l.nodes.firstWhere((n) => n.node.id == 'B');
      final c = l.nodes.firstWhere((n) => n.node.id == 'C');
      expect(b.top, c.top);
      expect(b.left, isNot(c.left));
    });

    test('LR menyusun ke samping, bukan ke bawah', () {
      final l = layout('graph LR\nA-->B\n');
      final a = l.nodes.firstWhere((n) => n.node.id == 'A');
      final b = l.nodes.firstWhere((n) => n.node.id == 'B');
      expect(a.left, lessThan(b.left));
      expect(a.top, b.top);
      expect(l.width, greaterThan(l.height));
    });

    test('BT membalik urutannya', () {
      final l = layout('graph BT\nA-->B\n');
      final a = l.nodes.firstWhere((n) => n.node.id == 'A');
      final b = l.nodes.firstWhere((n) => n.node.id == 'B');
      expect(a.top, greaterThan(b.top), reason: 'yang pertama ada di bawah');
    });

    test('label panjang melebarkan kotaknya', () {
      final pendek = layout('graph TD\nA[ok]-->B\n').nodes.first.width;
      final panjang = layout('graph TD\nA[label yang jauh lebih panjang]-->B\n').nodes.first.width;
      expect(panjang, greaterThan(pendek));
    });

    test('garis berhenti di tepi kotak, bukan di tengahnya', () {
      final l = layout('graph TD\nA-->B\n');
      final a = l.nodes.firstWhere((n) => n.node.id == 'A');
      final b = l.nodes.firstWhere((n) => n.node.id == 'B');
      final edge = l.edges.single;
      expect(edge.fromY, closeTo(a.bottom, 0.01));
      expect(edge.toY, closeTo(b.top, 0.01));
      expect(edge.fromX, closeTo(a.centerX, 0.01));
    });

    test('ukuran keseluruhan memuat seluruh simpul', () {
      final l = layout('graph TD\nA-->B\nA-->C\nB-->D\nC-->D\n');
      for (final node in l.nodes) {
        expect(node.left, greaterThanOrEqualTo(0));
        expect(node.top, greaterThanOrEqualTo(0));
        expect(node.right, lessThanOrEqualTo(l.width + 0.01));
        expect(node.bottom, lessThanOrEqualTo(l.height + 0.01));
      }
    });

    test('lingkaran penuh tetap tergambar, tidak menggantung', () {
      // A→B→A tidak punya simpul awal. Yang tidak boleh terjadi: perulangan
      // tanpa akhir atau diagram kosong.
      final l = layout('graph TD\nA-->B\nB-->A\n');
      expect(l.nodes, hasLength(2));
      expect(l.width, greaterThan(0));
    });

    test('simpul yang lebih dalam turun ke tingkat terjauh', () {
      // D dijangkau lewat dua jalur dengan panjang berbeda; ia harus duduk di
      // bawah keduanya supaya tidak ada panah yang naik.
      final l = layout('graph TD\nA-->B\nB-->C\nC-->D\nA-->D\n');
      final c = l.nodes.firstWhere((n) => n.node.id == 'C');
      final d = l.nodes.firstWhere((n) => n.node.id == 'D');
      expect(d.top, greaterThan(c.top));
    });
  });
}
