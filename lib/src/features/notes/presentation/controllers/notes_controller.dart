import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/domain/entities/library_index.dart';
import '../../../settings/domain/entities/repo_profile.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../data/notes_store.dart';
import '../../domain/note_entities.dart';
import 'package:path/path.dart' as p;
import '../../../files/domain/folder_scan.dart';

/// Folder catatan repositori yang sedang aktif, kalau ada.
final notesStoreProvider = Provider<NotesStore?>((ref) {
  final path = ref.watch(workspaceControllerProvider.select((s) => s.profile?.localPath));
  if (path == null || path.isEmpty) return null;
  return NotesStore(NotesStore.directoryFor(path));
});

/// Isi folder catatan, dibaca ulang setiap kali sesuatu berubah.
class NotesController extends AsyncNotifier<NotesIndex> {
  NotesStore? get _store => ref.read(notesStoreProvider);

  @override
  Future<NotesIndex> build() async {
    final store = ref.watch(notesStoreProvider);
    if (store == null) return NotesIndex.empty;
    // Commit terakhir ikut diperhatikan: sebuah pull mengubah isi folder
    // catatan di disk tanpa aplikasi ini menyentuhnya, dan daftar yang masih
    // memperlihatkan keadaan sebelum pull adalah daftar yang salah.
    ref.watch(workspaceControllerProvider.select((s) => s.gitStatus?.lastCommitDate));
    return store.read();
  }

  Future<void> reload() async {
    final store = _store;
    if (store == null) return;
    state = AsyncValue<NotesIndex>.data(await store.read());
  }

  /// Membuat koleksi catatan baru. Mengembalikan kuncinya, atau null kalau
  /// gagal — pesannya sudah dipasang di [errorProvider].
  Future<String?> createCollection({required String name, String? parentKey}) =>
      _guard('Membuat koleksi catatan: $name', (store) async {
        final created = await store.createCollection(name: name, parentKey: parentKey);
        return created.key;
      });

  Future<String?> renameCollection({required String key, required String name}) =>
      _guard('Ubah nama koleksi catatan: $name', (store) async {
        await store.renameCollection(key: key, name: name);
        return key;
      });

  Future<String?> deleteCollection(String key) => _guard('Hapus koleksi catatan', (store) async {
    await store.deleteCollection(key);
    return key;
  });

  /// Mengimpor satu folder ke catatan: folder itu sendiri jadi koleksi
  /// catatan di bawah [parentKey], subfoldernya jadi sub-koleksi, dan setiap
  /// berkas jadi catatan. Koleksi bernama sama di tempat yang sama dipakai
  /// ulang. Satu commit untuk semuanya.
  Future<FolderImportResult?> importFolder({
    required FolderNode folder,
    String? parentKey,
    void Function(int done, int total)? onProgress,
  }) async {
    var added = 0;
    var collections = 0;
    final failed = <String>[];
    final total = folder.fileCount;
    final key = await _guard('Impor folder ${folder.name} ke catatan', (store) async {
      final index = await store.read();
      final known = <(String?, String), String>{
        for (final c in index.collections) (c.parentKey, c.name.toLowerCase()): c.key,
      };
      Future<void> walk(FolderNode node, String? parent) async {
        final id = (parent, node.name.toLowerCase());
        var collectionKey = known[id];
        if (collectionKey == null) {
          collectionKey = (await store.createCollection(name: node.name, parentKey: parent)).key;
          known[id] = collectionKey;
          collections++;
        }
        for (final file in node.files) {
          try {
            await store.addFile(
              sourcePath: file,
              title: p.basenameWithoutExtension(file),
              collectionKey: collectionKey,
            );
            added++;
          } on Object catch (e) {
            failed.add('${p.basename(file)} ($e)');
          }
          onProgress?.call(added + failed.length, total);
        }
        for (final child in node.children) {
          await walk(child, collectionKey);
        }
      }

      await walk(folder, parentKey);
      return folder.name;
    });
    if (key == null) return null;
    return FolderImportResult(added: added, collections: collections, failed: failed);
  }

  /// Menyalin sebuah berkas ke folder catatan.
  Future<String?> addFile({
    required String sourcePath,
    required String title,
    String? collectionKey,
  }) => _guard('Tambah catatan: $title', (store) async {
    final item = await store.addFile(
      sourcePath: sourcePath,
      title: title,
      collectionKey: collectionKey,
    );
    return item.key;
  });

  Future<String?> fileInto({required String itemKey, String? collectionKey}) =>
      _guard('Pindahkan catatan', (store) async {
        final item = await store.fileInto(itemKey: itemKey, collectionKey: collectionKey);
        return item.key;
      });

  Future<String?> rename({required String itemKey, required String title}) =>
      _guard('Ubah nama catatan: $title', (store) async {
        final item = await store.rename(itemKey: itemKey, title: title);
        return item.key;
      });

  /// Menyimpan perubahan yang terjadi di luar store: berkasnya sudah ditulis
  /// penyunting, yang tersisa adalah mencatat waktunya dan meng-commit.
  Future<String?> touch({required String itemKey, required String message}) =>
      _guard(message, (store) async {
        await store.touch(itemKey);
        return itemKey;
      });

  Future<String?> deleteItem(String itemKey) => _guard('Hapus catatan', (store) async {
    await store.deleteItem(itemKey);
    return itemKey;
  });

  /// Menjalankan satu perubahan, membaca ulang, lalu menyimpannya ke git.
  ///
  /// Memindah atau menyalin satu catatan ke repositori lain.
  ///
  /// Disalin dulu dan di-commit di tujuan; baru setelah itu, bila memindah,
  /// dihapus dari sini dan di-commit di sini.
  Future<String?> transferItem({
    required String itemKey,
    required RepoProfile target,
    String? collectionKey,
    required bool move,
  }) async {
    final store = _store;
    final source = ref.read(workspaceControllerProvider).profile;
    if (store == null || source == null) return 'Belum ada repositori aktif.';
    final item = (await store.read()).items.where((i) => i.key == itemKey).firstOrNull;
    if (item == null) return 'Catatannya tidak ada lagi.';
    final workspace = ref.read(workspaceControllerProvider.notifier);
    try {
      await store.copyItemTo(
        itemKey: itemKey,
        target: NotesStore(NotesStore.directoryFor(target.localPath)),
        collectionKeys: <String>[?collectionKey],
      );
      await workspace.commitIn(
        target,
        '${move ? 'Dipindahkan' : 'Disalin'} dari ${source.name}: catatan ${item.title}',
      );
      if (move) {
        await store.deleteItem(itemKey);
        await workspace.commitIn(source, 'Dipindahkan ke ${target.name}: catatan ${item.title}');
      }
      state = AsyncValue<NotesIndex>.data(await store.read());
      return null;
    } on Object catch (e) {
      return '$e';
    }
  }

  /// Memindah atau menyalin koleksi catatan beserta isinya ke repositori lain.
  Future<String?> transferCollection({
    required String collectionKey,
    required RepoProfile target,
    String? parentKey,
    required bool move,
  }) async {
    final store = _store;
    final source = ref.read(workspaceControllerProvider).profile;
    if (store == null || source == null) return 'Belum ada repositori aktif.';
    final collection = (await store.read()).collections
        .where((c) => c.key == collectionKey)
        .firstOrNull;
    if (collection == null) return 'Koleksinya tidak ada lagi.';
    final workspace = ref.read(workspaceControllerProvider.notifier);
    try {
      final result = await store.copyCollectionTo(
        collectionKey: collectionKey,
        target: NotesStore(NotesStore.directoryFor(target.localPath)),
        targetParentKey: parentKey,
      );
      await workspace.commitIn(
        target,
        '${move ? 'Dipindahkan' : 'Disalin'} dari ${source.name}: koleksi catatan '
        '${collection.name} (${result.items.length} catatan)',
      );
      if (move) {
        for (final key in result.items) {
          if (!result.elsewhere.contains(key)) await store.deleteItem(key);
        }
        await store.deleteCollection(collectionKey);
        await workspace.commitIn(
          source,
          'Dipindahkan ke ${target.name}: koleksi catatan ${collection.name}',
        );
      }
      state = AsyncValue<NotesIndex>.data(await store.read());
      return null;
    } on Object catch (e) {
      return '$e';
    }
  }

  /// Catatan hidup di dalam repositori yang sama dengan papernya, jadi
  /// perubahannya ikut di-commit — kalau tidak, catatan hanya ada di satu
  /// perangkat dan janji "tersinkron" jadi bohong.
  Future<String?> _guard(String message, Future<String> Function(NotesStore store) action) async {
    final store = _store;
    if (store == null) {
      _fail('Belum ada repositori aktif untuk menyimpan catatan.');
      return null;
    }
    try {
      final result = await action(store);
      state = AsyncValue<NotesIndex>.data(await store.read());
      await ref.read(workspaceControllerProvider.notifier).commitChange(message);
      return result;
    } on Object catch (e) {
      _fail('$e');
      return null;
    }
  }

  void _fail(String message) => ref.read(notesErrorProvider.notifier).set(message);
}

final notesControllerProvider = AsyncNotifierProvider<NotesController, NotesIndex>(
  NotesController.new,
);

/// Pesan galat terakhir dari sisi catatan, supaya panelnya bisa menampilkannya
/// tanpa ikut menumpang banner repositori.
class NotesErrorController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? message) => state = message;

  void clear() => state = null;
}

final notesErrorProvider = NotifierProvider<NotesErrorController, String?>(
  NotesErrorController.new,
);

/// Catatan yang tampil di panel tengah untuk pilihan yang sedang aktif.
List<NoteItem> notesFor(NotesIndex index, LibrarySelection selection) => switch (selection.kind) {
  SelectionKind.notes => <NoteItem>[
    ...index.items,
  ]..sort((a, b) => b.dateModified.compareTo(a.dateModified)),
  SelectionKind.notesUnfiled => index.unfiled,
  SelectionKind.noteCollection => index.inCollection(selection.collectionKey!),
  _ => const <NoteItem>[],
};
