import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/audience_state.dart';
import '../presentation/laser_pointer.dart';

// Kanal antarjendela di desktop memakai mode satu arah: satu mesin
// mendaftar sebagai penerima, mesin lain cukup memanggil. Mode bawaannya
// (dua arah) menuntut kedua mesin mendaftar di nama yang sama, dan tanpa itu
// setiap panggilan ditolak dengan CHANNEL_UNREGISTERED.

/// Kanal tempat layar audiens menerima pesan presenter.
const String audienceChannel = 'readpaper/audiens';

/// Kanal tempat presenter menerima tombol yang ditekan di layar audiens —
/// presenter clicker mengirim ke jendela yang sedang fokus, dan itu bisa
/// jendela audiens di monitor kedua.
const String presenterChannel = 'readpaper/presenter';

/// Kanal native Android untuk layar eksternal (Presentation API).
const String androidDisplayChannel = 'readpaper/layar';

/// Tindakan dari tombol clicker / keyboard, dikirim antarjendela.
enum PresenterKey { next, previous, blank, exit }

/// Penghubung presenter ke layar audiens: jendela lain di desktop, layar
/// eksternal (HDMI, USB-C, cast) di Android.
abstract class AudienceLink {
  /// Penghubung untuk platform ini, atau null bila tidak didukung.
  static AudienceLink? forPlatform() {
    if (debugFactory case final factory?) return factory();
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return DesktopAudienceLink();
    }
    if (Platform.isAndroid) return AndroidAudienceLink();
    return null;
  }

  /// Platform ini punya layar audiens (tanpa membuat penghubungnya).
  static bool get isSupported =>
      debugFactory != null ||
      Platform.isLinux ||
      Platform.isWindows ||
      Platform.isMacOS ||
      Platform.isAndroid;

  /// Pengganti untuk uji: `flutter test` hanya menjalankan isolate utama,
  /// jadi jendela kedua yang sungguhan tidak bisa ikut diuji di sana.
  @visibleForTesting
  static AudienceLink Function()? debugFactory;

  /// Membuka layar audiens. False bila gagal (mis. tidak ada layar eksternal
  /// di Android).
  Future<bool> open();

  Future<void> send(Map<String, dynamic> message);

  Future<void> close();

  /// Layar audiens ditutup dari sisinya (jendela ditutup, kabel dicabut).
  Stream<void> get closed;

  /// Tombol clicker yang ditekan saat layar audiens yang sedang fokus.
  Stream<PresenterKey> get keys;
}

/// Jendela audiens di desktop: mesin Flutter kedua lewat desktop_multi_window,
/// yang memindahkan dirinya ke monitor kedua dan menjadi layar penuh.
class DesktopAudienceLink implements AudienceLink {
  WindowController? _window;
  final _closed = StreamController<void>.broadcast();
  final _keys = StreamController<PresenterKey>.broadcast();
  StreamSubscription<void>? _watch;
  static const _toAudience = WindowMethodChannel(audienceChannel, mode: ChannelMode.unidirectional);
  static const _fromAudience = WindowMethodChannel(
    presenterChannel,
    mode: ChannelMode.unidirectional,
  );

  @override
  Stream<void> get closed => _closed.stream;

  @override
  Stream<PresenterKey> get keys => _keys.stream;

  @override
  Future<bool> open() async {
    if (_window != null) return true;
    await _fromAudience.setMethodCallHandler((call) async {
      if (call.method == 'key') {
        final key = PresenterKey.values.where((k) => k.name == call.arguments).firstOrNull;
        if (key != null) _keys.add(key);
      }
      return null;
    });
    _window = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(<String, String>{'role': 'audiens'}),
      ),
    );
    final id = _window!.windowId;
    _watch = onWindowsChanged.listen((_) async {
      final all = await WindowController.getAll();
      if (!all.any((w) => w.windowId == id)) {
        _window = null;
        await _watch?.cancel();
        _closed.add(null);
      }
    });
    // Jendela audiens memberi tahu saat siap menerima pesan.
    for (var i = 0; i < 50; i++) {
      try {
        if (await _toAudience.invokeMethod<bool>('ready') ?? false) return true;
      } on Object {
        // belum siap
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_window == null) return;
    try {
      await _toAudience.invokeMethod<void>('message', jsonEncode(message));
    } on Object catch (e) {
      debugPrint('Layar audiens tidak menerima pesan: $e');
    }
  }

  @override
  Future<void> close() async {
    if (_window == null) return;
    await send(AudienceMessage.close);
    _window = null;
    await _watch?.cancel();
  }
}

/// Layar eksternal Android lewat Presentation API (kode native di
/// MainActivity). Mesin Flutter kedua menjalankan [audienceMain].
class AndroidAudienceLink implements AudienceLink {
  AndroidAudienceLink() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'closed':
          _open = false;
          _closed.add(null);
        case 'key':
          final key = PresenterKey.values.where((k) => k.name == call.arguments).firstOrNull;
          if (key != null) _keys.add(key);
      }
      return null;
    });
  }

  static const _channel = MethodChannel(androidDisplayChannel);
  final _closed = StreamController<void>.broadcast();
  final _keys = StreamController<PresenterKey>.broadcast();
  bool _open = false;

  @override
  Stream<void> get closed => _closed.stream;

  @override
  Stream<PresenterKey> get keys => _keys.stream;

  @override
  Future<bool> open() async {
    _open = await _channel.invokeMethod<bool>('open') ?? false;
    return _open;
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (!_open) return;
    await _channel.invokeMethod<void>('send', jsonEncode(message));
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    await _channel.invokeMethod<void>('close');
  }
}

/// Sisi audiens: menerapkan pesan presenter ke status yang digambar
/// [AudienceView], dan mendekode gambar tempelan.
class AudienceController {
  final ValueNotifier<AudienceState> state = ValueNotifier<AudienceState>(const AudienceState());
  final ValueNotifier<Map<String, ui.Image>> pictures = ValueNotifier<Map<String, ui.Image>>(
    const <String, ui.Image>{},
  );

  /// Penunjuk presenter, dilukis di atas halaman.
  final LaserPointer pointer = LaserPointer();

  /// Dipanggil saat presenter mengakhiri presentasi.
  VoidCallback? onClose;

  Future<void> handle(Map<String, dynamic> message) async {
    switch (message['type']) {
      case 'pictures':
        final decoded = Map<String, ui.Image>.of(pictures.value);
        for (final e in AudienceMessage.picturesOf(message).entries) {
          if (decoded.containsKey(e.key)) continue;
          final codec = await ui.instantiateImageCodec(e.value);
          decoded[e.key] = (await codec.getNextFrame()).image;
        }
        pictures.value = decoded;
      case 'pointer':
        pointer.apply(message);
      case 'close':
        onClose?.call();
      default:
        state.value = AudienceMessage.apply(state.value, message);
    }
  }
}
