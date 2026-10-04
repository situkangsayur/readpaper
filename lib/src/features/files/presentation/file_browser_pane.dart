import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/layout_size.dart';
import '../../../core/utils/work_folder.dart';
import '../../epub/presentation/epub_reader_screen.dart';
import '../../notebook/presentation/share_note.dart';
import '../../../shared/widgets/tree_drag.dart';
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
  const FileBrowserPane({this.collapsed = false, this.onToggleCollapsed, super.key});

  /// Hanya kepala panelnya yang tampil.
  ///
  /// Panel berkas berguna saat sedang memasukkan sesuatu, dan cuma jadi
  /// penyempit pohon koleksi di waktu lain — jadi ia bisa dilipat ke bawah.
  final bool collapsed;

  final VoidCallback? onToggleCollapsed;

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
  Future<void> _openDefault() async => _open(await WorkFolder.dir());

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

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    if (dir == null) {
      _say('Folder kerjanya belum siap. Pilih folder lain lewat ikon folder.');
      return;
    }
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
  /// Mengganti nama berkas atau folder di folder kerja.
  Future<void> _rename(FileSystemEntity file) async {
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
    final target = p.join(file.parent.path, safe);
    if (FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound) {
      _say('Sudah ada berkas atau folder bernama itu');
      return;
    }
    try {
      await file.rename(target);
    } on FileSystemException catch (e) {
      _say('Gagal mengganti nama: ${e.osError?.message ?? e.message}');
    }
    await _open(file.parent);
  }

  /// Menghapus folder beserta isinya.
  ///
  /// Jumlah berkasnya disebut lebih dulu: "hapus folder" yang ternyata
  /// membawa tiga puluh papan tulis adalah kejutan yang tidak bisa diurungkan.
  /// Folder kerja itu sendiri ditolak — tanpanya panel ini tidak punya
  /// tempat lagi.
  Future<void> _deleteFolder(Directory folder) async {
    final root = await WorkFolder.dir();
    if (p.equals(p.normalize(folder.path), p.normalize(root.path))) {
      _say('Folder kerja itu sendiri tidak bisa dihapus dari sini.');
      return;
    }
    var files = 0;
    try {
      files = folder.listSync(recursive: true).whereType<File>().length;
    } on FileSystemException {
      files = -1;
    }
    if (!mounted) return;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus folder ini?'),
        content: Text(
          '${p.basename(folder.path)}\n\n'
          '${files == 0
              ? 'Foldernya kosong.'
              : files < 0
              ? 'Isinya tidak bisa dihitung.'
              : '$files berkas di dalamnya ikut terhapus.'} '
          'Salinan yang sudah masuk library tidak tersentuh.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(files > 0 ? 'Hapus $files berkas' : 'Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await folder.delete(recursive: true);
    } on FileSystemException catch (e) {
      _say('Gagal menghapus: ${e.osError?.message ?? e.message}');
    }
    await _open(folder.parent);
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
    if (dir == null) {
      _say('Folder kerjanya belum siap. Pilih folder lain lewat ikon folder.');
      return;
    }

    // Arah kertas dipilih di sini juga, bukan hanya di dalam papannya: yang
    // mau menggambar bagan mendatar tahu itu sebelum mulai, dan memutar kertas
    // setelah menggambar selalu lebih merepotkan daripada memilihnya dulu.
    var orientation = BoardOrientation.tegak;
    final chosen = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
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
              SegmentedButton<BoardOrientation>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<BoardOrientation>>[
                  ButtonSegment<BoardOrientation>(
                    value: BoardOrientation.tegak,
                    icon: Icon(Icons.crop_portrait, size: 18),
                    label: Text('Tegak'),
                  ),
                  ButtonSegment<BoardOrientation>(
                    value: BoardOrientation.mendatar,
                    icon: Icon(Icons.crop_landscape, size: 18),
                    label: Text('Mendatar'),
                  ),
                ],
                selected: <BoardOrientation>{orientation},
                onSelectionChanged: (value) => setSheetState(() => orientation = value.first),
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
                  onTap: () => Navigator.of(sheet).pop(option.color),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;

    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            WhiteboardScreen(background: chosen, saveDir: dir.path, orientation: orientation),
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
    if (dir == null) {
      _say('Folder kerjanya belum siap. Pilih folder lain lewat ikon folder.');
      return;
    }
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
    if (dir == null) {
      _say('Folder kerjanya belum siap. Pilih folder lain lewat ikon folder.');
      return;
    }
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
    if (dir == null) {
      _say('Folder kerjanya belum siap. Pilih folder lain lewat ikon folder.');
      return;
    }
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
      MaterialPageRoute<String>(
        builder: (_) => NotebookScreen(path: target, title: stem),
      ),
    );
    await _open(dir);
  }

  void _openFile(File file) {
    final extension = p.extension(file.path).toLowerCase();
    if (NoteDocumentStore.isNoteDocument(file.path)) {
      Navigator.of(context).push(
        MaterialPageRoute<String>(
          builder: (_) =>
              NotebookScreen(path: file.path, title: NoteDocumentStore.stemOf(file.path)),
        ),
      );
      return;
    }
    if (extension == '.md') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<String>(builder: (_) => MarkdownEditorScreen(path: file.path)));
      return;
    }
    if (extension == '.epub') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => EpubReaderScreen(path: file.path)));
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
        // Kepala panel: nama folder, lalu empat kendali saja. Sebelumnya ada
        // tujuh ikon berdesakan di panel selebar 300 titik, dan yang mencari
        // "buat folder" atau "buka berkas" tidak pernah tahu yang mana.
        InkWell(
          onTap: widget.onToggleCollapsed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Row(
              children: <Widget>[
                if (widget.onToggleCollapsed != null)
                  Icon(
                    widget.collapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                Expanded(
                  child: Text(
                    dir == null ? 'Berkas' : p.basename(dir.path),
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!widget.collapsed) ...<Widget>[
                  IconButton(
                    tooltip: 'Naik satu tingkat',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    onPressed: dir == null || dir.parent.path == dir.path
                        ? null
                        : () => _open(dir.parent),
                  ),
                  PopupMenuButton<String>(
                    // Tetap bisa dibuka walau foldernya belum siap: tombol mati
                    // tanpa keterangan adalah jebakan yang sama seperti tombol
                    // yang tidak bisa ditekan.
                    tooltip: 'Buat baru di folder ini',
                    iconSize: 20,
                    icon: const Icon(Icons.add_circle_outline),
                    onSelected: (choice) => switch (choice) {
                      'papan' => _newBoard(),
                      'markdown' => _newMarkdown(),
                      'catatan' => _newNotebook(),
                      _ => _newFolder(),
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'papan',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.draw_outlined),
                          title: Text('Papan tulis'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'catatan',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.auto_stories_outlined),
                          title: Text('Buku catatan'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'markdown',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.post_add_outlined),
                          title: Text('Berkas Markdown'),
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'folder',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.create_new_folder_outlined),
                          title: Text('Folder'),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Salin berkas ke sini — dari mana pun di perangkat',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.file_download_outlined),
                    onPressed: dir == null ? null : _copyIn,
                  ),
                  IconButton(
                    tooltip: 'Buka folder lain',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.folder_open_outlined),
                    onPressed: _pickFolder,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.collapsed) const SizedBox.shrink(),
        if (_error != null && !widget.collapsed)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
          ),
        if (!widget.collapsed)
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
                      onDeleteFolder: _deleteFolder,
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
    required this.onDeleteFolder,
  });

  final FileSystemEntity entry;
  final void Function(Directory dir) onOpenDir;
  final void Function(File file) onOpenFile;
  final void Function(FileSystemEntity entry) onRename;
  final void Function(File file) onDelete;
  final void Function(Directory dir) onDeleteFolder;

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
                PopupMenuButton<String>(
                  tooltip: 'Tindakan folder',
                  icon: Icon(Icons.more_vert, size: 16, color: scheme.outline),
                  padding: EdgeInsets.zero,
                  onSelected: (choice) => switch (choice) {
                    'buka' => onOpenDir(entry as Directory),
                    'ganti-nama' => onRename(entry),
                    _ => onDeleteFolder(entry as Directory),
                  },
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'buka', child: Text('Buka')),
                    PopupMenuItem<String>(value: 'ganti-nama', child: Text('Ganti nama')),
                    PopupMenuItem<String>(value: 'hapus', child: Text('Hapus folder')),
                  ],
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
    final isEpub = extension == '.epub';
    final isMarkdown = extension == '.md';
    final isNotebook = NoteDocumentStore.isNoteDocument(name);
    final canOpen = isPdf || isEpub || isMarkdown || isNotebook;
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
                    : isEpub
                    ? Icons.menu_book_outlined
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
                  'bagikan' => shareAnyFile(context, file.path),
                  'ganti-nama' => onRename(file),
                  _ => onDelete(file),
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  if (canOpen) const PopupMenuItem<String>(value: 'buka', child: Text('Buka')),
                  const PopupMenuItem<String>(value: 'bagikan', child: Text('Bagikan')),
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

    return LongPressDraggable<TreeDrag>(
      data: FileDrag(path: file.path, label: name),
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
