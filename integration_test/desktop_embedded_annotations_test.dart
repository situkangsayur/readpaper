import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;

import 'support.dart';

/// PDF yang dianotasi di aplikasi lain: stabilo dan catatan tempelnya tampil
/// di panel anotasi, dan catatan tempel di halaman bisa dibuka isinya.
///
///   RP_KAMATH_PDF=/jalur/ke/berkas-ANOTASI.pdf \
///     flutter test integration_test/desktop_embedded_annotations_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final source = Platform.environment['RP_KAMATH_PDF'];

  late String pdf;
  setUpAll(() async {
    final fx = await Fixture.create();
    if (source != null) {
      pdf = p.join(fx.outside, 'kamath-ANOTASI.pdf');
      Directory(fx.outside).createSync(recursive: true);
      File(source).copySync(pdf);
    }
  });

  testWidgets('anotasi tertanam terbaca', (tester) async {
    app.main(<String>[pdf]);
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpUntil(tester, find.textContaining('371 anotasi'), seconds: 60);
    await pumpFor(tester, const Duration(seconds: 2));
    await _shotAll(tester, 'tertanam-panel');

    // Panel memuat komentar catatan ringkasannya, terkunci.
    expect(find.textContaining('RINGKASAN DAN PENILAIAN UMUM'), findsWidgets);
    expect(find.textContaining('Di dalam PDF'), findsWidgets);
    expect(find.byTooltip('Hapus'), findsNothing);

    // Catatan tempel pertama di halaman 1: x 20..42, y 741..763 dari bawah,
    // halaman 576 × 783 poin.
    final controller = tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;
    final page = controller.layout.pageLayouts.first;
    final scale = page.width / 576;
    final target = controller.documentToGlobal(
      Offset(page.left + 31 * scale, page.top + (782.929 - 752) * scale),
    )!;
    diag('ketuk catatan di $target');
    await tester.tapAt(target);
    await pumpFor(tester, const Duration(seconds: 1));
    await _shotAll(tester, 'tertanam-catatan');
    expect(find.byType(SelectableText), findsWidgets);
  }, skip: source == null || !File(source).existsSync());
}

Future<void> _shotAll(WidgetTester tester, String name) async {
  final image = await captureImage(find.byType(Overlay).first.evaluate().first);
  final bytes = await tester.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final dir = Directory('build/e2e-shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!);
}
