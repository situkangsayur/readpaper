import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_json.dart';
import 'package:readpaper/src/features/library/data/repositories/library_repository_impl.dart';
import 'package:readpaper/src/features/settings/domain/entities/repo_profile.dart';
import 'package:readpaper/src/features/workspace/domain/entities/workspace_state.dart';
import 'package:readpaper/src/features/workspace/presentation/controllers/workspace_controller.dart';

/// Ruang kerja yang sudah membuka repositori asal, tanpa melewati bootstrap.
class _Seeded extends WorkspaceController {
  _Seeded(this._state);

  final WorkspaceState _state;

  @override
  WorkspaceState build() => _state;
}

/// Memindah paper dan koleksi antar dua repositori git sungguhan, lewat
/// controller yang sama dengan yang dipakai layar.
void main() {
  late Directory root;
  late RepoProfile asal;
  late RepoProfile tujuan;

  Future<String> git(String repo, List<String> args) async {
    final r = await Process.run('git', args, workingDirectory: repo);
    expect(r.exitCode, 0, reason: '${args.join(' ')}\n${r.stderr}');
    return r.stdout as String;
  }

  void write(String path, String text) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  Future<RepoProfile> repo(String name, List<Object?> collections) async {
    final dir = p.join(root.path, name);
    final lib = p.join(dir, 'zotero', 'lib');
    write(p.join(lib, 'library.json'), '{"id": 1, "name": "$name", "type": "user"}\n');
    write(
      p.join(lib, 'collections.json'),
      '${const JsonEncoder.withIndent('\t').convert(ZoteroJson.sortKeys(collections))}\n',
    );
    Directory(p.join(lib, 'items')).createSync(recursive: true);
    write(p.join(lib, 'items', '.keep'), '');
    await Process.run('git', <String>['init', '-q', '-b', 'main', dir]);
    await git(dir, <String>['config', 'user.email', 'uji@readpaper.test']);
    await git(dir, <String>['config', 'user.name', 'Uji']);
    await git(dir, <String>['add', '-A']);
    await git(dir, <String>['commit', '-q', '-m', 'awal']);
    return RepoProfile(id: name, name: name, remoteUrl: '', localPath: dir);
  }

  Map<String, Object?> col(String key, String name, String? parent, String path) =>
      <String, Object?>{
        'key': key,
        'name': name,
        'parentKey': parent,
        'path': path,
        'relations': <String, Object?>{},
      };

  void item(String repoDir, String key, List<String> keys, List<String> paths) {
    final lib = p.join(repoDir, 'zotero', 'lib');
    write(
      p.join(lib, 'items', key.substring(0, 2), '$key.json'),
      ZoteroJson.encodeFile(<String, dynamic>{
        'children': <dynamic>[
          <String, dynamic>{
            'itemType': 'attachment',
            'key': 'PDF$key'.substring(0, 8),
            'parentItem': key,
          },
        ],
        'meta': <String, dynamic>{
          'attachments': <dynamic>[
            <String, dynamic>{
              'key': 'PDF$key'.substring(0, 8),
              'files': <dynamic>[
                <String, dynamic>{'path': 'x.pdf'},
              ],
            },
          ],
          'collections': paths,
          'title': 'Paper $key',
        },
        'zotero': <String, dynamic>{
          'key': key,
          'collections': keys,
          'itemType': 'journalArticle',
          'title': 'Paper $key',
        },
      }),
    );
    write(p.join(lib, 'attachments', 'PD', 'PDF$key'.substring(0, 8), 'x.pdf'), '%PDF $key');
  }

  Future<ProviderContainer> openOn(RepoProfile profile) async {
    final repo = const LibraryRepositoryImpl();
    final layout = await repo.detectLayout(profile.localPath);
    final library = layout!.libraries.single;
    final index = await repo.loadLibrary(library);
    final container = ProviderContainer(
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => _Seeded(
            WorkspaceState(
              settings: AppSettings(
                profiles: <RepoProfile>[asal, tujuan],
                activeProfileId: profile.id,
              ),
              profile: profile,
              library: library,
              index: index,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('rp_multirepo_');
    AppPaths.debugOverride(Directory(p.join(root.path, 'app')));
    asal = await repo('pribadi', <Object?>[
      col('PHDPHDPH', 'PhD', null, 'PhD'),
      col('LAINLAIN', 'Lain', null, 'Lain'),
    ]);
    tujuan = await repo('lab', <Object?>[col('ARSIPARS', 'Arsip', null, 'Arsip')]);
    item(asal.localPath, 'AAAAAAAA', <String>['PHDPHDPH'], <String>['PhD']);
    item(asal.localPath, 'BBBBBBBB', <String>['PHDPHDPH', 'LAINLAIN'], <String>['PhD', 'Lain']);
    await git(asal.localPath, <String>['add', '-A']);
    await git(asal.localPath, <String>['commit', '-q', '-m', 'paper']);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('memindah satu paper: commit di kedua repositori, hilang dari asal', () async {
    final container = await openOn(asal);
    final controller = container.read(workspaceControllerProvider.notifier);
    final paper = container.read(workspaceControllerProvider).index!.items['AAAAAAAA']!;
    final targetLibrary = (await controller.otherLibrary(tujuan))!;

    final failure = await controller.transferItem(
      item: paper,
      target: tujuan,
      targetLibrary: targetLibrary,
      collectionKey: 'ARSIPARS',
      move: true,
    );
    expect(failure, isNull);

    expect(
      await git(tujuan.localPath, <String>['log', '-1', '--format=%s']),
      contains('Dipindahkan dari pribadi: Paper AAAAAAAA'),
    );
    expect(
      await git(asal.localPath, <String>['log', '-1', '--format=%s']),
      contains('Dipindahkan ke lab: Paper AAAAAAAA'),
    );
    expect(
      File(
        p.join(tujuan.localPath, 'zotero', 'lib', 'attachments', 'PD', 'PDFAAAAA', 'x.pdf'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(asal.localPath, 'zotero', 'lib', 'items', 'AA', 'AAAAAAAA.json')).existsSync(),
      isFalse,
    );
    expect(
      Directory(
        p.join(asal.localPath, 'zotero', 'lib', 'attachments', 'PD', 'PDFAAAAA'),
      ).existsSync(),
      isFalse,
    );
    expect((await git(tujuan.localPath, <String>['status', '--porcelain'])).trim(), isEmpty);
    expect((await git(asal.localPath, <String>['status', '--porcelain'])).trim(), isEmpty);
  });

  test('memindah koleksi: paper yang juga di koleksi lain tetap di asal', () async {
    final container = await openOn(asal);
    final controller = container.read(workspaceControllerProvider.notifier);
    final targetLibrary = (await controller.otherLibrary(tujuan))!;

    final failure = await controller.transferCollection(
      collectionKey: 'PHDPHDPH',
      target: tujuan,
      targetLibrary: targetLibrary,
      parentKey: null,
      move: true,
    );
    expect(failure, isNull);

    final asalLib = p.join(asal.localPath, 'zotero', 'lib');
    expect(File(p.join(asalLib, 'items', 'AA', 'AAAAAAAA.json')).existsSync(), isFalse);
    final b = ZoteroJson.decodeObject(
      File(p.join(asalLib, 'items', 'BB', 'BBBBBBBB.json')).readAsStringSync(),
    );
    expect((b['zotero'] as Map)['collections'], <String>['LAINLAIN']);
    expect(
      File(p.join(asalLib, 'collections.json')).readAsStringSync(),
      isNot(contains('PHDPHDPH')),
    );
    expect(
      File(p.join(tujuan.localPath, 'zotero', 'lib', 'collections.json')).readAsStringSync(),
      contains('"PhD"'),
    );

    final stats = await controller.repoStats(tujuan);
    expect(stats.items, 2);
    expect(stats.collections, 2, reason: 'Arsip ditambah PhD yang dipindah');
    expect(stats.unsent, 0, reason: 'semuanya sudah di-commit');
    expect(stats.summary, contains('2 item'));
  });

  test('PDF yang belum diunduh: tidak ada yang dipindah, dan alasannya dikatakan', () async {
    File(
      p.join(asal.localPath, 'zotero', 'lib', 'attachments', 'PD', 'PDFAAAAA', 'x.pdf'),
    ).deleteSync();
    Directory(
      p.join(asal.localPath, 'zotero', 'lib', 'attachments', 'PD', 'PDFAAAAA'),
    ).deleteSync();
    final container = await openOn(asal);
    final controller = container.read(workspaceControllerProvider.notifier);
    final paper = container.read(workspaceControllerProvider).index!.items['AAAAAAAA']!;
    final failure = await controller.transferItem(
      item: paper,
      target: tujuan,
      targetLibrary: (await controller.otherLibrary(tujuan))!,
      collectionKey: null,
      move: true,
    );
    expect(failure, contains('belum ada di perangkat ini'));
    expect(
      File(p.join(asal.localPath, 'zotero', 'lib', 'items', 'AA', 'AAAAAAAA.json')).existsSync(),
      isTrue,
    );
  });
}
