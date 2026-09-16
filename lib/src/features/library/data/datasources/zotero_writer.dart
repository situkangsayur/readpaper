import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatting.dart';
import '../../domain/entities/zotero_annotation.dart';
import 'zotero_fs_datasource.dart';
import 'zotero_json.dart';

/// Writes annotations back into the Zotero export.
///
/// Everything is written in the plugin's own format (tab indented, sorted
/// keys) so that a later **Import from GitHub** in Zotero picks the
/// annotations up and so that git diffs stay small.
class ZoteroWriter {
  const ZoteroWriter();

  /// Inserts or replaces [annotation] inside its item file.
  ///
  /// Returns the list of files that were touched, for the commit message.
  Future<List<String>> upsertAnnotation({
    required String itemFilePath,
    required String libraryDir,
    required ZoteroAnnotation annotation,
  }) async {
    final json = await _readItem(itemFilePath);
    final children = _children(json);

    final index = children.indexWhere(
      (c) => c is Map && c['itemType'] == 'annotation' && c['key'] == annotation.key,
    );
    final encoded = ZoteroJson.sortKeys(annotation.toJson()) as Map<String, Object?>;
    if (index >= 0) {
      children[index] = encoded;
    } else {
      children.add(encoded);
    }

    return _persist(json: json, itemFilePath: itemFilePath, libraryDir: libraryDir);
  }

  /// Removes the annotation with [annotationKey] from its item file.
  Future<List<String>> deleteAnnotation({
    required String itemFilePath,
    required String libraryDir,
    required String annotationKey,
  }) async {
    final json = await _readItem(itemFilePath);
    final children = _children(json);
    children.removeWhere(
      (c) => c is Map && c['itemType'] == 'annotation' && c['key'] == annotationKey,
    );
    return _persist(json: json, itemFilePath: itemFilePath, libraryDir: libraryDir);
  }

  Future<Map<String, dynamic>> _readItem(String itemFilePath) async {
    final file = File(itemFilePath);
    if (!file.existsSync()) {
      throw LibraryFailure('Berkas item tidak ditemukan', details: itemFilePath);
    }
    return ZoteroJson.decodeObject(await file.readAsString());
  }

  List<dynamic> _children(Map<String, dynamic> json) {
    final existing = json['children'];
    if (existing is List) return existing;
    final created = <dynamic>[];
    json['children'] = created;
    return created;
  }

  Future<List<String>> _persist({
    required Map<String, dynamic> json,
    required String itemFilePath,
    required String libraryDir,
  }) async {
    final children = _children(json);
    children.sort((a, b) => _childKey(a).compareTo(_childKey(b)));

    final detail = buildItemDetail(json, itemFilePath);
    _refreshAnnotationCounts(json, detail.annotations);

    await File(itemFilePath).writeAsString(ZoteroJson.encodeFile(json), flush: true);
    final touched = <String>[itemFilePath];

    final notePath = await findNoteFile(libraryDir, detail.item.key);
    if (notePath != null) {
      final updated = await _rewriteNoteAnnotations(notePath, detail.annotations);
      if (updated) touched.add(notePath);
    }
    return touched;
  }

  /// The plugin writes `children` sorted by Zotero key, regardless of type.
  /// Matching that keeps an added annotation to a few added lines in the diff
  /// instead of rewriting the whole file.
  String _childKey(dynamic child) => child is Map ? (child['key'] as String? ?? '') : '';

  void _refreshAnnotationCounts(Map<String, dynamic> json, List<ZoteroAnnotation> annotations) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>();
    if (meta == null) return;
    final attachments = meta['attachments'];
    if (attachments is! List) return;
    for (final entry in attachments) {
      if (entry is! Map) continue;
      final key = entry['key'] as String?;
      if (key == null) continue;
      entry['annotationCount'] = annotations.where((a) => a.parentItemKey == key).length;
    }
  }

  /// Locates `notes/<bucket>/<title> (KEY).md` for an item key.
  Future<String?> findNoteFile(String libraryDir, String itemKey) async {
    final notesDir = Directory(p.join(libraryDir, 'notes'));
    if (!notesDir.existsSync()) return null;
    final suffix = '($itemKey).md';
    for (final entity in notesDir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith(suffix)) return entity.path;
    }
    return null;
  }

  /// Replaces the `## Annotations` section of a note markdown file.
  Future<bool> _rewriteNoteAnnotations(String notePath, List<ZoteroAnnotation> annotations) async {
    final file = File(notePath);
    final original = await file.readAsString();
    final rendered = renderAnnotationsSection(annotations);

    final lines = original.split('\n');
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimRight() == '## Annotations') {
        start = i;
        break;
      }
    }

    String updated;
    if (start >= 0) {
      var end = lines.length;
      for (var i = start + 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.startsWith('## ') || line == '---') {
          end = i;
          break;
        }
      }
      final rebuilt = <String>[...lines.sublist(0, start), ...rendered, ...lines.sublist(end)];
      updated = rebuilt.join('\n');
    } else if (rendered.isEmpty) {
      return false;
    } else {
      // Insert before the trailing `---` / "Open in Zotero" footer when present.
      var insertAt = lines.length;
      for (var i = lines.length - 1; i >= 0; i--) {
        if (lines[i].trimRight() == '---') {
          insertAt = i;
          break;
        }
      }
      updated = <String>[
        ...lines.sublist(0, insertAt),
        ...rendered,
        ...lines.sublist(insertAt),
      ].join('\n');
    }

    if (updated == original) return false;
    await file.writeAsString(updated, flush: true);
    return true;
  }

  /// Renders the markdown block the plugin writes for annotations.
  static List<String> renderAnnotationsSection(List<ZoteroAnnotation> annotations) {
    if (annotations.isEmpty) return const <String>[];
    final lines = <String>['## Annotations', ''];
    for (final annotation in annotations) {
      final page = annotation.pageLabel.isNotEmpty
          ? annotation.pageLabel
          : '${annotation.pageIndex + 1}';
      final head = '- **p. $page, ${annotation.type.wire}**';
      // The quoted text is written verbatim: the plugin keeps the double
      // spaces that come out of the PDF's text layer, and normalising them
      // here would rewrite every existing line on the next save.
      if (annotation.text.isNotEmpty) {
        lines.add('$head “${annotation.text}”');
      } else {
        lines.add(head);
      }
      final comment = _oneLine(annotation.comment);
      if (comment.isNotEmpty) lines.add('  $comment');
    }
    lines.add('');
    return lines;
  }

  /// A comment always lands on a single line: its lines are trimmed and joined
  /// with a space, the way the plugin writes them.
  static String _oneLine(String value) =>
      value.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).join(' ');
}

/// Builds a human readable commit message for an annotation change.
String annotationCommitMessage({
  required String action,
  required String itemTitle,
  required ZoteroAnnotation annotation,
}) {
  final page = annotation.pageLabel.isNotEmpty
      ? annotation.pageLabel
      : '${annotation.pageIndex + 1}';
  final title = itemTitle.length > 60 ? '${itemTitle.substring(0, 57)}...' : itemTitle;
  return '$action ${annotation.type.wire} p.$page — $title\n\n'
      'ReadPaper ${zoteroTimestamp()}';
}
