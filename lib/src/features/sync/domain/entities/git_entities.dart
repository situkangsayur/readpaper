import 'package:meta/meta.dart';

/// How a remote is authenticated.
enum GitTransport {
  ssh,
  https;

  static GitTransport parse(String? raw) => raw == 'https' ? GitTransport.https : GitTransport.ssh;

  String get wire => name;

  String get label => this == GitTransport.ssh ? 'SSH' : 'HTTPS';
}

/// Credentials for one remote.
@immutable
class GitAuth {
  const GitAuth({
    required this.transport,
    this.sshKeyPath,
    this.httpsUsername,
    this.httpsToken,
    this.strictHostKeyChecking = false,
  });

  const GitAuth.ssh({String? keyPath})
    : transport = GitTransport.ssh,
      sshKeyPath = keyPath,
      httpsUsername = null,
      httpsToken = null,
      strictHostKeyChecking = false;

  final GitTransport transport;

  /// Optional private key; when null the agent / default keys are used.
  final String? sshKeyPath;
  final String? httpsUsername;
  final String? httpsToken;
  final bool strictHostKeyChecking;

  bool get hasHttpsCredentials => (httpsToken ?? '').isNotEmpty;
}

/// A file with pending changes in the working tree.
@immutable
class GitChange {
  const GitChange({required this.status, required this.path});

  /// Two-letter porcelain code, e.g. `M `, `??`, ` D`.
  final String status;
  final String path;

  bool get isUntracked => status.trim() == '??';
  bool get isDeleted => status.contains('D');

  String get label => switch (status.trim()) {
    '??' => 'baru',
    'A' || 'AM' => 'ditambah',
    'M' || 'MM' => 'diubah',
    'D' => 'dihapus',
    'R' => 'dipindah',
    _ => status.trim(),
  };
}

/// Snapshot of a working copy.
@immutable
class GitRepoStatus {
  const GitRepoStatus({
    required this.repoPath,
    required this.exists,
    this.branch = '',
    this.remoteUrl = '',
    this.ahead = 0,
    this.behind = 0,
    this.changes = const <GitChange>[],
    this.lastCommitSubject = '',
    this.lastCommitDate,
    this.hasUpstream = true,
    this.lfsAvailable = false,
  });

  const GitRepoStatus.missing(String path)
    : repoPath = path,
      exists = false,
      branch = '',
      remoteUrl = '',
      ahead = 0,
      behind = 0,
      changes = const <GitChange>[],
      lastCommitSubject = '',
      lastCommitDate = null,
      hasUpstream = false,
      lfsAvailable = false;

  final String repoPath;
  final bool exists;
  final String branch;
  final String remoteUrl;
  final int ahead;
  final int behind;
  final List<GitChange> changes;
  final String lastCommitSubject;
  final DateTime? lastCommitDate;
  final bool hasUpstream;
  final bool lfsAvailable;

  bool get isDirty => changes.isNotEmpty;
  bool get needsPush => ahead > 0;
  bool get needsPull => behind > 0;
  bool get isClean => exists && !isDirty && ahead == 0 && behind == 0;

  String get summary {
    if (!exists) return 'Belum di-clone';
    final parts = <String>[];
    if (isDirty) parts.add('${changes.length} perubahan lokal');
    if (ahead > 0) parts.add('$ahead commit belum di-push');
    if (behind > 0) parts.add('$behind commit baru di remote');
    return parts.isEmpty ? 'Sinkron' : parts.join(' · ');
  }
}

/// Result of a git command.
@immutable
class GitResult {
  const GitResult({
    required this.ok,
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.message = '',
  });

  final bool ok;
  final int exitCode;
  final String stdout;
  final String stderr;
  final String message;

  String get output => (stdout + (stderr.isEmpty ? '' : '\n$stderr')).trim();
}

/// One entry of the commit log.
@immutable
class GitCommitInfo {
  const GitCommitInfo({
    required this.hash,
    required this.subject,
    required this.author,
    required this.date,
  });

  final String hash;
  final String subject;
  final String author;
  final DateTime date;

  String get shortHash => hash.length > 7 ? hash.substring(0, 7) : hash;
}
