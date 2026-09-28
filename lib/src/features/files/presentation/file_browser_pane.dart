import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/layout_size.dart';
import '../../markdown/presentation/screens/markdown_editor_screen.dart';
import '../../notebook/data/note_document_store.dart';
import '../../notebook/presentation/screens/notebook_screen.dart';
import '../../reader/presentation/screens/reader_screen.dart';
import '../../whiteboard/domain/board.dart';
import '../../whiteboard/presentation/whiteboard_screen.dart';

/// Penjelajah berkas di bawah pohon koleksi.
///
/// Pohon koleksi memperlihatkan apa yang sudah ada di dalam library. Yang
/// selama ini tidak terlihat sama sekali adalah berkas di perangkat —
/// formulir yang baru ditandatangani, PDF yang dikirim lewat pesan, papan
/// tulis yang baru disimpan. Semuanya berakhir di suatu folder dan harus
/// dicari lagi lewat pemilih berkas setiap kali.
///
/// Dari sini berkas bisa dibuka, dan bisa **diseret ke sebuah koleksi** di
/// pohon di atasnya untuk dimasukkan ke library.
class FileBrowserPane extends ConsumerStatefulWidget {
  const FileBrowserPane({super.key});

  @override
  ConsumerState<FileBrowserPane> createState() => _FileBrowserPaneState();
}

class _FileBrowserPaneState extends ConsumerState<FileBrowserPane> {
  Directory? _dir;
  List<FileSystemEntity> _entries = const <FileSystemEntity>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _openDefault();
  }

  /// Folder kerja bawaan: satu tempat milik aplikasi, supaya berkas yang
  /// disimpan dari dalam ReadPaper tidak tersebar.
  Future<void> _openDefault() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'readpaper'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    await _open(dir);
  }

  Future<void> _open(Directory dir) async {
    try {
      final entries = dir.listSync(followLinks: false)
        ..sort((a, b) {
          final aDir = a is Directory;
          final bDir = b is Directory;
          if (aDir != bDir) return aDir ? -1 : 1;
          return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
        });
      if (!mounted) return;
      setState(() {
        _dir = dir;
        _entries = entries;
        _error = null;
      });
    } on FileSystemException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Pilih folder kerja');
    if (path == null) return;
    await _open(Directory(path));
  }

  /// Menyalin berkas dari mana pun di perangkat ke folder kerja.
  ///
  /// Android melarang memberikan akses ke folder Download lewat pemilih
  /// folder — "Tidak dapat menggunakan folder ini" — jadi memindahkan
  /// pandangan ke sana memang tidak bisa. Yang bisa adalah memilih
  /// berkasnya, dan itu justru yang dimaui: satu salinan di folder kerja,
  /// bukan berkas di tempat yang bisa hilang kapan saja.
  Future<void> _copyIn() async {
    final dir = _dir;
    if (dir == null) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
      dialogTitle: 'Pilih PDF untuk disalin ke sini',
    );
    if (picked.isEmpty) return;

    var copied = 0;
    for (final item in picked) {
      final source = item.path;
      if (source == null) continue;
      var target = File(p.join(dir.path, p.basename(source)));
      // Nama yang sudah ada tidak ditimpa: yang menyalin tidak sedang
      // meminta berkas lamanya hilang.
      for (var n = 2; target.existsSync() && n < 100; n++) {
        final stem = p.basenameWithoutExtension(source);
        target = File(p.join(dir.path, '$stem-$n${p.extension(source)}'));
      }
      await File(source).copy(target.path);
      copied++;
    }
    await _open(dir);
    if (mounted && copied > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$copied berkas disalin ke sini')));
    }
  }

  /// Papan tulis baru: pilih warna latarnya, gambar, lalu hasilnya tersimpan
  /// sebagai PDF di folder ini — langsung terlihat, dan bisa diseret ke
  /// koleksi seperti berkas lain.
  /// Mengganti nama berkas di folder kerja.
  Future<void> _rename(File file) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: p.basename(file.path));
        return AlertDialog(
          title: const Text('Ganti nama'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    // Nama yang mengandung pemisah folder akan memindahkan berkasnya ke
    // tempat lain, bukan mengganti namanya.
    final safe = trimmed.replaceAll(RegExp(r'[\\/]'), '-');
    final target = File(p.join(file.parent.path, safe));
    if (target.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Sudah ada berkas bernama itu')));
      }
      return;
    }
    await file.rename(target.path);
    await _open(file.parent);
  }

  /// Menghapus berkas dari folder kerja.
  ///
  /// Hanya berkas di perangkat; yang sudah masuk library dihapus dari
  /// panel detailnya, dan itu memang dua hal yang berbeda.
  Future<void> _deleteFile(File file) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus berkas ini?'),
        content: Text(
          '${p.basename(file.path)}\n\nDihapus dari folder ini. Salinan yang '
          'sudah masuk library tidak tersentuh.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await file.delete();
    await _open(file.parent);
  }

  Future<void> _newBoard() async {
    final dir = _dir;
    if (dir == null) return;

    final chosen = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: <Widget>[
            Text('Papan tulis baru', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Berlembar-lembar, bisa dicoreti, lalu disimpan sebagai PDF di '
              'folder ini.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final option in BoardBackgrounds.all)
              ListTile(
                leading: Container(
                  width: 34,
                  height: 26,
                  decoration: BoxDecoration(
                    color: option.color,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                title: Text(option.name),
                onTap: () => Navigator.of(context).pop(option.color),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;

    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => WhiteboardScreen(background: chosen, saveDir: dir.path),
      ),
    );
    await _open(dir);
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${p.basename(saved)} tersimpan di folder ini')));
    }
  }

  Future<void> _newFolder() async {
    final dir = _dir;
    if (dir == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Folder baru'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nama'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Buat'),
            ),
          ],
        );
      },
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    // Nama yang mengandung pemisah folder akan membuat folder di tempat lain
    // daripada di sini, dan itu tidak pernah yang dimaksud.
    final safe = trimmed.replaceAll(RegExp(r'[\\/]'), '-');
    await Directory(p.join(dir.path, safe)).create(recursive: true);
    await _open(dir);
  }

  /// Membuat berkas Markdown kosong di folder ini, lalu membukanya.
  Future<void> _newMarkdown() async {
    final dir = _dir;
    if (dir == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) {
        final controller = TextEditingController(text: 'catatan');
        return AlertDialog(
          title: const Text('Berkas Markdown baru'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama berkas', suffixText: '.md'),
            onSubmitted: (value) => Navigator.of(dialog).pop(value),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(controller.text),
              child: const Text('Buat'),
            ),
          ],
        );
      },
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final stem = trimmed.replaceAll(RegExp(r'[\\/]'), '-').replaceAll(RegExp(r'\.md$'), '');

    var file = File(p.join(dir.path, '$stem.md'));
    // Berkas yang sudah ada tidak ditimpa: yang membuat berkas baru tidak
    // sedang meminta yang lama hilang.
    for (var n = 2; file.existsSync() && n < 100; n++) {
      file = File(p.join(dir.path, '$stem-$n.md'));
    }
    await file.writeAsString('# $stem\n\n');
    await _open(dir);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (_) => MarkdownEditorScreen(path: file.path, startInEdit: true),
      ),
    );
  }

  /// Membuat buku catatan baru di folder ini, lalu membukanya.
  Future<void> _newNotebook() async {
    final dir = _dir;
    if (dir == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) {
        final controller = TextEditingController(text: 'catatan');
        return AlertDialog(
          title: const Text('Buku catatan baru'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama', suffixText: '.catatan.json'),
            onSubmitted: (value) => Navigator.of(dialog).pop(value),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(controller.text),
              child: const Text('Buat'),
            ),
          ],
        );
      },
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final stem = trimmed.replaceAll(RegExp(r'[\\/]'), '-');

    var target = p.join(dir.path, '$stem${NoteDocumentStore.extension}');
    for (var n = 2; File(target).existsSync() && n < 100; n++) {
      target = p.join(dir.path, '$stem-$n${NoteDocumentStore.extension}');
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<String>(builder: (_) => NotebookScreen(path: target, title: stem)),
    );
    await _open(dir);
  }

  void _openFile(File file) {
    final extension = p.extension(file.path).toLowerCase();
    if (NoteDocumentStore.isNoteDocument(file.path)) {
      Navigator.of(context).push(
        MaterialPageRoute<String>(
          builder: (_) => NotebookScreen(
            path: file.path,
            title: NoteDocumentStore.stemOf(file.path),
          ),
        ),
      );
      return;
    }
    if (extension == '.md') {
      Navigator.of(context).push(
        MaterialPageRoute<String>(builder: (_) => MarkdownEditorScreen(path: file.path)),
      );
      return;
    }
    if (extension != '.pdf') return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          itemKey: '',
          itemFilePath: '',
          attachmentKey: '',
          filePath: file.path,
          title: p.basenameWithoutExtension(file.path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dir = _dir;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  dir == null ? 'Berkas' : p.basename(dir.path),
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Naik satu tingkat',
                iconSize: 18,
                icon: const Icon(Icons.drive_folder_upload_outlined),
                onPressed: dir == null || dir.parent.path == dir.path
                    ? null
                    : () => _open(dir.parent),
              ),
              IconButton(
                tooltip: 'Papan tulis baru',
                iconSize: 18,
                icon: const Icon(Icons.draw_outlined),
                onPressed: dir == null ? null : _newBoard,
              ),
              IconButton(
                tooltip: 'Berkas Markdown baru',
                iconSize: 18,
                icon: const Icon(Icons.post_add_outlined),
                onPressed: dir == null ? null : _newMarkdown,
              ),
              IconButton(
                tooltip: 'Buku catatan baru',
                iconSize: 18,
                icon: const Icon(Icons.auto_stories_outlined),
                onPressed: dir == null ? null : _newNotebook,
              ),
              IconButton(
                tooltip: 'Salin berkas ke sini',
                iconSize: 18,
                icon: const Icon(Icons.file_download_outlined),
                onPressed: dir == null ? null : _copyIn,
              ),
              IconButton(
                tooltip: 'Folder baru',
                iconSize: 18,
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: dir == null ? null : _newFolder,
              ),
              IconButton(
                tooltip: 'Buka folder lain',
                iconSize: 18,
                icon: const Icon(Icons.folder_open_outlined),
                onPressed: _pickFolder,
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
          ),
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Folder ini kosong.\n\nBuat papan tulis, atau salin PDF ke '
                      'sini dengan tombol unduh di atas — lalu seret ke sebuah '
                      'koleksi untuk memasukkannya ke library.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) => _EntryRow(
                    entry: _entries[i],
                    onOpenDir: _open,
                    onOpenFile: _openFile,
                    onRename: _rename,
                    onDelete: _deleteFile,
                  ),
                ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.onOpenDir,
    required this.onOpenFile,
    required this.onRename,
    required this.onDelete,
  });

  final FileSystemEntity entry;
  final void Function(Directory dir) onOpenDir;
  final void Function(File file) onOpenFile;
  final void Function(File file) onRename;
  final void Function(File file) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = p.basename(entry.path);

    if (entry is Directory) {
      return SizedBox(
        height: treeRowHeight,
        child: InkWell(
          onTap: () => onOpenDir(entry as Directory),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Icon(Icons.folder_outlined, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: scheme.outline),
              ],
            ),
          ),
        ),
      );
    }

    final file = entry as File;
    final extension = p.extension(name).toLowerCase();
    final isPdf = extension == '.pdf';
    final isMarkdown = extension == '.md';
    final isNotebook = NoteDocumentStore.isNoteDocument(name);
    final canOpen = isPdf || isMarkdown || isNotebook;
    final row = SizedBox(
      height: treeRowHeight,
      child: InkWell(
        onTap: canOpen ? () => onOpenFile(file) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              Icon(
                isPdf
                    ? Icons.picture_as_pdf_outlined
                    : isNotebook
                    ? Icons.auto_stories_outlined
                    : (isMarkdown ? Icons.notes_outlined : Icons.insert_drive_file_outlined),
                size: 15,
                color: canOpen ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: canOpen ? null : scheme.outline),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tindakan berkas',
                icon: Icon(Icons.more_vert, size: 16, color: scheme.outline),
                padding: EdgeInsets.zero,
                onSelected: (choice) => switch (choice) {
                  'buka' => onOpenFile(file),
                  'ganti-nama' => onRename(file),
                  _ => onDelete(file),
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  if (canOpen)
                    const PopupMenuItem<String>(value: 'buka', child: Text('Buka')),
                  const PopupMenuItem<String>(value: 'ganti-nama', child: Text('Ganti nama')),
                  const PopupMenuItem<String>(value: 'hapus', child: Text('Hapus berkas')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Hanya PDF yang bisa diseret ke koleksi: itulah yang bisa dijadikan item
    // Zotero. Berkas lain tetap terlihat — supaya folder tidak tampak kosong
    // padahal ada isinya — tapi tidak menawarkan sesuatu yang belum ada.
    if (!isPdf) return row;

    return LongPressDraggable<String>(
      data: file.path,
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
              const Icon(Icons.picture_as_pdf_outlined, size: 16),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );
  }
}
