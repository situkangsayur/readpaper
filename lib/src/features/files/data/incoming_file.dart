import 'dart:async';

import 'package:flutter/services.dart';

/// PDF yang dibuka dari aplikasi lain.
///
/// Android menyerahkan berkasnya sebagai `content://` URI yang hanya boleh
/// dibaca selama Activity-nya hidup; sisi Android sudah menyalinnya ke cache,
/// jadi yang sampai ke sini adalah jalur berkas biasa.
class IncomingFile {
  const IncomingFile._();

  static const MethodChannel _channel = MethodChannel('readpaper/berkas-masuk');

  /// Berkas yang membuka aplikasi ini, kalau ada. Hanya menjawab sekali.
  static Future<String?> takeInitial() async {
    try {
      return await _channel.invokeMethod<String>('takeInitialPdf');
    } on MissingPluginException {
      // Desktop dan uji tidak punya sisi Android-nya.
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Berkas yang dibuka saat aplikasinya sudah berjalan.
  static Stream<String> get opened {
    final controller = StreamController<String>.broadcast();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPdf' && call.arguments is String) {
        controller.add(call.arguments as String);
      }
      return null;
    });
    return controller.stream;
  }
}
