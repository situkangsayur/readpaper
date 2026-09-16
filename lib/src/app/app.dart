import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../features/workspace/presentation/controllers/workspace_controller.dart';
import '../features/workspace/presentation/screens/home_screen.dart';
import 'theme.dart';

class ReadPaperApp extends ConsumerWidget {
  const ReadPaperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      workspaceControllerProvider.select((state) => state.settings.themeMode),
    );

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: const HomeScreen(),
    );
  }
}
