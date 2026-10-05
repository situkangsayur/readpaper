import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'src/app/app.dart';
import 'src/core/utils/app_paths.dart';
import 'src/features/files/data/incoming_file.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Linux dan Windows menyerahkan berkas "Buka dengan" sebagai argumen
  // (`Exec=readpaper %f`); Android lewat kanal `readpaper/berkas-masuk`.
  IncomingFile.fromArguments(args);
  await pdfrxFlutterInitialize();
  final paths = await AppPaths.init();
  await paths.ensureDirs();
  runApp(const ProviderScope(child: ReadPaperApp()));
}
