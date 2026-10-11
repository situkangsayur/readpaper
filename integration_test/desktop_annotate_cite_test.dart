import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/reader/presentation/screens/reader_screen.dart';

/// Ujung ke ujung di desktop sungguhan (dijalankan CI di Windows): aplikasi
/// asli, library Zotero di repositori git asli, PDF asli. Menandai teks dengan
/// seret mouse, memberi komentar, menempel catatan — lalu memeriksa bahwa
/// semuanya tertulis dalam format anotasi Zotero dan ter-commit, dan bahwa
/// server sitasi serta inti add-in Word/OnlyOffice menyajikannya.
///
///   flutter test integration_test -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String repo;
  late String itemFile;
  late String pdfPath;

  Future<ProcessResult> git(List<String> args) =>
      Process.run('git', args, workingDirectory: repo, runInShell: Platform.isWindows);

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    final end = DateTime.now().add(total);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpUntil(WidgetTester tester, Finder finder, {int seconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Tidak muncul dalam $seconds detik: $finder');
  }

  // Tangkapan layar aplikasi per langkah, diunggah CI sebagai artefak:
  // tanpa ini kegagalan di runner Windows tidak bisa dilihat.
  Future<void> shot(WidgetTester tester, String name) async {
    try {
      final image = await captureImage(find.byType(Scaffold).last.evaluate().first);
      final bytes = await tester.runAsync(() async {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      final dir = Directory(p.join('build', 'e2e-shots'))..createSync(recursive: true);
      File(p.join(dir.path, '$name.png')).writeAsBytesSync(bytes!);
    } on Object catch (e) {
      // ignore: avoid_print
      print('[diag] tangkapan $name gagal: $e');
    }
  }

  // ignore: avoid_print
  void diag(String m) => print('[diag] $m');

  List<Map<String, dynamic>> annotations() {
    final item = jsonDecode(File(itemFile).readAsStringSync()) as Map<String, dynamic>;
    return (item['children'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((c) => c['itemType'] == 'annotation')
        .toList();
  }

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('rp_e2e_');
    repo = p.join(root.path, 'repo');
    final lib = p.join(repo, 'zotero', 'uji');
    void write(String path, String text) => File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    // PDF penuh teks: seretan di mana pun di halaman mengenai kata.
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            for (var i = 0; i < 26; i++)
              pw.Text(
                'Kriptografi pascakuantum melindungi data jangka panjang $i',
                style: const pw.TextStyle(fontSize: 18),
              ),
          ],
        ),
      ),
    );
    pdfPath = p.join(lib, 'attachments', 'AT', 'ATTACH01', 'paper.pdf');
    File(pdfPath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(await doc.save());

    write(p.join(lib, 'library.json'), '{"id": 1, "name": "uji", "type": "user"}\n');
    write(
      p.join(lib, 'collections.json'),
      '[\n\t{\n\t\t"key": "COLL0001",\n\t\t"name": "Kripto",\n\t\t"parentKey": null,'
      '\n\t\t"path": "Kripto",\n\t\t"relations": {}\n\t}\n]\n',
    );
    itemFile = p.join(lib, 'items', 'IT', 'ITEMKEY1.json');
    write(
      itemFile,
      const JsonEncoder.withIndent('\t').convert(<String, dynamic>{
        'children': <dynamic>[
          <String, dynamic>{
            'contentType': 'application/pdf',
            'filename': 'paper.pdf',
            'itemType': 'attachment',
            'key': 'ATTACH01',
            'linkMode': 'imported_file',
            'parentItem': 'ITEMKEY1',
            'title': 'PDF',
          },
        ],
        'meta': <String, dynamic>{
          'attachments': <dynamic>[
            <String, dynamic>{
              'annotationCount': 0,
              'contentType': 'application/pdf',
              'filename': 'paper.pdf',
              'files': <dynamic>[
                <String, dynamic>{
                  'path': 'attachments/AT/ATTACH01/paper.pdf',
                  'size': File(pdfPath).lengthSync(),
                  'storage': 'git',
                },
              ],
              'key': 'ATTACH01',
              'linkMode': 'imported_file',
              'status': 'ok',
              'title': 'PDF',
            },
          ],
          'collections': <dynamic>['Kripto'],
          'creators': <dynamic>['Naether, Christian'],
          'title': 'Migrasi kriptografi pascakuantum',
          'year': '2024',
        },
        'zotero': <String, dynamic>{
          'collections': <dynamic>['COLL0001'],
          'creators': <dynamic>[
            <String, dynamic>{
              'creatorType': 'author',
              'firstName': 'Christian',
              'lastName': 'Naether',
            },
          ],
          'date': '2024',
          'itemType': 'journalArticle',
          'key': 'ITEMKEY1',
          'publicationTitle': 'Journal of Demo',
          'title': 'Migrasi kriptografi pascakuantum',
        },
      }),
    );

    await Process.run('git', <String>[
      'init',
      '-q',
      '-b',
      'main',
      repo,
    ], runInShell: Platform.isWindows);
    await git(<String>['config', 'user.email', 'uji@readpaper.test']);
    await git(<String>['config', 'user.name', 'Uji']);
    await git(<String>['add', '-A']);
    final init = await git(<String>['commit', '-q', '-m', 'awal']);
    expect(init.exitCode, 0, reason: '${init.stderr}');

    final support = Directory(p.join(root.path, 'data'))..createSync();
    AppPaths.debugOverride(support);
    write(
      p.join(support.path, 'config.json'),
      jsonEncode(<String, dynamic>{
        'profiles': <dynamic>[
          <String, dynamic>{
            'id': 'uji',
            'name': 'uji',
            'remoteUrl': '',
            'localPath': repo,
            'transport': 'https',
            'branch': 'main',
            'authorName': 'Uji',
            'authorEmail': 'uji@readpaper.test',
            'lazyAttachments': false,
          },
        ],
        'activeProfileId': 'uji',
        'citationServer': true,
      }),
    );
  });

  testWidgets('tandai, komentar, catatan, lalu sitasi lewat inti add-in', (tester) async {
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    final commitsBefore = int.parse(
      ((await git(<String>['rev-list', '--count', 'HEAD'])).stdout as String).trim(),
    );

    // Membuka paper persis seperti dari daftar: item library, bukan PDF lepas.
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderScreen(
              itemKey: 'ITEMKEY1',
              itemFilePath: itemFile,
              attachmentKey: 'ATTACH01',
              filePath: pdfPath,
              title: 'Migrasi kriptografi pascakuantum',
            ),
          ),
        );
    await pumpUntil(tester, find.text('Tandai'));
    await pumpFor(tester, const Duration(seconds: 4)); // halaman dan teksnya dimuat

    await shot(tester, '1-pembaca');

    // 1) Tandai: tekan tombolnya, seret mouse di atas teks. Posisinya diukur
    // SESUDAH mode menyala: bilah petunjuknya mendorong halaman ke bawah, dan
    // di jendela yang pendek (runner Windows 1028x681) garis yang diukur
    // sebelumnya jatuh di margin kosong di atas teks.
    await tester.tap(find.text('Tandai'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    final viewer = tester.getRect(find.byType(PdfViewer));
    final view = tester.view;
    diag('jendela ${view.physicalSize} dpr=${view.devicePixelRatio} viewer=$viewer');
    // Tengah blok teks: halaman uji penuh baris tulisan dari atas ke bawah.
    final line = Offset(viewer.center.dx, viewer.top + viewer.height * 0.45);
    final drag = await tester.startGesture(
      Offset(viewer.left + viewer.width * 0.2, line.dy),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 20; i++) {
      await drag.moveTo(Offset(viewer.left + viewer.width * (0.2 + 0.03 * i), line.dy));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '2-sedang-menyeret');
    diag(
      'saat menyeret: Stabilo=${find.text('Stabilo').evaluate().length} '
      'Salin=${find.text('Salin').evaluate().length}',
    );
    await drag.up();
    await pumpFor(tester, const Duration(seconds: 3));
    await shot(tester, '3-sesudah-seret');
    diag(
      'sesudah seret: anotasi=${annotations().length} '
      'Tersimpan=${find.text('Tersimpan').evaluate().length}',
    );

    var notes = annotations();
    final highlight = notes.where((a) => a['annotationType'] == 'highlight').toList();
    expect(highlight, hasLength(1), reason: 'seret mouse dalam mode Tandai membuat satu stabilo');
    expect((highlight.single['annotationText'] as String).trim(), isNotEmpty);

    // 2) Komentar pada stabilo itu: klik stabilonya (masih di mode Tandai,
    // jadi halamannya belum bergeser), tulis komentar, simpan.
    await tester.tapAt(
      Offset(viewer.left + viewer.width * 0.45, line.dy),
      kind: PointerDeviceKind.mouse,
    );
    await pumpUntil(tester, find.text('Simpan'));
    await tester.enterText(find.byType(TextField).last, 'komentar uji windows');
    await tester.tap(find.text('Simpan'));
    await pumpFor(tester, const Duration(seconds: 3));

    await tester.tap(find.text('Menandai'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    // 3) Catatan tempel di bagian bawah halaman.
    await tester.tap(find.byTooltip('Tempel catatan di halaman'));
    await tester.pump();
    await tester.tapAt(
      Offset(viewer.center.dx, viewer.top + viewer.height * 0.7),
      kind: PointerDeviceKind.mouse,
    );
    await pumpUntil(tester, find.text('Simpan'));
    await tester.enterText(find.byType(TextField).last, 'catatan uji windows');
    await tester.tap(find.text('Simpan'));
    await pumpFor(tester, const Duration(seconds: 3));

    // Format Zotero, persis seperti yang ditulis plugin sinkronisasi.
    notes = annotations();
    final h = notes.singleWhere((a) => a['annotationType'] == 'highlight');
    final t = notes.singleWhere((a) => a['annotationType'] == 'text');
    expect(h['annotationComment'], 'komentar uji windows');
    expect(t['annotationComment'], 'catatan uji windows');
    for (final a in <Map<String, dynamic>>[h, t]) {
      expect(a['itemType'], 'annotation');
      expect(a['parentItem'], 'ATTACH01');
      expect(a['key'], matches(RegExp(r'^[23456789ABCDEFGHIJKLMNPQRSTUVWXYZ]{8}$')));
      expect(a['annotationColor'], matches(RegExp(r'^#[0-9a-fA-F]{6}$')));
      expect(a['annotationPageLabel'], '1');
      expect(a['annotationSortIndex'], matches(RegExp(r'^\d{5}\|\d{6}\|\d{5}$')));
      final position = jsonDecode(a['annotationPosition'] as String) as Map<String, dynamic>;
      expect(position['pageIndex'], 0);
      expect(position['rects'], isNotEmpty);
    }
    final item = jsonDecode(File(itemFile).readAsStringSync()) as Map<String, dynamic>;
    final meta = (item['meta'] as Map<String, dynamic>)['attachments'] as List<dynamic>;
    expect((meta.single as Map<String, dynamic>)['annotationCount'], 2);

    // Setiap simpan menjadi commit; tidak ada yang tertinggal tak ter-commit.
    final commitsAfter = int.parse(
      ((await git(<String>['rev-list', '--count', 'HEAD'])).stdout as String).trim(),
    );
    expect(commitsAfter, greaterThanOrEqualTo(commitsBefore + 3));
    expect(((await git(<String>['status', '--porcelain'])).stdout as String).trim(), isEmpty);

    // Server sitasi untuk Word/OnlyOffice: hidup, bertoken, dan melihat
    // anotasi yang baru dibuat.
    final credentials =
        jsonDecode(File(AppPaths.instance.credentialsFile).readAsStringSync())
            as Map<String, dynamic>;
    final token = credentials['readpaper:citation-server-token'] as String;
    final http = HttpClient();
    Future<dynamic> getJson(String path) async {
      final req = await http.getUrl(Uri.parse('http://127.0.0.1:23121$path'));
      req.headers.set('Authorization', 'Bearer $token');
      final res = await req.close();
      expect(res.statusCode, 200, reason: path);
      return jsonDecode(await res.transform(utf8.decoder).join());
    }

    final served = await tester.runAsync(() => getJson('/api/items/ITEMKEY1/annotations'));
    final list = (served as Map<String, dynamic>)['annotations'] as List<dynamic>;
    expect(list, hasLength(2));
    http.close();

    // Inti add-in (citeproc-js, gaya APA dan IEEE) terhadap server ini.
    final node = await tester.runAsync(
      () => Process.run(
        'node',
        <String>['--test', p.join('integrations', 'e2e', 'server.e2e.js')],
        environment: <String, String>{'READPAPER_TOKEN': token, 'READPAPER_KEYS': 'ITEMKEY1'},
        runInShell: Platform.isWindows,
      ),
    );
    // ignore: avoid_print
    print(node!.stdout);
    expect(node.exitCode, 0, reason: '${node.stdout}\n${node.stderr}');
  });
}
