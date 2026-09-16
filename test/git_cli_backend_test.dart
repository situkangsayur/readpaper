import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/sync/data/datasources/git_cli_backend.dart';
import 'package:readpaper/src/features/sync/domain/entities/git_entities.dart';

/// These exercise the real `git` binary, so they are skipped where it is absent.
void main() {
  late Directory repo;
  final backend = GitCliBackend();

  Future<void> git(List<String> args) async {
    final result = await Process.run('git', args, workingDirectory: repo.path);
    expect(result.exitCode, 0, reason: '${args.join(' ')}\n${result.stderr}');
  }

  setUp(() async {
    repo = Directory.systemTemp.createTempSync('readpaper_git_');
    await git(<String>['init', '-q', '-b', 'main']);
    await git(<String>['config', 'user.email', 'uji@readpaper.test']);
    await git(<String>['config', 'user.name', 'Uji']);
    File(p.join(repo.path, 'README.md')).writeAsStringSync('halo\n');
    await git(<String>['add', '-A']);
    await git(<String>['commit', '-q', '-m', 'awal']);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  test('an ordinary clone is not treated as lazy', () async {
    expect(await backend.isLazyRepo(repo.path), isFalse);

    final status = await backend.status(repo.path);
    expect(status.exists, isTrue);
    expect(status.branch, 'main');
    expect(
      status.lazyAttachments,
      isFalse,
      reason: 'a full working copy already holds every attachment',
    );
  });

  test('a partial + sparse working copy is detected as lazy', () async {
    // Both markers together are what a `--filter=blob:none --sparse` clone
    // leaves behind, and what tells the app to fetch attachments per paper.
    await git(<String>['config', 'remote.origin.partialclonefilter', 'blob:none']);
    await git(<String>['config', 'core.sparseCheckout', 'true']);

    expect(await backend.isLazyRepo(repo.path), isTrue);
    expect((await backend.status(repo.path)).lazyAttachments, isTrue);
  });

  test('sparse alone is not enough to call a working copy lazy', () async {
    await git(<String>['config', 'core.sparseCheckout', 'true']);
    expect(
      await backend.isLazyRepo(repo.path),
      isFalse,
      reason: 'without a blob filter the objects are already local',
    );
  });

  test('status reports local edits and the last commit', () async {
    File(p.join(repo.path, 'README.md')).writeAsStringSync('halo lagi\n');
    File(p.join(repo.path, 'baru.txt')).writeAsStringSync('baru\n');

    final status = await backend.status(repo.path);
    expect(status.isDirty, isTrue);
    expect(status.changes.map((c) => c.path), containsAll(<String>['README.md', 'baru.txt']));
    expect(status.lastCommitSubject, 'awal');
  });

  test('commitAll records a commit and leaves the tree clean', () async {
    File(p.join(repo.path, 'README.md')).writeAsStringSync('diubah\n');

    final result = await backend.commitAll(
      repoPath: repo.path,
      message: 'Tambah highlight p.1',
      authorName: 'Hendri',
      authorEmail: 'hendri@readpaper.test',
    );
    expect(result.ok, isTrue, reason: result.message);

    final status = await backend.status(repo.path);
    expect(status.isDirty, isFalse);
    expect(status.lastCommitSubject, 'Tambah highlight p.1');

    final log = await backend.log(repoPath: repo.path, limit: 5);
    expect(log.first.subject, 'Tambah highlight p.1');
    expect(log.first.author, 'Hendri');
  });

  test('commitAll says so when there is nothing to commit', () async {
    final result = await backend.commitAll(repoPath: repo.path, message: 'kosong');
    expect(result.ok, isTrue);
    expect(result.message, contains('Tidak ada perubahan'));
  });

  test('a directory that is not a repository reports as missing', () async {
    final empty = Directory.systemTemp.createTempSync('readpaper_empty_');
    addTearDown(() => empty.deleteSync(recursive: true));

    final status = await backend.status(empty.path);
    expect(status.exists, isFalse);
  });

  test('fetchAttachment is a no-op for a file that is already there', () async {
    final result = await backend.fetchAttachment(
      repoPath: repo.path,
      auth: const GitAuth.ssh(),
      absoluteFilePath: p.join(repo.path, 'README.md'),
    );
    expect(result.ok, isTrue);
    expect(result.message, contains('sudah ada'));
  });
}
