import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/failure.dart';
import '../../../library/domain/repositories/library_repository.dart';
import '../../domain/entities/repo_stats.dart';
import '../../../library/data/datasources/library_transfer.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../library/data/datasources/zotero_writer.dart';
import '../../../library/domain/entities/library_index.dart';
import '../../../library/domain/entities/zotero_annotation.dart';
import '../../../library/domain/entities/zotero_item.dart';
import '../../../reader/data/page_picture.dart';
import '../../../settings/domain/entities/repo_profile.dart';
import '../../../sync/domain/entities/git_entities.dart';
import '../../../sync/domain/entities/sync_progress.dart';
import '../../../sync/data/datasources/git_locator.dart';
import '../../../sync/domain/repositories/git_backend.dart';
import '../../domain/entities/workspace_state.dart';

/// Owns the active repository: its clone, its git state and the parsed library.
///
/// Every remote operation funnels through here so the UI only has to render
/// [WorkspaceState].
class WorkspaceController extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() {
    Future<void>.microtask(bootstrap);
    return const WorkspaceState();
  }

  /// Loads settings and opens the active profile.
  Future<void> bootstrap() async {
    final settings = await ref.read(settingsRepositoryProvider).load();
    state = state.copyWith(settings: settings);
    final profile = settings.activeProfile;
    if (profile == null) {
      state = state.copyWith(clearProfile: true, clearIndex: true, clearLayout: true);
      return;
    }
    await openProfile(profile);
  }

  /// Switches the active repository. The clone is reused when it already exists.
  Future<void> selectProfile(String profileId) async {
    final settings = await ref.read(settingsRepositoryProvider).setActiveProfile(profileId);
    state = state.copyWith(
      settings: settings,
      clearIndex: true,
      clearLayout: true,
      clearLibrary: true,
      clearError: true,
      clearMessage: true,
    );
    final profile = settings.profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => settings.profiles.first,
    );
    await openProfile(profile);
  }

  /// Membuka ulang profil aktif — dari tombol "Coba lagi" di banner galat.
  Future<void> retryOpen() async {
    final profile = state.profile;
    state = state.copyWith(clearError: true);
    if (profile == null) {
      await bootstrap();
    } else {
      await openProfile(profile);
    }
  }

  /// Reads the git state of [profile] and parses its library when present.
  Future<void> openProfile(RepoProfile profile) async {
    state = state.copyWith(profile: profile, clearError: true);
    final git = ref.read(gitBackendProvider);

    if (!await git.isAvailable()) {
      state = state.copyWith(error: GitLocator.installHint());
      return;
    }

    final status = await git.status(profile.localPath);
    state = state.copyWith(gitStatus: status);
    if (!status.exists) {
      state = state.copyWith(clearLayout: true, clearLibrary: true, clearIndex: true);
      return;
    }
    await loadLibraries(profile);
  }

  /// Detects the Zotero export inside the clone and parses the chosen library.
  Future<void> loadLibraries(RepoProfile profile, {LibraryRef? preferred}) async {
    state = state.copyWith(loadingLibrary: true, clearError: true);
    try {
      final repository = ref.read(libraryRepositoryProvider);
      final layout = await repository.detectLayout(profile.localPath);
      if (layout == null || layout.isEmpty) {
        state = state.copyWith(
          loadingLibrary: false,
          clearLayout: true,
          clearIndex: true,
          error:
              'Tidak menemukan ekspor Zotero di repositori ini. '
              'Struktur yang diharapkan: zotero/<library>/collections.json',
        );
        return;
      }

      final selected =
          preferred ??
          layout.libraries.firstWhere(
            (l) => l.directoryName == profile.preferredLibraryDir,
            orElse: () => layout.libraries.first,
          );

      final index = await repository.loadLibrary(selected);
      state = state.copyWith(
        layout: layout,
        library: selected,
        index: index,
        loadingLibrary: false,
      );
    } on Failure catch (e) {
      state = state.copyWith(loadingLibrary: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loadingLibrary: false, error: 'Gagal membaca library: $e');
    }
  }

  /// Switches between the libraries of the same repository.
  Future<void> selectLibrary(LibraryRef library) async {
    final profile = state.profile;
    if (profile == null) return;
    final updated = profile.copyWith(preferredLibraryDir: library.directoryName);
    await ref.read(settingsRepositoryProvider).saveProfile(updated);
    state = state.copyWith(profile: updated);
    await loadLibraries(updated, preferred: library);
  }

  /// Re-parses the library from disk (after a pull or an external edit).
  Future<void> reloadLibrary() async {
    final profile = state.profile;
    final library = state.library;
    if (profile == null) return;
    await loadLibraries(profile, preferred: library);
  }

  // --------------------------------------------------------------- git actions

  Future<bool> clone() async {
    final profile = state.profile;
    if (profile == null) return false;
    if (profile.remoteUrl.trim().isEmpty) {
      state = state.copyWith(error: 'URL remote belum diisi untuk profil ini.');
      return false;
    }

    _beginPhase(SyncPhase.cloning);
    final auth = await _authFor(profile);
    final result = await ref
        .read(gitBackendProvider)
        .clone(
          remoteUrl: profile.remoteUrl,
          targetPath: profile.localPath,
          auth: auth,
          branch: profile.branch.isEmpty ? null : profile.branch,
          lazyAttachments: profile.lazyAttachments,
          onProgress: _appendProgress,
        );
    await _endPhase(result);
    if (result.ok) {
      await openProfile(profile);
      await _touchSyncTime(profile);
    }
    return result.ok;
  }

  /// Throws away the working copy and takes it again, so an old full clone can
  /// become a lazy one without touching the profile.
  ///
  /// Refuses while anything is unsaved: a re-clone deletes local annotations
  /// that have not reached GitHub yet.
  Future<bool> recloneActive() async {
    final profile = state.profile;
    if (profile == null) return false;

    final status = state.gitStatus;
    if (status != null && (status.isDirty || status.ahead > 0)) {
      state = state.copyWith(
        error:
            'Masih ada perubahan yang belum dikirim ke GitHub. '
            'Kirim dulu, baru ambil ulang.',
      );
      return false;
    }

    final dir = Directory(profile.localPath);
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException catch (e) {
        state = state.copyWith(error: 'Gagal menghapus salinan lama: ${e.message}');
        return false;
      }
    }
    state = state.copyWith(clearIndex: true, clearLayout: true, clearLibrary: true);
    return clone();
  }

  Future<bool> fetch() => _remoteAction(SyncPhase.fetching, (backend, profile, auth) {
    return backend.fetch(repoPath: profile.localPath, auth: auth, onProgress: _appendProgress);
  });

  Future<bool> pull() async {
    final ok = await _remoteAction(SyncPhase.pulling, (backend, profile, auth) {
      return backend.pull(repoPath: profile.localPath, auth: auth, onProgress: _appendProgress);
    });
    if (ok) {
      await reloadLibrary();
      final profile = state.profile;
      if (profile != null) await _touchSyncTime(profile);
    }
    return ok;
  }

  Future<bool> push() => _remoteAction(SyncPhase.pushing, (backend, profile, auth) {
    return backend.push(repoPath: profile.localPath, auth: auth, onProgress: _appendProgress);
  });

  Future<bool> lfsPull() => _remoteAction(SyncPhase.pulling, (backend, profile, auth) {
    return backend.lfsPull(repoPath: profile.localPath, auth: auth, onProgress: _appendProgress);
  });

  /// Stages everything, commits, and pushes when [push] is true.
  Future<bool> commitAll({required String message, bool push = true}) async {
    final profile = state.profile;
    if (profile == null) return false;

    _beginPhase(SyncPhase.committing);
    final backend = ref.read(gitBackendProvider);
    final commit = await backend.commitAll(
      repoPath: profile.localPath,
      message: message,
      authorName: profile.authorName,
      authorEmail: profile.authorEmail,
    );
    if (!commit.ok) {
      await _endPhase(commit);
      return false;
    }
    if (!push) {
      await _endPhase(commit);
      return true;
    }

    state = state.copyWith(phase: SyncPhase.pushing);
    final auth = await _authFor(profile);
    final pushed = await backend.push(
      repoPath: profile.localPath,
      auth: auth,
      onProgress: _appendProgress,
    );
    await _endPhase(pushed);
    if (pushed.ok) await _touchSyncTime(profile);
    return pushed.ok;
  }

  /// Downloads one attachment that the mirror does not hold yet.
  ///
  /// Only the Android backend needs this: it keeps metadata locally but leaves
  /// the PDFs on GitHub until a paper is actually opened.
  Future<bool> downloadAttachment(String absoluteFilePath) async {
    final profile = state.profile;
    if (profile == null) return false;

    _beginPhase(SyncPhase.pulling);
    final auth = await _authFor(profile);
    final result = await ref
        .read(gitBackendProvider)
        .fetchAttachment(
          repoPath: profile.localPath,
          auth: auth,
          absoluteFilePath: absoluteFilePath,
          onProgress: _appendProgress,
        );
    await _endPhase(result);
    return result.ok;
  }

  /// Tests the connection without changing anything, for the button that
  /// answers "is it stuck, or is the network gone?".
  Future<bool> checkConnection() async {
    final profile = state.profile;
    if (profile == null) return false;
    _beginPhase(SyncPhase.fetching);
    final auth = await _authFor(profile);
    final result = await ref
        .read(gitBackendProvider)
        .checkConnection(auth: auth, repoPath: profile.localPath);
    await _endPhase(result);
    return result.ok;
  }

  Future<void> refreshGitStatus() async {
    final profile = state.profile;
    if (profile == null) return;
    final status = await ref.read(gitBackendProvider).status(profile.localPath);
    state = state.copyWith(gitStatus: status);
  }

  // ------------------------------------------------------------- annotations

  /// Persists an annotation and commits it (pushing when the profile says so).
  /// Persists an annotation and commits it. Returns false when it did not
  /// stick, after putting the reason on screen.
  ///
  /// Every failure here used to return silently, so a marker would appear and
  /// then vanish on the next reload with nothing to explain it.
  Future<bool> saveAnnotation({
    required ZoteroItem item,
    required ZoteroAnnotation annotation,
    required bool isNew,
  }) async {
    final library = state.library;
    final profile = state.profile;
    if (library == null || profile == null) {
      state = state.copyWith(
        error: 'Anotasi tidak tersimpan: tidak ada library aktif di aplikasi.',
      );
      return false;
    }

    try {
      final changed = await ref
          .read(libraryRepositoryProvider)
          .saveAnnotation(
            itemFilePath: item.filePath,
            libraryDir: library.directoryPath,
            annotation: annotation,
          );
      if (changed.isEmpty) {
        state = state.copyWith(error: 'Anotasi tidak tersimpan: berkas item tidak berubah.');
        return false;
      }

      await _commitAnnotation(
        profile: profile,
        message: annotationCommitMessage(
          action: isNew ? 'Tambah' : 'Ubah',
          itemTitle: item.title,
          annotation: annotation,
        ),
      );
      return true;
    } on Failure catch (e) {
      state = state.copyWith(error: 'Anotasi tidak tersimpan: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Anotasi tidak tersimpan: $e');
      return false;
    }
  }

  Future<bool> deleteAnnotation({
    required ZoteroItem item,
    required ZoteroAnnotation annotation,
  }) async {
    final library = state.library;
    final profile = state.profile;
    if (library == null || profile == null) {
      state = state.copyWith(error: 'Anotasi tidak dihapus: tidak ada library aktif.');
      return false;
    }

    try {
      await ref
          .read(libraryRepositoryProvider)
          .removeAnnotation(
            itemFilePath: item.filePath,
            libraryDir: library.directoryPath,
            annotationKey: annotation.key,
          );
    } catch (e) {
      state = state.copyWith(error: 'Anotasi tidak dihapus: $e');
      return false;
    }

    await _commitAnnotation(
      profile: profile,
      message: annotationCommitMessage(
        action: 'Hapus',
        itemTitle: item.title,
        annotation: annotation,
      ),
    );
    return true;
  }

  /// Tempat gambar tempelan sebuah lampiran, atau null tanpa repositori aktif.
  PagePictureStore? pagePictures(String attachmentKey) {
    final profile = state.profile;
    if (profile == null || profile.localPath.isEmpty || attachmentKey.isEmpty) return null;
    return PagePictureStore(
      PagePictureStore.directoryFor(repoRoot: profile.localPath, attachmentKey: attachmentKey),
    );
  }

  /// Menyimpan gambar tempelan paper library — di `catatan/`, bukan di
  /// ekspor Zotero — lalu meng-commit-nya seperti anotasi.
  Future<bool> savePagePicture({
    required String attachmentKey,
    required String itemTitle,
    required ZoteroAnnotation annotation,
    required bool isNew,
    Uint8List? bytes,
  }) async {
    final store = pagePictures(attachmentKey);
    final profile = state.profile;
    if (store == null || profile == null) {
      state = state.copyWith(error: 'Gambar tidak tersimpan: tidak ada repositori aktif.');
      return false;
    }
    try {
      await store.put(annotation, bytes: bytes);
    } catch (e) {
      state = state.copyWith(error: 'Gambar tidak tersimpan: $e');
      return false;
    }
    await _commitAnnotation(
      profile: profile,
      message: '${isNew ? 'Tambah' : 'Ubah'} gambar di halaman ${annotation.pageLabel}: $itemTitle',
    );
    return true;
  }

  Future<bool> deletePagePicture({
    required String attachmentKey,
    required String itemTitle,
    required ZoteroAnnotation annotation,
  }) async {
    final store = pagePictures(attachmentKey);
    final profile = state.profile;
    if (store == null || profile == null) return false;
    try {
      await store.remove(annotation.key);
    } catch (e) {
      state = state.copyWith(error: 'Gambar tidak dihapus: $e');
      return false;
    }
    await _commitAnnotation(
      profile: profile,
      message: 'Hapus gambar di halaman ${annotation.pageLabel}: $itemTitle',
    );
    return true;
  }

  /// Memasukkan sebuah PDF lepas ke library, dengan koleksi pilihan.
  ///
  /// Ini jalur yang berbeda dari menyimpan anotasi: yang dibuat adalah item
  /// Zotero yang belum pernah ada, beserta lampirannya. Karena itu berkasnya
  /// ditulis lebih dulu, lalu di-commit sekali dengan pesan yang menyebut
  /// judulnya — dan kalau profilnya menyalakan dorong otomatis, ikut terdorong.
  Future<CreatedItem?> addPdfToLibrary({
    required String pdfPath,
    required String title,
    String? collectionKey,
  }) async {
    final library = state.library;
    final profile = state.profile;
    final index = state.index;
    if (library == null || profile == null || index == null) {
      state = state.copyWith(error: 'Tidak ada library aktif untuk menampung berkas ini.');
      return null;
    }

    try {
      // Nama jalur koleksi ("PhD/Crypto") ikut ditulis di bagian meta, persis
      // seperti yang dilakukan plugin; keynya saja tidak cukup.
      final collection = collectionKey == null ? null : index.collections[collectionKey];

      final created = await ref
          .read(libraryRepositoryProvider)
          .addPdfAsItem(
            libraryDir: library.directoryPath,
            libraryName: library.name,
            libraryId: 1,
            pdfPath: pdfPath,
            title: title,
            collectionKey: collectionKey,
            collectionPath: collection?.path,
          );

      await _commitAnnotation(profile: profile, message: 'Tambah dokumen: $title');
      await reloadLibrary();
      return created;
    } on Object catch (e) {
      state = state.copyWith(error: 'Gagal menambahkan ke library: $e');
      return null;
    }
  }

  /// Membuat koleksi paper baru di dalam library yang aktif.
  ///
  /// Satu-satunya jalur yang menulis berkas struktur Zotero
  /// (`collections.json`), jadi hasilnya langsung di-commit dengan pesan yang
  /// menyebut namanya — kalau nanti ada yang perlu ditelusuri, riwayatnya ada.
  Future<String?> createCollection({required String name, String? parentKey}) async {
    final library = state.library;
    final profile = state.profile;
    if (library == null || profile == null) {
      state = state.copyWith(error: 'Tidak ada library aktif.');
      return null;
    }
    try {
      final created = await ref
          .read(libraryRepositoryProvider)
          .createCollection(libraryDir: library.directoryPath, name: name, parentKey: parentKey);
      await _commitAnnotation(profile: profile, message: 'Tambah koleksi: ${created.path}');
      await reloadLibrary();
      return created.key;
    } on Failure catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    } on Object catch (e) {
      state = state.copyWith(error: 'Gagal membuat koleksi: $e');
      return null;
    }
  }

  // ------------------------------------------------------ banyak repositori

  /// Ukuran dan isi sebuah repositori, aktif atau tidak.
  Future<RepoStats> repoStats(RepoProfile profile) async {
    if (profile.localPath.isEmpty || !Directory(profile.localPath).existsSync()) {
      return const RepoStats(cloned: false);
    }
    final layout = await ref.read(libraryRepositoryProvider).detectLayout(profile.localPath);
    final libraries = layout?.libraries ?? const <LibraryRef>[];
    final sizes = await RepoStats.measure(profile.localPath);
    var unsent = 0;
    var behind = 0;
    try {
      final status = await ref.read(gitBackendProvider).status(profile.localPath);
      unsent = status.changes.length + status.ahead;
      behind = status.behind;
    } on Object {
      // Status git yang gagal dibaca tidak membuat ukurannya salah.
    }
    var items = 0;
    var collections = 0;
    for (final library in libraries) {
      items += _countItems(library.directoryPath);
      collections += _countCollections(library.directoryPath);
    }
    return RepoStats(
      cloned: true,
      diskBytes: sizes.disk,
      attachmentBytes: sizes.attachments,
      items: items,
      collections: collections,
      unsent: unsent,
      behind: behind,
    );
  }

  /// Jumlah berkas item sungguhan. `library.json` menyimpan jumlah juga,
  /// tetapi itu ditulis plugin saat terakhir mengekspor: item yang dibuat
  /// ReadPaper sesudahnya tidak terhitung di sana.
  static int _countItems(String libraryDir) {
    final dir = Directory(p.join(libraryDir, 'items'));
    if (!dir.existsSync()) return 0;
    return dir.listSync(recursive: true).where((e) => e.path.endsWith('.json')).length;
  }

  /// Jumlah koleksi dari `collections.json` sendiri. Jumlah di manifest
  /// plugin hanya ada bila manifest-nya ada, dan basi begitu koleksi dibuat
  /// dari ReadPaper.
  static int _countCollections(String libraryDir) {
    final file = File(p.join(libraryDir, 'collections.json'));
    if (!file.existsSync()) return 0;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is List ? decoded.length : 0;
    } on FormatException {
      return 0;
    }
  }

  /// Library Zotero di repositori lain, untuk memilih koleksi tujuan.
  ///
  /// Repositori aktif tidak berpindah: yang dibaca hanya foldernya.
  Future<LibraryIndex?> otherLibrary(RepoProfile profile) async {
    if (!Directory(profile.localPath).existsSync()) return null;
    final repo = ref.read(libraryRepositoryProvider);
    final layout = await repo.detectLayout(profile.localPath);
    if (layout == null || layout.libraries.isEmpty) return null;
    final library = layout.libraries.firstWhere(
      (l) => l.directoryName == profile.preferredLibraryDir,
      orElse: () => layout.libraries.first,
    );
    return repo.loadLibrary(library);
  }

  /// Memindah atau menyalin satu paper ke koleksi di repositori lain.
  ///
  /// Dua commit, satu di tiap repositori, dengan pesan yang menyebut asal dan
  /// tujuannya. Memindah berarti menyalin dulu dan baru menghapus dari asal
  /// setelah salinannya utuh — urutan sebaliknya bisa kehilangan paper-nya.
  Future<String?> transferItem({
    required ZoteroItem item,
    required RepoProfile target,
    required LibraryIndex targetLibrary,
    required String? collectionKey,
    required bool move,
  }) async {
    final source = state.library;
    final profile = state.profile;
    if (source == null || profile == null) return 'Tidak ada library aktif.';
    if (target.id == profile.id) return 'Repositori tujuannya sama dengan asal.';
    const transfer = LibraryTransfer();
    final missing = await transfer.missingAttachments(source.directoryPath, item.filePath);
    if (missing.isNotEmpty) return _missingMessage(missing.length);

    final collection = collectionKey == null ? null : targetLibrary.collections[collectionKey];
    try {
      await transfer.copyItem(
        sourceDir: source.directoryPath,
        targetDir: targetLibrary.library.directoryPath,
        itemFilePath: item.filePath,
        collectionKeys: <String>[?collection?.key],
        collectionPaths: <String>[?collection?.path],
      );
      await _commitAnnotation(
        profile: target,
        message: '${move ? 'Dipindahkan' : 'Disalin'} dari ${profile.name}: ${item.title}',
      );
      if (move) {
        await ref
            .read(libraryRepositoryProvider)
            .removeItem(libraryDir: source.directoryPath, itemFilePath: item.filePath);
        await _commitAnnotation(
          profile: profile,
          message: 'Dipindahkan ke ${target.name}: ${item.title}',
        );
        await reloadLibrary();
      }
      return null;
    } on MissingAttachments catch (e) {
      return _missingMessage(e.files.length);
    } on Failure catch (e) {
      return e.message;
    } on Object catch (e) {
      return 'Gagal ${move ? 'memindah' : 'menyalin'}: $e';
    }
  }

  /// Memindah atau menyalin koleksi paper beserta isinya ke repositori lain.
  ///
  /// Saat memindah, paper yang juga anggota koleksi lain di asal tetap di
  /// sana — hanya dilepas dari koleksi yang dipindah. Yang hanya ada di
  /// koleksi itu dihapus dari asal, setelah salinannya utuh.
  Future<String?> transferCollection({
    required String collectionKey,
    required RepoProfile target,
    required LibraryIndex targetLibrary,
    required String? parentKey,
    required bool move,
  }) async {
    final source = state.library;
    final profile = state.profile;
    final collection = state.index?.collections[collectionKey];
    if (source == null || profile == null || collection == null) {
      return 'Koleksinya tidak ada lagi.';
    }
    if (target.id == profile.id) return 'Repositori tujuannya sama dengan asal.';
    const transfer = LibraryTransfer();
    try {
      final result = await transfer.copyCollection(
        sourceDir: source.directoryPath,
        targetDir: targetLibrary.library.directoryPath,
        collectionKey: collectionKey,
        targetParentKey: parentKey,
      );
      await _commitAnnotation(
        profile: target,
        message:
            '${move ? 'Dipindahkan' : 'Disalin'} dari ${profile.name}: koleksi ${collection.path} '
            '(${result.itemFiles.length} paper)',
      );
      if (move) {
        final repo = ref.read(libraryRepositoryProvider);
        for (final itemFile in result.itemFiles) {
          if (result.alsoElsewhere.contains(itemFile)) continue;
          await repo.removeItem(libraryDir: source.directoryPath, itemFilePath: itemFile);
        }
        await repo.deleteCollection(
          libraryDir: source.directoryPath,
          key: collectionKey,
          withChildren: true,
        );
        await _commitAnnotation(
          profile: profile,
          message: 'Dipindahkan ke ${target.name}: koleksi ${collection.path}',
        );
        await reloadLibrary();
      }
      return null;
    } on MissingAttachments catch (e) {
      return _missingMessage(e.files.length);
    } on Failure catch (e) {
      return e.message;
    } on Object catch (e) {
      return 'Gagal ${move ? 'memindah' : 'menyalin'}: $e';
    }
  }

  /// Meng-commit perubahan di repositori [profile], aktif atau tidak — untuk
  /// sisi tujuan saat memindah sesuatu antar repositori.
  Future<void> commitIn(RepoProfile profile, String message) =>
      _commitAnnotation(profile: profile, message: message);

  static String _missingMessage(int count) =>
      '$count lampiran belum ada di perangkat ini — belum diunduh, atau masih penunjuk '
      'Git LFS. Buka papernya sekali supaya PDF-nya diunduh (di desktop: LFS pull), '
      'lalu ulangi. Tidak ada yang dipindah: tanpa PDF-nya, paper itu akan tiba kosong.';

  /// Mengganti nama, memindah, atau menghapus koleksi paper, lalu meng-commit.
  ///
  /// Satu pintu untuk ketiganya: semua menulis `collections.json` dan item
  /// anggotanya, dan semua harus berakhir dengan commit yang menyebut apa yang
  /// terjadi — kalau nanti ada yang perlu ditelusuri, riwayatnya ada.
  Future<bool> changePaperCollection({
    required String message,
    required Future<List<String>> Function(LibraryRepository repo, String libraryDir) change,
  }) async {
    final library = state.library;
    final profile = state.profile;
    if (library == null || profile == null) {
      state = state.copyWith(error: 'Tidak ada library aktif.');
      return false;
    }
    try {
      await change(ref.read(libraryRepositoryProvider), library.directoryPath);
      await _commitAnnotation(profile: profile, message: message);
      await reloadLibrary();
      return true;
    } on Failure catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } on Object catch (e) {
      state = state.copyWith(error: 'Gagal mengubah koleksi: $e');
      return false;
    }
  }

  Future<({int children, int items})?> paperCollectionReach(String key) async {
    final library = state.library;
    if (library == null) return null;
    return ref.read(libraryRepositoryProvider).collectionReach(library.directoryPath, key);
  }

  /// Memindahkan sebuah item ke koleksi lain — jalur seret-dan-lepas di pohon.
  ///
  /// [collectionKey] null berarti dikeluarkan dari semua koleksi.
  Future<bool> moveItemToCollection({
    required ZoteroItem item,
    required String? collectionKey,
  }) async {
    final library = state.library;
    final profile = state.profile;
    final index = state.index;
    if (library == null || profile == null || index == null) {
      state = state.copyWith(error: 'Tidak ada library aktif.');
      return false;
    }
    final collection = collectionKey == null ? null : index.collections[collectionKey];
    if (collectionKey != null && collection == null) {
      state = state.copyWith(error: 'Koleksi tujuan tidak ada lagi.');
      return false;
    }

    try {
      await ref
          .read(libraryRepositoryProvider)
          .setItemCollections(
            libraryDir: library.directoryPath,
            itemFilePath: item.filePath,
            collectionKeys: <String>[?collectionKey],
            collectionPaths: <String>[?collection?.path],
          );
      await _commitAnnotation(
        profile: profile,
        message: collection == null
            ? 'Keluarkan dari koleksi: ${item.title}'
            : 'Pindahkan ke ${collection.name}: ${item.title}',
      );
      await reloadLibrary();
      return true;
    } on Object catch (e) {
      state = state.copyWith(error: 'Gagal memindahkan: $e');
      return false;
    }
  }

  /// Membuang sebuah item dari library, beserta lampiran dan catatannya.
  Future<bool> deleteItem(ZoteroItem item) async {
    final library = state.library;
    final profile = state.profile;
    if (library == null || profile == null) {
      state = state.copyWith(error: 'Tidak ada library aktif.');
      return false;
    }
    try {
      await ref
          .read(libraryRepositoryProvider)
          .removeItem(libraryDir: library.directoryPath, itemFilePath: item.filePath);
      await _commitAnnotation(profile: profile, message: 'Hapus dokumen: ${item.title}');
      await reloadLibrary();
      return true;
    } on Object catch (e) {
      state = state.copyWith(error: 'Gagal menghapus: $e');
      return false;
    }
  }

  /// Menyimpan perubahan apa pun di dalam repositori ke git, dengan pesan
  /// yang sudah disiapkan pemanggilnya.
  ///
  /// Dipakai sisi catatan: berkasnya ada di dalam repositori yang sama, di
  /// luar struktur Zotero, tetapi tetap harus ikut terkirim.
  Future<void> commitChange(String message) async {
    final profile = state.profile;
    if (profile == null) return;
    await _commitAnnotation(profile: profile, message: message);
  }

  Future<void> _commitAnnotation({required RepoProfile profile, required String message}) async {
    final backend = ref.read(gitBackendProvider);
    state = state.copyWith(phase: SyncPhase.committing, clearError: true);
    final commit = await backend.commitAll(
      repoPath: profile.localPath,
      message: message,
      authorName: profile.authorName,
      authorEmail: profile.authorEmail,
    );
    if (!commit.ok) {
      await _endPhase(commit);
      return;
    }
    if (!profile.autoPushOnSave) {
      await _endPhase(commit);
      return;
    }
    state = state.copyWith(phase: SyncPhase.pushing);
    final auth = await _authFor(profile);
    final pushed = await backend.push(repoPath: profile.localPath, auth: auth);
    await _endPhase(pushed);
  }

  // ------------------------------------------------------------------ profiles

  Future<void> saveProfile(RepoProfile profile, {String? httpsToken}) async {
    final settings = await ref
        .read(settingsRepositoryProvider)
        .saveProfile(profile, httpsToken: httpsToken);
    state = state.copyWith(settings: settings);
    if (settings.activeProfile?.id == profile.id) {
      await openProfile(profile);
    }
  }

  Future<void> deleteProfile(String profileId, {bool deleteClone = false}) async {
    if (deleteClone) {
      final profile = state.settings.profiles.where((p) => p.id == profileId).firstOrNull;
      if (profile != null && profile.localPath.isNotEmpty) {
        final dir = Directory(profile.localPath);
        if (dir.existsSync()) {
          try {
            await dir.delete(recursive: true);
          } on FileSystemException catch (e) {
            state = state.copyWith(error: 'Gagal menghapus clone lokal: ${e.message}');
          }
        }
      }
    }
    final settings = await ref.read(settingsRepositoryProvider).deleteProfile(profileId);
    state = state.copyWith(settings: settings, clearIndex: true, clearLayout: true);
    final active = settings.activeProfile;
    if (active == null) {
      state = state.copyWith(clearProfile: true);
    } else {
      await openProfile(active);
    }
  }

  Future<void> setLastAnnotationColor(String color) async {
    final settings = await ref
        .read(settingsRepositoryProvider)
        .updatePreferences(lastAnnotationColor: color);
    state = state.copyWith(settings: settings);
  }

  /// Menyalakan atau mematikan "layar tetap menyala saat membaca".
  Future<void> setKeepScreenOn(bool value) async {
    final settings = await ref
        .read(settingsRepositoryProvider)
        .updatePreferences(keepScreenOn: value);
    state = state.copyWith(settings: settings);
  }

  /// Menyalakan atau mematikan "hanya stylus yang menggambar".
  Future<void> setStylusOnly(bool value) async {
    final settings = await ref
        .read(settingsRepositoryProvider)
        .updatePreferences(stylusOnly: value);
    state = state.copyWith(settings: settings);
  }

  /// Menyalakan atau mematikan server sitasi untuk Word dan OnlyOffice.
  ///
  /// Hanya menyimpan pilihannya; `citationServerProvider` yang mendengarkan
  /// perubahan ini lalu menyalakan atau mematikan servernya.
  Future<void> setCitationServer(bool value) async {
    final settings = await ref
        .read(settingsRepositoryProvider)
        .updatePreferences(citationServer: value);
    state = state.copyWith(settings: settings);
  }

  /// Records that a paper was opened, and at which page it was left.
  Future<void> rememberRecent(RecentPaper entry) async {
    final settings = await ref.read(settingsRepositoryProvider).rememberRecent(entry);
    state = state.copyWith(settings: settings);
  }

  Future<void> forgetRecent({RecentPaper? entry}) async {
    final settings = await ref.read(settingsRepositoryProvider).forgetRecent(entry: entry);
    state = state.copyWith(settings: settings);
  }

  Future<void> setThemeMode(String mode) async {
    final settings = await ref.read(settingsRepositoryProvider).updatePreferences(themeMode: mode);
    state = state.copyWith(settings: settings);
  }

  void clearMessages() => state = state.copyWith(clearError: true, clearMessage: true);

  // ------------------------------------------------------------------ internals

  Future<GitAuth> _authFor(RepoProfile profile) async {
    if (profile.transport == GitTransport.https) {
      final token = await ref.read(settingsRepositoryProvider).tokenFor(profile.id);
      return profile.auth(token: token);
    }
    return profile.auth();
  }

  void _beginPhase(SyncPhase phase) {
    state = state.copyWith(
      phase: phase,
      progressLines: const <String>[],
      clearProgress: true,
      clearError: true,
      clearMessage: true,
    );
  }

  void _appendProgress(SyncProgress progress) {
    final line = progress.label;
    if (line.isEmpty) return;
    final lines = <String>[...state.progressLines, line];
    state = state.copyWith(
      // The bar keeps the last measurable percentage, but the caption always
      // shows the newest line so a long silent step never looks frozen.
      progress: progress.isMeasurable ? progress : null,
      progressLabel: line,
      progressLines: lines.length > 200 ? lines.sublist(lines.length - 200) : lines,
    );
  }

  Future<void> _endPhase(GitResult result) async {
    state = state.copyWith(
      phase: SyncPhase.idle,
      clearProgress: true,
      message: result.ok && result.message.isNotEmpty ? result.message : null,
      error: result.ok ? null : result.message,
      clearError: result.ok,
      clearMessage: !result.ok,
    );
    await refreshGitStatus();
  }

  Future<bool> _remoteAction(
    SyncPhase phase,
    Future<GitResult> Function(GitBackend backend, RepoProfile profile, GitAuth auth) action,
  ) async {
    final profile = state.profile;
    if (profile == null) return false;
    _beginPhase(phase);
    final auth = await _authFor(profile);
    final result = await action(ref.read(gitBackendProvider), profile, auth);
    await _endPhase(result);
    return result.ok;
  }

  Future<void> _touchSyncTime(RepoProfile profile) async {
    final updated = profile.copyWith(lastSyncedAt: DateTime.now());
    final settings = await ref.read(settingsRepositoryProvider).saveProfile(updated);
    state = state.copyWith(profile: updated, settings: settings);
  }
}

final workspaceControllerProvider = NotifierProvider<WorkspaceController, WorkspaceState>(
  WorkspaceController.new,
);
