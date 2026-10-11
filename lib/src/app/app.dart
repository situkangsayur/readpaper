import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n.dart';

import '../core/constants/app_constants.dart';
import '../features/citation/presentation/controllers/citation_server_controller.dart';
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
    final language = ref.watch(
      workspaceControllerProvider.select((state) => state.settings.language),
    );
    // Didengarkan di sini, bukan di layar pengaturan, supaya server sitasi
    // menyala begitu aplikasi terbuka dan tetap hidup selama aplikasi
    // berjalan. `listen`, bukan `watch`: perubahan statusnya tidak perlu
    // membangun ulang seluruh aplikasi.
    if (CitationServerController.isDesktop) {
      ref.listen(citationServerProvider, (_, _) {});
    }

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
      // Indonesia atau English, dipilih di Pengaturan; "ikuti sistem" jatuh ke
      // Indonesia bila bahasa sistemnya bukan salah satu dari keduanya.
      locale: localeFor(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (device, supported) {
        for (final locale in supported) {
          if (locale.languageCode == device?.languageCode) return locale;
        }
        return const Locale('id');
      },
      // Pesan dari kode tanpa BuildContext (controller, git) ikut bahasa ini.
      builder: (context, child) {
        setCurrentL10n(AppLocalizations.of(context));
        return child ?? const SizedBox.shrink();
      },
      home: const HomeScreen(),
    );
  }
}
