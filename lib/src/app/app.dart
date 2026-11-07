import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/frame_guard.dart';
import '../features/notes/presentation/controllers/notes_controller.dart';
import '../features/citation/presentation/controllers/citation_server_controller.dart';
import '../features/workspace/presentation/controllers/disk_watch.dart';
import '../features/workspace/presentation/controllers/workspace_controller.dart';
import '../features/tabs/presentation/document_tabs.dart';
import '../features/workspace/presentation/screens/home_screen.dart';
import '../features/update/presentation/update_controller.dart';
import '../features/update/presentation/update_widgets.dart';
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
    // Paper, folder, dan catatan yang masuk dari luar aplikasi (git pull di
    // terminal, Zotero, pengelola berkas) tampil tanpa menutup aplikasi.
    ref.listen(diskWatchProvider, (_, _) {});
    // Rilis baru di GitHub diberitahukan, dan bisa dipasang dari sini.
    ref.listen(updateControllerProvider, (_, _) {});
    // Letak bilah tab: dipilih dari menu tab atau Pengaturan, disimpan di
    // pengaturan aplikasi.
    final tabs = ref.read(documentTabsProvider.notifier);
    tabs.onBarPositionChanged ??= ref.read(workspaceControllerProvider.notifier).setTabsAtBottom;
    ref.listen(
      workspaceControllerProvider.select((state) => state.settings.tabsAtBottom),
      // Pengaturan dibaca dari disk sesudah bingkai pertama, jadi nilai
      // tersimpannya selalu datang sebagai perubahan.
      (_, atBottom) => tabs.setAtBottom(atBottom),
    );
    // Library dan catatan yang berubah harus tampil, juga bila mesinnya
    // sedang menganggap jendela tersembunyi; lihat [FrameGuard].
    FrameGuard.install();
    ref.listen(workspaceControllerProvider, (_, _) => FrameGuard.kick());
    ref.listen(notesControllerProvider, (_, _) => FrameGuard.kick());

    return MaterialApp(
      title: AppConstants.appName,
      navigatorKey: appNavigatorKey,
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
        return Stack(
          children: <Widget>[
            // Android 15 ke atas menggambar aplikasi di bawah bilah sistem
            // (edge-to-edge). Dengan navigasi gestur bilahnya tipis, jadi
            // nyaris tidak terasa; dengan tiga tombol (kembali, beranda,
            // aplikasi terakhir) bilahnya ~48 dp dan menutupi koleksi, berkas,
            // atau info paling bawah. Satu SafeArea untuk seluruh aplikasi,
            // termasuk dialog dan lembar bawah. Atas tidak: AppBar sudah
            // menanganinya. Di desktop jaraknya nol; di iPhone ini garis
            // beranda.
            ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(top: false, child: child ?? const SizedBox.shrink()),
            ),
            // Lapisan Overlay sendiri: kartunya duduk di atas Navigator,
            // jadi tooltip tombolnya tidak menemukan Overlay milik Navigator.
            Positioned.fill(child: Overlay(initialEntries: <OverlayEntry>[_updateEntry])),
          ],
        );
      },
      // Library jadi tab pertama; dokumen yang dibuka jadi tab di sebelahnya.
      home: const DocumentTabsHost(library: HomeScreen()),
    );
  }
}

/// Satu entri untuk selamanya; isinya ([UpdateOverlay]) membangun ulang
/// dirinya sendiri saat status pembaruan berubah.
final _updateEntry = OverlayEntry(builder: (_) => const UpdateOverlay());
