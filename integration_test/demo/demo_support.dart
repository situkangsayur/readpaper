import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../support.dart';

/// Perekam video demo: menjalankan aplikasi sungguhan lewat uji integrasi,
/// dengan kursor tiruan dan riak ketukan supaya penonton melihat apa yang
/// ditekan, dan keterangan singkat di atas layar. Tiap bagian direkam
/// ffmpeg dari layar X (Xvfb) menjadi satu berkas MP4.
///
///   DISPLAY=:77 flutter test integration_test/demo/demo_test.dart -d linux
///
/// Hasilnya di `build/demo/`.
class Demo {
  Demo(this.tester);

  final WidgetTester tester;

  final ValueNotifier<Offset> _cursor = ValueNotifier<Offset>(const Offset(640, 360));
  final ValueNotifier<double> _ripple = ValueNotifier<double>(0);
  final ValueNotifier<String?> _caption = ValueNotifier<String?>(null);
  OverlayEntry? _entry;
  Process? _recorder;

  /// Satu mouse untuk seluruh demo, seperti tangan sungguhan: bergerak,
  /// menekan, melepas. Mouse uji yang dibuat ulang per ketukan membuat
  /// pelacak mouse Flutter melihat perangkat yang sama "ditambahkan" dua kali.
  TestGesture? _mouse;

  Future<TestGesture> _theMouse() async {
    final existing = _mouse;
    if (existing != null) return existing;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: _cursor.value);
    return _mouse = mouse;
  }

  static String get outDir => p.join('build', 'demo');

  /// Kursor dan keterangan selalu di lapisan teratas: halaman baru yang
  /// dibuka menumpuk di atasnya, jadi lapisannya dipindah ke atas lagi
  /// sebelum setiap gerakan.
  void _raise() {
    final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: Stack(
          children: <Widget>[
            ValueListenableBuilder<String?>(
              valueListenable: _caption,
              builder: (context, text, _) => text == null
                  ? const SizedBox.shrink()
                  : Positioned(
                      left: 0,
                      right: 0,
                      bottom: 74,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xE6202A44),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            text,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            ValueListenableBuilder<Offset>(
              valueListenable: _cursor,
              builder: (context, at, _) => ValueListenableBuilder<double>(
                valueListenable: _ripple,
                builder: (context, r, _) =>
                    CustomPaint(size: Size.infinite, painter: _CursorPainter(at, r)),
              ),
            ),
          ],
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  /// Mulai merekam bagian [name] (nama berkas tanpa akhiran).
  Future<void> start(String name, {String? caption}) async {
    Directory(outDir).createSync(recursive: true);
    // Keterangan bagian sebelumnya tidak boleh ikut terekam di awal.
    clearCaption();
    _raise();
    await pause(200);
    final size = tester.view.physicalSize;
    final display = Platform.environment['DISPLAY'] ?? ':77';
    _recorder = await tester.runAsync(
      () => Process.start('ffmpeg', <String>[
        '-y',
        '-loglevel',
        'error',
        '-f',
        'x11grab',
        '-draw_mouse',
        '0',
        '-framerate',
        '30',
        '-video_size',
        '${size.width.toInt()}x${size.height.toInt()}',
        '-i',
        '$display+0,0',
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-crf',
        '20',
        '-pix_fmt',
        'yuv420p',
        p.join(outDir, '$name.mp4'),
      ]),
    );
    await pause(600);
    if (caption != null) await say(caption);
  }

  Future<void> stop() async {
    await pause(800);
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    recorder.stdin.write('q');
    await tester.runAsync(() => recorder.stdin.close());
    await tester.runAsync(() => recorder.exitCode.timeout(const Duration(seconds: 20)));
  }

  /// Menutup perekam yang masih berjalan (bagian yang gagal di tengah):
  /// ffmpeg yang dimatikan paksa meninggalkan MP4 yang tidak bisa diputar.
  Future<void> abort() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    recorder.stdin.write('q');
    await recorder.stdin.close();
    await recorder.exitCode.timeout(const Duration(seconds: 20), onTimeout: () => -1);
  }

  /// Keterangan di atas layar selama [ms].
  Future<void> say(String text, {int ms = 2600}) async {
    _raise();
    _caption.value = text;
    await pause(ms);
  }

  void clearCaption() => _caption.value = null;

  Future<void> pause(int ms) => pumpFor(tester, Duration(milliseconds: ms));

  /// Kursor bergerak halus ke [target].
  Future<void> moveTo(Offset target, {int ms = 550}) async {
    _raise();
    final from = _cursor.value;
    const step = 16;
    final steps = math.max(1, ms ~/ step);
    final mouse = await _theMouse();
    for (var i = 1; i <= steps; i++) {
      final t = Curves.easeInOut.transform(i / steps);
      _cursor.value = Offset.lerp(from, target, t)!;
      await mouse.moveTo(_cursor.value);
      await tester.pump(const Duration(milliseconds: step));
    }
  }

  /// Jeda singkat sebelum menekan, supaya mata sempat menangkap tempatnya.
  /// Tanda ketukannya digambar binding uji sendiri (lingkaran bidik).
  Future<void> _click() => pause(180);

  Future<void> _press() async {
    await _click();
    final mouse = await _theMouse();
    await mouse.down(_cursor.value);
    await tester.pump(const Duration(milliseconds: 60));
    await mouse.up();
  }

  Future<void> tap(Finder finder, {int after = 700}) async {
    await pumpUntil(tester, finder);
    await moveTo(tester.getCenter(finder.first));
    await _press();
    await pause(after);
  }

  Future<void> tapAt(Offset at, {int after = 700}) async {
    await moveTo(at);
    await _press();
    await pause(after);
  }

  /// Seretan mouse lewat titik-titik [path], kursor ikut.
  Future<void> drag(List<Offset> path, {int stepMs = 32, int after = 600}) async {
    await moveTo(path.first);
    final g = await _theMouse();
    await pause(150);
    await g.down(path.first);
    await pause(150);
    for (final point in path.skip(1)) {
      _cursor.value = point;
      await g.moveTo(point);
      await tester.pump(Duration(milliseconds: stepMs));
    }
    // Seleksi teks pdfrx diperbarui secara asinkron; dilepas terlalu cepat,
    // stabilo dan bilah pilihan tidak pernah muncul.
    await pause(350);
    await g.up();
    await pause(after);
  }

  /// Mouse melayang (tanpa tombol) lewat [path].
  Future<void> hover(List<Offset> path, {int stepMs = 24}) async {
    final mouse = await _theMouse();
    for (final point in path) {
      _cursor.value = point;
      await mouse.moveTo(point);
      await tester.pump(Duration(milliseconds: stepMs));
    }
  }

  /// Mengetik huruf demi huruf.
  Future<void> type(Finder field, String text, {int perChar = 45}) async {
    await pumpUntil(tester, field);
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(field.last, text.substring(0, i));
      await tester.pump(Duration(milliseconds: perChar));
    }
    await pause(400);
  }

  /// Titik-titik lurus dari [a] ke [b].
  static List<Offset> line(Offset a, Offset b, {int steps = 24}) => <Offset>[
    for (var i = 0; i <= steps; i++) Offset.lerp(a, b, i / steps)!,
  ];

  /// Titik-titik lingkaran (untuk melingkari sesuatu).
  static List<Offset> circle(Offset c, double rx, double ry, {int steps = 40}) => <Offset>[
    for (var i = 0; i <= steps; i++)
      c + Offset(rx * math.cos(2 * math.pi * i / steps), ry * math.sin(2 * math.pi * i / steps)),
  ];
}

class _CursorPainter extends CustomPainter {
  _CursorPainter(this.at, this.ripple);

  final Offset at;
  final double ripple;

  @override
  void paint(Canvas canvas, Size size) {
    if (ripple > 0) {
      canvas.drawCircle(
        at,
        10 + 22 * ripple,
        Paint()..color = const Color(0xFF2F81F7).withValues(alpha: 0.45 * (1 - ripple)),
      );
    }
    final arrow = Path()
      ..moveTo(at.dx, at.dy)
      ..lineTo(at.dx, at.dy + 22)
      ..lineTo(at.dx + 6, at.dy + 17)
      ..lineTo(at.dx + 10, at.dy + 26)
      ..lineTo(at.dx + 14, at.dy + 24)
      ..lineTo(at.dx + 10, at.dy + 15)
      ..lineTo(at.dx + 17, at.dy + 15)
      ..close();
    canvas
      ..drawPath(
        arrow.shift(const Offset(1.5, 2)),
        Paint()
          ..color = Colors.black26
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawPath(arrow, Paint()..color = Colors.black)
      ..drawPath(
        arrow,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_CursorPainter old) => old.at != at || old.ripple != ripple;
}

// ----------------------------------------------------------- library demo

/// PDF bergaya makalah: judul, penulis, abstrak, dan beberapa bagian.
Future<Uint8List> paperPdf({
  required String title,
  required String authors,
  required List<String> sections,
}) async {
  final doc = pw.Document();
  const body = pw.TextStyle(fontSize: 11, lineSpacing: 3);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(64, 60, 64, 60),
      build: (_) => <pw.Widget>[
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text(authors, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 18),
        pw.Text('Abstract', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(_abstract, style: body),
        for (var i = 0; i < sections.length; i++) ...<pw.Widget>[
          pw.SizedBox(height: 16),
          pw.Text(
            '${i + 1}. ${sections[i]}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(_paragraphs[i % _paragraphs.length], style: body),
          pw.SizedBox(height: 6),
          pw.Text(_paragraphs[(i + 1) % _paragraphs.length], style: body),
        ],
      ],
    ),
  );
  return doc.save();
}

const String _abstract =
    'Large-scale quantum computers would break the public-key schemes that protect most '
    'of today\'s long-lived data. This paper surveys migration strategies toward '
    'post-quantum cryptography, compares hybrid key exchange with pure lattice-based '
    'schemes, and reports measurements from a staged rollout across three production '
    'services. We find that hybrid deployment adds less than four percent latency while '
    'removing the harvest-now-decrypt-later risk.';

const List<String> _paragraphs = <String>[
  'Migration begins with an inventory of every place where asymmetric keys are created, '
      'stored, or exchanged. In our services the long tail mattered more than the core: '
      'internal tools and batch jobs held a third of all key material.',
  'Hybrid key exchange combines a classical elliptic-curve share with a lattice-based '
      'encapsulation, so that an attacker must break both. Implementations differ mainly in '
      'how they bind the two secrets and in the size of the resulting handshake.',
  'We measured handshake latency, message size, and CPU time on commodity hardware. The '
      'larger public keys increased the first flight by roughly one kilobyte, which stayed '
      'within a single packet for all observed paths.',
  'Operational lessons were less about algorithms than about agility: services that '
      'already rotated certificates automatically adopted the new schemes in days, while '
      'manually managed ones took months.',
];

/// Library contoh untuk video: beberapa koleksi dan paper bertema.
Future<void> enrichLibrary(Fixture fx) async {
  final lib = fx.library;
  Fixture.write(
    p.join(lib, 'collections.json'),
    const JsonEncoder.withIndent('\t').convert(<dynamic>[
      <String, dynamic>{
        'key': 'COLL0001',
        'name': 'Kripto',
        'parentKey': null,
        'path': 'Kripto',
        'relations': <String, dynamic>{},
      },
      <String, dynamic>{
        'key': 'COLL0002',
        'name': 'Pembelajaran Mesin',
        'parentKey': null,
        'path': 'Pembelajaran Mesin',
        'relations': <String, dynamic>{},
      },
      <String, dynamic>{
        'key': 'COLL0003',
        'name': 'Disertasi',
        'parentKey': null,
        'path': 'Disertasi',
        'relations': <String, dynamic>{},
      },
      <String, dynamic>{
        'key': 'COLL0004',
        'name': 'Bab 2 — Tinjauan',
        'parentKey': 'COLL0003',
        'path': 'Disertasi/Bab 2 — Tinjauan',
        'relations': <String, dynamic>{},
      },
    ]),
  );

  final papers =
      <
        ({
          String key,
          String att,
          String title,
          String last,
          String first,
          String year,
          String coll,
          String path,
        })
      >[
        (
          key: 'ITEMKEY1',
          att: 'ATTACH01',
          title: 'Migrasi kriptografi pascakuantum',
          last: 'Naether',
          first: 'Christian',
          year: '2024',
          coll: 'COLL0001',
          path: 'Kripto',
        ),
        (
          key: 'ITEMKEY2',
          att: 'ATTACH02',
          title: 'Sinkronisasi Zotero lewat Git',
          last: 'Karisma',
          first: 'Hendri',
          year: '2025',
          coll: 'COLL0003',
          path: 'Disertasi',
        ),
        (
          key: 'ITEMKEY3',
          att: 'ATTACH03',
          title: 'Hybrid key exchange in practice',
          last: 'Bos',
          first: 'Joppe',
          year: '2023',
          coll: 'COLL0001',
          path: 'Kripto',
        ),
        (
          key: 'ITEMKEY4',
          att: 'ATTACH04',
          title: 'Attention is all you need',
          last: 'Vaswani',
          first: 'Ashish',
          year: '2017',
          coll: 'COLL0002',
          path: 'Pembelajaran Mesin',
        ),
        (
          key: 'ITEMKEY5',
          att: 'ATTACH05',
          title: 'Lattice-based signatures at scale',
          last: 'Ducas',
          first: 'Léo',
          year: '2022',
          coll: 'COLL0004',
          path: 'Disertasi/Bab 2 — Tinjauan',
        ),
        (
          key: 'ITEMKEY6',
          att: 'ATTACH06',
          title: 'Federated learning on edge devices',
          last: 'McMahan',
          first: 'Brendan',
          year: '2019',
          coll: 'COLL0002',
          path: 'Pembelajaran Mesin',
        ),
      ];
  const enc = JsonEncoder.withIndent('\t');
  for (final paper in papers) {
    final bytes = await paperPdf(
      title: paper.title,
      authors: '${paper.first} ${paper.last} · ${paper.year}',
      sections: const <String>['Introduction', 'Background', 'Method', 'Evaluation', 'Discussion'],
    );
    final pdf = p.join(lib, 'attachments', paper.att.substring(0, 2), paper.att, 'paper.pdf');
    File(pdf)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    Fixture.write(
      fx.itemFile(paper.key),
      enc.convert(
        zoteroItem(
          key: paper.key,
          attachmentKey: paper.att,
          title: paper.title,
          lastName: paper.last,
          firstName: paper.first,
          year: paper.year,
          collectionKeys: <String>[paper.coll],
          collectionPaths: <String>[paper.path],
          pdfSize: bytes.length,
        ),
      ),
    );
  }
  await fx.git(<String>['add', '-A']);
  await fx.git(<String>['commit', '-q', '-m', 'Library contoh']);
  await fx.git(<String>['push', '-q', 'origin', 'main']);
}
