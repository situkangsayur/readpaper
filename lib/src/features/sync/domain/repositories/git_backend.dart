import '../entities/git_entities.dart';

/// Abstraction over the git implementation.
///
/// Desktop uses the system `git` binary ([GitCliBackend]); a future Android
/// build can plug a pure-Dart or libgit2 implementation in here without the
/// rest of the app changing.
abstract class GitBackend {
  /// Whether this backend can run on the current device.
  Future<bool> isAvailable();

  /// True when `git lfs` is installed.
  Future<bool> isLfsAvailable();

  Future<GitResult> clone({
    required String remoteUrl,
    required String targetPath,
    required GitAuth auth,
    String? branch,
    void Function(String line)? onProgress,
  });

  Future<GitRepoStatus> status(String repoPath);

  Future<GitResult> fetch({
    required String repoPath,
    required GitAuth auth,
    void Function(String line)? onProgress,
  });

  Future<GitResult> pull({
    required String repoPath,
    required GitAuth auth,
    void Function(String line)? onProgress,
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
    void Function(String line)? onProgress,
  });

  /// Materialises Git LFS pointer files into real attachments.
  Future<GitResult> lfsPull({
    required String repoPath,
    required GitAuth auth,
    void Function(String line)? onProgress,
  });

  Future<GitResult> setRemote({required String repoPath, required String remoteUrl});

  Future<List<GitCommitInfo>> log({required String repoPath, int limit = 20});
}
