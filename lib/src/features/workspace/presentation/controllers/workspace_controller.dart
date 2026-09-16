import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../library/data/datasources/zotero_writer.dart';
import '../../../library/domain/entities/library_index.dart';
import '../../../library/domain/entities/zotero_annotation.dart';
import '../../../library/domain/entities/zotero_item.dart';
import '../../../settings/domain/entities/repo_profile.dart';
import '../../../sync/domain/entities/git_entities.dart';
import '../../../sync/domain/entities/sync_progress.dart';
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

  /// Reads the git state of [profile] and parses its library when present.
  Future<void> openProfile(RepoProfile profile) async {
    state = state.copyWith(profile: profile, clearError: true);
    final git = ref.read(gitBackendProvider);

    if (!await git.isAvailable()) {
      state = state.copyWith(
        error: Platform.isLinux || Platform.isMacOS
            ? 'Perintah git tidak ditemukan di sistem. Pasang git terlebih dahulu '
                  '(sudo apt install git git-lfs).'
            : 'Backend sinkronisasi tidak tersedia di perangkat ini.',
      );
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

  Future<void> refreshGitStatus() async {
    final profile = state.profile;
    if (profile == null) return;
    final status = await ref.read(gitBackendProvider).status(profile.localPath);
    state = state.copyWith(gitStatus: status);
  }

  // ------------------------------------------------------------- annotations

  /// Persists an annotation and commits it (pushing when the profile says so).
  Future<void> saveAnnotation({
    required ZoteroItem item,
    required ZoteroAnnotation annotation,
    required bool isNew,
  }) async {
    final library = state.library;
    final profile = state.profile;
    if (library == null || profile == null) return;

    final changed = await ref
        .read(libraryRepositoryProvider)
        .saveAnnotation(
          itemFilePath: item.filePath,
          libraryDir: library.directoryPath,
          annotation: annotation,
        );
    if (changed.isEmpty) return;

    await _commitAnnotation(
      profile: profile,
      message: annotationCommitMessage(
        action: isNew ? 'Tambah' : 'Ubah',
        itemTitle: item.title,
        annotation: annotation,
      ),
    );
  }

  Future<void> deleteAnnotation({
    required ZoteroItem item,
    required ZoteroAnnotation annotation,
  }) async {
    final library = state.library;
    final profile = state.profile;
    if (library == null || profile == null) return;

    await ref
        .read(libraryRepositoryProvider)
        .removeAnnotation(
          itemFilePath: item.filePath,
          libraryDir: library.directoryPath,
          annotationKey: annotation.key,
        );

    await _commitAnnotation(
      profile: profile,
      message: annotationCommitMessage(
        action: 'Hapus',
        itemTitle: item.title,
        annotation: annotation,
      ),
    );
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
