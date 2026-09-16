// Manual check against a real clone of the Zotero repository.
// Not named `*_test.dart` on purpose: `flutter test` skips it.
// Run explicitly: flutter test test/_real_repo_check.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/data/datasources/repo_layout_detector.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_fs_datasource.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_json.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_writer.dart';

const repoRoot =
    '/tmp/claude-1000/-home-hendri-own-project-apps-readpaper/1c6bee0a-8687-486c-946a-628d4fa3e462/scratchpad/zh';

void main() {
  test('parses the real zotero-hendri export', () async {
    final layout = await const RepoLayoutDetector().detect(repoRoot);
    expect(layout, isNotNull);
    print('zoteroRoot: ${layout!.zoteroRoot}');
    for (final lib in layout.libraries) {
      print(
        'library: ${lib.name} dir=${lib.directoryName} items=${lib.itemCount} cols=${lib.collectionCount}',
      );
    }

    final sw = Stopwatch()..start();
    final index = parseLibrarySync(
      layout.libraries.first.directoryPath,
      layout.libraries.first.name,
      layout.libraries.first.directoryName,
      layout.libraries.first.type,
    );
    sw.stop();
    print(
      'parsed ${index.itemCount} items, ${index.collectionCount} collections in ${sw.elapsedMilliseconds}ms',
    );
    print('roots: ${index.roots.map((r) => '${r.name}(${r.totalItemCount})').join(', ')}');
    print('unfiled: ${index.unfiledItemKeys.length}');

    final withAttachments = index.allItems.where((i) => i.hasReadableFile).length;
    final withAnnotations = index.allItems.where((i) => i.annotationCount > 0).length;
    print('items with a local file: $withAttachments · items with annotations: $withAnnotations');

    final sample = index.items['4BTNYYX4'];
    expect(sample, isNotNull, reason: 'standalone attachment item must be indexed');
    print(
      'sample: ${sample!.title} attachments=${sample.attachments.length} ann=${sample.annotationCount}',
    );
    print('sample attachment path: ${sample.attachments.first.relativePath}');
  });

  test('re-encoding every item file reproduces the plugin output byte-for-byte', () async {
    final dir = Directory('$repoRoot/zotero/my-library/items');
    var checked = 0;
    var mismatched = 0;
    final examples = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final original = entity.readAsStringSync();
      final reencoded = ZoteroJson.encodeFile(ZoteroJson.decodeObject(original));
      checked++;
      if (original != reencoded) {
        mismatched++;
        if (examples.length < 3) examples.add(entity.path);
      }
    }
    print('checked $checked files, $mismatched mismatched');
    for (final e in examples) {
      print('mismatch example: $e');
    }
    expect(mismatched, 0);
  });

  test('rendered annotation blocks match what the plugin wrote', () async {
    const writer = ZoteroWriter();
    final libraryDir = '$repoRoot/zotero/my-library';
    var compared = 0;
    var mismatched = 0;
    final examples = <String>[];

    for (final entity in Directory('$libraryDir/items').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final detail = buildItemDetail(
        ZoteroJson.decodeObject(entity.readAsStringSync()),
        entity.path,
      );
      if (detail.annotations.isEmpty) continue;

      final notePath = await writer.findNoteFile(libraryDir, detail.item.key);
      if (notePath == null) continue;

      final noteLines = File(notePath).readAsStringSync().split('\n');
      final start = noteLines.indexWhere((l) => l.trimRight() == '## Annotations');
      if (start < 0) continue;
      var end = noteLines.length;
      for (var i = start + 1; i < noteLines.length; i++) {
        final line = noteLines[i].trimRight();
        if (line.startsWith('## ') || line == '---') {
          end = i;
          break;
        }
      }

      final actual = noteLines.sublist(start, end).join('\n').trimRight();
      final rendered = ZoteroWriter.renderAnnotationsSection(
        detail.annotations,
      ).join('\n').trimRight();

      compared++;
      if (actual != rendered) {
        mismatched++;
        if (examples.length < 2) {
          examples.add(notePath);
          final a = actual.split('\n');
          final b = rendered.split('\n');
          for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
            final left = i < a.length ? a[i] : '<tidak ada>';
            final right = i < b.length ? b[i] : '<tidak ada>';
            if (left != right) {
              print('BEDA di $notePath baris $i');
              print('  plugin  : ${left.length > 90 ? left.substring(0, 90) : left}');
              print('  readpaper: ${right.length > 90 ? right.substring(0, 90) : right}');
              break;
            }
          }
        }
      }
    }

    print('catatan dibandingkan: $compared, beda: $mismatched');
    expect(mismatched, 0);
  });
}
