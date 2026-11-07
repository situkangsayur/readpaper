import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/main.dart' as app;
import 'package:readpaper/src/features/workspace/presentation/controllers/workspace_controller.dart';

import 'support.dart';

/// Koleksi, paper, dan koleksi catatan yang datang lewat tombol Tarik tampil
/// seketika, tanpa menutup ReadPaper.
///
///   flutter test integration_test/desktop_pull_refresh_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;
  setUpAll(() async => fixture = await Fixture.create());

  testWidgets('tarik dari dalam aplikasi: semuanya langsung tampil', (tester) async {
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    await pumpFor(tester, const Duration(seconds: 4));

    // Perangkat lain menambah koleksi, paper di dalamnya, dan koleksi catatan.
    final other = p.join(fixture.root.path, 'lain');
    await Fixture.gitIn(fixture.root.path, <String>['clone', '-q', fixture.remote, other]);
    await Fixture.gitIn(other, <String>['config', 'user.email', 'lain@readpaper.test']);
    await Fixture.gitIn(other, <String>['config', 'user.name', 'Lain']);
    final lib = p.join(other, 'zotero', 'uji');
    final cols = jsonDecode(File(p.join(lib, 'collections.json')).readAsStringSync()) as List;
    cols.add(<String, dynamic>{
      'key': 'COLL0002',
      'name': 'Koleksi dari tablet',
      'parentKey': null,
      'path': 'Koleksi dari tablet',
      'relations': <String, dynamic>{},
    });
    Fixture.write(
      p.join(lib, 'collections.json'),
      '${const JsonEncoder.withIndent('\t').convert(cols)}\n',
    );
    final pdf = await textPdf('Paper baru dari tablet');
    File(p.join(lib, 'attachments', 'AT', 'ATTACH04', 'paper.pdf'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(pdf);
    Fixture.write(
      p.join(lib, 'items', 'IT', 'ITEMKEY4.json'),
      const JsonEncoder.withIndent('\t').convert(
        zoteroItem(
          key: 'ITEMKEY4',
          attachmentKey: 'ATTACH04',
          title: 'Paper dari tablet',
          lastName: 'Lestari',
          firstName: 'Astri',
          year: '2026',
          collectionKeys: <String>['COLL0002'],
          collectionPaths: <String>['Koleksi dari tablet'],
          pdfSize: pdf.length,
        ),
      ),
    );
    Fixture.write(
      p.join(other, 'catatan', 'koleksi.json'),
      '${const JsonEncoder.withIndent('\t').convert(<dynamic>[
        <String, dynamic>{'key': 'NCOL0001', 'name': 'Catatan rapat'},
      ])}\n',
    );
    await Fixture.gitIn(other, <String>['add', '-A']);
    await Fixture.gitIn(other, <String>['commit', '-q', '-m', 'Dari tablet']);
    final pushed = await Fixture.gitIn(other, <String>['push', '-q', 'origin', 'main']);
    expect(pushed.exitCode, 0, reason: '${pushed.stderr}');

    final container = ProviderScope.containerOf(
      tester.element(find.text('Migrasi kriptografi pascakuantum').first),
    );
    final ok = await container.read(workspaceControllerProvider.notifier).pull();
    expect(ok, isTrue);
    // "Langsung": tidak boleh menunggu pemeriksaan disk berikutnya.
    await pumpFor(tester, const Duration(milliseconds: 800));
    await shot(tester, 'tarik-sesudah');
    expect(find.text('Koleksi dari tablet'), findsWidgets);
    expect(find.text('Catatan rapat'), findsWidgets);
    await tester.tap(find.text('Koleksi dari tablet').first);
    await pumpUntil(tester, find.text('Paper dari tablet'), seconds: 3);
  });
}
