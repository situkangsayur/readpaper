import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/l10n.dart';
import '../../../core/utils/app_paths.dart';
import '../../settings/data/datasources/settings_local_datasource.dart';
import '../data/audience_link.dart';
import 'audience_view.dart';
import 'presenter_keys.dart';

/// True bila mesin ini adalah jendela audiens yang dibuat presenter.
///
/// desktop_multi_window menjalankan `main` yang sama untuk setiap jendela
/// baru, dengan argumen `multi_window <id> <argumen jendela>`. Dibaca dari
/// argumen, bukan lewat kanal: jendela utama tidak perlu menunggu apa pun
/// untuk tahu bahwa ia jendela utama.
bool isAudienceWindow(List<String> args) {
  if (args.length < 3 || args.first != 'multi_window') return false;
  try {
    final config = jsonDecode(args[2]);
    return config is Map && config['role'] == 'audiens';
  } on FormatException {
    return false;
  }
}

/// Jendela audiens di desktop (dipanggil dari main bila jendela ini dibuat
/// sebagai layar audiens).
Future<void> runDesktopAudience() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  await AppPaths.init();
  final language = (await const SettingsLocalDataSource().load()).language;
  final controller = AudienceController();
  const toPresenter = WindowMethodChannel(presenterChannel, mode: ChannelMode.unidirectional);
  await const WindowMethodChannel(
    audienceChannel,
    mode: ChannelMode.unidirectional,
  ).setMethodCallHandler((call) async {
    switch (call.method) {
      case 'ready':
        return true;
      // Untuk uji: apa yang sedang tampil di layar audiens.
      case 'describe':
        final s = controller.state.value;
        return jsonEncode(<String, dynamic>{
          'path': s.path,
          'page': s.page,
          'annotations': s.annotations.length,
          'pending': s.pending.length,
          'live': s.live.length,
          'tint': s.tint,
          'blank': s.blank,
          'pointerPage': controller.pointer.head == null ? null : controller.pointer.page,
          'pictures': controller.pictures.value.length,
        });
      case 'message':
        await controller.handle(
          (jsonDecode(call.arguments as String) as Map).cast<String, dynamic>(),
        );
    }
    return null;
  });

  await windowManager.ensureInitialized();
  controller.onClose = () => windowManager.destroy();
  await _placeOnSecondDisplay();

  runApp(
    AudienceApp(
      controller: controller,
      language: language,
      onKey: (key) async {
        if (key == null) {
          await windowManager.setFullScreen(!await windowManager.isFullScreen());
          return;
        }
        try {
          await toPresenter.invokeMethod<void>('key', key.name);
        } on Object {
          // presenter sudah tidak ada
        }
      },
    ),
  );
}

/// Layar audiens di layar eksternal Android (titik masuk mesin kedua).
Future<void> runAndroidAudience() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  await AppPaths.init();
  final language = (await const SettingsLocalDataSource().load()).language;
  final controller = AudienceController();
  const channel = MethodChannel(audienceChannel);
  const toPresenter = MethodChannel(presenterChannel);
  channel.setMethodCallHandler((call) async {
    if (call.method == 'message') {
      await controller.handle(
        (jsonDecode(call.arguments as String) as Map).cast<String, dynamic>(),
      );
    }
    return null;
  });
  // Pesan yang dikirim sebelum titik ini ditahan di sisi native; ini tanda
  // untuk mengirimkannya.
  await toPresenter.invokeMethod<void>('ready');
  runApp(
    AudienceApp(
      controller: controller,
      language: language,
      onKey: (key) async {
        if (key != null) await toPresenter.invokeMethod<void>('key', key.name);
      },
    ),
  );
}

/// Monitor yang bukan monitor utama, sepenuh layar; bila hanya ada satu
/// monitor, jendela biasa yang bisa diseret ke proyektor (F11 untuk layar
/// penuh).
Future<void> _placeOnSecondDisplay() async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    final primary = await screenRetriever.getPrimaryDisplay();
    final other = displays.where((d) => d.id != primary.id).firstOrNull;
    if (other != null) {
      final origin = other.visiblePosition ?? Offset.zero;
      final size = other.visibleSize ?? other.size;
      await windowManager.setBounds(Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height));
      await windowManager.show();
      await windowManager.setFullScreen(true);
      return;
    }
  } on Object catch (e) {
    debugPrint('Monitor kedua tidak terbaca: $e');
  }
  await windowManager.setSize(const Size(1280, 720));
  await windowManager.center();
  await windowManager.show();
}

class AudienceApp extends StatelessWidget {
  const AudienceApp({
    required this.controller,
    required this.language,
    required this.onKey,
    super.key,
  });

  final AudienceController controller;
  final String language;

  /// Tombol clicker; null berarti "ubah layar penuh" (F11 / F).
  final ValueChanged<PresenterKey?> onKey;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ReadPaper',
    locale: localeFor(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(),
    home: Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.f11 ||
            event.logicalKey == LogicalKeyboardKey.keyF) {
          if (!Platform.isAndroid) onKey(null);
          return KeyEventResult.handled;
        }
        final key = presenterKeyFor(event.logicalKey);
        if (key == null) return KeyEventResult.ignored;
        onKey(key);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AudienceView(
          state: controller.state,
          pictures: controller.pictures,
          pointer: controller.pointer,
        ),
      ),
    ),
  );
}
