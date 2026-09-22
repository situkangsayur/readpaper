import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/layout_size.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/entities/library_index.dart';
import '../../domain/entities/zotero_collection.dart';
import '../controllers/library_controllers.dart';

/// The Zotero collection tree: expandable, with item counts, plus the
/// "all items" / "unfiled" pseudo-collections.
class CollectionTreePane extends ConsumerWidget {
  const CollectionTreePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(workspaceControllerProvider).index;
    if (index == null) return const SizedBox.shrink();

    final selection = ref.watch(selectionProvider);
    final expanded = ref.watch(expandedCollectionsProvider);
    final expandedController = ref.read(expandedCollectionsProvider.notifier);
    final selectionController = ref.read(selectionProvider.notifier);

    final rows = <Widget>[
      _TreeRow(
        label: 'Semua item',
        icon: Icons.inbox_outlined,
        count: index.itemCount,
        depth: 0,
        selected: selection.kind == SelectionKind.all,
        onTap: () => selectionController.select(const LibrarySelection.all()),
      ),
      if (index.unfiledItemKeys.isNotEmpty)
        _TreeRow(
          label: 'Tanpa koleksi',
          icon: Icons.folder_off_outlined,
          count: index.unfiledItemKeys.length,
          depth: 0,
          selected: selection.kind == SelectionKind.unfiled,
          onTap: () => selectionController.select(const LibrarySelection.unfiled()),
        ),
      const Divider(height: 12),
    ];

    void addNode(CollectionNode node, int depth) {
      final isExpanded = expanded.contains(node.key);
      rows.add(
        _TreeRow(
          label: node.name,
          icon: isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined,
          count: node.totalItemCount,
          depth: depth,
          selected:
              selection.kind == SelectionKind.collection && selection.collectionKey == node.key,
          hasChildren: node.children.isNotEmpty,
          isExpanded: isExpanded,
          onToggle: () => expandedController.toggle(node.key),
          onTap: () => selectionController.select(LibrarySelection.collection(node.key)),
        ),
      );
      if (!isExpanded) return;
      for (final child in node.children) {
        addNode(child, depth + 1);
      }
    }

    for (final root in index.roots) {
      addNode(root, 0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(index: index),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: rows.length,
            itemBuilder: (context, i) => rows[i],
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.index});

  final LibraryIndex index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final includeSub = ref.watch(includeSubcollectionsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(index.library.name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${index.itemCount} item · ${index.collectionCount} koleksi',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: includeSub
                ? 'Sertakan item sub-koleksi: aktif'
                : 'Sertakan item sub-koleksi: nonaktif',
            iconSize: 18,
            icon: Icon(includeSub ? Icons.account_tree : Icons.account_tree_outlined),
            onPressed: ref.read(includeSubcollectionsProvider.notifier).toggle,
          ),
          IconButton(
            tooltip: 'Tutup semua',
            iconSize: 18,
            icon: const Icon(Icons.unfold_less),
            onPressed: ref.read(expandedCollectionsProvider.notifier).collapseAll,
          ),
          IconButton(
            tooltip: 'Buka semua',
            iconSize: 18,
            icon: const Icon(Icons.unfold_more),
            onPressed: () =>
                ref.read(expandedCollectionsProvider.notifier).expandAll(index.collections.keys),
          ),
        ],
      ),
    );
  }
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.label,
    required this.icon,
    required this.count,
    required this.depth,
    required this.selected,
    required this.onTap,
    this.hasChildren = false,
    this.isExpanded = false,
    this.onToggle,
  });

  final String label;
  final IconData icon;
  final int count;
  final int depth;
  final bool selected;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: treeRowHeight,
        padding: EdgeInsets.only(left: 4 + depth * 14.0, right: 8),
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
        child: Row(
          children: <Widget>[
            SizedBox(
              // The chevron is its own tap target, so it needs room of its own
              // on a touch screen or it swallows taps meant for the row.
              width: isTouchPlatform ? 34 : 20,
              child: hasChildren
                  ? InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: treeRowHeight,
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                          size: isTouchPlatform ? 22 : 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : null,
            ),
            Icon(icon, size: 15, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (count > 0)
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
              ),
          ],
        ),
      ),
    );
  }
}
