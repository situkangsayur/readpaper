import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'src/app/app.dart';
import 'src/core/utils/app_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  final paths = await AppPaths.init();
  await paths.ensureDirs();
  runApp(const ProviderScope(child: ReadPaperApp()));
}
