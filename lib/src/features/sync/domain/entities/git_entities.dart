import 'package:meta/meta.dart';
import '../../../../core/l10n.dart';

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
    this.remoteUrl,
    this.strictHostKeyChecking = false,
  });

  const GitAuth.ssh({String? keyPath})
    : transport = GitTransport.ssh,
      sshKeyPath = keyPath,
      httpsUsername = null,
      httpsToken = null,
      remoteUrl = null,
      strictHostKeyChecking = false;

  final GitTransport transport;

  /// Optional private key; when null the agent / default keys are used.
  final String? sshKeyPath;
  final String? httpsUsername;
  final String? httpsToken;

  /// Remote this credential belongs to. The API backend needs it because a
  /// mirror has no `.git/config` to read the remote from.
  final String? remoteUrl;
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
    '??' => l10n.syncChangeNew,
    'A' || 'AM' => l10n.syncChangeAdded,
    'M' || 'MM' => l10n.syncChangeModified,
    'D' => l10n.syncChangeDeleted,
    'R' => l10n.syncChangeRenamed,
    _ => status.trim(),
  };
}

/// Berkas yang ditolak GitHub saat dikirim — biasanya karena terlalu besar —
/// dan masih menunggu keputusan pemiliknya: dikecualikan, dihapus, atau
/// dicoba lagi. Lihat [FileDecision].
@immutable
class GitRejectedFile {
  const GitRejectedFile({
    required this.path,
    required this.reason,
    this.size,
    this.onRemote = false,
  });

  /// Jalur relatif terhadap akar repositori, dengan `/`.
  final String path;

  /// Jawaban GitHub, apa adanya.
  final String reason;

  /// Ukuran berkasnya di perangkat; null bila sudah tidak ada.
  final int? size;

  /// Versi lama berkas ini ada di GitHub: menghapusnya di sini ikut
  /// menghapusnya di sana pada pengiriman berikutnya.
  final bool onRemote;
}

/// Yang dilakukan pada berkas yang ditolak GitHub.
enum FileDecision {
  /// Tetap di perangkat, tetapi tidak pernah dikirim lagi.
  exclude,

  /// Kebalikan [exclude]: ikut dikirim lagi.
  include,

  /// Dihapus dari perangkat, dan dari antrean kirim.
  remove,

  /// Dikirim lagi pada pengiriman berikutnya walaupun isinya sama.
  retry,
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
    this.lazyAttachments = false,
    this.rejected = const <GitRejectedFile>[],
    this.excluded = const <String>[],
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
      lfsAvailable = false,
      lazyAttachments = false,
      rejected = const <GitRejectedFile>[],
      excluded = const <String>[];

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

  /// True when attachments are not in the working copy and are fetched per
  /// file: a partial+sparse git clone, or the Android mirror.
  final bool lazyAttachments;

  /// Berkas yang ditolak GitHub pada pengiriman terakhir; lihat
  /// [GitRejectedFile].
  final List<GitRejectedFile> rejected;

  /// Berkas yang sengaja tidak dikirim ([FileDecision.exclude]).
  final List<String> excluded;

  bool get isDirty => changes.isNotEmpty;
  bool get needsPush => ahead > 0;
  bool get needsPull => behind > 0;
  bool get isClean => exists && !isDirty && ahead == 0 && behind == 0;

  String get summary {
    if (!exists) return l10n.syncStatusNotCloned;
    final parts = <String>[];
    if (isDirty) parts.add(l10n.syncStatusLocalChanges(changes.length));
    if (ahead > 0) parts.add(l10n.syncStatusAhead(ahead));
    if (behind > 0) parts.add(l10n.syncStatusBehind(behind));
    if (rejected.isNotEmpty) parts.add(l10n.syncStatusRejected(rejected.length));
    return parts.isEmpty ? l10n.syncStatusInSync : parts.join(' · ');
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
