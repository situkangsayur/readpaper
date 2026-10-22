import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;

import 'support.dart';

/// Dua paper berdampingan: masing-masing dibuka sebagai tab, yang kedua
/// dipindah ke panel kanan.
///
///   flutter test integration_test/desktop_tabs_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(Fixture.create);

  testWidgets('dua paper di panel kiri dan kanan', (tester) async {
    app.main(const <String>[]);
    Future<void> read(String title) async {
      await tester.tap(find.text('Library'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text(title).first);
      await pumpUntil(tester, find.text('Baca'));
      await tester.tap(find.text('Baca'));
      await pumpUntil(tester, find.byType(PdfViewer));
      await pumpFor(tester, const Duration(seconds: 2));
    }

    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    await tester.tap(find.text('Migrasi kriptografi pascakuantum').first);
    await pumpUntil(tester, find.text('Baca'));
    await tester.tap(find.text('Baca'));
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpFor(tester, const Duration(seconds: 2));
    await _shotAll(tester, 'tab-satu');

    await read('Sinkronisasi Zotero lewat Git');
    await tester.tap(find.byTooltip('Pindah ke panel kanan').first);
    await pumpFor(tester, const Duration(seconds: 2));
    await _shotAll(tester, 'tab-kanan-kiri');

    final viewers = find.byType(PdfViewer, skipOffstage: true).evaluate().toList();
    diag('penampil terlihat: ${viewers.length}');
    expect(viewers.length, 2);
    final rects = <Rect>[
      for (final e in viewers)
        (e.renderObject! as RenderBox).localToGlobal(Offset.zero) &
            (e.renderObject! as RenderBox).size,
    ]..sort((a, b) => a.left.compareTo(b.left));
    diag('kiri ${rects[0]}, kanan ${rects[1]}');
    expect(rects[0].right, lessThanOrEqualTo(rects[1].left));
  });
}

/// Seluruh jendela, termasuk bilah tab — [shot] hanya memotret Scaffold
/// terakhir.
Future<void> _shotAll(WidgetTester tester, String name) async {
  final image = await captureImage(find.byType(Overlay).first.evaluate().first);
  final bytes = await tester.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final dir = Directory('build/e2e-shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!);
}
