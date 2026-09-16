import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// Resolves (and lazily creates) the directories ReadPaper stores data in.
///
/// Linux    : `~/.local/share/readpaper/...`
/// Android  : the app's private support directory.
class AppPaths {
  AppPaths._(this.supportDir);

  final Directory supportDir;

  static AppPaths? _instance;

  static AppPaths get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('AppPaths.init() must be awaited before use.');
    }
    return instance;
  }

  static Future<AppPaths> init() async {
    if (_instance != null) return _instance!;
    Directory base;
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      final xdgData = Platform.environment['XDG_DATA_HOME'];
      if (xdgData != null && xdgData.isNotEmpty) {
        base = Directory(p.join(xdgData, AppConstants.configDirName));
      } else if (home != null && home.isNotEmpty) {
        base = Directory(p.join(home, '.local', 'share', AppConstants.configDirName));
      } else {
        base = await getApplicationSupportDirectory();
      }
    } else {
      base = await getApplicationSupportDirectory();
    }
    await base.create(recursive: true);
    return _instance = AppPaths._(base);
  }

  /// Visible for tests: override the resolved directory.
  static void debugOverride(Directory dir) => _instance = AppPaths._(dir);

  String get configFile => p.join(supportDir.path, AppConstants.configFileName);

  String get credentialsFile => p.join(supportDir.path, AppConstants.credentialsFileName);

  Directory get reposDir => Directory(p.join(supportDir.path, AppConstants.reposDirName));

  Directory get cacheDir => Directory(p.join(supportDir.path, AppConstants.cacheDirName));

  /// Default clone location for a profile.
  String defaultClonePath(String slug) => p.join(reposDir.path, slug);

  Future<void> ensureDirs() async {
    await reposDir.create(recursive: true);
    await cacheDir.create(recursive: true);
  }
}

/// Turns an arbitrary label or remote URL into a safe directory name.
String slugify(String input) {
  final lower = input.trim().toLowerCase();
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9._-]+'), '-').replaceAll(RegExp(r'-{2,}'), '-');
  final trimmed = cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'repo' : trimmed;
}

/// Derives a readable `owner-repo` slug from a git remote URL.
String slugFromRemote(String remoteUrl) {
  var url = remoteUrl.trim();
  if (url.endsWith('.git')) url = url.substring(0, url.length - 4);
  final sshMatch = RegExp(r'^[^@]+@[^:]+:(.+)$').firstMatch(url);
  if (sshMatch != null) return slugify(sshMatch.group(1)!.replaceAll('/', '-'));
  final uri = Uri.tryParse(url);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    return slugify(uri.pathSegments.join('-'));
  }
  return slugify(url);
}
