import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../library/domain/entities/library_index.dart';
import '../../../library/presentation/controllers/library_controllers.dart';
import '../../../markdown/presentation/screens/markdown_editor_screen.dart';
import '../../../notebook/data/note_document_store.dart';
import '../../../notebook/domain/note_document.dart';
import '../../../notebook/presentation/screens/notebook_screen.dart';
import '../../../reader/presentation/screens/reader_screen.dart';
import '../../domain/note_entities.dart';
import '../controllers/notes_controller.dart';

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
    final title = switch (selection.kind) {
      SelectionKind.notesUnfiled => 'Catatan tanpa koleksi',
      SelectionKind.noteCollection =>
        index.collections
                .where((c) => c.key == selection.collectionKey)
                .map((c) => c.name)
                .firstOrNull ??
            'Catatan',
      _ => 'Semua catatan',
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
                      '${notes.length} catatan',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Buku catatan baru',
                icon: const Icon(Icons.auto_stories_outlined, size: 20),
                onPressed: () => _newNotebook(context, ref, selection),
              ),              IconButton(
                tooltip: 'Catatan Markdown baru',
                icon: const Icon(Icons.post_add_outlined, size: 20),
                onPressed: () => _newMarkdown(context, ref, selection),
              ),
              IconButton(
                tooltip: 'Tambah catatan dari berkas',
                icon: const Icon(Icons.note_add_outlined, size: 20),
                onPressed: () => _addFile(context, ref, selection),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (error != null)
          _NoteBanner(
            message: error,
            onClose: () => ref.read(notesErrorProvider.notifier).clear(),
          ),
        if (asyncNotes.isLoading && asyncNotes.value == null)
          const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 3)))
        else
          Expanded(
            child: notes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Belum ada catatan di sini. Seret berkas dari panel berkas, '
                        'atau pakai tombol tambah di atas.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _NoteTile(
                      note: notes[i],
                      directory: index.directory,
                      onOpen: () => _open(context, ref, notes[i], index),
                      onMenu: () => _menu(context, ref, notes[i]),
                    ),
                  ),
          ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.directory,
    required this.onOpen,
    required this.onMenu,
  });

  final NoteItem note;
  final String directory;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final icon = note.isNotebook
        ? Icons.auto_stories_outlined
        : switch (note.extension) {
      '.pdf' => Icons.picture_as_pdf_outlined,
      '.md' || '.txt' => Icons.notes_outlined,
      '.png' || '.jpg' || '.jpeg' || '.webp' => Icons.image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${p.basename(note.file)} · ${_when(note.dateModified)}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: IconButton(
        tooltip: 'Tindakan',
        icon: const Icon(Icons.more_vert, size: 20),
        onPressed: onMenu,
      ),
      onTap: onOpen,
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
              tooltip: 'Tutup',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _addFile(BuildContext context, WidgetRef ref, LibrarySelection selection) async {
  final picked = await FilePicker.pickFiles(dialogTitle: 'Pilih berkas catatan');
  final path = picked.isEmpty ? null : picked.first.path;
  if (path == null || !context.mounted) return;
  final key = await ref
      .read(notesControllerProvider.notifier)
      .addFile(
        sourcePath: path,
        title: p.basenameWithoutExtension(path),
        collectionKey: selection.noteCollectionKey,
      );
  if (!context.mounted || key != null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ref.read(notesErrorProvider) ?? 'Gagal menambahkan catatan')),
  );
}

/// Membuat buku catatan baru di koleksi yang sedang dipilih.
///
/// Berkasnya ditulis di folder sementara lalu disalin masuk oleh [NotesStore],
/// sama seperti catatan lain — supaya penamaan dan pencatatannya satu jalur.
Future<void> _newNotebook(BuildContext context, WidgetRef ref, LibrarySelection selection) async {
  final title = await _askText(context, title: 'Buku catatan baru', initial: 'Catatan');
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
      SnackBar(content: Text(ref.read(notesErrorProvider) ?? 'Gagal membuat buku catatan')),
    );
    return;
  }

  final index = ref.read(notesControllerProvider).value ?? NotesIndex.empty;
  final note = index.items.firstWhereOrNull((item) => item.key == key);
  if (note == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute<String>(
      builder: (_) => NotebookScreen(
        path: p.join(index.directory, note.file),
        title: note.title,
      ),
    ),
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
  final title = await _askText(context, title: 'Catatan baru', initial: 'Catatan');
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
      SnackBar(content: Text(ref.read(notesErrorProvider) ?? 'Gagal membuat catatan')),
    );
    return;
  }

  final index = ref.read(notesControllerProvider).value ?? NotesIndex.empty;
  final note = index.items.firstWhereOrNull((item) => item.key == key);
  if (note == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute<String>(
      builder: (_) => MarkdownEditorScreen(
        path: p.join(index.directory, note.file),
        title: note.title,
        startInEdit: true,
      ),
    ),
  );
  // Isinya berubah di luar store, jadi commit-nya dilakukan di sini.
  await controller.touch(itemKey: key, message: 'Ubah catatan: ${note.title}');
}

Future<void> _open(
  BuildContext context,
  WidgetRef ref,
  NoteItem note,
  NotesIndex index,
) async {
  final path = p.join(index.directory, note.file);
  if (note.isNotebook) {
    await Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (_) => NotebookScreen(path: path, title: note.title),
      ),
    );
    await ref
        .read(notesControllerProvider.notifier)
        .touch(itemKey: note.key, message: 'Ubah catatan: ${note.title}');
    return;
  }
  if (note.isMarkdown) {
    await Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (_) => MarkdownEditorScreen(path: path, title: note.title),
      ),
    );
    // Penyuntingnya sudah menulis berkasnya; yang tersisa adalah mencatat
    // perubahannya ke git, sama seperti perubahan catatan yang lain.
    await ref
        .read(notesControllerProvider.notifier)
        .touch(itemKey: note.key, message: 'Ubah catatan: ${note.title}');
    return;
  }
  if (note.isPdf) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          itemKey: '',
          itemFilePath: '',
          attachmentKey: '',
          filePath: path,
          title: note.title,
        ),
      ),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Berkas ${note.extension.isEmpty ? 'ini' : note.extension} belum bisa dibuka '
        'di dalam aplikasi. Yang sudah bisa: PDF, Markdown, dan buku catatan.',
      ),
    ),
  );
}

Future<void> _menu(BuildContext context, WidgetRef ref, NoteItem note) async {
  final index = ref.read(notesControllerProvider).value ?? NotesIndex.empty;
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(dense: true, title: Text(note.title)),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Ubah judul'),
            onTap: () => Navigator.of(sheet).pop('nama'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: const Text('Pindahkan ke koleksi'),
            onTap: () => Navigator.of(sheet).pop('pindah'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Hapus catatan'),
            subtitle: const Text('Berkasnya ikut terhapus'),
            onTap: () => Navigator.of(sheet).pop('hapus'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final controller = ref.read(notesControllerProvider.notifier);

  switch (action) {
    case 'nama':
      final name = await _askText(context, title: 'Ubah judul', initial: note.title);
      if (name == null || name.trim().isEmpty) return;
      await controller.rename(itemKey: note.key, title: name);
    case 'pindah':
      final target = await _pickCollection(context, index);
      if (target == null) return;
      await controller.fileInto(
        itemKey: note.key,
        collectionKey: target.isEmpty ? null : target,
      );
    case 'hapus':
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Hapus catatan?'),
          content: Text('“${note.title}” beserta berkasnya akan dihapus dari repositori.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );
      if (yes ?? false) await controller.deleteItem(note.key);
  }
}

/// Mengembalikan kunci koleksi, string kosong untuk "tanpa koleksi", atau
/// null kalau dibatalkan.
Future<String?> _pickCollection(BuildContext context, NotesIndex index) => showModalBottomSheet<String>(
  context: context,
  builder: (sheet) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.folder_off_outlined),
          title: const Text('Tanpa koleksi'),
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
        decoration: const InputDecoration(labelText: 'Judul'),
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
