import 'package:meta/meta.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../sync/domain/entities/git_entities.dart';

/// A GitHub repository ReadPaper keeps a local clone of.
///
/// Switching library means switching the active profile: each profile owns its
/// own clone directory, so moving between repositories never re-clones one that
/// is already on disk.
@immutable
class RepoProfile {
  const RepoProfile({
    required this.id,
    required this.name,
    required this.remoteUrl,
    required this.localPath,
    this.transport = GitTransport.ssh,
    this.branch = AppConstants.defaultBranch,
    this.sshKeyPath,
    this.httpsUsername,
    this.authorName = '',
    this.authorEmail = '',
    this.autoPushOnSave = false,
    this.preferredLibraryDir,
    this.lastSyncedAt,
  });

  factory RepoProfile.fromJson(Map<String, dynamic> json) => RepoProfile(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Repositori',
    remoteUrl: json['remoteUrl'] as String? ?? '',
    localPath: json['localPath'] as String? ?? '',
    transport: GitTransport.parse(json['transport'] as String?),
    branch: json['branch'] as String? ?? AppConstants.defaultBranch,
    sshKeyPath: json['sshKeyPath'] as String?,
    httpsUsername: json['httpsUsername'] as String?,
    authorName: json['authorName'] as String? ?? '',
    authorEmail: json['authorEmail'] as String? ?? '',
    autoPushOnSave: json['autoPushOnSave'] as bool? ?? false,
    preferredLibraryDir: json['preferredLibraryDir'] as String?,
    lastSyncedAt: DateTime.tryParse(json['lastSyncedAt'] as String? ?? ''),
  );

  final String id;
  final String name;
  final String remoteUrl;

  /// Absolute path of the local clone.
  final String localPath;
  final GitTransport transport;
  final String branch;

  /// Private key used for SSH remotes; null means "use the ssh agent".
  final String? sshKeyPath;
  final String? httpsUsername;
  final String authorName;
  final String authorEmail;

  /// Push straight after every annotation commit.
  final bool autoPushOnSave;

  /// Library directory name last opened for this repo (`my-library`).
  final String? preferredLibraryDir;
  final DateTime? lastSyncedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'remoteUrl': remoteUrl,
    'localPath': localPath,
    'transport': transport.wire,
    'branch': branch,
    'sshKeyPath': sshKeyPath,
    'httpsUsername': httpsUsername,
    'authorName': authorName,
    'authorEmail': authorEmail,
    'autoPushOnSave': autoPushOnSave,
    'preferredLibraryDir': preferredLibraryDir,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  RepoProfile copyWith({
    String? name,
    String? remoteUrl,
    String? localPath,
    GitTransport? transport,
    String? branch,
    String? sshKeyPath,
    String? httpsUsername,
    String? authorName,
    String? authorEmail,
    bool? autoPushOnSave,
    String? preferredLibraryDir,
    DateTime? lastSyncedAt,
    bool clearSshKey = false,
  }) => RepoProfile(
    id: id,
    name: name ?? this.name,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    localPath: localPath ?? this.localPath,
    transport: transport ?? this.transport,
    branch: branch ?? this.branch,
    sshKeyPath: clearSshKey ? null : (sshKeyPath ?? this.sshKeyPath),
    httpsUsername: httpsUsername ?? this.httpsUsername,
    authorName: authorName ?? this.authorName,
    authorEmail: authorEmail ?? this.authorEmail,
    autoPushOnSave: autoPushOnSave ?? this.autoPushOnSave,
    preferredLibraryDir: preferredLibraryDir ?? this.preferredLibraryDir,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );

  /// Builds the credentials for this profile; [token] comes from the
  /// separately stored credential file.
  GitAuth auth({String? token}) => GitAuth(
    transport: transport,
    sshKeyPath: sshKeyPath,
    httpsUsername: httpsUsername,
    httpsToken: token,
    remoteUrl: remoteUrl,
  );

  /// True when the remote URL matches the chosen transport.
  bool get remoteMatchesTransport {
    final url = remoteUrl.trim();
    if (url.isEmpty) return false;
    final looksSsh = url.startsWith('git@') || url.startsWith('ssh://');
    return transport == GitTransport.ssh ? looksSsh : !looksSsh;
  }

  /// `owner/repo` shown in the UI.
  String get shortRemote {
    var url = remoteUrl.trim();
    if (url.endsWith('.git')) url = url.substring(0, url.length - 4);
    final sshMatch = RegExp(r'^[^@]+@[^:]+:(.+)$').firstMatch(url);
    if (sshMatch != null) return sshMatch.group(1)!;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.isNotEmpty) return uri.pathSegments.join('/');
    return url;
  }
}

/// The persisted application settings.
@immutable
class AppSettings {
  const AppSettings({
    this.profiles = const <RepoProfile>[],
    this.activeProfileId,
    this.themeMode = 'system',
    this.lastAnnotationColor = AnnotationPalette.yellow,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    profiles: <RepoProfile>[
      for (final entry in (json['profiles'] as List?) ?? const <dynamic>[])
        if (entry is Map) RepoProfile.fromJson(entry.cast<String, dynamic>()),
    ],
    activeProfileId: json['activeProfileId'] as String?,
    themeMode: json['themeMode'] as String? ?? 'system',
    lastAnnotationColor: json['lastAnnotationColor'] as String? ?? AnnotationPalette.yellow,
  );

  final List<RepoProfile> profiles;
  final String? activeProfileId;
  final String themeMode;
  final String lastAnnotationColor;

  RepoProfile? get activeProfile {
    if (profiles.isEmpty) return null;
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.first;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'profiles': profiles.map((p) => p.toJson()).toList(),
    'activeProfileId': activeProfileId,
    'themeMode': themeMode,
    'lastAnnotationColor': lastAnnotationColor,
  };

  AppSettings copyWith({
    List<RepoProfile>? profiles,
    String? activeProfileId,
    String? themeMode,
    String? lastAnnotationColor,
    bool clearActive = false,
  }) => AppSettings(
    profiles: profiles ?? this.profiles,
    activeProfileId: clearActive ? null : (activeProfileId ?? this.activeProfileId),
    themeMode: themeMode ?? this.themeMode,
    lastAnnotationColor: lastAnnotationColor ?? this.lastAnnotationColor,
  );
}
