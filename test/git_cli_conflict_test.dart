import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/sync/data/datasources/git_cli_backend.dart';
import 'package:readpaper/src/features/sync/domain/entities/git_entities.dart';
import 'package:readpaper/src/features/sync/domain/json_merge.dart';

/// Dua perangkat, satu repositori — dengan `git` sungguhan.
///
/// Meniru yang terjadi di sebuah laptop: koleksi catatan dibuat di laptop dan
/// di tablet, pull berhenti karena bentrok di `catatan/koleksi.json`, dan
/// versi lama ReadPaper meng-commit penanda konfliknya.
void main() {
  late Directory root;
  late String origin;
  late String laptop;
  late String tablet;
  final backend = GitCliBackend();
  const auth = GitAuth.ssh();

  Future<ProcessResult> git(String dir, List<String> args, {bool check = true}) async {
    final r = await Process.run('git', args, workingDirectory: dir);
    if (check) expect(r.exitCode, 0, reason: '${args.join(' ')}\n${r.stderr}');
    return r;
  }

  String koleksi(List<String> keys) => JsonMerge.encode(<Object?>[
    for (final k in keys) <String, Object?>{'key': k, 'name': 'nama-$k', 'parentKey': null},
  ]);

  void write(String repo, String path, String text) {
    File(p.join(repo, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  Future<void> commit(String repo, String message) async {
    await git(repo, <String>['add', '-A']);
    await git(repo, <String>['commit', '-q', '-m', message]);
  }

  List<String> keysIn(String repo) =>
      (jsonDecode(File(p.join(repo, 'catatan', 'koleksi.json')).readAsStringSync()) as List)
          .map((e) => (e as Map)['key'] as String)
          .toList();

  setUp(() async {
    root = Directory.systemTemp.createTempSync('readpaper_bentrok_');
    origin = p.join(root.path, 'origin.git');
    await Process.run('git', <String>['init', '-q', '--bare', '-b', 'main', origin]);
    final seed = p.join(root.path, 'seed');
    await Process.run('git', <String>['init', '-q', '-b', 'main', seed]);
    for (final dir in <String>[seed]) {
      await git(dir, <String>['config', 'user.email', 'uji@readpaper.test']);
      await git(dir, <String>['config', 'user.name', 'Uji']);
    }
    write(seed, 'catatan/koleksi.json', koleksi(<String>[]));
    write(seed, 'catatan/berkas/catatan.md', '# Catatan\n');
    write(seed, 'zotero/lib/notes/n.md', 'awal\n');
    await commit(seed, 'awal');
    await git(seed, <String>['remote', 'add', 'origin', origin]);
    await git(seed, <String>['push', '-q', 'origin', 'main']);
    laptop = p.join(root.path, 'laptop');
    tablet = p.join(root.path, 'tablet');
    for (final dir in <String>[laptop, tablet]) {
      await Process.run('git', <String>['clone', '-q', origin, dir]);
      await git(dir, <String>['config', 'user.email', 'uji@readpaper.test']);
      await git(dir, <String>['config', 'user.name', 'Uji']);
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('koleksi dari dua perangkat disatukan, tanpa rebase yang tertinggal', () async {
    write(tablet, 'catatan/koleksi.json', koleksi(<String>['79MRPNSW', 'CG89AXRD']));
    await commit(tablet, 'tablet');
    await git(tablet, <String>['push', '-q']);

    write(laptop, 'catatan/koleksi.json', koleksi(<String>['9B4SWSJG']));
    await commit(laptop, 'Membuat koleksi catatan: phd');
    write(laptop, 'catatan/koleksi.json', koleksi(<String>['9B4SWSJG', 'I6KF894R']));
    await commit(laptop, 'Membuat koleksi catatan: proposal');

    final pulled = await backend.pull(repoPath: laptop, auth: auth);
    expect(pulled.ok, isTrue, reason: pulled.message);
    expect(pulled.message, contains('koleksi.json'));
    expect(keysIn(laptop), <String>['79MRPNSW', '9B4SWSJG', 'CG89AXRD', 'I6KF894R']);
    expect(Directory(p.join(laptop, '.git', 'rebase-merge')).existsSync(), isFalse);

    final pushed = await git(laptop, <String>['push', '-q'], check: false);
    expect(pushed.exitCode, 0, reason: 'riwayatnya lurus di atas GitHub: ${pushed.stderr}');
  });

  test('rebase yang macet dari versi lama dipulihkan, lalu pull menyatukan', () async {
    write(tablet, 'catatan/koleksi.json', koleksi(<String>['79MRPNSW']));
    await commit(tablet, 'tablet');
    await git(tablet, <String>['push', '-q']);

    write(laptop, 'catatan/koleksi.json', koleksi(<String>['9B4SWSJG']));
    await commit(laptop, 'Membuat koleksi catatan: phd');
    // Versi lama: pull berhenti di tengah, lalu commit berikutnya ikut
    // membawa penanda konflik.
    await git(laptop, <String>['pull', '--rebase', '-q'], check: false);
    await git(laptop, <String>['add', '-A']);
    await git(laptop, <String>['commit', '-q', '-m', 'Perbarui anotasi dari ReadPaper']);
    expect(File(p.join(laptop, 'catatan', 'koleksi.json')).readAsStringSync(), contains('<<<<<<<'));

    final again = await backend.pull(repoPath: laptop, auth: auth);
    expect(again.ok, isTrue, reason: again.message);
    expect(again.message, contains('dipulihkan'));
    expect(keysIn(laptop), <String>['79MRPNSW', '9B4SWSJG']);
    final refs = await git(laptop, <String>['for-each-ref', 'refs/readpaper/cadangan']);
    expect(refs.stdout as String, isNotEmpty, reason: 'keadaan macetnya dicadangkan');
  });

  test('commit tidak lagi terjadi di tengah rebase yang berhenti', () async {
    write(tablet, 'catatan/koleksi.json', koleksi(<String>['A']));
    await commit(tablet, 'tablet');
    await git(tablet, <String>['push', '-q']);
    write(laptop, 'catatan/koleksi.json', koleksi(<String>['B']));
    await commit(laptop, 'laptop');
    await git(laptop, <String>['pull', '--rebase', '-q'], check: false);

    write(laptop, 'catatan/berkas/catatan.md', '# Catatan\nditulis saat macet\n');
    final committed = await backend.commitAll(repoPath: laptop, message: 'Simpan');
    expect(committed.ok, isTrue, reason: committed.message);
    final log = await git(laptop, <String>['log', '-p', '-3']);
    expect(log.stdout as String, isNot(contains('<<<<<<<')));
    expect(
      File(p.join(laptop, 'catatan', 'berkas', 'catatan.md')).readAsStringSync(),
      contains('ditulis saat macet'),
      reason: 'perubahan yang belum di-commit tidak dibuang saat pemulihan',
    );
  });

  test('catatan Markdown yang bentrok: lokal dipertahankan, versi GitHub disalin', () async {
    write(tablet, 'catatan/berkas/catatan.md', '# Catatan\ndari tablet\n');
    write(tablet, 'zotero/lib/notes/n.md', 'dari plugin\n');
    await commit(tablet, 'tablet');
    await git(tablet, <String>['push', '-q']);
    write(laptop, 'catatan/berkas/catatan.md', '# Catatan\ndari laptop\n');
    write(laptop, 'zotero/lib/notes/n.md', 'dari laptop\n');
    await commit(laptop, 'laptop');

    final pulled = await backend.pull(repoPath: laptop, auth: auth);
    expect(pulled.ok, isTrue, reason: pulled.message);
    expect(
      File(p.join(laptop, 'catatan/berkas/catatan.md')).readAsStringSync(),
      contains('laptop'),
    );
    final copies = Directory(
      p.join(laptop, 'catatan/berkas'),
    ).listSync().map((e) => p.basename(e.path)).where((n) => n.contains('versi GitHub'));
    expect(copies, hasLength(1));
    expect(
      File(p.join(laptop, 'zotero/lib/notes/n.md')).readAsStringSync(),
      'dari plugin\n',
      reason: 'berkas turunan di zotero/ mengikuti GitHub',
    );
  });
}
