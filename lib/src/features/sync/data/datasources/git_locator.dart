import 'dart:io';

import 'package:path/path.dart' as p;

/// Mencari biner git yang bisa dipakai.
///
/// `Process.run('git')` hanya melihat PATH milik proses ReadPaper. Di Windows
/// itu sering tidak memuat folder Git: Git for Windows dipasang tanpa pilihan
/// "add to PATH", dipasang per pengguna, lewat Scoop, atau hanya ikut GitHub
/// Desktop — atau ReadPaper sudah terbuka sebelum PATH diperbarui. Peluncur
/// desktop di Linux dan macOS juga bisa membawa PATH yang lebih pendek dari
/// terminal. Akibatnya sama: "git tidak ada", padahal ada. Jadi setelah PATH,
/// tempat-tempat yang lazim diperiksa satu per satu.
class GitLocator {
  const GitLocator._();

  /// Jalur git yang ditemukan, atau `git` (biar PATH yang menentukan) bila
  /// tidak ada kandidat yang berkasnya ada.
  static String locate({
    Map<String, String>? environment,
    bool Function(String path)? exists,
    List<String> Function(String dir)? listDirs,
    String? operatingSystem,
    String? appDir,
  }) {
    final env = environment ?? Platform.environment;
    final has = exists ?? (path) => File(path).existsSync();
    final dirs =
        listDirs ??
        (dir) {
          final d = Directory(dir);
          if (!d.existsSync()) return const <String>[];
          return d.listSync().whereType<Directory>().map((e) => e.path).toList();
        };
    final os = operatingSystem ?? Platform.operatingSystem;
    final here = appDir ?? p.dirname(Platform.resolvedExecutable);
    for (final candidate in candidates(env, os, dirs, appDir: here)) {
      if (has(candidate)) return candidate;
    }
    return 'git';
  }

  static List<String> candidates(
    Map<String, String> env,
    String os,
    List<String> Function(String dir) listDirs, {
    String? appDir,
  }) {
    if (os == 'windows') {
      final w = p.windows;
      String? at(String key) {
        final value = env[key] ?? env[key.toUpperCase()];
        return value == null || value.isEmpty ? null : value;
      }

      final out = <String>[
        for (final dir in (env['PATH'] ?? env['Path'] ?? '').split(';'))
          if (dir.trim().isNotEmpty) w.join(dir.trim(), 'git.exe'),
        // MinGit yang ikut di zip Windows, di samping readpaper.exe: ReadPaper
        // tetap bisa sinkron walau Git for Windows tidak pernah dipasang.
        if (appDir != null) w.join(appDir, 'git', 'cmd', 'git.exe'),
        for (final key in <String>['ProgramFiles', 'ProgramW6432', 'ProgramFiles(x86)'])
          if (at(key) != null) w.join(at(key)!, 'Git', 'cmd', 'git.exe'),
        if (at('LOCALAPPDATA') != null)
          w.join(at('LOCALAPPDATA')!, 'Programs', 'Git', 'cmd', 'git.exe'),
        if (at('USERPROFILE') != null) ...<String>[
          w.join(at('USERPROFILE')!, 'scoop', 'shims', 'git.exe'),
          w.join(at('USERPROFILE')!, 'scoop', 'apps', 'git', 'current', 'cmd', 'git.exe'),
        ],
      ];
      // GitHub Desktop membawa git sendiri di folder per versi; yang terbaru
      // didahulukan.
      final desktop = at('LOCALAPPDATA');
      if (desktop != null) {
        final versions = listDirs(
          w.join(desktop, 'GitHubDesktop'),
        ).where((d) => w.basename(d).startsWith('app-')).toList()..sort((a, b) => b.compareTo(a));
        for (final version in versions) {
          out.add(w.join(version, 'resources', 'app', 'git', 'cmd', 'git.exe'));
        }
      }
      return out;
    }
    return <String>[
      for (final dir in (env['PATH'] ?? '').split(':'))
        if (dir.trim().isNotEmpty) p.posix.join(dir.trim(), 'git'),
      '/usr/bin/git',
      '/usr/local/bin/git',
      '/opt/homebrew/bin/git',
      '/bin/git',
    ];
  }

  /// Cara memasang git, untuk pesan galat.
  static String installHint([String? operatingSystem]) =>
      switch (operatingSystem ?? Platform.operatingSystem) {
        'windows' =>
          'Git for Windows tidak ditemukan. Pasang dari git-scm.com, atau di PowerShell: '
              'winget install --id Git.Git -e — lalu tekan Coba lagi.',
        'macos' => 'git tidak ditemukan. Jalankan di Terminal: xcode-select --install.',
        _ =>
          'git tidak ditemukan. Pasang git dan git-lfs — CachyOS/Arch: '
              'sudo pacman -S git git-lfs; Debian/Ubuntu: sudo apt install git git-lfs.',
      };
}
