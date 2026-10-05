import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../data/citation_server.dart';
import '../../data/citation_token_store.dart';

/// Keadaan server sitasi, seperti yang ditampilkan di pengaturan.
@immutable
class CitationServerStatus {
  const CitationServerStatus({
    this.available = false,
    this.enabled = false,
    this.running = false,
    this.port = CitationServer.defaultPort,
    this.token,
    this.error,
  });

  /// False di Android dan iOS: tidak ada Word atau OnlyOffice desktop di sana
  /// yang bisa memakainya.
  final bool available;
  final bool enabled;
  final bool running;
  final int port;
  final String? token;

  /// Mengapa server tidak berjalan padahal diminta menyala, mis. port dipakai.
  final String? error;

  String get address => 'http://127.0.0.1:$port';

  CitationServerStatus copyWith({
    bool? enabled,
    bool? running,
    int? port,
    String? token,
    String? error,
    bool clearError = false,
  }) => CitationServerStatus(
    available: available,
    enabled: enabled ?? this.enabled,
    running: running ?? this.running,
    port: port ?? this.port,
    token: token ?? this.token,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Menyalakan, mematikan, dan melaporkan server sitasi lokal.
///
/// Dibangun sekali oleh `ReadPaperApp` begitu aplikasi terbuka, supaya Word
/// bisa langsung tersambung tanpa orang harus membuka layar pengaturan dulu.
class CitationServerController extends Notifier<CitationServerStatus> {
  CitationServer? _server;

  /// Semua perubahan dijalankan berurutan. Menekan sakelar dua kali dengan
  /// cepat tidak boleh berakhir dengan dua server berebut satu port.
  Future<void> _queue = Future<void>.value();

  static bool get isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  CitationServerStatus build() {
    if (!isDesktop) return const CitationServerStatus();
    ref.listen<bool>(
      workspaceControllerProvider.select((s) => s.settings.citationServer),
      (_, enabled) => _enqueue(() => _apply(enabled)),
    );
    ref.onDispose(() {
      final server = _server;
      _server = null;
      unawaited(server?.stop());
    });
    Future<void>.microtask(() => _enqueue(_init));
    return const CitationServerStatus(available: true);
  }

  CitationTokenStore get _tokens => CitationTokenStore(ref.read(settingsLocalDataSourceProvider));

  /// Dipanggil dari sakelar di pengaturan.
  Future<void> setEnabled(bool enabled) =>
      ref.read(workspaceControllerProvider.notifier).setCitationServer(enabled);

  /// Mencoba menyalakan lagi, mis. setelah program yang memakai port-nya
  /// ditutup.
  Future<void> retry() => _enqueue(() async {
    if (state.enabled && _server == null) await _start();
  });

  /// Membuat token baru. Server yang sedang berjalan langsung memakainya, jadi
  /// add-in yang masih memegang token lama langsung ditolak.
  Future<void> regenerateToken() => _enqueue(() async {
    try {
      final token = await _tokens.regenerate();
      _server?.token = token;
      state = state.copyWith(token: token, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Token baru tidak bisa disimpan: $e');
    }
  });

  Future<void> _enqueue(Future<void> Function() step) {
    final next = _queue.then((_) => step()).catchError((Object _) {});
    _queue = next;
    return next;
  }

  /// Membaca pilihan dari berkas, bukan dari keadaan workspace: workspace
  /// belum selesai memuat pengaturan saat ini dipanggil, dan nilai bawaannya
  /// akan menyalakan server sesaat padahal sengaja dimatikan.
  Future<void> _init() async {
    final bool enabled;
    try {
      enabled = (await ref.read(settingsRepositoryProvider).load()).citationServer;
      final token = await _tokens.loadOrCreate();
      state = state.copyWith(token: token, enabled: enabled);
    } catch (e) {
      state = state.copyWith(error: 'Pengaturan server sitasi tidak terbaca: $e');
      return;
    }
    if (enabled) await _start();
  }

  Future<void> _apply(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    if (enabled) {
      if (_server == null && state.token != null) await _start();
    } else {
      await _stop();
    }
  }

  Future<void> _start() async {
    final token = state.token;
    if (token == null) return;
    final server = CitationServer(
      source: CitationSource(
        index: () => ref.read(workspaceControllerProvider).index,
        loadDetail: (item) => ref.read(libraryRepositoryProvider).loadItem(item.filePath),
        loadAsset: (path) => rootBundle.loadString('assets/csl/$path'),
        version: await _version(),
      ),
      token: token,
    );
    try {
      await server.start();
      _server = server;
      state = state.copyWith(running: true, port: server.boundPort, clearError: true);
    } on SocketException catch (e) {
      // Jangan sampai aplikasi gagal terbuka hanya karena port-nya dipakai —
      // biasanya ReadPaper lain yang sedang terbuka. Dilaporkan, lalu dibiarkan.
      final reason = e.osError?.message ?? e.message;
      state = state.copyWith(
        running: false,
        error:
            'Port ${CitationServer.defaultPort} sudah dipakai program lain '
            '(mungkin ReadPaper lain yang sedang terbuka). $reason',
      );
    }
  }

  Future<void> _stop() async {
    final server = _server;
    _server = null;
    await server?.stop();
    state = state.copyWith(running: false, clearError: true);
  }

  static Future<String> _version() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return AppConstants.appVersion;
    }
  }
}

final citationServerProvider = NotifierProvider<CitationServerController, CitationServerStatus>(
  CitationServerController.new,
);
