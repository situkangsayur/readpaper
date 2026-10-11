import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'src/app/app.dart';
import 'src/core/utils/app_paths.dart';
import 'src/features/files/data/incoming_file.dart';
import 'src/features/presenter/presentation/audience_app.dart';

Future<void> main(List<String> args) async {
  // Jendela audiens mode presenter (desktop) memakai main yang sama, dengan
  // argumen jendelanya sendiri.
  if (isAudienceWindow(args)) {
    await runDesktopAudience();
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  // Linux dan Windows menyerahkan berkas "Buka dengan" sebagai argumen
  // (`Exec=readpaper %f`); Android lewat kanal `readpaper/berkas-masuk`.
  IncomingFile.fromArguments(args);
  await pdfrxFlutterInitialize();
  final paths = await AppPaths.init();
  await paths.ensureDirs();
  runApp(const ProviderScope(child: ReadPaperApp()));
}

/// Titik masuk layar audiens di layar eksternal Android (Presentation API):
/// mesin Flutter kedua yang dibuat MainActivity menjalankan fungsi ini.
@pragma('vm:entry-point')
Future<void> audienceMain() => runAndroidAudience();
