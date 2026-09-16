import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/library_index.dart';
import 'zotero_json.dart';

/// Finds the Zotero export inside a cloned repository.
///
/// The `zotero-github-sync` plugin writes everything under a `zotero/`
/// directory with a `.zotero-sync/manifest.json` describing the libraries, but
/// a repository may also have the export at its root, so both are probed and a
/// filesystem scan is used as a last resort.
class RepoLayoutDetector {
  const RepoLayoutDetector();

  Future<RepoLayout?> detect(String repoRoot) async {
    if (!Directory(repoRoot).existsSync()) return null;

    for (final candidate in <String>[p.join(repoRoot, 'zotero'), repoRoot]) {
      final layout = await _fromManifest(repoRoot, candidate);
      if (layout != null) return layout;
    }
    return _byScanning(repoRoot);
  }

  Future<RepoLayout?> _fromManifest(String repoRoot, String zoteroRoot) async {
    final manifest = File(p.join(zoteroRoot, AppConstants.zoteroSyncDirName, 'manifest.json'));
    if (!manifest.existsSync()) return null;

    try {
      final json = ZoteroJson.decodeObject(await manifest.readAsString());
      final libs = (json['libraries'] as List?) ?? const <dynamic>[];
      final refs = <LibraryRef>[];
      for (final entry in libs) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final dirName = map['directory'] as String? ?? '';
        final dirPath = p.join(zoteroRoot, dirName);
        if (dirName.isEmpty || !Directory(dirPath).existsSync()) continue;
        refs.add(
          LibraryRef(
            name: map['name'] as String? ?? dirName,
            directoryName: dirName,
            directoryPath: dirPath,
            itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
            collectionCount: (map['collectionCount'] as num?)?.toInt() ?? 0,
            type: map['type'] as String? ?? 'user',
          ),
        );
      }
      if (refs.isEmpty) return null;
      return RepoLayout(repoRoot: repoRoot, zoteroRoot: zoteroRoot, libraries: refs);
    } on FormatException {
      return null;
    }
  }

  /// Fallback: any directory (at most two levels deep) holding `collections.json`.
  Future<RepoLayout?> _byScanning(String repoRoot) async {
    final found = <LibraryRef>[];
    String? zoteroRoot;

    Future<void> probe(Directory dir) async {
      if (!File(p.join(dir.path, 'collections.json')).existsSync()) return;
      if (!Directory(p.join(dir.path, 'items')).existsSync()) return;
      zoteroRoot ??= dir.parent.path;
      found.add(
        LibraryRef(
          name: _libraryName(dir),
          directoryName: p.basename(dir.path),
          directoryPath: dir.path,
        ),
      );
    }

    await probe(Directory(repoRoot));
    for (final entry in Directory(repoRoot).listSync().whereType<Directory>()) {
      if (p.basename(entry.path).startsWith('.')) continue;
      await probe(entry);
      for (final nested in entry.listSync().whereType<Directory>()) {
        if (p.basename(nested.path).startsWith('.')) continue;
        await probe(nested);
      }
    }

    if (found.isEmpty) return null;
    return RepoLayout(repoRoot: repoRoot, zoteroRoot: zoteroRoot ?? repoRoot, libraries: found);
  }

  String _libraryName(Directory dir) {
    final file = File(p.join(dir.path, 'library.json'));
    if (file.existsSync()) {
      try {
        final json = ZoteroJson.decodeObject(file.readAsStringSync());
        final name = json['name'] as String?;
        if (name != null && name.isNotEmpty) return name;
      } on FormatException {
        // fall through to the directory name
      }
    }
    return p.basename(dir.path);
  }
}
