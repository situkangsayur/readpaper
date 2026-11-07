import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;

import 'support.dart';

/// Menyisipkan halaman kosong ke PDF lepas yang fontnya tidak tertanam.
///
///   flutter test integration_test/desktop_blank_page_standalone_test.dart -d linux
///
/// Dulu aplikasinya mati di sini: penyunting halaman memanggil pdfium dari
/// isolate utama, dan pdfium memanggil balik pemeta font milik isolate
/// pekerja pdfrx ("Cannot invoke native callback from a different isolate").
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late String pdf;
  setUpAll(() async {
    final fx = await Fixture.create();
    Directory(fx.outside).createSync(recursive: true);
    pdf = p.join(fx.outside, 'lepas.pdf');
    File(pdf).writeAsBytesSync(await textPdf('lepas'));
  });
  testWidgets('halaman kosong di PDF lepas tidak mematikan aplikasi', (tester) async {
    app.main(<String>[pdf]);
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpFor(tester, const Duration(seconds: 3));
    await tester.tap(find.byTooltip('Tambah lembar kosong'));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.textContaining('setelah halaman 1').first);
    await pumpFor(tester, const Duration(seconds: 4));
    await shot(tester, 'sisip-lepas');
    expect(find.textContaining('halaman 2 dari 2'), findsOneWidget);
  });
}
