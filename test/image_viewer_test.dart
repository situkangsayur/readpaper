import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/notes/presentation/screens/image_viewer_screen.dart';

void main() {
  late Directory dir;

  /// PNG 1×1 yang sah.
  const png = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
    0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00,
    0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78,
    0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  setUp(() => dir = Directory.systemTemp.createTempSync('rp-gambar-'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('gambar catatan bisa dilihat dan diperbesar', (tester) async {
    final file = File(p.join(dir.path, 'papan.png'))..writeAsBytesSync(png);
    await tester.pumpWidget(
      MaterialApp(home: ImageViewerScreen(path: file.path, title: 'Papan tulis')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Papan tulis'), findsOneWidget);
    expect(find.text('papan.png'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    // Dua jari memperbesar: gambar pindaian sering perlu diperbesar untuk dibaca.
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('berkas yang hilang dikatakan, bukan layar kosong', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ImageViewerScreen(path: p.join(dir.path, 'hantu.png'))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('tidak ada lagi'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
