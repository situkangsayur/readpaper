import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/notes_store.dart';

import '../../../library/domain/entities/library_index.dart';
import '../../../../shared/widgets/tree_drag.dart';
import '../../../library/presentation/controllers/library_controllers.dart';
import '../../../markdown/presentation/screens/markdown_editor_screen.dart';
import '../../../notebook/data/note_document_store.dart';
import '../../../notebook/domain/note_document.dart';
import '../../../notebook/presentation/screens/notebook_screen.dart';
import '../screens/image_viewer_screen.dart';
import '../../../epub/presentation/epub_reader_screen.dart';
import '../../../notebook/presentation/share_note.dart';
import '../../../workspace/presentation/widgets/repo_transfer_sheet.dart';
import '../../../reader/presentation/screens/reader_screen.dart';
import '../../../tabs/presentation/document_tabs.dart';
import '../../domain/note_entities.dart';
import '../controllers/notes_controller.dart';
import '../../../files/presentation/open_any_file.dart';
import '../../../library/presentation/import_actions.dart';
import '../../../../core/l10n.dart';
import '../../../../shared/widgets/tree_drawer_button.dart';
import 'note_detail_pane.dart';

/// Panel tengah saat yang dipilih ada di bawah akar catatan.
///
/// Sengaja bukan daftar item Zotero: catatan tidak punya pengarang, tahun,
/// atau kunci sitasi, jadi kolom-kolom itu hanya akan kosong. Yang berguna di
/// sini adalah judul, jenis berkas, dan kapan terakhir diubah.
class NoteListPane extends ConsumerWidget {
  const NoteListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    final asyncNotes = ref.watch(notesControllerProvider);
    final error = ref.watch(notesErrorProvider);

    final index = asyncNotes.value ?? NotesIndex.empty;
    final notes = notesFor(index, selection);
    final selectedNote = ref.watch(selectedNoteKeyProvider);
    // Seperti folder di aplikasi berkas: sub-koleksi di atas, bisa dimasuki,
    // lalu berkas koleksi ini sendiri. Tanpa ini isi sub-koleksi hanya bisa
    // dicapai lewat pohon di panel kiri, yang di ponsel tersembunyi di laci.
    final currentKey = selection.noteCollectionKey;
    final folders = switch (selection.kind) {
      SelectionKind.noteCollection => index.childrenOf(currentKey),
      SelectionKind.notes => index.childrenOf(null),
      _ => const <NoteCollection>[],
    };
    final current = index.collections.firstWhereOrNull((c) => c.key == currentKey);
    final parent = current?.parentKey == null
        ? null
        : index.collections.firstWhereOrNull((c) => c.key == current!.parentKey);
    final showUp = selection.kind == SelectionKind.noteCollection;
    final leading = <Widget>[
      if (showUp)
        _UpTile(
          label: context.l10n.notesUpTo(parent?.name ?? context.l10n.libraryNotesRoot),
          onTap: () => ref
              .read(selectionProvider.notifier)
              .select(
                parent == null
                    ? const LibrarySelection.notes()
                    : LibrarySelection.noteCollection(parent.key),
              ),
        ),
      for (final folder in folders)
        _FolderTile(
          collection: folder,
          notes: index.countIn(folder.key),
          subcollections: index.childrenOf(folder.key).length,
          onOpen: () => ref
              .read(selectionProvider.notifier)
              .select(LibrarySelection.noteCollection(folder.key)),
        ),
    ];
    final title = switch (selection.kind) {
      SelectionKind.notesUnfiled => context.l10n.notesUnfiledTitle,
      SelectionKind.noteCollection =>
        index.collections
                .where((c) => c.key == selection.collectionKey)
                .map((c) => c.name)
                .firstOrNull ??
            context.l10n.notesRootTitle,
      _ => context.l10n.notesAllTitle,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      context.l10n.notesCount(notes.length),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.notesNewNotebook,
                icon: const Icon(Icons.auto_stories_outlined, size: 20),
                onPressed: () => _newNotebook(context, ref, selection),
              ),
              IconButton(
                tooltip: context.l10n.notesNewMarkdown,
                icon: const Icon(Icons.post_add_outlined, size: 20),
                onPressed: () => _newMarkdown(context, ref, selection),
              ),
              // Berkas apa pun (beberapa sekaligus) atau satu folder utuh.
              AddFilesButton(
                notes: true,
                collectionKey: selection.noteCollectionKey,
                collectionName: title,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (error != null)
          _NoteBanner(message: error, onClose: () => ref.read(notesErrorProvider.notifier).clear()),
        if (asyncNotes.isLoading && asyncNotes.value == null)
          const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 3)))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => pullToRefresh(ref),
              child: notes.isEmpty && folders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        ...leading,
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(context.l10n.notesEmpty, textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: leading.length + notes.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i < leading.length) return leading[i];
                        final note = notes[i - leading.length];
                        return _NoteTile(
                          note: note,
                          directory: index.directory,
                          onOpen: () => openNote(context, ref, note, index),
                          onMenu: () => showNoteMenu(context, ref, note),
                          onSelect: () =>
                              ref.read(selectedNoteKeyProvider.notifier).select(note.key),
                          selected: note.key == selectedNote,
                        );
                      },
                    ),
            ),
          ),
        if (TreeDrawerButton.available(context))
          Container(
            height: 40,
            padding: const EdgeInsets.only(right: 4),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: const TreeDrawerButton(),
          ),
      ],
    );
  }
}

/// Baris "kembali ke induk" di atas isi sebuah koleksi catatan.
class _UpTile extends StatelessWidget {
  const _UpTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: const Icon(Icons.arrow_upward),
    title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: onTap,
  );
}

/// Sub-koleksi di daftar catatan: diketuk untuk masuk; catatan yang
/// diseret ke sini dipindahkan ke dalamnya.
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.collection,
    required this.notes,
    required this.subcollections,
    required this.onOpen,
  });

  final NoteCollection collection;
  final int notes;
  final int subcollections;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<TreeDrag>(
      onAcceptWithDetails: (details) =>
          dropIntoNotes(ImportHost.of(context), details.data, collection.key, collection.name),
      builder: (context, candidate, rejected) => ListTile(
        tileColor: candidate.isNotEmpty ? scheme.primary.withValues(alpha: 0.18) : null,
        leading: Icon(Icons.folder, color: scheme.primary),
        title: Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(context.l10n.notesSubcollectionSummary(notes, subcollections)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.directory,
    required this.onOpen,
    required this.onMenu,
    required this.onSelect,
    required this.selected,
  });

  final NoteItem note;
  final String directory;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final VoidCallback onSelect;
  final bool selected;

  @override
  Widget build(BuildContext context) => LongPressDraggable<TreeDrag>(
    // Ditekan lama untuk dipindahkan ke koleksi lain di pohon.
    data: NoteDrag(noteKey: note.key, label: note.title),
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.sticky_note_2_outlined, size: 16),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    ),
    child: _tile(context),
  );

  Widget _tile(BuildContext context) {
    final icon = noteIcon(note);
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${p.basename(note.file)} · ${_when(note.dateModified)}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      selected: selected,
      // Ketuk memilih dan menampilkan keterangannya, seperti paper di My
      // Library; membuka langsung tetap sekali ketuk lewat tombol di kanan.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: context.l10n.notesOpen,
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: onOpen,
          ),
          IconButton(
            tooltip: context.l10n.notesActions,
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: onMenu,
          ),
        ],
      ),
      onTap: onSelect,
      onLongPress: onMenu,
    );
  }

  static String _when(DateTime when) {
    final local = when.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _NoteBanner extends StatelessWidget {
  const _NoteBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: scheme.onErrorContainer),
              tooltip: context.l10n.notesClose,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Membuat buku catatan baru di koleksi yang sedang dipilih.
///
/// Berkasnya ditulis di folder sementara lalu disalin masuk oleh [NotesStore],
/// sama seperti catatan lain — supaya penamaan dan pencatatannya satu jalur.
Future<void> _newNotebook(BuildContext context, WidgetRef ref, LibrarySelection selection) async {
  final title = await _askText(
    context,
    title: context.l10n.notesNewNotebook,
    initial: context.l10n.notesNotebookDefaultTitle,
  );
  if (title == null || title.trim().isEmpty || !context.mounted) return;

  final stem = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  final temp = await Directory.systemTemp.createTemp('readpaper-buku-');
  final seed = p.join(temp.path, '$stem${NoteDocumentStore.extension}');
  await NoteDocumentStore.write(seed, NoteDocument.blank(title: title.trim()));

  final controller = ref.read(notesControllerProvider.notifier);
  final key = await controller.addFile(
    sourcePath: seed,
    title: title.trim(),
    collectionKey: selection.noteCollectionKey,
  );
  await temp.delete(recursive: true);
  if (!context.mounted) return;
  if (key == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(notesErrorProvider) ?? context.l10n.notesNewNotebookFailed)),
    );
    return;
  }

  final index = ref.read(notesControllerProvider).value ?? NotesIndex.empty;
  final note = index.items.firstWhereOrNull((item) => item.key == key);
  if (note == null) return;
  await openDocument<String>(
    context,
    NotebookScreen(path: p.join(index.directory, note.file), title: note.title),
    title: note.title,
    icon: Icons.edit_note,
    dedupeKey: p.join(index.directory, note.file),
  );
  await controller.touch(itemKey: key, message: 'Ubah catatan: ${note.title}');
}

/// Membuat catatan Markdown kosong di koleksi yang sedang dipilih, lalu
/// membukanya.
///
/// Berkasnya dibuat lewat folder sementara dan disalin masuk oleh
/// [NotesStore], supaya penamaan dan pencatatannya tetap satu jalur dengan
/// catatan yang datang dari mana pun.
Future<void> _newMarkdown(BuildContext context, WidgetRef ref, LibrarySelection selection) async {
  final title = await _askText(
    context,
    title: context.l10n.notesNewNoteTitle,
    initial: context.l10n.notesNotebookDefaultTitle,
  );
  if (title == null || title.trim().isEmpty || !context.mounted) return;

  final stem = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  final temp = await Directory.systemTemp.createTemp('readpaper-catatan-');
  final seed = File(p.join(temp.path, '$stem.md'));
  await seed.writeAsString('# ${title.trim()}\n\n');

  final controller = ref.read(notesControllerProvider.notifier);
  final key = await controller.addFile(
    sourcePath: seed.path,
    title: title.trim(),
    collectionKey: selection.noteCollectionKey,
  );
  await temp.delete(recursive: true);
  if (!context.mounted) return;
  if (key == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(notesErrorProvider) ?? context.l10n.notesNewNoteFailed)),
    );
    return;
  }

  final index = ref.read(notesControllerProvider).value ?? NotesIndex.empty;
  final note = index.items.firstWhereOrNull((item) => item.key == key);
  if (note == null) return;
  await openDocument<String>(
    context,
    MarkdownEditorScreen(
      path: p.join(index.directory, note.file),
      title: note.title,
      startInEdit: true,
    ),
    title: note.title,
    icon: Icons.notes_outlined,
    dedupeKey: p.join(index.directory, note.file),
  );
  // Isinya berubah di luar store, jadi commit-nya dilakukan di sini.
  await controller.touch(itemKey: key, message: 'Ubah catatan: ${note.title}');
}

/// Membuka catatan di penampil atau penyunting yang sesuai jenis berkasnya.
Future<void> openNote(BuildContext context, WidgetRef ref, NoteItem note, NotesIndex index) async {
  final path = p.join(index.directory, note.file);
  if (note.isNotebook) {
    await openDocument<String>(
      context,
      NotebookScreen(path: path, title: note.title),
      title: note.title,
      icon: Icons.edit_note,
      dedupeKey: path,
    );
    await ref
        .read(notesControllerProvider.notifier)
        .touch(itemKey: note.key, message: 'Ubah catatan: ${note.title}');
    return;
  }
  if (note.isMarkdown) {
    await openDocument<String>(
      context,
      MarkdownEditorScreen(path: path, title: note.title),
      title: note.title,
      icon: Icons.notes_outlined,
      dedupeKey: path,
    );
    // Penyuntingnya sudah menulis berkasnya; yang tersisa adalah mencatat
    // perubahannya ke git, sama seperti perubahan catatan yang lain.
    await ref
        .read(notesControllerProvider.notifier)
        .touch(itemKey: note.key, message: 'Ubah catatan: ${note.title}');
    return;
  }
  if (const <String>{'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'}.contains(note.extension)) {
    await openDocument<void>(
      context,
      ImageViewerScreen(path: path, title: note.title),
      title: note.title,
      icon: Icons.image_outlined,
      dedupeKey: path,
    );
    return;
  }
  if (note.extension == '.epub') {
    await openDocument<void>(
      context,
      EpubReaderScreen(path: path, title: note.title),
      title: note.title,
      icon: Icons.menu_book_outlined,
      dedupeKey: path,
    );
    return;
  }
  if (note.isPdf) {
    openDocument<void>(
      context,
      ReaderScreen(
        itemKey: '',
        itemFilePath: '',
        attachmentKey: '',
        filePath: path,
        title: note.title,
        // Anotasi PDF catatan tersimpan seketika di folder catatannya dan
        // menunggu Kirim seperti perubahan lain — bukan coretan yang
        // menuntut "Simpan sebagai".
        annotationsFile: NotesStore.annotationsFileFor(path),
        onAnnotationsChanged: (message) async {
          await ref
              .read(notesControllerProvider.notifier)
              .touch(itemKey: note.key, message: message);
        },
      ),
      title: note.title,
      icon: Icons.picture_as_pdf_outlined,
      dedupeKey: path,
    );
    return;
  }
  // CSV dan Excel dibuka sebagai tabel, Word dan PowerPoint di penampilnya;
  // jenis lain diserahkan ke aplikasi bawaan sistem di desktop.
  await openAnyFile(context, path, title: note.title);
}

/// Aksi untuk satu catatan: ubah keterangan, ganti nama, bagikan, pindahkan,
/// kirim ke repo lain, hapus.
Future<void> showNoteMenu(BuildContext context, WidgetRef ref, NoteItem note) async {
  final index = ref.read(notesControllerProvider).value ?? NotesIndex.empty;
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(dense: true, title: Text(note.title)),
          const Divider(height: 1),
          // Dari sini juga, bukan hanya mengetuk barisnya: dan ke panel kanan
          // tanpa harus menyeret tab.
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(canUseTabs(context) ? context.l10n.tabsOpenNew : context.l10n.tabsOpen),
            onTap: () => Navigator.of(sheet).pop('buka'),
          ),
          if (canUseTabs(context))
            ListTile(
              leading: const Icon(Icons.vertical_split_outlined),
              title: Text(context.l10n.tabsOpenRight),
              onTap: () => Navigator.of(sheet).pop('kanan'),
            ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(context.l10n.notesEditDetails),
            onTap: () => Navigator.of(sheet).pop('keterangan'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: Text(context.l10n.notesRename),
            onTap: () => Navigator.of(sheet).pop('nama'),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(context.l10n.notesShare),
            subtitle: Text(
              note.isNotebook ? context.l10n.notesShareAsPdf : context.l10n.notesShareToApps,
            ),
            onTap: () => Navigator.of(sheet).pop('bagikan'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: Text(context.l10n.notesMoveToCollection),
            onTap: () => Navigator.of(sheet).pop('pindah'),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(context.l10n.notesTransferToRepo),
            onTap: () => Navigator.of(sheet).pop('repo'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(context.l10n.notesDelete),
            subtitle: Text(context.l10n.notesDeleteSubtitle),
            onTap: () => Navigator.of(sheet).pop('hapus'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final controller = ref.read(notesControllerProvider.notifier);

  switch (action) {
    case 'buka':
      await openNote(context, ref, note, index);
    case 'kanan':
      openOnRight(context, () => openNote(context, ref, note, index));
    case 'repo':
      final choice = await showRepoTransferSheet(
        context,
        what: context.l10n.notesTransferWhat(note.title),
        forCollection: false,
        notes: true,
      );
      if (choice == null || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final text = context.l10n;
      final failure = await controller.transferItem(
        itemKey: note.key,
        target: choice.target,
        collectionKey: choice.collectionKey,
        move: choice.move,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: Duration(seconds: failure == null ? 4 : 8),
            content: Text(
              failure ??
                  (choice.move
                      ? text.notesMoved(choice.target.name)
                      : text.notesCopied(choice.target.name)),
            ),
          ),
        );
    case 'keterangan':
      await editNoteDetails(context, ref, note);
    case 'bagikan':
      await shareAnyFile(context, p.join(index.directory, note.file), title: note.title);
    case 'nama':
      final name = await _askText(context, title: context.l10n.notesRename, initial: note.title);
      if (name == null || name.trim().isEmpty) return;
      await controller.rename(itemKey: note.key, title: name);
    case 'pindah':
      final target = await _pickCollection(context, index);
      if (target == null) return;
      await controller.fileInto(itemKey: note.key, collectionKey: target.isEmpty ? null : target);
    case 'hapus':
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(context.l10n.notesDeleteConfirmTitle),
          content: Text(context.l10n.notesDeleteConfirmBody(note.title)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(context.l10n.notesCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(context.l10n.notesDeleteButton),
            ),
          ],
        ),
      );
      if (yes ?? false) await controller.deleteItem(note.key);
  }
}

/// Mengembalikan kunci koleksi, string kosong untuk "tanpa koleksi", atau
/// null kalau dibatalkan.
Future<String?> _pickCollection(BuildContext context, NotesIndex index) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(context.l10n.notesNoCollection),
              onTap: () => Navigator.of(sheet).pop(''),
            ),
            const Divider(height: 1),
            for (final collection in index.collections)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(collection.name),
                onTap: () => Navigator.of(sheet).pop(collection.key),
              ),
          ],
        ),
      ),
    );

Future<String?> _askText(BuildContext context, {required String title, String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: context.l10n.notesTitleField),
        onSubmitted: (value) => Navigator.of(dialog).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(context.l10n.notesCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(controller.text),
          child: Text(context.l10n.notesSave),
        ),
      ],
    ),
  );
}
