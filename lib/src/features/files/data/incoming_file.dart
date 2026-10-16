import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../office/data/office_loader.dart';

/// Berkas yang dibuka dari aplikasi lain: PDF, EPUB, Word, PowerPoint, Excel,
/// dan OpenDocument (LibreOffice).
///
/// Android menyerahkan berkasnya sebagai `content://` URI yang hanya boleh
/// dibaca selama Activity-nya hidup; sisi Android sudah menyalinnya ke cache,
/// jadi yang sampai ke sini adalah jalur berkas biasa.
class IncomingFile {
  const IncomingFile._();

  static const MethodChannel _channel = MethodChannel('readpaper/berkas-masuk');

  static String? _fromArguments;

  /// Akhiran yang dibuka ReadPaper sendiri saat diserahkan aplikasi lain.
  static bool accepts(String path) {
    final ext = p.extension(path).toLowerCase();
    return const <String>{'.pdf', '.epub', '.xlsx', '.xlsm', '.xls', '.csv'}.contains(ext) ||
        officeExtensions.contains(ext) ||
        odfSheetExtensions.contains(ext);
  }

  /// Berkas dari baris perintah di desktop: argumen pertama yang menunjuk ke
  /// berkas yang bisa dibuka ([accepts]) dan ada. Pengelola berkas di Linux memanggil
  /// `readpaper /jalur/berkas.pdf`, Windows `readpaper.exe "C:\...\berkas.pdf"`.
  /// Tanpa ini "Buka dengan ReadPaper" hanya membuka layar utama.
  static void fromArguments(List<String> args) {
    for (final arg in args) {
      final path = arg.startsWith('file://') ? Uri.parse(arg).toFilePath() : arg;
      if (accepts(path) && File(path).existsSync()) {
        _fromArguments = File(path).absolute.path;
        return;
      }
    }
  }

  /// Berkas yang membuka aplikasi ini, kalau ada. Hanya menjawab sekali.
  static Future<String?> takeInitial() async {
    final fromArguments = _fromArguments;
    if (fromArguments != null) {
      _fromArguments = null;
      return fromArguments;
    }
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
