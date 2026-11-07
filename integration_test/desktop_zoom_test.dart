import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;

import 'support.dart';

/// Tombol zum melangkah sedikit-sedikit, dan dokumen dibuka lagi pada zum
/// yang terakhir dipakai.
///
///   flutter test integration_test/desktop_zoom_test.dart -d linux
///
/// Dulu satu tekan "Perbesar" melipatgandakan zum (pas → 2×): terlalu dekat,
/// sedangkan kembali ke pas terlalu jauh; dan setiap kali dibuka, zumnya
/// kembali ke bawaan.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => Fixture.create());

  PdfViewerController viewer(WidgetTester tester) =>
      tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Migrasi kriptografi pascakuantum').first);
    await pumpFor(tester, const Duration(seconds: 1));
    // Paper yang sudah terpilih langsung terbuka saat diketuk lagi.
    if (find.text('Baca').evaluate().isNotEmpty) await tester.tap(find.text('Baca'));
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpFor(tester, const Duration(seconds: 3));
  }

  testWidgets('zum selangkah ~1,25× dan diingat per dokumen', (tester) async {
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    await open(tester);

    final c = viewer(tester);
    final z0 = c.currentZoom;
    await tester.tap(find.byTooltip('Perbesar').first);
    await pumpFor(tester, const Duration(seconds: 1));
    final z1 = c.currentZoom;
    diag('zum $z0 → $z1 (×${(z1 / z0).toStringAsFixed(2)})');
    expect(z1 / z0, inInclusiveRange(1.1, 1.35));
    await tester.tap(find.byTooltip('Perbesar').first);
    await pumpFor(tester, const Duration(seconds: 2));
    final z2 = c.currentZoom;

    // Ditutup, lalu dibuka lagi.
    // Tab dokumennya ditutup, bukan sekadar disembunyikan di belakang tab
    // library; kalau tidak, judulnya di bilah tab membuka tab yang sama.
    await tester.tap(find.byType(BackButton).last);
    await pumpFor(tester, const Duration(seconds: 1));
    while (find.byTooltip('Tutup tab').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Tutup tab').last);
      await pumpFor(tester, const Duration(seconds: 1));
    }
    expect(find.byType(PdfViewer, skipOffstage: false), findsNothing);
    await open(tester);
    final again = viewer(tester).currentZoom;
    diag('dibuka lagi pada $again (tadi $z2)');
    expect(again, closeTo(z2, z2 * 0.02));
  });
}
