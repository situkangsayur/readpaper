import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_json.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_item.dart';
import 'package:readpaper/src/features/settings/domain/entities/repo_profile.dart';
import 'package:readpaper/src/features/workspace/domain/entities/workspace_state.dart';
import 'package:readpaper/src/features/workspace/presentation/controllers/workspace_controller.dart';

/// Multi repo di desktop, ujung ke ujung: dua remote git, dua profil, clone,
/// berpindah bolak-balik, ukuran tiap repo, memindah koleksi, lalu mengirim
/// keduanya. Lewat controller yang sama dengan layar dan git sistem yang sama
/// dengan aplikasi — jalan di CI Linux dan Windows.
void main() {
  late Directory root;

  Future<void> git(String dir, List<String> args) async {
    final r = await Process.run('git', args, workingDirectory: dir);
    expect(r.exitCode, 0, reason: '${args.join(' ')}\n${r.stderr}');
  }

  void write(String path, String text) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  /// Remote bare berisi ekspor Zotero kecil: satu koleksi, satu paper.
  Future<String> remote(String name, String collectionKey, String itemKey) async {
    final work = p.join(root.path, 'kerja-$name');
    final lib = p.join(work, 'zotero', name);
    write(p.join(lib, 'library.json'), '{"id": 1, "name": "$name", "type": "user"}\n');
    write(
      p.join(lib, 'collections.json'),
      '${const JsonEncoder.withIndent('\t').convert(ZoteroJson.sortKeys(<Object?>[
        <String, Object?>{'key': collectionKey, 'name': 'Koleksi $name', 'parentKey': null, 'path': 'Koleksi $name', 'relations': <String, Object?>{}},
      ]))}\n',
    );
    write(
      p.join(lib, 'items', itemKey.substring(0, 2), '$itemKey.json'),
      ZoteroJson.encodeFile(<String, dynamic>{
        'children': <dynamic>[],
        'meta': <String, dynamic>{
          'collections': <String>['Koleksi $name'],
          'title': 'Paper $name',
        },
        'zotero': <String, dynamic>{
          'key': itemKey,
          'collections': <String>[collectionKey],
          'itemType': 'journalArticle',
          'title': 'Paper $name',
        },
      }),
    );
    await Process.run('git', <String>['init', '-q', '-b', 'main', work]);
    await git(work, <String>['config', 'user.email', 'uji@readpaper.test']);
    await git(work, <String>['config', 'user.name', 'Uji']);
    await git(work, <String>['add', '-A']);
    await git(work, <String>['commit', '-q', '-m', 'awal']);
    final bare = p.join(root.path, '$name.git');
    await git(root.path, <String>['clone', '-q', '--bare', work, bare]);
    return bare;
  }

  RepoProfile profile(String id, String bare) => RepoProfile(
    id: id,
    name: id,
    remoteUrl: Uri.file(bare).toString(),
    localPath: p.join(root.path, 'clone', id),
    branch: 'main',
    authorName: 'Uji',
    authorEmail: 'uji@readpaper.test',
    lazyAttachments: false,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('rp_profil_');
    AppPaths.debugOverride(Directory(p.join(root.path, 'app')));
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('dua profil: clone, pindah bolak-balik, ukuran, pindah koleksi, kirim', () async {
    final a = profile('pribadi', await remote('pribadi', 'KOLPRIBA', 'AAAAAAAA'));
    final b = profile('lab', await remote('lab', 'KOLLABLA', 'BBBBBBBB'));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctl = container.read(workspaceControllerProvider.notifier);
    await ctl.bootstrap();
    WorkspaceStateView state() => WorkspaceStateView(container.read(workspaceControllerProvider));

    // Profil pertama: belum ada clone → clone → library terbaca.
    await ctl.saveProfile(a);
    await ctl.selectProfile(a.id);
    expect(state().profileId, a.id);
    expect(await ctl.clone(), isTrue, reason: state().error);
    expect(state().titles, <String>['Paper pribadi']);

    // Profil kedua, lalu pindah ke sana.
    await ctl.saveProfile(b);
    await ctl.selectProfile(b.id);
    expect(state().profileId, b.id);
    expect(state().titles, isEmpty, reason: 'belum di-clone');
    expect(await ctl.clone(), isTrue, reason: state().error);
    expect(state().titles, <String>['Paper lab']);

    // Kembali ke yang pertama tanpa clone ulang.
    await ctl.selectProfile(a.id);
    expect(state().titles, <String>['Paper pribadi']);
    expect(state().error, isNull);

    // Ukuran kedua repo, dari repo mana pun yang sedang aktif.
    final statsA = await ctl.repoStats(a);
    final statsB = await ctl.repoStats(b);
    expect(statsA.cloned && statsB.cloned, isTrue);
    expect((statsA.items, statsA.collections), (1, 1));
    expect((statsB.items, statsB.collections), (1, 1));
    expect(statsA.diskBytes, greaterThan(0));

    // Pindahkan koleksi pribadi ke lab, lalu kirim keduanya.
    final targetIndex = await ctl.otherLibrary(b);
    expect(targetIndex, isNotNull);
    final failure = await ctl.transferCollection(
      collectionKey: 'KOLPRIBA',
      target: b,
      targetLibrary: targetIndex!,
      parentKey: null,
      move: true,
    );
    expect(failure, isNull);
    expect(state().titles, isEmpty, reason: 'paper sudah pindah dari pribadi');
    expect(await ctl.push(), isTrue, reason: state().error);

    await ctl.selectProfile(b.id);
    expect(state().titles..sort(), <String>['Paper lab', 'Paper pribadi']);
    expect(await ctl.push(), isTrue, reason: state().error);

    // Remote lab sekarang memuat paper pribadi; remote pribadi tidak lagi.
    final check = p.join(root.path, 'periksa');
    await git(root.path, <String>['clone', '-q', b.remoteUrl, check]);
    expect(
      Directory(
        p.join(check, 'zotero', 'lab', 'items'),
      ).listSync(recursive: true).whereType<File>().map((f) => p.basename(f.path)).toSet(),
      containsAll(<String>['AAAAAAAA.json', 'BBBBBBBB.json']),
    );
  });
}

/// Pandangan ringkas atas state ruang kerja untuk pernyataan uji.
class WorkspaceStateView {
  WorkspaceStateView(this._state);
  final WorkspaceState _state;

  String? get profileId => _state.profile?.id;
  String? get error => _state.error;
  List<String> get titles => <String>[
    for (final item in _state.index?.items.values ?? const <ZoteroItem>[]) item.title,
  ];
}
