import 'dart:async';
import 'dart:io';

import '../../../core/utils/file_pick.dart';
import '../../../shared/widgets/file_drop_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/layout_size.dart';
import '../../../core/utils/frame_guard.dart';
import '../../../core/utils/work_folder.dart';
import '../../epub/presentation/epub_reader_screen.dart';
import '../../notebook/presentation/share_note.dart';
import '../../../shared/widgets/tree_drag.dart';
import '../../markdown/presentation/screens/markdown_editor_screen.dart';
import '../../notebook/data/note_document_store.dart';
import '../../notebook/presentation/screens/notebook_screen.dart';
import '../../reader/presentation/screens/reader_screen.dart';
import '../../tabs/presentation/document_tabs.dart';
import '../../whiteboard/domain/board.dart';
import '../../whiteboard/presentation/whiteboard_screen.dart';
import 'open_any_file.dart';
import '../domain/folder_scan.dart';
import '../../../core/l10n.dart';

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

  /// Folder yang terbuka diawasi: berkas yang disimpan aplikasi lain, disalin
  /// pengelola berkas, atau datang lewat pull tampil tanpa harus membuka
  /// folder itu lagi.
  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _settle;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _relist);
    _openDefault();
  }

  @override
  void dispose() {
    _watch?.cancel();
    _settle?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _relist() {
    final dir = _dir;
    if (dir != null && mounted) _open(dir);
  }

  void _watchDir(Directory dir) {
    _watch?.cancel();
    _watch = null;
    try {
      // Satu tingkat saja: hanya isi folder ini yang tampil di daftar. Satu
      // salinan besar memicu puluhan peristiwa, jadi daftarnya dibaca ulang
      // sekali sesudah semuanya reda.
      _watch = dir.watch().listen((_) {
        _settle?.cancel();
        _settle = Timer(const Duration(milliseconds: 300), _relist);
      }, onError: (_) {});
    } on FileSystemException {
      // Tanpa pengawas, kembali ke aplikasi tetap membaca ulang.
    }
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
      if (_dir?.path != dir.path || _watch == null) _watchDir(dir);
      setState(() {
        _dir = dir;
        _entries = entries;
        _error = null;
      });
      FrameGuard.kick();
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
    final path = await pickDirectoryOrTell(context, title: context.l10n.filesPickWorkFolder);
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
      _say(context.l10n.filesWorkFolderNotReady);
      return;
    }
    final picked = await pickFilesOrTell(context, title: context.l10n.filesPickFilesToCopy);
    if (picked.isEmpty) return;
    await _copyPaths(picked);
  }

  /// Menyalin [paths] ke folder kerja yang sedang terbuka — dari pemilih
  /// berkas, atau diseret dari pengelola berkas.
  Future<void> _copyPaths(List<String> paths) async {
    final dir = _dir;
    if (dir == null) return;
    var copied = 0;
    for (final source in paths) {
      if (Directory(source).existsSync()) {
        // Folder disalin utuh dengan strukturnya; nama yang sudah ada diberi
        // akhiran, seperti berkas.
        var targetDir = Directory(p.join(dir.path, p.basename(source)));
        for (var n = 2; targetDir.existsSync() && n < 100; n++) {
          targetDir = Directory(p.join(dir.path, '${p.basename(source)}-$n'));
        }
        copied += await _copyFolder(Directory(source), targetDir);
        continue;
      }
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
        ..showSnackBar(SnackBar(content: Text(context.l10n.filesCopiedHere(copied))));
    }
  }

  static Future<int> _copyFolder(Directory from, Directory to) async {
    await to.create(recursive: true);
    var count = 0;
    await for (final entry in from.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (FolderScan.skipped(name)) continue;
      if (entry is Directory) {
        count += await _copyFolder(entry, Directory(p.join(to.path, name)));
      } else if (entry is File) {
        await entry.copy(p.join(to.path, name));
        count++;
      }
    }
    return count;
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
          title: Text(context.l10n.filesRename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.filesCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(context.l10n.filesSave),
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
      if (mounted) _say(context.l10n.filesNameTaken);
      return;
    }
    try {
      await file.rename(target);
    } on FileSystemException catch (e) {
      if (mounted) _say(context.l10n.filesRenameFailed(e.osError?.message ?? e.message));
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
      if (mounted) _say(context.l10n.filesCannotDeleteRoot);
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
        title: Text(context.l10n.filesDeleteFolderTitle),
        content: Text(
          '${p.basename(folder.path)}\n\n'
          '${files == 0
              ? context.l10n.filesFolderEmpty
              : files < 0
              ? context.l10n.filesFolderUncountable
              : context.l10n.filesFolderDeletesCount(files)} '
          '${context.l10n.filesLibraryCopiesUntouched}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.filesCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              files > 0 ? context.l10n.filesDeleteCount(files) : context.l10n.filesDelete,
            ),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await folder.delete(recursive: true);
    } on FileSystemException catch (e) {
      if (mounted) _say(context.l10n.filesDeleteFailed(e.osError?.message ?? e.message));
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
        title: Text(context.l10n.filesDeleteFileTitle),
        content: Text(context.l10n.filesDeleteFileBody(p.basename(file.path))),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.filesCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.filesDelete),
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
      _say(context.l10n.filesWorkFolderNotReady);
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
              Text(context.l10n.filesNewBoardTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(context.l10n.filesNewBoardBody, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              SegmentedButton<BoardOrientation>(
                showSelectedIcon: false,
                segments: <ButtonSegment<BoardOrientation>>[
                  ButtonSegment<BoardOrientation>(
                    value: BoardOrientation.tegak,
                    icon: const Icon(Icons.crop_portrait, size: 18),
                    label: Text(context.l10n.filesPortrait),
                  ),
                  ButtonSegment<BoardOrientation>(
                    value: BoardOrientation.mendatar,
                    icon: const Icon(Icons.crop_landscape, size: 18),
                    label: Text(context.l10n.filesLandscape),
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
        ..showSnackBar(SnackBar(content: Text(context.l10n.filesSavedHere(p.basename(saved)))));
    }
  }

  Future<void> _newFolder() async {
    final dir = _dir;
    if (dir == null) {
      _say(context.l10n.filesWorkFolderNotReady);
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(context.l10n.filesNewFolderTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: context.l10n.filesNameLabel,
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.filesCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(context.l10n.filesCreate),
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
      _say(context.l10n.filesWorkFolderNotReady);
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) {
        final controller = TextEditingController(text: 'catatan');
        return AlertDialog(
          title: Text(context.l10n.filesNewMarkdownTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.filesFileNameLabel,
              suffixText: '.md',
            ),
            onSubmitted: (value) => Navigator.of(dialog).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: Text(context.l10n.filesCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(controller.text),
              child: Text(context.l10n.filesCreate),
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
    await openDocument<String>(
      context,
      MarkdownEditorScreen(path: file.path, startInEdit: true),
      title: p.basenameWithoutExtension(file.path),
      icon: Icons.notes_outlined,
      dedupeKey: file.path,
    );
  }

  /// Membuat buku catatan baru di folder ini, lalu membukanya.
  Future<void> _newNotebook() async {
    final dir = _dir;
    if (dir == null) {
      _say(context.l10n.filesWorkFolderNotReady);
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) {
        final controller = TextEditingController(text: 'catatan');
        return AlertDialog(
          title: Text(context.l10n.filesNewNotebookTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.filesNameLabel,
              suffixText: '.catatan.json',
            ),
            onSubmitted: (value) => Navigator.of(dialog).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: Text(context.l10n.filesCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(controller.text),
              child: Text(context.l10n.filesCreate),
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
    await openDocument<String>(
      context,
      NotebookScreen(path: target, title: stem),
      title: stem,
      icon: Icons.edit_note,
      dedupeKey: target,
    );
    await _open(dir);
  }

  void _openFile(File file) {
    final extension = p.extension(file.path).toLowerCase();
    if (NoteDocumentStore.isNoteDocument(file.path)) {
      openDocument<String>(
        context,
        NotebookScreen(path: file.path, title: NoteDocumentStore.stemOf(file.path)),
        title: NoteDocumentStore.stemOf(file.path),
        icon: Icons.edit_note,
        dedupeKey: file.path,
      );
      return;
    }
    if (extension == '.md') {
      openDocument<String>(
        context,
        MarkdownEditorScreen(path: file.path),
        title: p.basenameWithoutExtension(file.path),
        icon: Icons.notes_outlined,
        dedupeKey: file.path,
      );
      return;
    }
    if (extension == '.epub') {
      openDocument<void>(
        context,
        EpubReaderScreen(path: file.path),
        title: p.basenameWithoutExtension(file.path),
        icon: Icons.menu_book_outlined,
        dedupeKey: file.path,
      );
      return;
    }
    if (extension != '.pdf') {
      openAnyFile(context, file.path);
      return;
    }
    openDocument<void>(
      context,
      ReaderScreen(
        itemKey: '',
        itemFilePath: '',
        attachmentKey: '',
        filePath: file.path,
        title: p.basenameWithoutExtension(file.path),
      ),
      title: p.basenameWithoutExtension(file.path),
      icon: Icons.picture_as_pdf_outlined,
      dedupeKey: file.path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dir = _dir;
    final scheme = Theme.of(context).colorScheme;

    // Berkas yang diseret dari pengelola berkas sistem disalin ke folder ini,
    // sama seperti "Salin PDF ke sini" — apa pun jenisnya, karena folder kerja
    // juga menampung catatan, markdown, dan gambar.
    return FileDropZone(
      onFiles: _copyPaths,
      builder: (context, hovering) => DecoratedBox(
        decoration: BoxDecoration(
          color: hovering ? scheme.primary.withValues(alpha: 0.08) : null,
          border: hovering ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: Column(
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
                        dir == null ? context.l10n.filesHeader : p.basename(dir.path),
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!widget.collapsed) ...<Widget>[
                      IconButton(
                        tooltip: context.l10n.filesUpOneLevel,
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
                        tooltip: context.l10n.filesCreateHere,
                        iconSize: 20,
                        icon: const Icon(Icons.add_circle_outline),
                        onSelected: (choice) => switch (choice) {
                          'papan' => _newBoard(),
                          'markdown' => _newMarkdown(),
                          'catatan' => _newNotebook(),
                          _ => _newFolder(),
                        },
                        itemBuilder: (_) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'papan',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.draw_outlined),
                              title: Text(context.l10n.filesWhiteboard),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'catatan',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.auto_stories_outlined),
                              title: Text(context.l10n.filesNotebook),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'markdown',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.post_add_outlined),
                              title: Text(context.l10n.filesMarkdownFile),
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'folder',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.create_new_folder_outlined),
                              title: Text(context.l10n.filesFolder),
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        tooltip: context.l10n.filesCopyInTooltip,
                        iconSize: 18,
                        enabled: dir != null,
                        icon: const Icon(Icons.file_download_outlined),
                        onSelected: (choice) async {
                          if (choice == 'berkas') {
                            await _copyIn();
                            return;
                          }
                          final folder = await pickDirectoryOrTell(
                            context,
                            title: context.l10n.filesPickFolderToCopy,
                          );
                          if (folder != null) await _copyPaths(<String>[folder]);
                        },
                        itemBuilder: (_) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'berkas',
                            child: Text(context.l10n.filesCopyFiles),
                          ),
                          PopupMenuItem<String>(
                            value: 'folder',
                            child: Text(context.l10n.filesCopyFolder),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: context.l10n.filesOpenOtherFolder,
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
                            context.l10n.filesEmptyFolderHint,
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
        ),
      ),
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
                  tooltip: context.l10n.filesFolderActions,
                  icon: Icon(Icons.more_vert, size: 16, color: scheme.outline),
                  padding: EdgeInsets.zero,
                  onSelected: (choice) => switch (choice) {
                    'buka' => onOpenDir(entry as Directory),
                    'ganti-nama' => onRename(entry),
                    _ => onDeleteFolder(entry as Directory),
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'buka', child: Text(context.l10n.filesOpen)),
                    PopupMenuItem<String>(
                      value: 'ganti-nama',
                      child: Text(context.l10n.filesRename),
                    ),
                    PopupMenuItem<String>(
                      value: 'hapus',
                      child: Text(context.l10n.filesDeleteFolder),
                    ),
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
    final kind = fileKindOf(name);
    final canOpen =
        isPdf || isEpub || isMarkdown || isNotebook || canOpenInApp(name) || canOpenWithSystem;
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
                    : isMarkdown
                    ? Icons.notes_outlined
                    : kind == FileKind.image
                    ? Icons.image_outlined
                    : kind == FileKind.table
                    ? Icons.table_chart_outlined
                    : kind == FileKind.office
                    ? Icons.article_outlined
                    : Icons.insert_drive_file_outlined,
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
                tooltip: context.l10n.filesFileActions,
                icon: Icon(Icons.more_vert, size: 16, color: scheme.outline),
                padding: EdgeInsets.zero,
                onSelected: (choice) => switch (choice) {
                  'buka' => onOpenFile(file),
                  'bagikan' => shareAnyFile(context, file.path),
                  'ganti-nama' => onRename(file),
                  _ => onDelete(file),
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  if (canOpen)
                    PopupMenuItem<String>(value: 'buka', child: Text(context.l10n.filesOpen)),
                  PopupMenuItem<String>(value: 'bagikan', child: Text(context.l10n.filesShare)),
                  PopupMenuItem<String>(value: 'ganti-nama', child: Text(context.l10n.filesRename)),
                  PopupMenuItem<String>(value: 'hapus', child: Text(context.l10n.filesDeleteFile)),
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
