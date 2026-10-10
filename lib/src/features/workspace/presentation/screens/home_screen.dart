import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/layout_size.dart';
import '../../../library/presentation/controllers/library_controllers.dart';
import 'package:path/path.dart' as p;

import '../../../files/data/incoming_file.dart';
import '../../../files/presentation/file_browser_pane.dart';
import '../../../epub/presentation/epub_reader_screen.dart';
import '../../../reader/presentation/screens/reader_screen.dart';
import '../../../library/presentation/widgets/collection_tree_pane.dart';
import '../../../library/presentation/widgets/item_detail_pane.dart';
import '../../../library/presentation/widgets/item_list_pane.dart';
import '../../../notes/presentation/widgets/note_list_pane.dart';
import '../../../settings/presentation/screens/profiles_screen.dart';
import '../controllers/workspace_controller.dart';
import '../widgets/workspace_bar.dart';
import '../widgets/workspace_placeholders.dart';
import '../../../settings/presentation/widgets/profile_editor_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<String>? _incoming;

  @override
  void initState() {
    super.initState();
    // PDF yang membuka aplikasi ini dari tempat lain — berkas, surel, pesan.
    // Dijalankan setelah bingkai pertama supaya Navigator sudah ada.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final path = await IncomingFile.takeInitial();
      if (path != null && mounted) _openIncoming(path);
    });
    _incoming = IncomingFile.opened.listen((path) {
      if (mounted) _openIncoming(path);
    });
  }

  @override
  void dispose() {
    _incoming?.cancel();
    super.dispose();
  }

  void _openIncoming(String path) {
    if (p.extension(path).toLowerCase() == '.epub') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => EpubReaderScreen(path: path)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          itemKey: '',
          itemFilePath: '',
          attachmentKey: '',
          filePath: path,
          title: p.basenameWithoutExtension(path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceControllerProvider);
    final layout = LayoutSize.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        // Only the app name lives here. Everything else sits in the full-width
        // WorkspaceBar below: the app bar gives its title a fixed box, and a
        // long repository name used to overflow it right over the action icons.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.menu_book_outlined, size: 20),
            const SizedBox(width: 8),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Kelola repositori',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const ProfilesScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // On anything narrower than a tablet in landscape the collection tree
      // costs more width than it is worth, so it moves into a drawer.
      drawer: layout.treeInDrawer && state.hasLibrary
          ? const Drawer(child: SafeArea(child: _TreeAndFiles()))
          : null,
      body: Column(
        children: <Widget>[
          const WorkspaceBar(),
          if (state.error != null) _Banner(message: state.error!, isError: true),
          if (state.message != null) _Banner(message: state.message!, isError: false),
          Expanded(child: _Body(layout: layout)),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.layout});

  final LayoutSize layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);

    if (!state.hasProfile) return const NoProfileView();
    if (!state.isCloned) return const NotClonedView();
    if (state.loadingLibrary && !state.hasLibrary) {
      return const Center(child: _LoadingLibrary());
    }
    if (!state.hasLibrary) return const NoLibraryView();

    // Pohon koleksi punya dua akar, dan panel tengah mengikuti akar yang
    // sedang dipilih: daftar item Zotero untuk paper, daftar catatan untuk
    // catatan. Catatan tidak punya pengarang atau tahun, jadi memakai daftar
    // yang sama hanya menghasilkan kolom kosong.
    final notesSelected = ref.watch(selectionProvider.select((s) => s.isNotes));
    final Widget list = notesSelected ? const NoteListPane() : const ItemListPane();

    switch (layout) {
      case LayoutSize.compact:
        if (notesSelected) return list;
        final selected = ref.watch(selectedItemKeyProvider);
        return selected == null ? const ItemListPane() : const ItemDetailPane();

      // A tablet in portrait has room for the list and the paper side by side,
      // which is the pairing that matters while reading.
      case LayoutSize.medium:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 340, child: list),
            const VerticalDivider(width: 1),
            const Expanded(child: ItemDetailPane()),
          ],
        );

      case LayoutSize.expanded:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(width: 300, child: _TreeAndFiles()),
            const VerticalDivider(width: 1),
            SizedBox(width: 400, child: list),
            const VerticalDivider(width: 1),
            const Expanded(child: ItemDetailPane()),
          ],
        );
    }
  }
}

class _LoadingLibrary extends StatelessWidget {
  const _LoadingLibrary();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
      const SizedBox(height: 16),
      Text('Membaca library…', style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _Banner extends ConsumerWidget {
  const _Banner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError ? scheme.errorContainer : scheme.secondaryContainer;
    final foreground = isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;

    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: <Widget>[
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
            // Galat membuka repo sering selesai di luar aplikasi — git baru
            // dipasang, folder clone dikembalikan — jadi membuka ulang tidak
            // boleh menuntut aplikasinya ditutup dulu.
            // Galat token tidak selesai dengan mencoba lagi: profilnya yang
            // perlu diisi, jadi tombolnya langsung ke sana.
            if (isError && message.toLowerCase().contains('token'))
              TextButton(
                onPressed: () {
                  final profile = ref.read(workspaceControllerProvider).profile;
                  if (profile != null) showProfileEditor(context, ref, existing: profile);
                },
                child: Text('Isi token', style: TextStyle(color: foreground)),
              )
            else if (isError)
              TextButton(
                onPressed: () => ref.read(workspaceControllerProvider.notifier).retryOpen(),
                child: Text('Coba lagi', style: TextStyle(color: foreground)),
              ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: foreground),
              tooltip: 'Tutup',
              onPressed: () => ref.read(workspaceControllerProvider.notifier).clearMessages(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pohon koleksi di atas, penjelajah berkas di bawah.
///
/// Dua hal yang saling melengkapi dan karena itu pantas bersebelahan: yang
/// di atas adalah apa yang sudah ada di library, yang di bawah adalah berkas
/// di perangkat yang belum masuk. Berkas diseret dari bawah ke atas untuk
/// memasukkannya.
class _TreeAndFiles extends StatefulWidget {
  const _TreeAndFiles();

  @override
  State<_TreeAndFiles> createState() => _TreeAndFilesState();
}

class _TreeAndFilesState extends State<_TreeAndFiles> {
  /// Panel berkas terbuka atau terlipat ke bawah.
  ///
  /// Terbuka secara bawaan karena di situlah berkas masuk ke koleksi, tetapi
  /// bisa dilipat: saat sedang menelusuri koleksi, panel berkas hanya
  /// mempersempit pohonnya.
  bool _filesOpen = true;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Expanded(child: const CollectionTreePane()),
      const Divider(height: 1),
      if (_filesOpen)
        Expanded(
          flex: 2,
          child: FileBrowserPane(onToggleCollapsed: () => setState(() => _filesOpen = false)),
        )
      else
        FileBrowserPane(
          collapsed: true,
          onToggleCollapsed: () => setState(() => _filesOpen = true),
        ),
    ],
  );
}
