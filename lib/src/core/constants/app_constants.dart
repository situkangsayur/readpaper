/// Application-wide constants for ReadPaper.
class AppConstants {
  const AppConstants._();

  static const String appName = 'ReadPaper';
  static const String appVersion = '0.1.0';

  /// Directory name used for the on-disk configuration.
  static const String configDirName = 'readpaper';

  /// Name of the file holding the repository profiles.
  static const String configFileName = 'config.json';

  /// Name of the file holding HTTPS tokens (written with 0600 permissions).
  static const String credentialsFileName = 'credentials.json';

  /// Sub-directory (inside the data dir) where repositories are cloned.
  static const String reposDirName = 'repos';

  /// Sub-directory (inside the data dir) holding the parsed library caches.
  static const String cacheDirName = 'cache';

  /// Marker directory written by the zotero-github-sync plugin.
  static const String zoteroSyncDirName = '.zotero-sync';

  /// Default git branch used when a profile does not define one.
  static const String defaultBranch = 'main';

  /// Author used for annotations created by this app.
  static const String annotationAuthorTag = 'ReadPaper';
}

/// Zotero highlight palette (matches the colors Zotero itself offers).
class AnnotationPalette {
  const AnnotationPalette._();

  static const String yellow = '#ffd400';
  static const String red = '#ff6666';
  static const String green = '#5fb236';
  static const String blue = '#2ea8e5';
  static const String purple = '#a28ae5';
  static const String magenta = '#e56eee';
  static const String orange = '#f19837';
  static const String gray = '#aaaaaa';

  static const List<String> all = <String>[
    yellow,
    red,
    green,
    blue,
    purple,
    magenta,
    orange,
    gray,
  ];

  static const Map<String, String> names = <String, String>{
    yellow: 'Kuning',
    red: 'Merah',
    green: 'Hijau',
    blue: 'Biru',
    purple: 'Ungu',
    magenta: 'Magenta',
    orange: 'Oranye',
    gray: 'Abu-abu',
  };
}
