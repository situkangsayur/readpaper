import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/file_pick.dart';
import '../../../shared/widgets/file_drop_zone.dart';
import '../../../shared/widgets/tree_drag.dart';
import '../../files/domain/folder_scan.dart';
import '../../notes/domain/note_target.dart';
import '../../notes/presentation/controllers/notes_controller.dart';
import '../../workspace/presentation/controllers/workspace_controller.dart';

/// Memasukkan berkas dan folder ke library atau catatan — satu jalur untuk
/// semua tombol dan semua tempat lepas: menu koleksi, akar pohon, daftar
/// paper, daftar catatan, dan seretan dari pengelola berkas. Sebelumnya tiap
/// tombol punya versinya sendiri, dan yang tertinggal tetap khusus PDF.

/// Memilih folder lalu mengimpornya ke koleksi paper ([notes] false) atau
/// koleksi catatan [key] (null: di akar).
Future<void> pickFolderInto(
  BuildContext context,
  WidgetRef ref, {
  required bool notes,
  required String? key,
  required String name,
}) async {
  final path = await pickDirectoryOrTell(context, title: 'Pilih folder untuk $name');
  if (path == null || !context.mounted) return;
  await importFolderInto(context, ref, path, notes: notes, key: key, name: name);
}

/// Memilih berkas apa pun lalu memasukkannya ke koleksi catatan [key].
Future<void> pickFilesIntoNotes(
  BuildContext context,
  WidgetRef ref, {
  required String? key,
  required String name,
}) async {
  final paths = await pickFilesOrTell(context, title: 'Pilih berkas untuk $name');
  for (final path in paths) {
    if (!context.mounted) return;
    await dropIntoNotes(context, ref, FileDrag(path: path, label: p.basename(path)), key, name);
  }
}

/// Memilih satu atau beberapa PDF lalu memasukkannya ke koleksi [key]
/// (null: library tanpa koleksi), satu per satu lewat jalur yang sama dengan
/// menyeret berkas ke pohon.
Future<void> pickFilesIntoPapers(
  BuildContext context,
  WidgetRef ref,
  String? key,
  String name,
) async {
  final paths = await pickFilesOrTell(context, title: 'Pilih berkas untuk $name');
  final failed = <String>[];
  for (final path in paths) {
    if (!context.mounted) return;
    final ok = await dropIntoPapers(
      context,
      ref,
      FileDrag(path: path, label: p.basename(path)),
      key,
      name,
    );
    if (!ok) failed.add(p.basename(path));
  }
  // Satu berkas sudah dilaporkan oleh pesannya sendiri; beberapa berkas
  // dirangkum, dan yang gagal disebut namanya.
  if (paths.length > 1 && context.mounted) {
    final added = paths.length - failed.length;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: failed.isEmpty ? 4 : 10),
          content: Text(
            failed.isEmpty
                ? '$added berkas masuk ke $name'
                : '$added dari ${paths.length} berkas masuk ke $name. Gagal: ${failed.join(', ')}. '
                      '${ref.read(workspaceControllerProvider).error ?? ''}',
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
Future<bool> dropIntoPapers(
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
      return false;

    case ItemDrag():
      final item = ref.read(workspaceControllerProvider).index?.items[drag.itemKey];
      if (item == null) return false;
      say('Memindahkan ke $collectionName…');
      final ok = await ref
          .read(workspaceControllerProvider.notifier)
          .moveItemToCollection(item: item, collectionKey: collectionKey);
      if (!context.mounted) return ok;
      say(
        ok
            ? 'Pindah ke $collectionName'
            : (ref.read(workspaceControllerProvider).error ?? 'Gagal memindahkan'),
      );
      return ok;

    case FileDrag():
      // Folder: strukturnya jadi koleksi dan sub-koleksi.
      if (Directory(drag.path).existsSync()) {
        return importFolderInto(
          context,
          ref,
          drag.path,
          notes: false,
          key: collectionKey,
          name: collectionName,
        );
      }
      // Berkas apa pun boleh: Zotero menyimpan lampiran jenis apa saja dan
      // membuka yang bukan PDF dengan aplikasi bawaan sistemnya.
      say('Memasukkan ke $collectionName…');
      final created = await ref
          .read(workspaceControllerProvider.notifier)
          .addFileToLibrary(
            filePath: drag.path,
            title: p.basenameWithoutExtension(drag.path),
            collectionKey: collectionKey,
          );
      if (!context.mounted) return created != null;
      say(
        created == null
            ? (ref.read(workspaceControllerProvider).error ?? 'Gagal memasukkan berkas')
            : 'Masuk ke $collectionName',
      );
      return created != null;
  }
}

/// Menerima lepasan di akar catatan: berkas apa pun, atau catatan yang
/// dipindahkan antar koleksi.
///
/// Apa pun jenis berkasnya boleh: catatan bisa berupa PDF papan tulis,
/// markdown, buku catatan, atau gambar pindaian. Yang membedakannya dari paper
/// bukan formatnya, melainkan tempatnya.
Future<void> dropIntoNotes(
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
      if (Directory(drag.path).existsSync()) {
        await importFolderInto(
          context,
          ref,
          drag.path,
          notes: true,
          key: collectionKey,
          name: collectionName,
        );
        return;
      }
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

/// Mengimpor satu folder ke koleksi paper ([notes] false) atau koleksi
/// catatan: ditanya dulu dengan jumlah dan ukurannya, lalu dikerjakan dengan
/// kemajuan yang terlihat. True bila ada yang masuk.
Future<bool> importFolderInto(
  BuildContext context,
  WidgetRef ref,
  String path, {
  required bool notes,
  required String? key,
  required String name,
}) async {
  final folder = await Isolate.run(() => FolderScan.scan(path));
  final bytes = await Isolate.run(() => folder.totalBytes);
  if (!context.mounted) return false;
  if (folder.fileCount == 0) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Folder ${folder.name} tidak berisi berkas.')));
    return false;
  }
  final mb = bytes / (1024 * 1024);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text('Impor folder "${folder.name}" ke $name?'),
      content: Text(
        <String>[
          '${folder.fileCount} berkas dalam ${folder.folderCount} folder '
              '(${mb < 1 ? '${(bytes / 1024).ceil()} kB' : '${mb.toStringAsFixed(1)} MB'}).',
          notes
              ? 'Folder ini jadi koleksi catatan, subfoldernya jadi sub-koleksi, dan '
                    'setiap berkas jadi catatan.'
              : 'Folder ini jadi koleksi, subfoldernya jadi sub-koleksi, dan setiap berkas '
                    'jadi item Zotero dengan lampirannya — terlihat juga di Zotero.',
          'Koleksi yang namanya sudah ada di tempat yang sama dipakai, bukan digandakan.',
          if (mb > 100)
            'Ukurannya besar. Semua berkas ini masuk repositori git dan ikut terkirim ke '
                'GitHub.',
        ].join('\n\n'),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Impor')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  final progress = ValueNotifier<(int, int)>((0, folder.fileCount));
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('Mengimpor ${folder.name}…'),
          content: ValueListenableBuilder<(int, int)>(
            valueListenable: progress,
            builder: (_, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LinearProgressIndicator(value: value.$2 == 0 ? null : value.$1 / value.$2),
                const SizedBox(height: 8),
                Text('${value.$1} dari ${value.$2} berkas'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  void onProgress(int done, int total) => progress.value = (done, total);
  final result = notes
      ? await ref
            .read(notesControllerProvider.notifier)
            .importFolder(folder: folder, parentKey: key, onProgress: onProgress)
      : await ref
            .read(workspaceControllerProvider.notifier)
            .importFolderToLibrary(folder: folder, parentKey: key, onProgress: onProgress);
  navigator.pop();
  progress.dispose();
  final error = notes ? ref.read(notesErrorProvider) : ref.read(workspaceControllerProvider).error;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(seconds: result == null || result.failed.isNotEmpty ? 10 : 5),
        content: Text(
          result == null
              ? (error ?? 'Impor folder gagal')
              : <String>[
                  '${result.added} berkas masuk, ${result.collections} koleksi baru.',
                  if (result.failed.isNotEmpty)
                    'Gagal (${result.failed.length}): ${result.failed.take(3).join('; ')}'
                        '${result.failed.length > 3 ? '…' : ''}',
                ].join(' '),
        ),
      ),
    );
  return result != null && result.added > 0;
}

/// Tombol "tambah": berkas apa pun (beberapa sekaligus) atau satu folder yang
/// jadi koleksi beserta sub-koleksinya — ke koleksi paper atau catatan
/// [collectionKey] (null: akarnya).
class AddFilesButton extends ConsumerWidget {
  const AddFilesButton({
    required this.notes,
    required this.collectionKey,
    required this.collectionName,
    this.iconSize = 20,
    super.key,
  });

  final bool notes;
  final String? collectionKey;
  final String collectionName;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: 'Tambahkan berkas atau folder ke $collectionName',
    iconSize: iconSize,
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.note_add_outlined),
    onSelected: (choice) async {
      if (choice == 'folder') {
        await pickFolderInto(context, ref, notes: notes, key: collectionKey, name: collectionName);
      } else if (notes) {
        await pickFilesIntoNotes(context, ref, key: collectionKey, name: collectionName);
      } else {
        await pickFilesIntoPapers(context, ref, collectionKey, collectionName);
      }
    },
    itemBuilder: (_) => <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'berkas',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.note_add_outlined),
          title: const Text('Tambahkan berkas…'),
          subtitle: const Text('jenis apa pun, bisa beberapa sekaligus'),
        ),
      ),
      if (FileDropZone.supported)
        PopupMenuItem<String>(
          value: 'folder',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.drive_folder_upload_outlined),
            title: const Text('Tambahkan folder…'),
            subtitle: Text('jadi koleksi di $collectionName, subfolder jadi sub-koleksi'),
          ),
        ),
    ],
  );
}
