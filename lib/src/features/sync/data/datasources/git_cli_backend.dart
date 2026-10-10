import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/git_entities.dart';
import '../../domain/json_merge.dart';
import '../../domain/entities/sync_progress.dart';
import '../../domain/repositories/git_backend.dart';
import 'git_locator.dart';

/// Git implementation backed by the system `git` executable.
///
/// Works on Linux/macOS/Windows desktops. SSH uses `GIT_SSH_COMMAND` so a
/// per-profile key can be selected; HTTPS uses a throwaway `GIT_ASKPASS`
/// helper so the token never lands in the remote URL or in `.git/config`.
class GitCliBackend implements GitBackend {
  GitCliBackend({String? gitExecutable}) : gitExecutable = gitExecutable ?? GitLocator.locate();

  /// Biner git yang dipakai. Dicari ulang bila belum ketemu, supaya git yang
  /// baru dipasang langsung terpakai tanpa membuka ulang aplikasi.
  String gitExecutable;

  /// Field separator for `git log --format`; a byte that cannot appear in a
  /// commit subject.
  static final String _logSeparator = String.fromCharCode(1);

  bool? _available;
  bool? _lfsAvailable;

  @override
  Future<bool> isAvailable() async {
    // Hanya "ada" yang diingat. "Tidak ada" diperiksa ulang setiap kali,
    // karena jawabannya berubah begitu git dipasang.
    if (_available == true) return true;
    if (await _runs(gitExecutable)) return _available = true;
    final found = GitLocator.locate();
    if (found != gitExecutable && await _runs(found)) {
      gitExecutable = found;
      return _available = true;
    }
    return false;
  }

  static Future<bool> _runs(String executable) async {
    try {
      final result = await Process.run(executable, <String>['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  String get label => 'git (CLI sistem)';

  @override
  Set<GitTransport> get supportedTransports => <GitTransport>{GitTransport.ssh, GitTransport.https};

  /// Widens the sparse checkout so git materialises this one attachment.
  ///
  /// On a partial clone that also pulls the blob down from the remote, which is
  /// exactly what "open this paper" should cost.
  @override
  Future<GitResult> fetchAttachment({
    required String repoPath,
    required GitAuth auth,
    required String absoluteFilePath,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final file = File(absoluteFilePath);
    if (file.existsSync()) {
      return const GitResult(ok: true, exitCode: 0, message: 'Berkas sudah ada di lokal');
    }

    final relativeDir = p.dirname(p.relative(absoluteFilePath, from: repoPath));
    if (relativeDir.isEmpty || relativeDir == '.') {
      return const GitResult(ok: false, exitCode: 1, message: 'Lokasi berkas tidak dikenali.');
    }

    onProgress?.call(SyncProgress.message('Mengunduh ${p.basename(absoluteFilePath)}…'));
    final result = await _run(
      args: <String>['sparse-checkout', 'add', '/$relativeDir/*'],
      workingDirectory: repoPath,
      auth: auth,
      onProgress: onProgress,
      successMessage: 'Berkas selesai diunduh',
    );
    if (!result.ok) return result;
    if (!file.existsSync()) {
      return const GitResult(
        ok: false,
        exitCode: 1,
        message: 'Berkas tidak ada di repositori ini.',
      );
    }

    // A checked-out LFS file is still just a pointer; pull the one object it
    // names rather than every LFS object in the repository.
    if (_isLfsPointer(file) && await isLfsAvailable()) {
      final relativePath = p.relative(absoluteFilePath, from: repoPath);
      onProgress?.call(const SyncProgress.message('Mengunduh berkas besar (Git LFS)…'));
      final lfs = await _run(
        args: <String>['lfs', 'pull', '--include=$relativePath'],
        workingDirectory: repoPath,
        auth: auth,
        onProgress: onProgress,
        successMessage: 'Berkas selesai diunduh',
      );
      if (!lfs.ok) return lfs;
    }
    return result;
  }

  /// Cheap check for the small text stub Git LFS leaves in the working tree.
  bool _isLfsPointer(File file) {
    try {
      if (file.lengthSync() > 1024) return false;
      return file.readAsStringSync().startsWith('version https://git-lfs');
    } on FileSystemException {
      return false;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<GitResult> checkConnection({required GitAuth auth, String? repoPath}) async {
    final path = repoPath ?? Directory.systemTemp.path;
    final result = await _run(
      args: <String>['ls-remote', '--heads', 'origin'],
      workingDirectory: path,
      auth: auth,
      successMessage: 'Remote terjangkau',
    );
    if (!result.ok) return result;
    final branches = const LineSplitter().convert(result.stdout).where((l) => l.isNotEmpty).length;
    return GitResult(ok: true, exitCode: 0, message: 'Terhubung · $branches branch di remote');
  }

  @override
  Future<bool> isLfsAvailable() async {
    if (_lfsAvailable != null) return _lfsAvailable!;
    try {
      final result = await Process.run(gitExecutable, <String>['lfs', 'version']);
      return _lfsAvailable = result.exitCode == 0;
    } on ProcessException {
      return _lfsAvailable = false;
    }
  }

  /// Sparse patterns that keep every metadata file but no attachment.
  static const List<String> _sparsePatterns = <String>[
    '/*',
    '!/**/attachments/**',
    '!/**/attachments-lfs/**',
  ];

  @override
  Future<GitResult> clone({
    required String remoteUrl,
    required String targetPath,
    required GitAuth auth,
    String? branch,
    bool lazyAttachments = true,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final parent = Directory(p.dirname(targetPath));
    if (!parent.existsSync()) await parent.create(recursive: true);

    final target = Directory(targetPath);
    if (target.existsSync() && target.listSync().isNotEmpty) {
      return const GitResult(
        ok: false,
        exitCode: 1,
        message: 'Direktori tujuan sudah berisi berkas. Hapus atau pilih lokasi lain.',
      );
    }

    // A Zotero library is mostly PDFs: for one real library that is ~940 MB of
    // clone versus ~23 MB when the blobs are left on the server and fetched per
    // paper. So the default is a partial + sparse clone.
    final result = await _run(
      args: <String>[
        'clone',
        '--progress',
        '--single-branch',
        if (lazyAttachments) ...<String>['--filter=blob:none', '--sparse'],
        if (branch != null && branch.isNotEmpty) ...<String>['--branch', branch],
        remoteUrl,
        targetPath,
      ],
      workingDirectory: parent.path,
      auth: auth,
      onProgress: onProgress,
      successMessage: 'Repositori berhasil di-clone',
    );
    if (!result.ok || !lazyAttachments) return result;

    onProgress?.call(const SyncProgress.message('Menyiapkan berkas metadata…'));
    final sparse = await _run(
      args: <String>['sparse-checkout', 'set', '--no-cone', ..._sparsePatterns],
      workingDirectory: targetPath,
      auth: auth,
      onProgress: onProgress,
      successMessage: 'Metadata siap',
    );
    if (!sparse.ok) return sparse;

    return const GitResult(
      ok: true,
      exitCode: 0,
      message: 'Repositori siap. Lampiran diunduh saat papernya dibuka.',
    );
  }

  @override
  Future<GitRepoStatus> status(String repoPath) async {
    if (!Directory(p.join(repoPath, '.git')).existsSync()) {
      return GitRepoStatus.missing(repoPath);
    }

    final branch = (await _capture(repoPath, <String>['rev-parse', '--abbrev-ref', 'HEAD'])).trim();
    final remote = (await _capture(repoPath, <String>['remote', 'get-url', 'origin'])).trim();
    final porcelain = await _capture(repoPath, <String>[
      'status',
      '--porcelain=v1',
      '--untracked-files=all',
    ]);

    final changes = <GitChange>[];
    for (final line in const LineSplitter().convert(porcelain)) {
      if (line.length < 4) continue;
      changes.add(GitChange(status: line.substring(0, 2), path: line.substring(3).trim()));
    }

    var ahead = 0;
    var behind = 0;
    var hasUpstream = true;
    final counts = await _capture(repoPath, <String>[
      'rev-list',
      '--left-right',
      '--count',
      '@{upstream}...HEAD',
    ]);
    final parts = counts.trim().split(RegExp(r'\s+'));
    if (parts.length == 2) {
      behind = int.tryParse(parts[0]) ?? 0;
      ahead = int.tryParse(parts[1]) ?? 0;
    } else {
      hasUpstream = false;
    }

    final lastCommit = await _capture(repoPath, <String>['log', '-1', '--format=%s%n%cI']);
    final commitLines = const LineSplitter().convert(lastCommit);

    final lazy = await isLazyRepo(repoPath);

    return GitRepoStatus(
      repoPath: repoPath,
      exists: true,
      branch: branch,
      remoteUrl: remote,
      ahead: ahead,
      behind: behind,
      changes: changes,
      lastCommitSubject: commitLines.isNotEmpty ? commitLines.first : '',
      lastCommitDate: commitLines.length > 1 ? DateTime.tryParse(commitLines[1]) : null,
      hasUpstream: hasUpstream,
      lfsAvailable: await isLfsAvailable(),
      lazyAttachments: lazy,
    );
  }

  @override
  Future<GitResult> fetch({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  }) => _run(
    args: <String>['fetch', '--prune', '--progress', 'origin'],
    workingDirectory: repoPath,
    auth: auth,
    onProgress: onProgress,
    successMessage: 'Fetch selesai',
  );

  @override
  Future<GitResult> pull({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final notes = <String>[];
    final recovered = await _recoverInterrupted(repoPath);
    if (recovered != null && !recovered.ok) return recovered;
    if (recovered != null) notes.add(recovered.message);

    var result = await _run(
      args: <String>['pull', '--rebase', '--autostash', '--progress'],
      workingDirectory: repoPath,
      auth: auth,
      onProgress: onProgress,
      successMessage: 'Pull selesai',
    );
    if (!result.ok) {
      // Gagal karena jaringan atau token: tidak ada rebase yang tertinggal,
      // dan pesannya dikembalikan apa adanya.
      if (await _interruptedOperation(repoPath) == null) return result;
      // Gagal karena bentrok: diselesaikan di sini, bukan ditinggal
      // menggantung. Rebase yang ditinggal adalah yang membuat setiap pull
      // berikutnya gagal dengan "there is already a rebase-merge directory".
      final resolved = await _finishRebase(repoPath);
      if (!resolved.ok) return resolved;
      notes.add(resolved.message);
    }
    // --autostash memasang ulang perubahan yang belum di-commit; kalau itu
    // yang bentrok, git meninggalkan penanda konflik di berkasnya.
    final stash = await _resolveUnmerged(repoPath, keepUnstaged: true);
    if (stash != null) notes.add(stash);
    if (notes.isNotEmpty) {
      result = GitResult(
        ok: true,
        exitCode: 0,
        message: <String>['Pull selesai', ...notes].join('. '),
      );
    }

    // Never pull Git LFS objects automatically on a lazy working copy: they are
    // attachments too. One real library holds 136 MB of them in two books, so
    // doing this after every pull is exactly what the sparse checkout avoids.
    if (!await isLazyRepo(repoPath) && await isLfsAvailable()) {
      await lfsPull(repoPath: repoPath, auth: auth, onProgress: onProgress);
    }
    return result;
  }

  // ------------------------------------------------------------ bentrok

  /// Rebase atau merge yang berhenti di tengah: `rebase`, `merge`, atau null.
  Future<String?> _interruptedOperation(String repoPath) async {
    for (final (name, operation) in const <(String, String)>[
      ('rebase-merge', 'rebase'),
      ('rebase-apply', 'rebase'),
      ('MERGE_HEAD', 'merge'),
    ]) {
      final relative = (await _capture(repoPath, <String>['rev-parse', '--git-path', name])).trim();
      if (relative.isEmpty) continue;
      final path = p.isAbsolute(relative) ? relative : p.join(repoPath, relative);
      if (FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound) return operation;
    }
    return null;
  }

  /// Membatalkan rebase atau merge yang ditinggal versi lama, tanpa membuang
  /// apa pun.
  ///
  /// Sebelum dibatalkan, keadaannya dicadangkan sebagai ref
  /// `refs/readpaper/cadangan/<waktu>` — termasuk commit yang sempat dibuat
  /// di tengahnya — dan perubahan yang belum di-commit dipasang ulang setelah
  /// pembatalan. Membatalkan saja akan mengembalikan berkas kerja ke keadaan
  /// sebelum rebase, dan anotasi yang ditulis sesudahnya hilang.
  Future<GitResult?> _recoverInterrupted(String repoPath) async {
    final operation = await _interruptedOperation(repoPath);
    if (operation == null) return null;

    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    final backup = 'refs/readpaper/cadangan/${stamp.substring(0, 14)}';
    await _git(repoPath, <String>['update-ref', backup, 'HEAD']);
    // `stash create` menyimpan berkas kerja sebagai commit tanpa mengubah
    // apa pun. Ia gagal kalau masih ada berkas bentrok di indeks — dan berkas
    // seperti itu memang hanya berisi penanda konflik, bukan pekerjaan.
    // Berkas yang masih bentrok dikembalikan dulu ke versi HEAD: isinya hanya
    // penanda konflik, dan selama ia ada `stash create` menolak bekerja —
    // perubahan lain yang ditulis selama macet ikut tidak tercadang.
    final unmerged = await _unmergedPaths(repoPath);
    if (unmerged.isNotEmpty) {
      await _git(repoPath, <String>['checkout', 'HEAD', '--', ...unmerged]);
    }
    final work = (await _git(repoPath, <String>['stash', 'create'])).stdout.toString().trim();
    if (work.isNotEmpty) await _git(repoPath, <String>['update-ref', '$backup-kerja', work]);

    final abort = await _git(repoPath, <String>[operation, '--abort']);
    if (abort.exitCode != 0) {
      return GitResult(
        ok: false,
        exitCode: abort.exitCode,
        message:
            'Sinkronisasi sebelumnya berhenti di tengah $operation dan tidak bisa dibatalkan '
            'otomatis. Keadaannya dicadangkan di $backup.',
        stderr: abort.stderr.toString(),
      );
    }
    if (work.isNotEmpty) {
      final apply = await _git(repoPath, <String>['stash', 'apply', work]);
      if (apply.exitCode != 0) await _resolveUnmerged(repoPath, keepUnstaged: true);
    }
    return GitResult(
      ok: true,
      exitCode: 0,
      message: 'Sinkronisasi yang dulu berhenti di tengah sudah dipulihkan (cadangan: $backup)',
    );
  }

  /// Menyelesaikan rebase yang berhenti karena bentrok, commit demi commit.
  Future<GitResult> _finishRebase(String repoPath) async {
    final merged = <String>{};
    for (var step = 0; step < 200 && await _interruptedOperation(repoPath) == 'rebase'; step++) {
      final note = await _resolveUnmerged(repoPath, keepUnstaged: false);
      if (note != null) merged.add(note);
      final next = await _git(repoPath, <String>['-c', 'core.editor=true', 'rebase', '--continue']);
      if (next.exitCode == 0) continue;
      if (await _interruptedOperation(repoPath) != 'rebase') break;
      // Commit yang isinya sudah ada di GitHub menjadi kosong setelah
      // digabung, dan rebase berhenti menanyakannya. Dilewati.
      if (await _unmergedPaths(repoPath) case final left when left.isEmpty) {
        final status = await _capture(repoPath, <String>['status', '--porcelain']);
        if (status.trim().isEmpty) {
          await _git(repoPath, <String>['rebase', '--skip']);
          continue;
        }
      }
    }
    if (await _interruptedOperation(repoPath) != null) {
      final failed = await _recoverInterrupted(repoPath);
      return GitResult(
        ok: false,
        exitCode: 1,
        message:
            'Perubahan di sini dan di GitHub bentrok dan tidak bisa disatukan otomatis. '
            'Tidak ada yang hilang: perubahan lokal tetap di commit-nya'
            '${failed == null ? '' : ' (${failed.message})'}.',
      );
    }
    return GitResult(
      ok: true,
      exitCode: 0,
      message: merged.isEmpty ? 'Perubahan lokal dipasang di atas versi GitHub' : merged.join('. '),
    );
  }

  Future<List<String>> _unmergedPaths(String repoPath) async => (await _capture(repoPath, <String>[
    'diff',
    '--name-only',
    '--diff-filter=U',
  ])).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// Menyelesaikan setiap berkas yang bentrok di indeks.
  ///
  /// Tahap 2 adalah versi yang sudah ada di cabang tujuan (GitHub, saat
  /// rebase), tahap 3 versi lokal yang sedang dipasang, tahap 1 versi bersama
  /// terakhir. JSON digabung per kunci ([JsonMerge]). Yang lain:
  /// - di bawah `zotero/` versi GitHub diambil — berkas non-JSON di sana
  ///   (catatan Markdown) ditulis ulang plugin dari datanya;
  /// - di tempat lain versi lokal dipertahankan, dan versi GitHub disimpan di
  ///   sebelahnya sebagai salinan "(versi GitHub)" supaya tidak ada yang hilang.
  ///
  /// [keepUnstaged] untuk bentrok dari --autostash: hasilnya dibiarkan sebagai
  /// perubahan yang belum di-commit, persis seperti sebelum pull.
  Future<String?> _resolveUnmerged(String repoPath, {required bool keepUnstaged}) async {
    final paths = await _unmergedPaths(repoPath);
    if (paths.isEmpty) return null;
    final joined = <String>[];
    final copies = <String>[];
    for (final path in paths) {
      final base = await _stage(repoPath, 1, path);
      final remote = await _stage(repoPath, 2, path);
      final local = await _stage(repoPath, 3, path);
      final file = File(p.join(repoPath, path));
      if (remote == null || local == null) {
        // Satu sisi menghapus, sisi lain mengubah: yang diubah dipertahankan.
        final kept = local ?? remote;
        if (kept == null) {
          await _git(repoPath, <String>['rm', '-q', '--cached', '--', path]);
          continue;
        }
        await file.parent.create(recursive: true);
        await file.writeAsBytes(kept);
      } else {
        final merged = JsonMerge.mergeText(
          base: base == null ? null : utf8.decode(base, allowMalformed: true),
          remote: utf8.decode(remote, allowMalformed: true),
          local: utf8.decode(local, allowMalformed: true),
        );
        if (merged != null) {
          await file.writeAsString(merged);
          joined.add(p.basename(path));
        } else if (p.split(path).first == 'zotero') {
          await file.writeAsBytes(remote);
        } else {
          await file.writeAsBytes(local);
          final copy = _conflictCopyPath(path);
          await File(p.join(repoPath, copy)).writeAsBytes(remote);
          await _git(repoPath, <String>['add', '--sparse', '--', copy]);
          copies.add(p.basename(copy));
        }
      }
      await _git(repoPath, <String>['add', '--sparse', '--', path]);
    }
    if (keepUnstaged) {
      await _git(repoPath, <String>['reset', '-q']);
      // Stash otomatis yang bentrok tidak dibuang git sendiri; sekarang isinya
      // sudah kembali ke berkas kerja.
      final top = await _capture(repoPath, <String>['stash', 'list', '-1', '--format=%gs']);
      if (top.contains('autostash')) await _git(repoPath, <String>['stash', 'drop', '-q']);
    }
    final summary = <String>[
      if (joined.isNotEmpty) 'Digabung otomatis: ${joined.join(', ')}',
      if (copies.isNotEmpty) 'Versi GitHub disimpan sebagai ${copies.join(', ')}',
    ].join('. ');
    return summary.isEmpty ? null : summary;
  }

  static String _conflictCopyPath(String path) {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final dir = p.posix.dirname(path);
    final name = '${p.basenameWithoutExtension(path)} (versi GitHub $day)${p.extension(path)}';
    return dir == '.' ? name : p.posix.join(dir, name);
  }

  Future<List<int>?> _stage(String repoPath, int stage, String path) async {
    try {
      final result = await Process.run(
        gitExecutable,
        <String>['show', ':$stage:$path'],
        workingDirectory: repoPath,
        environment: <String, String>{'GIT_TERMINAL_PROMPT': '0'},
        stdoutEncoding: null,
      );
      return result.exitCode == 0 ? result.stdout as List<int> : null;
    } on ProcessException {
      return null;
    }
  }

  Future<ProcessResult> _git(String repoPath, List<String> args) async {
    try {
      return await Process.run(
        gitExecutable,
        args,
        workingDirectory: repoPath,
        environment: <String, String>{'GIT_TERMINAL_PROMPT': '0', 'LC_ALL': 'C'},
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } on ProcessException catch (e) {
      return ProcessResult(0, 127, '', e.message);
    }
  }

  /// True when this working copy is a partial + sparse clone.
  Future<bool> isLazyRepo(String repoPath) async {
    final filter = (await _capture(repoPath, <String>[
      'config',
      '--get',
      'remote.origin.partialclonefilter',
    ])).trim();
    final sparse = (await _capture(repoPath, <String>[
      'config',
      '--get',
      'core.sparseCheckout',
    ])).trim();
    return filter.isNotEmpty && sparse == 'true';
  }

  @override
  Future<GitResult> commitAll({
    required String repoPath,
    required String message,
    String? authorName,
    String? authorEmail,
    List<String> paths = const <String>[],
  }) async {
    // Commit di tengah rebase yang berhenti adalah cara penanda konflik
    // `<<<<<<<` masuk ke riwayat — terbukti di sebuah laptop: koleksi catatan
    // jadi JSON yang rusak dan tidak terbaca lagi. Rebase-nya dipulihkan dulu.
    final recovered = await _recoverInterrupted(repoPath);
    if (recovered != null && !recovered.ok) return recovered;

    // Clone ramping mengecualikan folder lampiran dari sparse checkout, dan
    // git menolak menambahkan berkas baru di sana tanpa `--sparse` ("outside
    // of your sparse-checkout definition", keluar dengan 1). Itu persis yang
    // dilakukan "Tambahkan ke koleksi": PDF baru di attachments/ — jadi di
    // desktop seluruh commit-nya gagal. `--sparse` ada sejak git 2.34; Debian
    // 12 membawa 2.39 dan Ubuntu 22.04 membawa 2.34.
    final sparse =
        (await _capture(repoPath, <String>['config', '--get', 'core.sparseCheckout'])).trim() ==
        'true';
    final addArgs = <String>[
      'add',
      if (sparse) '--sparse',
      '--',
      if (paths.isEmpty) '.' else ...paths,
    ];
    final add = await _run(args: addArgs, workingDirectory: repoPath, auth: const GitAuth.ssh());
    if (!add.ok) return add;

    final staged = await _capture(repoPath, <String>['diff', '--cached', '--name-only']);
    if (staged.trim().isEmpty) {
      return const GitResult(ok: true, exitCode: 0, message: 'Tidak ada perubahan untuk di-commit');
    }

    final config = <String>[
      if ((authorName ?? '').isNotEmpty) ...<String>['-c', 'user.name=$authorName'],
      if ((authorEmail ?? '').isNotEmpty) ...<String>['-c', 'user.email=$authorEmail'],
    ];

    return _run(
      args: <String>[...config, 'commit', '-m', message],
      workingDirectory: repoPath,
      auth: const GitAuth.ssh(),
      successMessage: 'Commit dibuat',
    );
  }

  @override
  Future<GitResult> push({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final branch = (await _capture(repoPath, <String>['rev-parse', '--abbrev-ref', 'HEAD'])).trim();
    final upstream = (await _capture(repoPath, <String>[
      'rev-parse',
      '--abbrev-ref',
      '--symbolic-full-name',
      '@{upstream}',
    ])).trim();

    return _run(
      args: <String>[
        'push',
        '--progress',
        if (upstream.isEmpty) ...<String>['--set-upstream', 'origin', branch],
      ],
      workingDirectory: repoPath,
      auth: auth,
      onProgress: onProgress,
      successMessage: 'Push selesai',
    );
  }

  @override
  Future<GitResult> lfsPull({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    if (!await isLfsAvailable()) {
      return const GitResult(ok: true, exitCode: 0, message: 'git-lfs tidak terpasang, dilewati');
    }
    return _run(
      args: <String>['lfs', 'pull'],
      workingDirectory: repoPath,
      auth: auth,
      onProgress: onProgress,
      successMessage: 'Berkas LFS diunduh',
    );
  }

  @override
  Future<GitResult> setRemote({required String repoPath, required String remoteUrl}) async {
    final existing = (await _capture(repoPath, <String>['remote'])).trim();
    final hasOrigin = existing.split('\n').map((e) => e.trim()).contains('origin');
    return _run(
      args: hasOrigin
          ? <String>['remote', 'set-url', 'origin', remoteUrl]
          : <String>['remote', 'add', 'origin', remoteUrl],
      workingDirectory: repoPath,
      auth: const GitAuth.ssh(),
      successMessage: 'Remote diperbarui',
    );
  }

  @override
  Future<List<GitCommitInfo>> log({required String repoPath, int limit = 20}) async {
    final raw = await _capture(repoPath, <String>[
      'log',
      '-n',
      '$limit',
      '--format=%H$_logSeparator%s$_logSeparator%an$_logSeparator%cI',
    ]);
    final commits = <GitCommitInfo>[];
    for (final line in const LineSplitter().convert(raw)) {
      final parts = line.split(_logSeparator);
      if (parts.length < 4) continue;
      commits.add(
        GitCommitInfo(
          hash: parts[0],
          subject: parts[1],
          author: parts[2],
          date: DateTime.tryParse(parts[3]) ?? DateTime.now(),
        ),
      );
    }
    return commits;
  }

  // ---------------------------------------------------------------- internals

  Future<String> _capture(String repoPath, List<String> args) async {
    try {
      final result = await Process.run(
        gitExecutable,
        args,
        workingDirectory: repoPath,
        environment: <String, String>{'GIT_TERMINAL_PROMPT': '0'},
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return result.exitCode == 0 ? result.stdout as String : '';
    } on ProcessException {
      return '';
    }
  }

  Future<GitResult> _run({
    required List<String> args,
    required String workingDirectory,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
    String successMessage = '',
  }) async {
    File? askpass;
    try {
      final env = <String, String>{'GIT_TERMINAL_PROMPT': '0', 'LC_ALL': 'C'};

      if (auth.transport == GitTransport.ssh) {
        env['GIT_SSH_COMMAND'] = _sshCommand(auth);
      } else if (auth.hasHttpsCredentials) {
        askpass = await _writeAskpassScript();
        env['GIT_ASKPASS'] = askpass.path;
        env['READPAPER_GIT_USERNAME'] = (auth.httpsUsername ?? '').isNotEmpty
            ? auth.httpsUsername!
            : 'x-access-token';
        env['READPAPER_GIT_TOKEN'] = auth.httpsToken!;
      }

      final process = await Process.start(
        gitExecutable,
        args,
        workingDirectory: workingDirectory,
        environment: env,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stdoutBuffer.writeln(line);
            if (line.trim().isNotEmpty) onProgress?.call(GitProgressParser.parse(line));
          })
          .asFuture<void>();

      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stderrBuffer.writeln(line);
            if (line.trim().isNotEmpty) onProgress?.call(GitProgressParser.parse(line));
          })
          .asFuture<void>();

      final exitCode = await process.exitCode;
      await Future.wait(<Future<void>>[stdoutDone, stderrDone]);

      final ok = exitCode == 0;
      return GitResult(
        ok: ok,
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        message: ok ? successMessage : _friendlyError(stderrBuffer.toString(), exitCode),
      );
    } on ProcessException catch (e) {
      return GitResult(
        ok: false,
        exitCode: -1,
        message: 'git tidak dapat dijalankan: ${e.message}',
      );
    } finally {
      final script = askpass;
      if (script != null && script.existsSync()) {
        try {
          script.parent.deleteSync(recursive: true);
        } on FileSystemException {
          // best effort
        }
      }
    }
  }

  String _sshCommand(GitAuth auth) {
    final parts = <String>[
      'ssh',
      '-o',
      'BatchMode=yes',
      '-o',
      auth.strictHostKeyChecking ? 'StrictHostKeyChecking=yes' : 'StrictHostKeyChecking=accept-new',
    ];
    final key = auth.sshKeyPath;
    if (key != null && key.isNotEmpty) {
      parts.addAll(<String>['-i', _quote(key), '-o', 'IdentitiesOnly=yes']);
    }
    return parts.join(' ');
  }

  String _quote(String value) => value.contains(' ') ? '"$value"' : value;

  /// Writes a short-lived helper that feeds the HTTPS token to git.
  Future<File> _writeAskpassScript() async {
    final dir = await Directory.systemTemp.createTemp('readpaper_git_');
    final file = File(p.join(dir.path, 'askpass.sh'));
    await file.writeAsString(
      '#!/bin/sh\n'
      'case "\$1" in\n'
      "  *[Uu]sername*) printf '%s' \"\$READPAPER_GIT_USERNAME\" ;;\n"
      "  *) printf '%s' \"\$READPAPER_GIT_TOKEN\" ;;\n"
      'esac\n',
    );
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['700', file.path]);
    }
    return file;
  }

  String _friendlyError(String stderr, int exitCode) {
    final lower = stderr.toLowerCase();
    if (lower.contains('permission denied (publickey')) {
      return 'SSH ditolak: kunci tidak diterima GitHub. Periksa path kunci di profil.';
    }
    if (lower.contains('could not read username') || lower.contains('authentication failed')) {
      return 'Autentikasi HTTPS gagal: token kosong atau tidak berlaku.';
    }
    if (lower.contains('repository not found')) {
      return 'Repositori tidak ditemukan atau tidak punya akses.';
    }
    if (lower.contains('conflict')) {
      return 'Ada konflik saat menggabungkan perubahan. Selesaikan konflik di repo lokal.';
    }
    if (lower.contains('could not resolve host') || lower.contains('network is unreachable')) {
      return 'Jaringan tidak tersedia.';
    }
    return stderr
        .split('\n')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => 'git gagal (kode $exitCode)');
  }
}
