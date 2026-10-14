import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;
import 'package:readpaper/src/features/reader/presentation/widgets/annotation_overlay_painter.dart';

import 'support.dart';

/// Slide 4:3 di layar lebar: begitu mode menyajikan dimulai, slidenya harus
/// utuh di layar dan di tengah, di atas bilah kendali — tanpa menekan
/// "pas ke layar".
///
///   flutter test integration_test/desktop_present_fit_test.dart -d linux
///
/// Dulu pemasangan pertama menunggu animasi yang dihentikan penampil saat
/// menyusun ulang dirinya, pemasangan susulannya tidak pernah jalan, dan
/// slidenya tertinggal terlalu besar dengan bagian bawah terpotong.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fx = await Fixture.create();
    final pdf = p.join(fx.library, 'attachments', 'AT', 'ATTACH01', 'paper.pdf');
    File(pdf).writeAsBytesSync(await _slides43());
  });

  testWidgets('slide utuh dan di tengah saat menyajikan', (tester) async {
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    await tester.tap(find.text('Migrasi kriptografi pascakuantum').first);
    await pumpUntil(tester, find.text('Baca'));
    await tester.tap(find.text('Baca'));
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpFor(tester, const Duration(seconds: 3));
    await tester.tap(find.byTooltip('Sajikan — satu halaman penuh layar'));
    await pumpFor(tester, const Duration(seconds: 3));
    await shot(tester, 'menyajikan-4-3');

    final viewer = tester.getRect(find.byType(PdfViewer));
    final page = find
        .byWidgetPredicate((w) => w is CustomPaint && w.painter is AnnotationOverlayPainter)
        .evaluate()
        .map((e) {
          final box = e.renderObject! as RenderBox;
          return box.localToGlobal(Offset.zero) & box.size;
        })
        .firstWhere((r) => r.overlaps(viewer));
    diag('penampil $viewer, slide $page');

    // Utuh: tidak ada tepi yang keluar dari penampil.
    expect(page.top, greaterThanOrEqualTo(viewer.top - 1));
    expect(page.bottom, lessThanOrEqualTo(viewer.bottom + 1));
    // Di tengah.
    expect((page.center.dx - viewer.center.dx).abs(), lessThan(2));
    expect((page.center.dy - viewer.center.dy).abs(), lessThan(2));
    // Di atas bilah kendali menyajikan, bukan di bawahnya.
    final bar = tester.getRect(find.byTooltip('Pas satu halaman ke layar'));
    expect(page.bottom, lessThanOrEqualTo(bar.top));
  });
}

/// Tiga slide 4:3.
Future<Uint8List> _slides43() async {
  final doc = pw.Document();
  for (var i = 1; i <= 3; i++) {
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(720, 540),
        build: (_) =>
            pw.Center(child: pw.Text('Slide $i', style: const pw.TextStyle(fontSize: 64))),
      ),
    );
  }
  return doc.save();
}
