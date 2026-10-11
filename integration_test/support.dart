import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:readpaper/src/core/utils/app_paths.dart';

/// Bahan bersama uji ujung ke ujung desktop: library Zotero di repositori git
/// asli (dengan remote bare lokal), PDF bertulisan, pemilih berkas tiruan, dan
/// pembantu menunggu, memotret, serta membaca berkas di repositori.

// ignore: avoid_print
void diag(String m) => print('[diag] $m');

/// PDF satu halaman penuh baris tulisan: seretan di mana pun mengenai kata.
Future<Uint8List> textPdf(String line) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          for (var i = 0; i < 26; i++) pw.Text('$line $i', style: const pw.TextStyle(fontSize: 18)),
        ],
      ),
    ),
  );
  return doc.save();
}

Map<String, dynamic> zoteroItem({
  required String key,
  required String attachmentKey,
  required String title,
  required String lastName,
  required String firstName,
  required String year,
  required List<String> collectionKeys,
  required List<String> collectionPaths,
  required int pdfSize,
}) => <String, dynamic>{
  'children': <dynamic>[
    <String, dynamic>{
      'contentType': 'application/pdf',
      'filename': 'paper.pdf',
      'itemType': 'attachment',
      'key': attachmentKey,
      'linkMode': 'imported_file',
      'parentItem': key,
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
            'path': 'attachments/${attachmentKey.substring(0, 2)}/$attachmentKey/paper.pdf',
            'size': pdfSize,
            'storage': 'git',
          },
        ],
        'key': attachmentKey,
        'linkMode': 'imported_file',
        'status': 'ok',
        'title': 'PDF',
      },
    ],
    'collections': collectionPaths,
    'creators': <dynamic>['$lastName, $firstName'],
    'title': title,
    'year': year,
  },
  'zotero': <String, dynamic>{
    'collections': collectionKeys,
    'creators': <dynamic>[
      <String, dynamic>{'creatorType': 'author', 'firstName': firstName, 'lastName': lastName},
    ],
    'date': year,
    'itemType': 'journalArticle',
    'key': key,
    'publicationTitle': 'Journal of Demo',
    'title': title,
  },
};

/// Library uji di disk: `repo` (clone kerja), `remote` (bare), dan berkas
/// tambahan di luar library untuk dimasukkan lewat pemilih berkas.
class Fixture {
  Fixture._(this.root);

  final Directory root;
  String get repo => p.join(root.path, 'repo');
  String get remote => p.join(root.path, 'remote.git');
  String get library => p.join(repo, 'zotero', 'uji');
  String get outside => p.join(root.path, 'luar');
  String itemFile(String key) => p.join(library, 'items', key.substring(0, 2), '$key.json');

  static Future<ProcessResult> gitIn(String dir, List<String> args) =>
      Process.run('git', args, workingDirectory: dir, runInShell: Platform.isWindows);

  Future<ProcessResult> git(List<String> args) => gitIn(repo, args);

  Future<int> commitCount([String? dir]) async => int.parse(
    ((await gitIn(dir ?? repo, <String>['rev-list', '--count', 'HEAD'])).stdout as String).trim(),
  );

  Future<String> status() async =>
      ((await git(<String>['status', '--porcelain'])).stdout as String).trim();

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  List<Map<String, dynamic>> collections() =>
      (jsonDecode(File(p.join(library, 'collections.json')).readAsStringSync()) as List<dynamic>)
          .cast<Map<String, dynamic>>();

  /// Semua item paper (bukan anotasi, bukan lampiran) beserta isinya.
  List<Map<String, dynamic>> items() => <Map<String, dynamic>>[
    for (final f in Directory(p.join(library, 'items')).listSync(recursive: true))
      if (f is File && f.path.endsWith('.json')) readJson(f.path),
  ];

  static void write(String path, String text) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  static Future<Fixture> create() async {
    final f = Fixture._(Directory.systemTemp.createTempSync('rp_e2e_'));
    final lib = f.library;

    Future<int> pdf(String key, String line) async {
      final path = p.join(lib, 'attachments', key.substring(0, 2), key, 'paper.pdf');
      final bytes = await textPdf(line);
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      return bytes.length;
    }

    write(p.join(lib, 'library.json'), '{"id": 1, "name": "uji", "type": "user"}\n');
    write(
      p.join(lib, 'collections.json'),
      '[\n\t{\n\t\t"key": "COLL0001",\n\t\t"name": "Kripto",\n\t\t"parentKey": null,'
      '\n\t\t"path": "Kripto",\n\t\t"relations": {}\n\t}\n]\n',
    );
    final enc = const JsonEncoder.withIndent('\t');
    write(
      f.itemFile('ITEMKEY1'),
      enc.convert(
        zoteroItem(
          key: 'ITEMKEY1',
          attachmentKey: 'ATTACH01',
          title: 'Migrasi kriptografi pascakuantum',
          lastName: 'Naether',
          firstName: 'Christian',
          year: '2024',
          collectionKeys: <String>['COLL0001'],
          collectionPaths: <String>['Kripto'],
          pdfSize: await pdf('ATTACH01', 'Kriptografi pascakuantum melindungi data jangka panjang'),
        ),
      ),
    );
    write(
      f.itemFile('ITEMKEY2'),
      enc.convert(
        zoteroItem(
          key: 'ITEMKEY2',
          attachmentKey: 'ATTACH02',
          title: 'Sinkronisasi Zotero lewat Git',
          lastName: 'Karisma',
          firstName: 'Hendri',
          year: '2025',
          collectionKeys: <String>[],
          collectionPaths: <String>[],
          pdfSize: await pdf('ATTACH02', 'Setiap anotasi menjadi satu commit di repositori'),
        ),
      ),
    );

    // Berkas di luar library, untuk "tambahkan berkas" dan "impor folder".
    File(p.join(f.outside, 'tambahan.pdf'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(await textPdf('Berkas tambahan dari luar library'));
    final folder = p.join(f.outside, 'bahan-seminar');
    File(p.join(folder, 'slide.pdf'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(await textPdf('Slide seminar'));
    write(p.join(folder, 'data', 'hasil.csv'), 'a,b\n1,2\n');

    await Process.run('git', <String>[
      'init',
      '-q',
      '-b',
      'main',
      f.repo,
    ], runInShell: Platform.isWindows);
    await f.git(<String>['config', 'user.email', 'uji@readpaper.test']);
    await f.git(<String>['config', 'user.name', 'Uji']);
    await f.git(<String>['add', '-A']);
    final init = await f.git(<String>['commit', '-q', '-m', 'awal']);
    expect(init.exitCode, 0, reason: '${init.stderr}');
    await Process.run('git', <String>[
      'clone',
      '-q',
      '--bare',
      f.repo,
      f.remote,
    ], runInShell: Platform.isWindows);
    await f.git(<String>['remote', 'add', 'origin', f.remote]);
    await f.git(<String>['fetch', '-q', 'origin']);
    await f.git(<String>['branch', '-q', '--set-upstream-to=origin/main', 'main']);

    final support = Directory(p.join(f.root.path, 'data'))..createSync();
    AppPaths.debugOverride(support);
    write(
      p.join(support.path, 'config.json'),
      jsonEncode(<String, dynamic>{
        'profiles': <dynamic>[
          <String, dynamic>{
            'id': 'uji',
            'name': 'uji',
            'remoteUrl': f.remote,
            'localPath': f.repo,
            'transport': 'https',
            'branch': 'main',
            'authorName': 'Uji',
            'authorEmail': 'uji@readpaper.test',
            'lazyAttachments': false,
          },
        ],
        'activeProfileId': 'uji',
        'citationServer': false,
      }),
    );
    return f;
  }
}

/// Pemilih berkas tiruan: dialog bawaan Windows tidak bisa diotomasi di CI,
/// jadi jawabannya disiapkan test. Seluruh alur sesudah dialog tetap asli.
final class FakePicker extends FilePickerPlatform {
  final List<List<String>> files = <List<String>>[];
  final List<String?> directories = <String?>[];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    diag('pemilih berkas: $dialogTitle');
    return <PlatformFile>[for (final f in files.removeAt(0)) _PickedFile(f)];
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    diag('pemilih folder: $dialogTitle');
    return directories.removeAt(0);
  }
}

final class _PickedFile extends PlatformFile {
  _PickedFile(String path) : uri = Uri.file(path);

  @override
  final Uri uri;

  @override
  String get name => p.basename(uri.toFilePath());

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => null;

  @override
  Future<int?> length() async => null;

  @override
  Future<Uint8List> readAsBytes() => throw UnimplementedError();

  @override
  Stream<Uint8List> readAsByteStream() => throw UnimplementedError();
}

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
  await shot(tester, 'gagal-menunggu');
  fail('Tidak muncul dalam $seconds detik: $finder');
}

/// Menunggu sampai [check] benar — untuk hasil yang ditulis ke disk atau git.
Future<void> pumpUntilTrue(
  WidgetTester tester,
  FutureOr<bool> Function() check,
  String what, {
  int seconds = 30,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    // Berkas yang sedang ditulis aplikasi bisa terbaca setengah jadi; itu
    // berarti "belum", bukan gagal.
    final ok = await tester.runAsync(() async {
      try {
        return await check();
      } on FormatException {
        return false;
      } on FileSystemException {
        return false;
      }
    });
    if (ok ?? false) return;
  }
  await shot(tester, 'gagal-$what');
  fail('Tidak terjadi dalam $seconds detik: $what');
}

/// Tangkapan layar aplikasi, diunggah CI sebagai artefak.
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
    diag('tangkapan $name gagal: $e');
  }
}

/// Teks yang muncul di SnackBar mana pun saat ini.
String snackText() => find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
    .evaluate()
    .map((e) => (e.widget as Text).data ?? '')
    .join(' ');
