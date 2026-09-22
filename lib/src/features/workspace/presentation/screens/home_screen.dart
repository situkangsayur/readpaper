import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/layout_size.dart';
import '../../../library/presentation/controllers/library_controllers.dart';
import '../../../library/presentation/widgets/collection_tree_pane.dart';
import '../../../library/presentation/widgets/item_detail_pane.dart';
import '../../../library/presentation/widgets/item_list_pane.dart';
import '../../../settings/presentation/screens/profiles_screen.dart';
import '../controllers/workspace_controller.dart';
import '../widgets/workspace_bar.dart';
import '../widgets/workspace_placeholders.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          ? const Drawer(child: SafeArea(child: CollectionTreePane()))
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

    switch (layout) {
      case LayoutSize.compact:
        final selected = ref.watch(selectedItemKeyProvider);
        return selected == null ? const ItemListPane() : const ItemDetailPane();

      // A tablet in portrait has room for the list and the paper side by side,
      // which is the pairing that matters while reading.
      case LayoutSize.medium:
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 340, child: ItemListPane()),
            VerticalDivider(width: 1),
            Expanded(child: ItemDetailPane()),
          ],
        );

      case LayoutSize.expanded:
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 300, child: CollectionTreePane()),
            VerticalDivider(width: 1),
            SizedBox(width: 400, child: ItemListPane()),
            VerticalDivider(width: 1),
            Expanded(child: ItemDetailPane()),
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
