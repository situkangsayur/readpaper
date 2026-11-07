import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../domain/app_release.dart';
import '../domain/install_kind.dart';
import 'update_service.dart';

/// `readpaper --perbarui`: memeriksa rilis GitHub dan memasang yang lebih
/// baru, tanpa antarmuka — dari terminal, skrip, atau uji paket di kontainer.
/// Mengembalikan kode keluar: 0 terbaru atau terpasang, 1 gagal, 2 harus
/// diunduh sendiri.
Future<int> runHeadlessUpdate() async {
  final service = UpdateService();
  try {
    final current = (await PackageInfo.fromPlatform()).version;
    final kind = await UpdateService.detect();
    stdout.writeln('ReadPaper $current (${kind.name})');
    final release = await service.latest();
    if (!isNewerVersion(release.version, current)) {
      stdout.writeln('Sudah versi terbaru (${release.version}).');
      return 0;
    }
    stdout.writeln('Versi baru: ${release.version}');
    final asset = kind.assetIn(release);
    if (!kind.canInstall || asset == null) {
      stdout.writeln('Unduh sendiri dari ${release.pageUrl}');
      return 2;
    }
    var shown = -1;
    final file = await service.download(
      asset,
      progress: (v) {
        final pct = (v * 100).floor() ~/ 10 * 10;
        if (pct != shown) {
          shown = pct;
          stdout.writeln('  mengunduh ${asset.name}: $pct%');
        }
      },
    );
    stdout.writeln('Memasang…');
    await service.install(kind, release, file);
    stdout.writeln(
      kind == InstallKind.windowsSetup
          ? 'Pemasang berjalan; ReadPaper dibuka lagi setelah selesai.'
          : 'ReadPaper ${release.version} terpasang.',
    );
    return 0;
  } on UpdateFailure catch (e) {
    stderr.writeln('Pembaruan gagal: $e');
    return 1;
  }
}
