import '../entities/git_entities.dart';
import '../entities/sync_progress.dart';

/// Abstraction over the git implementation.
///
/// Desktop uses the system `git` binary ([GitCliBackend]); a future Android
/// build can plug a pure-Dart or libgit2 implementation in here without the
/// rest of the app changing.
abstract class GitBackend {
  /// Whether this backend can run on the current device.
  Future<bool> isAvailable();

  /// Checks that the remote is reachable and the credentials still work,
  /// without changing anything.
  Future<GitResult> checkConnection({required GitAuth auth, String? repoPath});

  /// Human readable name of the backend, shown in the sync panel.
  String get label;

  /// Transports this backend can authenticate with.
  Set<GitTransport> get supportedTransports;

  /// True when `git lfs` is installed.
  Future<bool> isLfsAvailable();

  Future<GitResult> clone({
    required String remoteUrl,
    required String targetPath,
    required GitAuth auth,
    String? branch,

    /// Fetch attachments only when a paper is opened, instead of pulling every
    /// PDF up front.
    bool lazyAttachments = true,
    void Function(SyncProgress progress)? onProgress,
  });

  Future<GitRepoStatus> status(String repoPath);

  Future<GitResult> fetch({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  });

  Future<GitResult> pull({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  });

  Future<GitResult> commitAll({
    required String repoPath,
    required String message,
    String? authorName,
    String? authorEmail,
    List<String> paths = const <String>[],
  });

  Future<GitResult> push({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  });

  /// Materialises Git LFS pointer files into real attachments.
  Future<GitResult> lfsPull({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  });

  /// Downloads a single attachment into the mirror.
  ///
  /// [absoluteFilePath] is where the file is expected to live locally.
  Future<GitResult> fetchAttachment({
    required String repoPath,
    required GitAuth auth,
    required String absoluteFilePath,
    void Function(SyncProgress progress)? onProgress,
  });

  Future<GitResult> setRemote({required String repoPath, required String remoteUrl});

  Future<List<GitCommitInfo>> log({required String repoPath, int limit = 20});
}
