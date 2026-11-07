import 'dart:convert';
import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/main.dart' as app;
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/update/data/update_service.dart';
import 'package:readpaper/src/features/update/presentation/update_controller.dart';

import 'support.dart';

/// Rilis baru di GitHub diberitahukan di pojok layar.
///
///   flutter test integration_test/desktop_update_notice_test.dart -d linux
///
/// Rilisnya disajikan uji ini sendiri, berbentuk jawaban API GitHub.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;

  setUpAll(() async {
    await Fixture.create();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      req.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'tag_name': 'v0.99.0',
            'body': '- Pembaruan dari dalam aplikasi\n- Catatan rilis tampil di sini',
            'html_url': 'http://127.0.0.1/rilis',
            'assets': <dynamic>[],
          }),
        )
        ..close();
    });
    UpdateService.feedOverride = 'http://127.0.0.1:${server.port}/rilis.json';
  });

  tearDownAll(() async {
    UpdateService.feedOverride = null;
    await server.close(force: true);
  });

  testWidgets('versi baru: kartu muncul, catatan rilis, lalu dilewati', (tester) async {
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));

    final container = ProviderScope.containerOf(
      tester.element(find.text('Migrasi kriptografi pascakuantum').first),
    );
    await container.read(updateControllerProvider.notifier).check();
    await pumpUntil(tester, find.text('ReadPaper 0.99.0 tersedia'));
    await _shotOf(tester, 'pembaruan-kartu', find.byKey(const ValueKey('kartu-pembaruan')));
    expect(find.byKey(const ValueKey('kartu-pembaruan')), findsOneWidget);

    await tester.tap(find.text('Catatan rilis'));
    await pumpUntil(tester, find.textContaining('Catatan rilis tampil di sini'));
    await shot(tester, 'pembaruan-catatan');
    await tester.tap(find.text('Tutup').last);
    await pumpFor(tester, const Duration(milliseconds: 500));

    await tester.tap(find.text('Lewati versi ini'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('kartu-pembaruan')), findsNothing);

    // Versi yang dilewati diingat, jadi tidak ditawarkan lagi saat dibuka ulang.
    final prefs = File(p.join(AppPaths.instance.supportDir.path, 'pembaruan.json'));
    final saved = jsonDecode(prefs.readAsStringSync()) as Map<String, dynamic>;
    diag('pembaruan.json: $saved');
    expect(saved['lewati'], '0.99.0');

    await container.read(updateControllerProvider.notifier).check();
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('kartu-pembaruan')), findsNothing);
  });
}

/// [shot] memotret Scaffold terakhir, sedangkan kartunya duduk di atas
/// Navigator; dipotret sendiri.
Future<void> _shotOf(WidgetTester tester, String name, Finder finder) async {
  final image = await captureImage(finder.evaluate().first);
  final bytes = await tester.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final dir = Directory(p.join('build', 'e2e-shots'))..createSync(recursive: true);
  File(p.join(dir.path, '$name.png')).writeAsBytesSync(bytes!);
}
