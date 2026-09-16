import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/zotero_item.dart';
import '../controllers/library_controllers.dart';

/// The middle pane: every item of the selected collection, with search + sort.
class ItemListPane extends ConsumerWidget {
  const ItemListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visibleItemsProvider);
    final selectedKey = ref.watch(selectedItemKeyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ListHeader(),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Tidak ada item.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return _ItemTile(
                      item: item,
                      selected: item.key == selectedKey,
                      onTap: () =>
                          ref.read(selectedItemKeyProvider.notifier).select(item.key),
                    );
                  },
                ),
        ),
        _ListFooter(count: items.length),
      ],
    );
  }
}

class _ListHeader extends ConsumerStatefulWidget {
  const _ListHeader();

  @override
  ConsumerState<_ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends ConsumerState<_ListHeader> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(searchQueryProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sort = ref.watch(itemSortProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Cari judul, pengarang, tahun, DOI…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).set('');
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).set(value);
                setState(() {});
              },
            ),
          ),
          PopupMenuButton<ItemSort>(
            tooltip: 'Urutkan: ${sort.label}',
            icon: const Icon(Icons.sort, size: 18),
            initialValue: sort,
            onSelected: ref.read(itemSortProvider.notifier).set,
            itemBuilder: (_) => <PopupMenuEntry<ItemSort>>[
              for (final option in ItemSort.values)
                PopupMenuItem<ItemSort>(value: option, child: Text(option.label)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Text('$count item', style: Theme.of(context).textTheme.labelSmall),
  );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.selected, required this.onTap});

  final ZoteroItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attachment = item.primaryReadable;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(itemTypeIcon(item.itemType), size: 16, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      if (attachment != null)
                        _Badge(
                          icon: attachment.isPdf
                              ? Icons.picture_as_pdf_outlined
                              : attachment.isEpub
                              ? Icons.menu_book_outlined
                              : Icons.attach_file,
                          label: attachment.isAvailable ? 'berkas' : 'tidak ada berkas',
                          muted: !attachment.isAvailable,
                        ),
                      if (item.annotationCount > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        _Badge(
                          icon: Icons.format_color_fill_outlined,
                          label: '${item.annotationCount}',
                        ),
                      ],
                      if (item.notes.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 6),
                        _Badge(icon: Icons.sticky_note_2_outlined, label: '${item.notes.length}'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, this.muted = false});

  final IconData icon;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = muted ? scheme.outline : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}

/// Maps a Zotero item type to an icon.
IconData itemTypeIcon(String itemType) => switch (itemType) {
  'journalArticle' => Icons.article_outlined,
  'book' => Icons.menu_book_outlined,
  'bookSection' => Icons.bookmark_outline,
  'conferencePaper' => Icons.groups_outlined,
  'thesis' => Icons.school_outlined,
  'report' => Icons.description_outlined,
  'webpage' => Icons.public,
  'preprint' => Icons.science_outlined,
  'attachment' => Icons.insert_drive_file_outlined,
  _ => Icons.text_snippet_outlined,
};
