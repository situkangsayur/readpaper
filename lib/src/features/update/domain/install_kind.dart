import 'app_release.dart';

/// Bagaimana ReadPaper yang sedang berjalan ini terpasang. Itulah yang
/// menentukan berkas rilis mana yang diambil dan bagaimana ia dipasang:
/// paket .deb tidak boleh ditimpa dengan isi tarball, dan sebaliknya.
enum InstallKind {
  /// APK; dipasang lewat pemasang paket Android (pengguna mengonfirmasi).
  androidApk,

  /// Dipasang setup.exe (ada `unins000.exe` di sebelahnya).
  windowsSetup,

  /// Tarball yang dibongkar ke folder yang bisa ditulisi, mis.
  /// `~/.local/opt/readpaper`. Diganti di tempat tanpa hak root.
  linuxTarball,

  /// Paket `readpaper` dari .deb di `/opt/readpaper`.
  linuxDeb,

  /// Paket pacman `readpaper-bin` (CachyOS, Arch, Manjaro).
  linuxArch,

  /// iOS, Windows portabel (zip), build pengembangan, atau pemasangan yang
  /// tidak dikenali: diberi tahu, lalu halaman rilisnya dibuka.
  manual;

  bool get canInstall => this != manual;

  /// Berkas di [release] yang dipasang untuk jenis ini; null bila rilisnya
  /// tidak membawanya (mis. build Windows CI belum selesai).
  ReleaseAsset? assetIn(AppRelease release) => switch (this) {
    androidApk => release.asset((n) => n.endsWith('.apk')),
    windowsSetup => release.asset((n) => n.endsWith('-windows-x64-setup.exe')),
    linuxTarball || linuxArch => release.asset((n) => n.endsWith('-linux-x64.tar.gz')),
    linuxDeb => release.asset((n) => n.endsWith('_amd64.deb')),
    manual => null,
  };
}
