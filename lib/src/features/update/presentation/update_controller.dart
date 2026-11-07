import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_paths.dart';
import '../data/update_service.dart';
import '../domain/app_release.dart';
import '../domain/install_kind.dart';

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,

  /// Android: pemasang sistem sudah terbuka, menunggu konfirmasi pengguna.
  handedOff,

  /// Linux: berkas baru sudah terpasang, tinggal dibuka ulang.
  ready,
  failed,
}

class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.current = '',
    this.kind = InstallKind.manual,
    this.release,
    this.progress = 0,
    this.error,
    this.autoCheck = true,
    this.skipped,
    this.dismissed = false,
  });

  final UpdatePhase phase;
  final String current;
  final InstallKind kind;
  final AppRelease? release;
  final double progress;
  final UpdateFailure? error;
  final bool autoCheck;

  /// Versi yang dipilih "Lewati versi ini".
  final String? skipped;

  /// "Nanti": kartunya disembunyikan sampai pemeriksaan berikutnya.
  final bool dismissed;

  bool get hasUpdate => release != null && isNewerVersion(release!.version, current);

  /// Kartu pemberitahuan di pojok layar tampil?
  bool get showsCard => switch (phase) {
    UpdatePhase.available => !dismissed && skipped != release?.version,
    UpdatePhase.downloading ||
    UpdatePhase.installing ||
    UpdatePhase.handedOff ||
    UpdatePhase.ready => true,
    // Gagal saat memperbarui ditunjukkan; gagal memeriksa (luring) tidak.
    UpdatePhase.failed => hasUpdate && !dismissed,
    _ => false,
  };

  UpdateState copyWith({
    UpdatePhase? phase,
    String? current,
    InstallKind? kind,
    AppRelease? release,
    double? progress,
    UpdateFailure? error,
    bool clearError = false,
    bool? autoCheck,
    String? skipped,
    bool? dismissed,
  }) => UpdateState(
    phase: phase ?? this.phase,
    current: current ?? this.current,
    kind: kind ?? this.kind,
    release: release ?? this.release,
    progress: progress ?? this.progress,
    error: clearError ? null : error ?? this.error,
    autoCheck: autoCheck ?? this.autoCheck,
    skipped: skipped ?? this.skipped,
    dismissed: dismissed ?? this.dismissed,
  );
}

/// Memberi tahu bila ada rilis baru di GitHub, dan memasangnya dari dalam
/// ReadPaper tanpa mengunduh dan memasang ulang dengan tangan.
class UpdateController extends Notifier<UpdateState> {
  /// Uji integrasi mematikan pemeriksaan otomatis: kartu yang muncul di
  /// tengah uji menutupi tombol yang hendak diketuk.
  static bool automatic = true;

  /// Jeda sesudah aplikasi terbuka, dan selang pemeriksaan berikutnya.
  static const firstDelay = Duration(seconds: 12);
  static const interval = Duration(hours: 6);

  final UpdateService _service = UpdateService();
  Timer? _timer;
  DateTime? _lastCheck;

  @override
  UpdateState build() {
    ref.onDispose(() => _timer?.cancel());
    unawaited(_init());
    return const UpdateState();
  }

  File get _prefsFile => File(p.join(AppPaths.instance.supportDir.path, 'pembaruan.json'));

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    final kind = await UpdateService.detect();
    var auto = true;
    String? skipped;
    try {
      final json = jsonDecode(await _prefsFile.readAsString()) as Map<String, dynamic>;
      auto = json['otomatis'] as bool? ?? true;
      skipped = json['lewati'] as String?;
      final last = json['terakhir'] as String?;
      _lastCheck = last == null ? null : DateTime.tryParse(last);
    } on Object {
      // Belum pernah disimpan.
    }
    state = state.copyWith(current: info.version, kind: kind, autoCheck: auto, skipped: skipped);
    if (!automatic) return;
    _timer = Timer(firstDelay, _autoTick);
  }

  void _autoTick() {
    _timer = Timer(interval, _autoTick);
    if (!state.autoCheck) return;
    final last = _lastCheck;
    // Membuka-tutup aplikasi berkali-kali sehari tidak perlu bertanya ke
    // GitHub setiap kali; batas tanpa token 60 permintaan per jam.
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 1)) return;
    unawaited(check());
  }

  Future<void> _savePrefs() async {
    try {
      await _prefsFile.writeAsString(
        jsonEncode(<String, Object?>{
          'otomatis': state.autoCheck,
          'lewati': state.skipped,
          'terakhir': _lastCheck?.toIso8601String(),
        }),
      );
    } on Object {
      // Preferensi kecil; gagal menyimpannya tidak menghalangi apa pun.
    }
  }

  bool get _busy => switch (state.phase) {
    UpdatePhase.checking ||
    UpdatePhase.downloading ||
    UpdatePhase.installing ||
    UpdatePhase.ready => true,
    _ => false,
  };

  Future<void> check() async {
    if (_busy) return;
    if (state.current.isEmpty) await _init();
    state = state.copyWith(phase: UpdatePhase.checking, clearError: true);
    try {
      final release = await _service.latest();
      _lastCheck = DateTime.now();
      unawaited(_savePrefs());
      final newer = isNewerVersion(release.version, state.current);
      state = state.copyWith(
        phase: newer ? UpdatePhase.available : UpdatePhase.upToDate,
        release: release,
        dismissed: false,
      );
    } on UpdateFailure catch (e) {
      state = state.copyWith(phase: UpdatePhase.failed, error: e);
    }
  }

  void dismiss() => state = state.copyWith(dismissed: true);

  Future<void> skip() async {
    final v = state.release?.version;
    if (v == null) return;
    state = state.copyWith(skipped: v, dismissed: true);
    await _savePrefs();
  }

  Future<void> setAutoCheck(bool value) async {
    state = state.copyWith(autoCheck: value);
    await _savePrefs();
  }

  Future<void> openReleasePage() async {
    final url = state.release?.pageUrl;
    final uri = Uri.parse(
      url == null || url.isEmpty ? 'https://github.com/${UpdateService.repo}/releases/latest' : url,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Mengunduh dan memasang rilis yang ditemukan [check].
  ///
  /// Windows keluar dari aplikasi begitu pemasangnya berjalan; pemanggil
  /// sudah meminta persetujuan untuk itu.
  Future<void> update() async {
    final release = state.release;
    if (release == null || _busy) return;
    final kind = state.kind;
    if (!kind.canInstall) {
      await openReleasePage();
      return;
    }
    final asset = kind.assetIn(release);
    if (asset == null) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        error: const UpdateFailure('tanpa-berkas'),
        dismissed: false,
      );
      return;
    }
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      progress: 0,
      clearError: true,
      dismissed: false,
    );
    try {
      final file = await _service.download(
        asset,
        progress: (v) {
          // Tidak perlu membangun ulang untuk setiap potongan 64 KB.
          if ((v - state.progress).abs() >= 0.01 || v >= 1) {
            state = state.copyWith(progress: v);
          }
        },
      );
      state = state.copyWith(phase: UpdatePhase.installing);
      await _service.install(kind, release, file);
      switch (kind) {
        case InstallKind.windowsSetup:
          exit(0);
        case InstallKind.androidApk:
          state = state.copyWith(phase: UpdatePhase.handedOff);
        default:
          state = state.copyWith(phase: UpdatePhase.ready);
      }
    } on UpdateFailure catch (e) {
      state = state.copyWith(phase: UpdatePhase.failed, error: e);
    } on Object catch (e) {
      state = state.copyWith(phase: UpdatePhase.failed, error: UpdateFailure('$e'));
    }
  }

  Future<void> restart() => UpdateService.relaunch();
}

final updateControllerProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);
