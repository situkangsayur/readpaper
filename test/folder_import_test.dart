import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/files/domain/folder_scan.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_json.dart';
import 'package:readpaper/src/features/notes/presentation/controllers/notes_controller.dart';
import 'package:readpaper/src/features/settings/domain/entities/repo_profile.dart';
import 'package:readpaper/src/features/workspace/presentation/controllers/workspace_controller.dart';

/// Folder yang diseret ke pohon: strukturnya jadi koleksi, semua jenis
/// berkas masuk, lewat controller dan git sungguhan.
void main() {
  late Directory root;
  late Directory source;

  void write(String path, String text) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  Future<void> git(String dir, List<String> args) async {
    final r = await Process.run('git', args, workingDirectory: dir);
    expect(r.exitCode, 0, reason: '${args.join(' ')}\n${r.stderr}');
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('rp_folder_');
    AppPaths.debugOverride(Directory(p.join(root.path, 'app')));
    source = Directory(p.join(root.path, 'Kuliah 2026'));
    write(p.join(source.path, 'silabus.pdf'), '%PDF-1.4 silabus');
    write(p.join(source.path, 'nilai.xlsx'), 'PK-xlsx');
    write(p.join(source.path, 'Minggu 1', 'slide.pptx'), 'pptx');
    write(p.join(source.path, 'Minggu 1', 'foto.jpg'), 'jpg');
    write(p.join(source.path, 'Minggu 1', 'Data', 'hasil.csv'), 'a,b\n1,2\n');
    write(p.join(source.path, '.git', 'config'), 'jangan ikut');
    write(p.join(source.path, '.DS_Store'), 'x');
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('pemindai melewati berkas tersembunyi dan menghitung isinya', () {
    final node = FolderScan.scan(source.path);
    expect(node.name, 'Kuliah 2026');
    expect(node.fileCount, 5);
    expect(node.folderCount, 3);
    expect(node.files.map(p.basename), <String>['nilai.xlsx', 'silabus.pdf']);
    expect(node.children.single.children.single.name, 'Data');
  });

  test('ke Zotero dan ke Catatan: koleksi bertingkat, satu commit, tidak menggandakan', () async {
    final repo = p.join(root.path, 'repo');
    final lib = p.join(repo, 'zotero', 'uji');
    write(p.join(lib, 'library.json'), '{"id": 1, "name": "uji", "type": "user"}\n');
    write(
      p.join(lib, 'collections.json'),
      '${const JsonEncoder.withIndent('\t').convert(ZoteroJson.sortKeys(<Object?>[]))}\n',
    );
    write(p.join(lib, 'items', '.keep'), '');
    await Process.run('git', <String>['init', '-q', '-b', 'main', repo]);
    await git(repo, <String>['config', 'user.email', 'uji@readpaper.test']);
    await git(repo, <String>['config', 'user.name', 'Uji']);
    await git(repo, <String>['add', '-A']);
    await git(repo, <String>['commit', '-q', '-m', 'awal']);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctl = container.read(workspaceControllerProvider.notifier);
    await ctl.bootstrap();
    await ctl.saveProfile(
      RepoProfile(id: 'uji', name: 'uji', remoteUrl: '', localPath: repo, authorName: 'Uji'),
    );
    await ctl.selectProfile('uji');
    expect(container.read(workspaceControllerProvider).index, isNotNull);

    final folder = FolderScan.scan(source.path);
    final progress = <int>[];
    final result = await ctl.importFolderToLibrary(
      folder: folder,
      onProgress: (done, _) => progress.add(done),
    );
    expect(result!.added, 5);
    expect(result.collections, 3);
    expect(result.failed, isEmpty);
    expect(progress.last, 5);

    final index = container.read(workspaceControllerProvider).index!;
    expect(index.collections.values.map((c) => c.path).toSet(), <String>{
      'Kuliah 2026',
      'Kuliah 2026/Minggu 1',
      'Kuliah 2026/Minggu 1/Data',
    });
    final data = index.collections.values.firstWhere((c) => c.name == 'Data');
    final csvItem = index.items.values.firstWhere((i) => i.title == 'hasil');
    expect(csvItem.collectionKeys, <String>[data.key]);
    expect(csvItem.attachments.single.contentType, 'text/csv');

    final log = await Process.run('git', <String>['log', '--oneline'], workingDirectory: repo);
    expect((log.stdout as String).trim().split('\n'), hasLength(2), reason: 'satu commit impor');

    // Impor ulang: koleksi dipakai lagi, tidak ada "Kuliah 2026" kedua.
    final again = await ctl.importFolderToLibrary(folder: folder);
    expect(again!.collections, 0);
    expect(container.read(workspaceControllerProvider).index!.collections, hasLength(3));

    // Ke Catatan.
    await container.read(notesControllerProvider.future);
    final notesResult = await container
        .read(notesControllerProvider.notifier)
        .importFolder(folder: folder);
    expect(notesResult!.added, 5);
    expect(notesResult.collections, 3);
    final notes = container.read(notesControllerProvider).value!;
    expect(notes.collections.map((c) => c.name).toSet(), <String>{
      'Kuliah 2026',
      'Minggu 1',
      'Data',
    });
    expect(notes.items, hasLength(5));
    expect(
      Directory(
        p.join(repo, 'zotero'),
      ).listSync(recursive: true).where((e) => e.path.contains('catatan')),
      isEmpty,
    );
  });
}
