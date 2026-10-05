import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/layout_size.dart';
import '../../../../shared/widgets/tree_drag.dart';
import '../../../notes/domain/note_entities.dart';
import '../../../notes/domain/note_target.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../../workspace/presentation/widgets/repo_transfer_sheet.dart';
import '../../domain/entities/library_index.dart';
import '../../domain/entities/zotero_collection.dart';
import '../controllers/library_controllers.dart';

/// Pohon koleksi dengan **dua akar**: paper dan catatan.
///
/// Akar paper adalah ekspor Zotero — item dengan penulis, tahun, dan kunci
/// sitasi, yang formatnya dijaga byte-for-byte oleh plugin sinkronisasi.
/// Akar catatan adalah folder tersendiri di dalam repositori yang sama, di
/// luar struktur Zotero: catatan tidak punya bibliografi, dan Zotero tidak
/// mengenal catatan lepas semacam ini. Memisahkannya membuat keduanya bisa
/// hidup di satu repositori tanpa yang satu merusak yang lain.
class CollectionTreePane extends ConsumerWidget {
  const CollectionTreePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(workspaceControllerProvider).index;
    if (index == null) return const SizedBox.shrink();

    final notes = ref.watch(notesControllerProvider).value ?? NotesIndex.empty;
    final selection = ref.watch(selectionProvider);
    final expanded = ref.watch(expandedCollectionsProvider);
    final expandedController = ref.read(expandedCollectionsProvider.notifier);
    final selectionController = ref.read(selectionProvider.notifier);

    final paperOpen = expanded.contains(paperRootNodeKey);
    final notesOpen = expanded.contains(notesRootNodeKey);

    final rows = <Widget>[
      _TreeRow(
        label: index.library.name,
        icon: Icons.local_library_outlined,
        count: index.itemCount,
        depth: 0,
        isRoot: true,
        selected: selection.kind == SelectionKind.all,
        hasChildren: true,
        isExpanded: paperOpen,
        onToggle: () => expandedController.toggle(paperRootNodeKey),
        onTap: () => selectionController.select(const LibrarySelection.all()),
        // Melepas di sini berarti "masuk library, tanpa koleksi".
        onDrop: (drag) => _dropIntoPapers(context, ref, drag, null, index.library.name),
        trailing: IconButton(
          tooltip: 'Koleksi paper baru',
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: () => _newPaperCollection(context, ref, parentKey: null),
        ),
      ),
    ];

    if (paperOpen) {
      if (index.unfiledItemKeys.isNotEmpty) {
        rows.add(
          _TreeRow(
            label: 'Tanpa koleksi',
            icon: Icons.folder_off_outlined,
            count: index.unfiledItemKeys.length,
            depth: 1,
            selected: selection.kind == SelectionKind.unfiled,
            onTap: () => selectionController.select(const LibrarySelection.unfiled()),
          ),
        );
      }

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
            onAddChild: () => _newPaperCollection(context, ref, parentKey: node.key),
            onMenu: () => _paperCollectionMenu(context, ref, node.key),
            onDrop: (drag) => _dropIntoPapers(context, ref, drag, node.key, node.name),
          ),
        );
        if (!isExpanded) return;
        for (final child in node.children) {
          addNode(child, depth + 1);
        }
      }

      for (final root in index.roots) {
        addNode(root, 1);
      }
    }

    rows.add(const Divider(height: 12));

    rows.add(
      _TreeRow(
        label: 'Catatan',
        icon: Icons.sticky_note_2_outlined,
        count: notes.items.length,
        depth: 0,
        isRoot: true,
        selected: selection.kind == SelectionKind.notes,
        hasChildren: true,
        isExpanded: notesOpen,
        onToggle: () => expandedController.toggle(notesRootNodeKey),
        onTap: () => selectionController.select(const LibrarySelection.notes()),
        onDrop: (drag) => _dropIntoNotes(context, ref, drag, null, 'Catatan'),
        trailing: IconButton(
          tooltip: 'Koleksi catatan baru',
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: () => _newNoteCollection(context, ref, parentKey: null),
        ),
      ),
    );

    if (notesOpen) {
      if (notes.unfiled.isNotEmpty) {
        rows.add(
          _TreeRow(
            label: 'Tanpa koleksi',
            icon: Icons.folder_off_outlined,
            count: notes.unfiled.length,
            depth: 1,
            selected: selection.kind == SelectionKind.notesUnfiled,
            onTap: () => selectionController.select(const LibrarySelection.notesUnfiled()),
            onDrop: (drag) => _dropIntoNotes(context, ref, drag, null, 'Catatan'),
          ),
        );
      }

      void addNote(NoteCollection collection, int depth) {
        final nodeKey = noteNodeKey(collection.key);
        final children = notes.childrenOf(collection.key);
        final isExpanded = expanded.contains(nodeKey);
        rows.add(
          _TreeRow(
            label: collection.name,
            icon: isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined,
            count: notes.countIn(collection.key),
            depth: depth,
            selected:
                selection.kind == SelectionKind.noteCollection &&
                selection.collectionKey == collection.key,
            hasChildren: children.isNotEmpty,
            isExpanded: isExpanded,
            onToggle: () => expandedController.toggle(nodeKey),
            onTap: () =>
                selectionController.select(LibrarySelection.noteCollection(collection.key)),
            onMenu: () => _noteCollectionMenu(context, ref, collection),
            onAddChild: () => _newNoteCollection(context, ref, parentKey: collection.key),
            onDrop: (drag) => _dropIntoNotes(context, ref, drag, collection.key, collection.name),
          ),
        );
        if (!isExpanded) return;
        for (final child in children) {
          addNote(child, depth + 1);
        }
      }

      final roots = notes.childrenOf(null);
      if (roots.isEmpty && notes.items.isEmpty) {
        rows.add(const _EmptyNotesHint());
      }
      for (final root in roots) {
        addNote(root, 1);
      }
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
            onPressed: () => ref.read(expandedCollectionsProvider.notifier).expandAll(<String>[
              paperRootNodeKey,
              notesRootNodeKey,
              ...index.collections.keys,
            ]),
          ),
        ],
      ),
    );
  }
}

/// Keterangan singkat saat akar catatan masih kosong, supaya tidak terlihat
/// seperti bagian yang rusak.
class _EmptyNotesHint extends StatelessWidget {
  const _EmptyNotesHint();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 4, 12, 8),
    child: Text(
      'Belum ada koleksi catatan. Catatan disimpan di folder tersendiri di '
      'dalam repositori, terpisah dari paper.',
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
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
    this.isRoot = false,
    this.onToggle,
    this.onDrop,
    this.trailing,
    this.onAddChild,
    this.onMenu,
  });

  final String label;
  final IconData icon;
  final int count;
  final int depth;
  final bool selected;
  final bool hasChildren;
  final bool isExpanded;

  /// Akar pohon ditulis tebal: dua akar yang tampak sama beratnya dengan
  /// koleksi di bawahnya membuat jenisnya tidak terbaca.
  final bool isRoot;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  /// Dipanggil saat sesuatu dilepas di atas baris ini.
  final void Function(TreeDrag drag)? onDrop;

  final Widget? trailing;

  /// Membuat sub-koleksi di bawah baris ini. Muncul sebagai tombol tetap,
  /// bukan hanya di menu tekan-lama: yang tidak pernah menekan lama tidak
  /// pernah menemukannya, dan itu memang yang terjadi.
  final VoidCallback? onAddChild;

  /// Menu ubah nama, pindah, dan hapus. Tombol ⋮ yang terlihat, bukan hanya
  /// tekan lama: di desktop tekan lama nyaris tidak pernah dicoba, dan menu
  /// yang tidak ditemukan sama saja dengan menu yang tidak ada.
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Sasaran lepas untuk berkas yang diseret dari panel berkas di bawah.
    return DragTarget<TreeDrag>(
      onWillAcceptWithDetails: (_) => onDrop != null,
      onAcceptWithDetails: (details) => onDrop?.call(details.data),
      builder: (context, candidate, rejected) => InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        child: Container(
          height: treeRowHeight,
          padding: EdgeInsets.only(left: 4 + depth * 14.0, right: 8),
          // Berubah warna saat berkas melayang di atasnya: tanpa itu yang
          // menyeret tidak tahu apakah lepasannya akan mendarat.
          color: candidate.isNotEmpty
              ? scheme.primary.withValues(alpha: 0.22)
              : (selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null),
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
              Icon(
                icon,
                size: isRoot ? 17 : 15,
                color: selected || isRoot ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: selected || isRoot ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              if (onAddChild != null)
                IconButton(
                  tooltip: 'Sub-koleksi baru di sini',
                  iconSize: 15,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add),
                  onPressed: onAddChild,
                ),
              if (onMenu != null)
                IconButton(
                  tooltip: 'Ubah nama, pindahkan, atau hapus',
                  iconSize: 15,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert),
                  onPressed: onMenu,
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Menerima lepasan di akar paper: berkas baru, atau item yang dipindahkan.
///
/// Catatan ditolak di sini. Akar paper berisi item Zotero, dan catatan tidak
/// punya rujukan maupun bibliografi untuk jadi salah satunya — penolakannya
/// menyebutkan itu, bukan sekadar berkata tidak bisa.
Future<void> _dropIntoPapers(
  BuildContext context,
  WidgetRef ref,
  TreeDrag drag,
  String? collectionKey,
  String collectionName,
) async {
  final messenger = ScaffoldMessenger.of(context);

  void say(String message, {bool panjang = false}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: panjang ? 6 : 3),
      ),
    );

  switch (drag) {
    case NoteDrag():
      say(NoteTarget.refusalMessage, panjang: true);

    case ItemDrag():
      final item = ref.read(workspaceControllerProvider).index?.items[drag.itemKey];
      if (item == null) return;
      say('Memindahkan ke $collectionName…');
      final ok = await ref
          .read(workspaceControllerProvider.notifier)
          .moveItemToCollection(item: item, collectionKey: collectionKey);
      if (!context.mounted) return;
      say(
        ok
            ? 'Pindah ke $collectionName'
            : (ref.read(workspaceControllerProvider).error ?? 'Gagal memindahkan'),
      );

    case FileDrag():
      // Akar paper hanya menerima PDF. Item Zotero adalah paper dengan
      // lampiran PDF; berkas lain yang dipaksa masuk akan jadi item yang tidak
      // bisa dibuka Zotero.
      if (p.extension(drag.path).toLowerCase() != '.pdf') {
        say(
          'Akar paper hanya menerima PDF, karena isinya item Zotero dengan '
          'lampiran PDF. Lepas ${p.basename(drag.path)} di akar "Catatan".',
          panjang: true,
        );
        return;
      }
      say('Memasukkan ke $collectionName…');
      final created = await ref
          .read(workspaceControllerProvider.notifier)
          .addPdfToLibrary(
            pdfPath: drag.path,
            title: p.basenameWithoutExtension(drag.path),
            collectionKey: collectionKey,
          );
      if (!context.mounted) return;
      say(
        created == null
            ? (ref.read(workspaceControllerProvider).error ?? 'Gagal memasukkan berkas')
            : 'Masuk ke $collectionName',
      );
  }
}

/// Menerima lepasan di akar catatan: berkas apa pun, atau catatan yang
/// dipindahkan antar koleksi.
///
/// Apa pun jenis berkasnya boleh: catatan bisa berupa PDF papan tulis,
/// markdown, buku catatan, atau gambar pindaian. Yang membedakannya dari paper
/// bukan formatnya, melainkan tempatnya.
Future<void> _dropIntoNotes(
  BuildContext context,
  WidgetRef ref,
  TreeDrag drag,
  String? collectionKey,
  String collectionName,
) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String message, {bool panjang = false}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: panjang ? 6 : 3),
      ),
    );

  switch (drag) {
    case ItemDrag():
      say(
        'Paper tinggal di akar paper: item Zotero punya rujukan dan '
        'bibliografi yang dijaga plugin sinkronisasi, dan folder catatan tidak '
        'mengenalnya. Yang bisa dipindahkan ke sini adalah catatan.',
        panjang: true,
      );

    case NoteDrag():
      final moved = await ref
          .read(notesControllerProvider.notifier)
          .fileInto(itemKey: drag.noteKey, collectionKey: collectionKey);
      if (!context.mounted) return;
      say(
        moved == null
            ? (ref.read(notesErrorProvider) ?? 'Gagal memindahkan catatan')
            : 'Pindah ke $collectionName',
      );

    case FileDrag():
      say('Memasukkan ke $collectionName…');
      final key = await ref
          .read(notesControllerProvider.notifier)
          .addFile(
            sourcePath: drag.path,
            title: p.basenameWithoutExtension(drag.path),
            collectionKey: collectionKey,
          );
      if (!context.mounted) return;
      say(
        key == null
            ? (ref.read(notesErrorProvider) ?? 'Gagal menyimpan catatan')
            : 'Masuk ke $collectionName',
      );
  }
}

/// Membuat koleksi paper baru.
///
/// Satu-satunya tempat ReadPaper menulis berkas struktur Zotero, jadi
/// penjelasannya ikut disebut di layar: yang memakainya berhak tahu bahwa
/// koleksinya nanti muncul juga di Zotero setelah diimpor.
Future<void> _newPaperCollection(
  BuildContext context,
  WidgetRef ref, {
  required String? parentKey,
}) async {
  final name = await _askName(
    context,
    title: parentKey == null ? 'Koleksi paper baru' : 'Sub-koleksi paper baru',
    hint: 'Ditulis ke collections.json, ikut tersinkron ke GitHub',
  );
  if (name == null || name.trim().isEmpty) return;

  final key = await ref
      .read(workspaceControllerProvider.notifier)
      .createCollection(name: name, parentKey: parentKey);
  if (!context.mounted) return;
  if (key == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ref.read(workspaceControllerProvider).error ?? 'Gagal membuat koleksi'),
        duration: const Duration(seconds: 5),
      ),
    );
    return;
  }
  ref.read(expandedCollectionsProvider.notifier).expandAll(<String>[paperRootNodeKey, ?parentKey]);
  ref.read(selectionProvider.notifier).select(LibrarySelection.collection(key));
}

Future<void> _newNoteCollection(
  BuildContext context,
  WidgetRef ref, {
  required String? parentKey,
}) async {
  final name = await _askName(
    context,
    title: parentKey == null ? 'Koleksi catatan baru' : 'Sub-koleksi catatan baru',
  );
  if (name == null || name.trim().isEmpty) return;
  final key = await ref
      .read(notesControllerProvider.notifier)
      .createCollection(name: name, parentKey: parentKey);
  if (!context.mounted) return;
  if (key == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(notesErrorProvider) ?? 'Gagal membuat koleksi')),
    );
    return;
  }
  // Koleksi yang baru dibuat langsung dipilih: itu yang sedang dituju.
  ref.read(expandedCollectionsProvider.notifier).expandAll(<String>[
    notesRootNodeKey,
    if (parentKey != null) noteNodeKey(parentKey),
  ]);
  ref.read(selectionProvider.notifier).select(LibrarySelection.noteCollection(key));
}

/// Menu satu koleksi paper: sub-koleksi, ubah nama, pindahkan, hapus.
///
/// Semuanya menulis struktur Zotero, jadi semuanya lewat penulis yang sama
/// dengan "Koleksi baru" dan berakhir dengan commit yang menyebut namanya.
Future<void> _paperCollectionMenu(BuildContext context, WidgetRef ref, String key) async {
  final index = ref.read(workspaceControllerProvider).index;
  final collection = index?.collections[key];
  if (index == null || collection == null) return;

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            dense: true,
            title: Text(collection.name, style: Theme.of(sheet).textTheme.titleSmall),
            subtitle: collection.path == collection.name ? null : Text(collection.path),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Sub-koleksi baru'),
            onTap: () => Navigator.of(sheet).pop('baru'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Ubah nama'),
            onTap: () => Navigator.of(sheet).pop('nama'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: const Text('Pindahkan ke…'),
            onTap: () => Navigator.of(sheet).pop('pindah'),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Pindahkan atau salin ke repositori lain…'),
            subtitle: const Text('beserta sub-koleksi dan paper-nya'),
            onTap: () => Navigator.of(sheet).pop('repo'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_delete_outlined),
            title: const Text('Hapus koleksi'),
            subtitle: const Text('Paper di dalamnya tidak ikut terhapus'),
            onTap: () => Navigator.of(sheet).pop('hapus'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  final controller = ref.read(workspaceControllerProvider.notifier);
  void report(bool ok, String done) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? done : (ref.read(workspaceControllerProvider).error ?? 'Gagal mengubah koleksi'),
          ),
          duration: Duration(seconds: ok ? 3 : 6),
        ),
      );
  }

  switch (action) {
    case 'baru':
      await _newPaperCollection(context, ref, parentKey: key);
    case 'nama':
      final name = await _askName(
        context,
        title: 'Ubah nama koleksi',
        initial: collection.name,
        hint: 'Paper di dalamnya tetap; jalur sub-koleksinya ikut berubah',
      );
      if (name == null || name.trim().isEmpty || name.trim() == collection.name) return;
      final ok = await controller.changePaperCollection(
        message: 'Ubah nama koleksi: ${collection.path} → ${name.trim()}',
        change: (repo, dir) => repo.renameCollection(libraryDir: dir, key: key, name: name),
      );
      report(ok, 'Koleksi diubah namanya jadi "${name.trim()}"');
    case 'pindah':
      if (!context.mounted) return;
      final target = await _pickPaperParent(context, index, collection);
      if (target == null) return;
      final parentKey = target.isEmpty ? null : target;
      if (parentKey == collection.parentKey) return;
      final parentName = parentKey == null ? 'akar' : index.collections[parentKey]!.path;
      final ok = await controller.changePaperCollection(
        message: 'Pindahkan koleksi ${collection.path} ke $parentName',
        change: (repo, dir) =>
            repo.moveCollection(libraryDir: dir, key: key, newParentKey: parentKey),
      );
      report(ok, 'Koleksi dipindah ke $parentName');
    case 'repo':
      if (!context.mounted) return;
      final choice = await showRepoTransferSheet(
        context,
        what: 'Koleksi ${collection.path}, beserta sub-koleksi dan paper-nya',
        forCollection: true,
      );
      if (choice == null || !context.mounted) return;
      final failure = await controller.transferCollection(
        collectionKey: key,
        target: choice.target,
        targetLibrary: choice.library,
        parentKey: choice.collectionKey,
        move: choice.move,
      );
      if (failure == null && choice.move) {
        ref.read(selectionProvider.notifier).select(const LibrarySelection.all());
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: Duration(seconds: failure == null ? 4 : 8),
            content: Text(
              failure ??
                  'Koleksi "${collection.name}" ${choice.move ? 'dipindahkan' : 'disalin'} '
                      'ke ${choice.target.name}',
            ),
          ),
        );
    case 'hapus':
      final reach = await controller.paperCollectionReach(key);
      if (reach == null || !context.mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Hapus koleksi "${collection.name}"?'),
          content: Text(
            <String>[
              if (reach.items > 0)
                '${reach.items} paper di dalamnya tidak ikut terhapus — hanya dilepas dari '
                    'koleksi ini, sama seperti di Zotero.',
              if (reach.children > 0)
                'Koleksi ini punya ${reach.children} sub-koleksi. Ikut dihapus, atau naik '
                    'satu tingkat?',
              if (reach.items == 0 && reach.children == 0) 'Koleksinya kosong.',
            ].join('\n\n'),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Batal')),
            if (reach.children > 0)
              TextButton(
                onPressed: () => Navigator.of(dialog).pop('naik'),
                child: const Text('Sub-koleksi naik'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop('semua'),
              child: Text(reach.children > 0 ? 'Hapus semuanya' : 'Hapus'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      final selected = ref.read(selectionProvider).collectionKey;
      final ok = await controller.changePaperCollection(
        message: 'Hapus koleksi: ${collection.path}',
        change: (repo, dir) =>
            repo.deleteCollection(libraryDir: dir, key: key, withChildren: choice == 'semua'),
      );
      if (ok && ref.read(workspaceControllerProvider).index?.collections[selected] == null) {
        ref.read(selectionProvider.notifier).select(const LibrarySelection.all());
      }
      report(ok, 'Koleksi "${collection.name}" dihapus; paper-nya tetap ada');
  }
}

/// Memilih induk baru; string kosong berarti akar. Koleksi itu sendiri dan
/// keturunannya tidak ditawarkan — memindah ke dalam diri sendiri membuat
/// pohonnya jadi lingkaran.
Future<String?> _pickPaperParent(
  BuildContext context,
  LibraryIndex index,
  ZoteroCollection moving,
) {
  final candidates =
      index.collections.values
          .where((c) => c.key != moving.key && !c.path.startsWith('${moving.path}/'))
          .toList()
        ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(dense: true, title: Text('Pindahkan "${moving.name}" ke…')),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.local_library_outlined),
              title: const Text('Akar library'),
              subtitle: const Text('tanpa induk'),
              enabled: moving.parentKey != null,
              onTap: () => Navigator.of(sheet).pop(''),
            ),
            for (final c in candidates)
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_outlined),
                title: Text(c.name),
                subtitle: c.path == c.name ? null : Text(c.path),
                enabled: c.key != moving.parentKey,
                onTap: () => Navigator.of(sheet).pop(c.key),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _noteCollectionMenu(
  BuildContext context,
  WidgetRef ref,
  NoteCollection collection,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            dense: true,
            title: Text(collection.name, style: Theme.of(sheet).textTheme.titleSmall),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Sub-koleksi baru'),
            onTap: () => Navigator.of(sheet).pop('baru'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Ubah nama'),
            onTap: () => Navigator.of(sheet).pop('nama'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_delete_outlined),
            title: const Text('Hapus koleksi'),
            subtitle: const Text('Catatannya tidak ikut terhapus'),
            onTap: () => Navigator.of(sheet).pop('hapus'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  final controller = ref.read(notesControllerProvider.notifier);
  switch (action) {
    case 'baru':
      await _newNoteCollection(context, ref, parentKey: collection.key);
    case 'nama':
      final name = await _askName(context, title: 'Ubah nama', initial: collection.name);
      if (name == null || name.trim().isEmpty) return;
      await controller.renameCollection(key: collection.key, name: name);
    case 'hapus':
      await controller.deleteCollection(collection.key);
      if (ref.read(selectionProvider).collectionKey == collection.key) {
        ref.read(selectionProvider.notifier).select(const LibrarySelection.notes());
      }
  }
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: 'Nama', helperText: hint, helperMaxLines: 2),
        onSubmitted: (value) => Navigator.of(dialog).pop(value),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(controller.text),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}
