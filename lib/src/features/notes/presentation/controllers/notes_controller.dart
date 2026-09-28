import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/domain/entities/library_index.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../data/notes_store.dart';
import '../../domain/note_entities.dart';

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
    ref.watch(
      workspaceControllerProvider.select((s) => s.gitStatus?.lastCommitDate),
    );
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

  Future<String?> deleteCollection(String key) =>
      _guard('Hapus koleksi catatan', (store) async {
        await store.deleteCollection(key);
        return key;
      });

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

  Future<String?> deleteItem(String itemKey) =>
      _guard('Hapus catatan', (store) async {
        await store.deleteItem(itemKey);
        return itemKey;
      });

  /// Menjalankan satu perubahan, membaca ulang, lalu menyimpannya ke git.
  ///
  /// Catatan hidup di dalam repositori yang sama dengan papernya, jadi
  /// perubahannya ikut di-commit — kalau tidak, catatan hanya ada di satu
  /// perangkat dan janji "tersinkron" jadi bohong.
  Future<String?> _guard(
    String message,
    Future<String> Function(NotesStore store) action,
  ) async {
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
  SelectionKind.notes => <NoteItem>[...index.items]
    ..sort((a, b) => b.dateModified.compareTo(a.dateModified)),
  SelectionKind.notesUnfiled => index.unfiled,
  SelectionKind.noteCollection => index.inCollection(selection.collectionKey!),
  _ => const <NoteItem>[],
};
