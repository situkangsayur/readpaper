import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/git_entities.dart';
import '../../domain/repositories/git_backend.dart';

/// Git implementation backed by the system `git` executable.
///
/// Works on Linux/macOS/Windows desktops. SSH uses `GIT_SSH_COMMAND` so a
/// per-profile key can be selected; HTTPS uses a throwaway `GIT_ASKPASS`
/// helper so the token never lands in the remote URL or in `.git/config`.
class GitCliBackend implements GitBackend {
  GitCliBackend({this.gitExecutable = 'git'});

  final String gitExecutable;

  /// Field separator for `git log --format`; a byte that cannot appear in a
  /// commit subject.
  static final String _logSeparator = String.fromCharCode(1);

  bool? _available;
  bool? _lfsAvailable;

  @override
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      final result = await Process.run(gitExecutable, <String>['--version']);
      return _available = result.exitCode == 0;
    } on ProcessException {
      return _available = false;
    }
  }

  @override
  String get label => 'git (CLI sistem)';

  @override
  bool get usesLazyAttachments => false;

  @override
  Set<GitTransport> get supportedTransports => <GitTransport>{GitTransport.ssh, GitTransport.https};

  /// The CLI mirror always holds every attachment, so there is nothing to fetch.
  @override
  Future<GitResult> fetchAttachment({
    required String repoPath,
    required GitAuth auth,
    required String absoluteFilePath,
    void Function(String line)? onProgress,
  }) async => File(absoluteFilePath).existsSync()
      ? const GitResult(ok: true, exitCode: 0, message: 'Berkas sudah ada di lokal')
      : const GitResult(
          ok: false,
          exitCode: 1,
          message: 'Berkas belum ada di clone lokal. Jalankan pull (atau LFS pull).',
        );

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

  @override
  Future<GitResult> clone({
    required String remoteUrl,
    required String targetPath,
    required GitAuth auth,
    String? branch,
    void Function(String line)? onProgress,
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

    return _run(
      args: <String>[
        'clone',
        '--progress',
        if (branch != null && branch.isNotEmpty) ...<String>['--branch', branch],
        remoteUrl,
        targetPath,
      ],
      workingDirectory: parent.path,
      auth: auth,
      onProgress: onProgress,
      successMessage: 'Repositori berhasil di-clone',
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
    );
  }

  @override
  Future<GitResult> fetch({
    required String repoPath,
    required GitAuth auth,
    void Function(String line)? onProgress,
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
    void Function(String line)? onProgress,
  }) async {
    final result = await _run(
      args: <String>['pull', '--rebase', '--autostash', '--progress'],
      workingDirectory: repoPath,
      auth: auth,
      onProgress: onProgress,
      successMessage: 'Pull selesai',
    );
    if (!result.ok) return result;
    if (await isLfsAvailable()) {
      await lfsPull(repoPath: repoPath, auth: auth, onProgress: onProgress);
    }
    return result;
  }

  @override
  Future<GitResult> commitAll({
    required String repoPath,
    required String message,
    String? authorName,
    String? authorEmail,
    List<String> paths = const <String>[],
  }) async {
    final addArgs = <String>['add', '--', if (paths.isEmpty) '.' else ...paths];
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
    void Function(String line)? onProgress,
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
    void Function(String line)? onProgress,
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
    void Function(String line)? onProgress,
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
            onProgress?.call(line);
          })
          .asFuture<void>();

      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stderrBuffer.writeln(line);
            onProgress?.call(line);
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
      return GitResult(ok: false, exitCode: -1, message: 'git tidak dapat dijalankan: ${e.message}');
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
