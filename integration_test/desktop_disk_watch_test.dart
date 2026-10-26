import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;

import 'support.dart';

/// Paper yang masuk dari luar aplikasi — `git pull` di terminal — tampil
/// tanpa menutup ReadPaper; dan menu klik kanan sebuah paper membukanya di
/// panel kanan.
///
///   flutter test integration_test/desktop_disk_watch_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;
  setUpAll(() async => fixture = await Fixture.create());

  testWidgets('pull di terminal tampil tanpa menutup aplikasi', (tester) async {
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));

    // Orang lain menambahkan paper ke remote; di sini ditarik dengan git
    // sendiri, di luar ReadPaper.
    final other = p.join(fixture.root.path, 'lain');
    await Fixture.gitIn(fixture.root.path, <String>['clone', '-q', fixture.remote, other]);
    await Fixture.gitIn(other, <String>['config', 'user.email', 'lain@readpaper.test']);
    await Fixture.gitIn(other, <String>['config', 'user.name', 'Lain']);
    final lib = p.join(other, 'zotero', 'uji');
    final pdf = await textPdf('Paper baru dari repositori lain');
    File(p.join(lib, 'attachments', 'AT', 'ATTACH03', 'paper.pdf'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(pdf);
    Fixture.write(
      p.join(lib, 'items', 'IT', 'ITEMKEY3.json'),
      const JsonEncoder.withIndent('\t').convert(
        zoteroItem(
          key: 'ITEMKEY3',
          attachmentKey: 'ATTACH03',
          title: 'Paper yang datang lewat pull',
          lastName: 'Lestari',
          firstName: 'Astri',
          year: '2026',
          collectionKeys: <String>[],
          collectionPaths: <String>[],
          pdfSize: pdf.length,
        ),
      ),
    );
    await Fixture.gitIn(other, <String>['add', '-A']);
    await Fixture.gitIn(other, <String>['commit', '-q', '-m', 'Paper baru']);
    await Fixture.gitIn(other, <String>['push', '-q', 'origin', 'main']);
    final pulled = await fixture.git(<String>['pull', '-q', '--ff-only']);
    expect(pulled.exitCode, 0, reason: '${pulled.stderr}');

    final started = DateTime.now();
    await pumpUntil(tester, find.text('Paper yang datang lewat pull'), seconds: 15);
    diag('tampil setelah ${DateTime.now().difference(started).inMilliseconds} ms');

    // Klik kanan paper itu: buka di panel kanan, berdampingan dengan library.
    final tile = find.text('Paper yang datang lewat pull');
    final gesture = await tester.startGesture(
      tester.getCenter(tile),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await pumpUntil(tester, find.text('Buka di panel kanan'));
    expect(find.text('Baca'), findsWidgets);
    await tester.tap(find.text('Buka di panel kanan'));
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpFor(tester, const Duration(seconds: 1));
    final viewer = find.byType(PdfViewer).evaluate().single.renderObject! as RenderBox;
    final left = viewer.localToGlobal(Offset.zero).dx;
    diag('penampil mulai di x=$left dari ${tester.view.physicalSize.width}');
    expect(left, greaterThan(200), reason: 'paper terbuka di panel kanan');
    // Library tetap terlihat di kiri.
    expect(find.text('Migrasi kriptografi pascakuantum'), findsWidgets);
  });
}
