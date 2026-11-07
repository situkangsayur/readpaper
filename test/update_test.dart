import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/update/data/update_service.dart';
import 'package:readpaper/src/features/update/domain/app_release.dart';
import 'package:readpaper/src/features/update/domain/install_kind.dart';

Map<String, dynamic> _asset(String name, {String? digest}) => <String, dynamic>{
  'name': name,
  'browser_download_url': 'https://example.test/$name',
  'size': 10,
  'digest': ?digest,
};

void main() {
  final github = <String, dynamic>{
    'tag_name': 'v0.35.0',
    'body': 'Pembaruan dari dalam aplikasi',
    'html_url': 'https://github.com/situkangsayur/readpaper/releases/tag/v0.35.0',
    'assets': <dynamic>[
      _asset('pasang-arch.sh'),
      _asset('PKGBUILD'),
      _asset('ReadPaper-0.35.0-ios-unsigned.ipa'),
      _asset('readpaper-0.35.0-linux-x64.tar.gz', digest: 'sha256:abc'),
      _asset('readpaper-0.35.0-windows-x64-setup.exe'),
      _asset('readpaper-0.35.0-windows-x64.zip'),
      _asset('readpaper-google-docs-1.0.0.zip'),
      _asset('readpaper_0.35.0_amd64.deb'),
      _asset('readpaper_v0.35.0.apk'),
    ],
  };

  group('nomor versi', () {
    test('angka, bukan teks', () {
      expect(isNewerVersion('0.10.0', '0.9.9'), isTrue);
      expect(isNewerVersion('0.34.1', '0.34.1'), isFalse);
      expect(isNewerVersion('0.34.0', '0.34.1'), isFalse);
      expect(isNewerVersion('v1.0.0', '0.99.99'), isTrue);
    });

    test('nomor build diabaikan', () {
      expect(compareVersions('0.35.0+79', '0.35.0'), 0);
    });
  });

  test('rilis GitHub: versi tanpa v, sha256 dari digest', () {
    final r = AppRelease.fromGitHub(github);
    expect(r.version, '0.35.0');
    expect(r.asset((n) => n.endsWith('.tar.gz'))!.sha256, 'abc');
    expect(r.asset((n) => n.endsWith('.apk'))!.sha256, isNull);
  });

  test('setiap cara pemasangan mengambil berkasnya sendiri', () {
    final r = AppRelease.fromGitHub(github);
    expect(InstallKind.androidApk.assetIn(r)!.name, 'readpaper_v0.35.0.apk');
    expect(InstallKind.windowsSetup.assetIn(r)!.name, 'readpaper-0.35.0-windows-x64-setup.exe');
    expect(InstallKind.linuxTarball.assetIn(r)!.name, 'readpaper-0.35.0-linux-x64.tar.gz');
    expect(InstallKind.linuxArch.assetIn(r)!.name, 'readpaper-0.35.0-linux-x64.tar.gz');
    expect(InstallKind.linuxDeb.assetIn(r)!.name, 'readpaper_0.35.0_amd64.deb');
    expect(InstallKind.manual.assetIn(r), isNull);
    expect(InstallKind.manual.canInstall, isFalse);
  });

  group('mengenali pemasangan Linux', () {
    Future<ProcessResult> Function(String, List<String>) owner(String? tool) =>
        (cmd, _) async => ProcessResult(0, cmd == tool ? 0 : 1, '', '');

    test('/opt dari pacman, dari dpkg, atau tak dikenal', () async {
      const exe = '/opt/readpaper/readpaper';
      expect(await UpdateService.detectLinux(exe, run: owner('pacman')), InstallKind.linuxArch);
      expect(await UpdateService.detectLinux(exe, run: owner('dpkg')), InstallKind.linuxDeb);
      expect(await UpdateService.detectLinux(exe, run: owner(null)), InstallKind.manual);
    });

    test('folder tarball yang bisa ditulisi; build pengembangan tidak', () async {
      final tmp = Directory.systemTemp.createTempSync('rp_upd_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final dir = Directory(p.join(tmp.path, 'readpaper'))..createSync();
      Directory(p.join(dir.path, 'data')).createSync();
      final exe = p.join(dir.path, 'readpaper');
      File(exe).writeAsStringSync('');
      expect(await UpdateService.detectLinux(exe, run: owner(null)), InstallKind.manual);
      File(p.join(dir.path, 'VERSI')).writeAsStringSync('0.34.1\n');
      expect(await UpdateService.detectLinux(exe, run: owner(null)), InstallKind.linuxTarball);
    });
  });

  test('tarball menggantikan folder pemasangan di tempat', () async {
    final tmp = Directory.systemTemp.createTempSync('rp_upd_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final target = Directory(p.join(tmp.path, 'opt', 'readpaper'))..createSync(recursive: true);
    File(p.join(target.path, 'readpaper')).writeAsStringSync('lama');
    File(p.join(target.path, 'VERSI')).writeAsStringSync('0.34.1\n');
    File(p.join(target.path, 'sisa-lama.txt')).writeAsStringSync('');

    final src = Directory(p.join(tmp.path, 'src', 'readpaper-0.35.0-linux-x64'))
      ..createSync(recursive: true);
    File(p.join(src.path, 'readpaper')).writeAsStringSync('baru');
    File(p.join(src.path, 'VERSI')).writeAsStringSync('0.35.0\n');
    final tar = File(p.join(tmp.path, 'r.tar.gz'));
    final res = await Process.run('tar', <String>[
      '-C',
      src.parent.path,
      '-czf',
      tar.path,
      'readpaper-0.35.0-linux-x64',
    ]);
    expect(res.exitCode, 0);

    await UpdateService.replaceTarballInstall(tar, target);
    expect(File(p.join(target.path, 'readpaper')).readAsStringSync(), 'baru');
    expect(File(p.join(target.path, 'VERSI')).readAsStringSync().trim(), '0.35.0');
    expect(File(p.join(target.path, 'sisa-lama.txt')).existsSync(), isFalse);
    // Tidak ada folder sementara yang tertinggal.
    expect(target.parent.listSync().map((e) => p.basename(e.path)), <String>['readpaper']);
  }, skip: Platform.isWindows);

  group('unduhan', () {
    final bytes = utf8.encode('isi apk');
    final good = sha256.convert(bytes).toString();
    UpdateService service() => UpdateService(
      client: MockClient.streaming((_, _) async => http.StreamedResponse(Stream.value(bytes), 200)),
    );

    test('sha256 cocok: berkasnya utuh', () async {
      final f = await service().download(
        ReleaseAsset(name: 'uji-cocok.apk', url: 'https://x.test/a', size: 7, sha256: good),
      );
      addTearDown(f.deleteSync);
      expect(f.readAsBytesSync(), bytes);
    });

    test('sha256 tidak cocok: ditolak dan dibuang', () async {
      await expectLater(
        service().download(
          const ReleaseAsset(name: 'uji-rusak.apk', url: 'https://x.test/a', size: 7, sha256: '00'),
        ),
        throwsA(isA<UpdateFailure>()),
      );
      expect(
        File(
          p.join(Directory.systemTemp.path, 'readpaper-pembaruan', 'uji-rusak.apk'),
        ).existsSync(),
        isFalse,
      );
    });
  });
}
