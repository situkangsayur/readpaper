import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/app_release.dart';
import '../domain/install_kind.dart';

/// Gagal memperbarui, dengan pesan yang bisa ditunjukkan apa adanya.
///
/// [command] diisi bila pemasangan bisa diselesaikan sendiri di terminal
/// (mis. tidak ada polkit untuk meminta kata sandi).
class UpdateFailure implements Exception {
  const UpdateFailure(this.message, {this.command});

  final String message;
  final String? command;

  @override
  String toString() => command == null ? message : '$message\n$command';
}

/// Memeriksa rilis terbaru di GitHub dan memasangnya di atas ReadPaper yang
/// sedang berjalan, dengan berkas yang sesuai cara ia terpasang.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const repo = 'situkangsayur/readpaper';

  /// `READPAPER_RILIS_URL` menunjuk ke JSON rilis lain; dipakai uji (server
  /// lokal) supaya pembaruan bisa dicoba tanpa membuat rilis sungguhan.
  /// Untuk uji integrasi yang menyajikan rilisnya sendiri.
  static String? feedOverride;

  static String get feedUrl {
    final over = feedOverride;
    if (over != null) return over;
    final env = Platform.environment['READPAPER_RILIS_URL'];
    return env != null && env.isNotEmpty
        ? env
        : 'https://api.github.com/repos/$repo/releases/latest';
  }

  static const _android = MethodChannel('readpaper/berkas-masuk');

  Future<AppRelease> latest() async {
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse(feedUrl),
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'ReadPaper',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on Object catch (e) {
      throw UpdateFailure('$e');
    }
    if (res.statusCode != 200) throw UpdateFailure('HTTP ${res.statusCode}');
    return AppRelease.fromGitHub(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  // ── Mengenali pemasangan ──────────────────────────────────────────────

  static Future<InstallKind> detect() async {
    if (Platform.isAndroid) return InstallKind.androidApk;
    final exe = Platform.resolvedExecutable;
    final dir = p.dirname(exe);
    if (Platform.isWindows) {
      // setup.exe meninggalkan pencopot di sebelah program; zip portabel tidak.
      return File(p.join(dir, 'unins000.exe')).existsSync()
          ? InstallKind.windowsSetup
          : InstallKind.manual;
    }
    if (Platform.isLinux) return detectLinux(exe);
    return InstallKind.manual;
  }

  /// Bisa diuji dengan [run] tiruan.
  static Future<InstallKind> detectLinux(
    String exe, {
    Future<ProcessResult> Function(String, List<String>)? run,
  }) async {
    final runner = run ?? _tryRun;
    if (p.dirname(exe) == '/opt/readpaper') {
      if ((await runner('pacman', <String>['-Qqo', exe])).exitCode == 0) {
        return InstallKind.linuxArch;
      }
      if ((await runner('dpkg', <String>['-S', exe])).exitCode == 0) return InstallKind.linuxDeb;
      return InstallKind.manual;
    }
    // Hanya folder tarball (yang membawa VERSI) yang diganti di tempat. Build
    // pengembangan di `build/linux/...` tidak punya berkas itu.
    final dir = Directory(p.dirname(exe));
    if (File(p.join(dir.path, 'VERSI')).existsSync() &&
        Directory(p.join(dir.path, 'data')).existsSync() &&
        _writable(dir.parent)) {
      return InstallKind.linuxTarball;
    }
    return InstallKind.manual;
  }

  static Future<ProcessResult> _tryRun(String cmd, List<String> args) async {
    try {
      return await Process.run(cmd, args);
    } on ProcessException {
      return ProcessResult(0, 127, '', '');
    }
  }

  static bool _writable(Directory dir) {
    try {
      final probe = File(p.join(dir.path, '.readpaper-tulis-$pid'));
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  // ── Mengunduh ─────────────────────────────────────────────────────────

  /// Mengunduh [asset] ke folder sementara dan memeriksa sha256-nya.
  /// [progress] menerima 0..1.
  Future<File> download(ReleaseAsset asset, {void Function(double)? progress}) async {
    final base = Platform.isAndroid ? await getTemporaryDirectory() : Directory.systemTemp;
    final dir = Directory(p.join(base.path, 'readpaper-pembaruan'))..createSync(recursive: true);
    final file = File(p.join(dir.path, asset.name));
    if (file.existsSync()) file.deleteSync();
    final http.StreamedResponse res;
    try {
      res = await _client
          .send(http.Request('GET', Uri.parse(asset.url))..headers['User-Agent'] = 'ReadPaper')
          .timeout(const Duration(seconds: 30));
    } on Object catch (e) {
      throw UpdateFailure('$e');
    }
    if (res.statusCode != 200) throw UpdateFailure('HTTP ${res.statusCode}: ${asset.name}');
    final total = res.contentLength ?? asset.size;
    final sink = file.openWrite();
    final hashOut = _DigestSink();
    final hasher = sha256.startChunkedConversion(hashOut);
    var got = 0;
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        hasher.add(chunk);
        got += chunk.length;
        if (total > 0) progress?.call(got / total);
      }
    } on Object catch (e) {
      await sink.close();
      throw UpdateFailure('$e');
    }
    await sink.close();
    hasher.close();
    final want = asset.sha256;
    if (want != null && hashOut.value.toString() != want.toLowerCase()) {
      file.deleteSync();
      throw UpdateFailure('sha256 ${asset.name} tidak cocok');
    }
    return file;
  }

  // ── Memasang ──────────────────────────────────────────────────────────

  /// Memasang [file] (hasil [download]) untuk [kind]. Untuk Windows dan
  /// Android, pemasang sistem yang mengambil alih: fungsi ini kembali
  /// setelah pemasangnya berjalan, dan pemanggil harus keluar (Windows).
  /// Untuk Linux, berkasnya sudah terpasang saat fungsi ini kembali; versi
  /// baru berjalan setelah [relaunch].
  Future<void> install(InstallKind kind, AppRelease release, File file) async {
    switch (kind) {
      case InstallKind.androidApk:
        final res = await _android.invokeMethod<String>('installApk', file.path);
        if (res == 'izin') throw const UpdateFailure('izin');
      case InstallKind.windowsSetup:
        await _startWindowsSetup(file);
      case InstallKind.linuxTarball:
        await replaceTarballInstall(file, Directory(p.dirname(Platform.resolvedExecutable)));
      case InstallKind.linuxDeb:
        await _installDeb(file);
      case InstallKind.linuxArch:
        await _installArch(release, file);
      case InstallKind.manual:
        throw const UpdateFailure('manual');
    }
  }

  Future<void> _startWindowsSetup(File setup) async {
    // Pemasangan per pengguna (di AppData) diperbarui di tempatnya sendiri;
    // tanpa ini setup senyap memasang salinan kedua di Program Files.
    final local = Platform.environment['LOCALAPPDATA'] ?? '';
    final perUser =
        local.isNotEmpty &&
        p.isWithin(local.toLowerCase(), Platform.resolvedExecutable.toLowerCase());
    final args = <String>[
      '/SILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
      perUser ? '/CURRENTUSER' : '/ALLUSERS',
      // readpaper.iss membuka ReadPaper lagi setelah selesai bila diminta.
      '/RELAUNCH=1',
      // Catatan pemasangan di sebelah setup-nya, untuk menelusuri pembaruan
      // yang tidak selesai.
      '/LOG=${p.join(setup.parent.path, 'setup.log')}',
    ];
    // Lewat Start-Process (ShellExecute), bukan CreateProcess langsung: bila
    // pemasangnya meminta hak administrator, CreateProcess gagal dengan
    // galat 740, sedangkan ShellExecute menampilkan kotak UAC.
    String q(String s) => "'${s.replaceAll("'", "''")}'";
    await Process.start('powershell', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-WindowStyle',
      'Hidden',
      '-Command',
      'Start-Process -FilePath ${q(setup.path)} -ArgumentList ${args.map(q).join(',')}',
    ], mode: ProcessStartMode.detached);
  }

  /// Membongkar [tarball] di sebelah [target], lalu menukar foldernya.
  ///
  /// Program yang sedang berjalan tidak terganggu: Linux tetap membaca berkas
  /// lama yang sudah terbuka, sementara namanya sudah dipakai folder baru.
  static Future<void> replaceTarballInstall(File tarball, Directory target) async {
    final parent = target.parent;
    final staging = Directory(p.join(parent.path, '.readpaper-baru'));
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync();
    final res = await Process.run('tar', <String>['-xzf', tarball.path, '-C', staging.path]);
    if (res.exitCode != 0) {
      staging.deleteSync(recursive: true);
      throw UpdateFailure('tar: ${res.stderr}'.trim());
    }
    // Isi tarball adalah satu folder `readpaper-<versi>-linux-x64/`.
    final inner = staging.listSync().whereType<Directory>().toList();
    final fresh = inner.length == 1 ? inner.single : staging;
    if (!File(p.join(fresh.path, 'readpaper')).existsSync()) {
      staging.deleteSync(recursive: true);
      throw const UpdateFailure('tarball tanpa program readpaper');
    }
    final old = Directory(p.join(parent.path, '.readpaper-lama'));
    if (old.existsSync()) old.deleteSync(recursive: true);
    target.renameSync(old.path);
    try {
      fresh.renameSync(target.path);
    } on FileSystemException {
      old.renameSync(target.path);
      rethrow;
    } finally {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
    }
    try {
      old.deleteSync(recursive: true);
    } on FileSystemException {
      // Tertinggal tidak apa-apa; dibuang pada pembaruan berikutnya.
    }
  }

  Future<void> _installDeb(File deb) async {
    final apt = await _has('apt-get');
    // `apt-get install ./x.deb` sekaligus memasang dependensi baru bila ada.
    final cmd = apt
        ? <String>['apt-get', 'install', '-y', '--allow-downgrades', deb.path]
        : <String>['dpkg', '-i', deb.path];
    await _runElevated(cmd);
  }

  Future<void> _installArch(AppRelease release, File tarball) async {
    // Dibangun persis seperti pasang-arch.sh: PKGBUILD rilisnya, dengan
    // tarball yang sudah diunduh (dan diperiksa) diletakkan di bawah nama yang
    // dicari makepkg, jadi tidak diunduh dua kali. sha256 di PKGBUILD
    // memeriksanya sekali lagi.
    final pkgbuild = release.asset((n) => n == 'PKGBUILD');
    if (pkgbuild == null) throw const UpdateFailure('PKGBUILD tidak ada di rilis');
    if (!await _has('makepkg')) {
      throw const UpdateFailure(
        'makepkg tidak ada',
        command:
            'curl -fsSL https://github.com/$repo/releases/latest/download/pasang-arch.sh | bash',
      );
    }
    final pb = await download(pkgbuild);
    final work = Directory(p.join(tarball.parent.path, 'arch'));
    if (work.existsSync()) work.deleteSync(recursive: true);
    work.createSync();
    pb.copySync(p.join(work.path, 'PKGBUILD'));
    tarball.copySync(p.join(work.path, 'readpaper-bin-${release.version}.tar.gz'));
    final build = await Process.run('makepkg', <String>[
      '-f',
      '--noconfirm',
      '--nodeps',
    ], workingDirectory: work.path);
    if (build.exitCode != 0) {
      throw UpdateFailure('makepkg: ${_tail(build.stderr)}');
    }
    final pkg = work
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).contains('.pkg.tar'))
        .toList();
    if (pkg.isEmpty) throw const UpdateFailure('makepkg tidak menghasilkan paket');
    await _runElevated(<String>['pacman', '-U', '--noconfirm', pkg.first.path]);
  }

  /// Menjalankan [cmd] sebagai root: langsung bila sudah root, lewat pkexec
  /// (kotak kata sandi desktop), atau sudo tanpa kata sandi.
  Future<void> _runElevated(List<String> cmd) async {
    final shown = 'sudo ${cmd.join(' ')}';
    List<String>? full;
    if (_isRoot()) {
      full = cmd;
    } else if (await _has('pkexec') && _hasDisplay()) {
      full = <String>['pkexec', ...cmd];
    } else if ((await _tryRun('sudo', <String>['-n', 'true'])).exitCode == 0) {
      full = <String>['sudo', '-n', ...cmd];
    }
    if (full == null) throw UpdateFailure('tanpa-root', command: shown);
    final res = await Process.run(full.first, full.sublist(1));
    if (res.exitCode == 126 || res.exitCode == 127 && full.first == 'pkexec') {
      // 126: kotak kata sandinya ditutup; 127: tidak ada agen polkit.
      throw UpdateFailure('batal', command: shown);
    }
    if (res.exitCode != 0) {
      throw UpdateFailure('${cmd.first}: ${_tail(res.stderr)}', command: shown);
    }
  }

  static bool _isRoot() {
    try {
      return (Process.runSync('id', <String>['-u']).stdout as String).trim() == '0';
    } on ProcessException {
      return false;
    }
  }

  static bool _hasDisplay() {
    final env = Platform.environment;
    return (env['DISPLAY'] ?? '').isNotEmpty || (env['WAYLAND_DISPLAY'] ?? '').isNotEmpty;
  }

  static Future<bool> _has(String cmd) async =>
      (await _tryRun('sh', <String>['-c', 'command -v $cmd'])).exitCode == 0;

  static String _tail(Object? text) {
    final lines = '$text'.trim().split('\n');
    return lines.skip(lines.length > 6 ? lines.length - 6 : 0).join('\n');
  }

  /// Menutup ReadPaper dan membukanya lagi dari jalur yang sama, kini berisi
  /// versi baru. Hanya Linux; Windows dibuka lagi oleh pemasangnya.
  static Future<Never> relaunch() async {
    final exe = Platform.resolvedExecutable;
    await Process.start('/bin/sh', <String>[
      '-c',
      r'sleep 1; exec "$0"',
      exe,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
