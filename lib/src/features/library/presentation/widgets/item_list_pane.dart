import 'package:collection/collection.dart';
import '../../../../core/utils/file_pick.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reader/presentation/screens/reader_screen.dart';
import '../../domain/entities/zotero_item.dart';
import '../../../../shared/widgets/tree_drag.dart';
import '../controllers/library_controllers.dart';
import '../screens/duplicate_screen.dart';
import '../screens/library_stats_screen.dart';
import 'creator_facet_sheet.dart';
import 'recent_papers_card.dart';
import '../import_actions.dart';
import '../../../files/presentation/open_any_file.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/entities/library_index.dart';

/// The middle pane: every item of the selected collection, with search + sort.
class ItemListPane extends ConsumerWidget {
  const ItemListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visibleItemsProvider);
    final selectedKey = ref.watch(selectedItemKeyProvider);
    // While searching, the history is in the way: the screen was asked a
    // question and should answer it.
    final searching = ref.watch(searchQueryProvider).trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ListHeader(),
        const Divider(height: 1),
        Expanded(
          // Tarik ke bawah = tarik perubahan dari GitHub, seperti aplikasi lain.
          child: RefreshIndicator(
            onRefresh: () => pullToRefresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: <Widget>[
                if (!searching)
                  RecentPapersCard(
                    onOpen: (entry) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReaderScreen(
                          itemKey: entry.itemKey,
                          itemFilePath: entry.itemFilePath,
                          attachmentKey: entry.attachmentKey,
                          filePath: entry.filePath,
                          title: entry.title,
                          subtitle: entry.subtitle,
                        ),
                      ),
                    ),
                  ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Tidak ada item.')),
                  )
                else
                  for (var i = 0; i < items.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    _ItemTile(
                      item: items[i],
                      selected: items[i].key == selectedKey,
                      onTap: () => ref.read(selectedItemKeyProvider.notifier).select(items[i].key),
                    ),
                  ],
              ],
            ),
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

  /// Explains the operators, because nothing on screen hints they exist.
  void _showSearchHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mempersempit pencarian'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Kata biasa dicari di judul, pengarang, jurnal, tag, koleksi, '
                'DOI, dan abstrak. Beberapa kata berarti semuanya harus cocok.',
              ),
              const SizedBox(height: 14),
              for (final row in const <(String, String)>[
                ('pengarang:hendri', 'hanya di nama pengarang'),
                ('judul:"deep learning"', 'frasa utuh di judul'),
                ('tahun:2024', 'tahun persis'),
                ('tag:radiologi', 'hanya di tag'),
                ('jenis:book', 'jenis item Zotero'),
                ('jurnal:nature', 'nama publikasi'),
                ('abstrak:segmentasi', 'hanya di abstrak'),
                ('koleksi:tesis', 'nama koleksi'),
                ('doi:10.1000', 'DOI'),
                ('-astrofisika', 'kecualikan yang mengandungnya'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 170,
                        child: Text(
                          row.$1,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                        ),
                      ),
                      Expanded(child: Text(row.$2, style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Nama bidang boleh bahasa Inggris juga: author, title, year, '
                'type, journal, abstract, collection.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
        ],
      ),
    );
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
                hintText: 'Cari judul, pengarang, abstrak, DOI…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).set('');
                          setState(() {});
                        },
                      ),
                    IconButton(
                      tooltip: 'Cara mempersempit pencarian',
                      icon: const Icon(Icons.help_outline, size: 16),
                      onPressed: () => _showSearchHelp(context),
                    ),
                  ],
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).set(value);
                setState(() {});
              },
            ),
          ),
          Builder(
            builder: (context) {
              // Tambahkan ke koleksi yang sedang dibuka; di "Semua item" dan
              // "Tanpa koleksi" berarti masuk library tanpa koleksi.
              final selection = ref.watch(selectionProvider);
              final index = ref.watch(workspaceControllerProvider).index;
              final key = selection.kind == SelectionKind.collection
                  ? selection.collectionKey
                  : null;
              final name =
                  (key == null ? null : index?.collections[key]?.name) ??
                  index?.library.name ??
                  'library';
              return AddFilesButton(
                notes: false,
                collectionKey: key,
                collectionName: name,
                iconSize: 18,
              );
            },
          ),
          IconButton(
            tooltip: 'Buka berkas dari perangkat ini (tanpa memasukkannya ke library)',
            icon: const Icon(Icons.file_open_outlined, size: 18),
            onPressed: () async {
              // Berkas apa pun, bukan hanya milik library: menandatangani
              // formulir atau membaca tabel kiriman orang adalah pekerjaan
              // yang sama. PDF dibuka di pembaca, CSV/Excel sebagai tabel.
              final picked = await pickFilesOrTell(
                context,
                title: 'Pilih berkas untuk dibuka',
                multiple: false,
              );
              final path = picked.firstOrNull;
              if (path == null || !context.mounted) return;
              await openAnyFile(context, path, title: p.basenameWithoutExtension(path));
            },
          ),
          // Jumlahnya ikut di tombolnya: "ada 147 kelompok" adalah alasan
          // untuk menekannya, sementara ikon yang diam tidak memberi tahu
          // bahwa ada yang perlu dilihat sama sekali.
          Builder(
            builder: (context) {
              final groups = ref.watch(duplicateGroupsProvider);
              return IconButton(
                tooltip: groups.isEmpty
                    ? 'Cari item yang masuk lebih dari sekali'
                    : '${groups.length} kemungkinan duplikat',
                icon: Badge(
                  isLabelVisible: groups.isNotEmpty,
                  label: Text('${groups.length}'),
                  child: const Icon(Icons.copy_all_outlined, size: 18),
                ),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => const DuplicateScreen())),
              );
            },
          ),
          IconButton(
            tooltip: 'Statistik library',
            icon: const Icon(Icons.insights_outlined, size: 18),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const LibraryStatsScreen())),
          ),
          IconButton(
            tooltip: 'Telusuri berdasarkan pengarang',
            icon: const Icon(Icons.people_alt_outlined, size: 18),
            onPressed: () async {
              final query = await showCreatorFacetSheet(context);
              if (query == null || !mounted) return;
              _controller.text = query;
              ref.read(searchQueryProvider.notifier).set(query);
              setState(() {});
            },
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

    // Ditekan lama untuk diseret ke koleksi lain di pohon. Tekan lama, bukan
    // seret langsung: daftar ini digulir dengan seretan, dan yang menggulir
    // tidak sedang memindahkan apa pun.
    return LongPressDraggable<TreeDrag>(
      data: ItemDrag(itemKey: item.key, label: item.title),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(itemTypeIcon(item.itemType), size: 16),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
      child: _body(context, scheme, attachment),
    );
  }

  Widget _body(BuildContext context, ColorScheme scheme, ZoteroAttachment? attachment) {
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
