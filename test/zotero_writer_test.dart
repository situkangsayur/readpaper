import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/library/data/datasources/zotero_fs_datasource.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_json.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_writer.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';

/// Minimal stand-in for a `zotero-github-sync` export.
Directory _buildFixture() {
  final root = Directory.systemTemp.createTempSync('readpaper_fixture_');
  final library = Directory(p.join(root.path, 'zotero', 'my-library'))..createSync(recursive: true);

  File(p.join(root.path, 'zotero', '.zotero-sync', 'manifest.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(
      ZoteroJson.encodeFile(<String, dynamic>{
        'generator': 'zotero-github-sync',
        'schema': 1,
        'libraries': <dynamic>[
          <String, dynamic>{
            'directory': 'my-library',
            'id': 1,
            'name': 'My Library',
            'type': 'user',
            'itemCount': 1,
            'collectionCount': 2,
          },
        ],
      }),
    );

  File(p.join(library.path, 'collections.json')).writeAsStringSync(
    '[\n\t{\n\t\t"key": "PARENT01",\n\t\t"name": "PhD",\n\t\t"parentKey": null,\n\t\t"path": "PhD",\n\t\t"relations": {}\n\t},\n'
    '\t{\n\t\t"key": "CHILD001",\n\t\t"name": "Crypto",\n\t\t"parentKey": "PARENT01",\n\t\t"path": "PhD/Crypto",\n\t\t"relations": {}\n\t}\n]\n',
  );

  final item = <String, dynamic>{
    'children': <dynamic>[
      <String, dynamic>{
        'charset': '',
        'contentType': 'application/pdf',
        'dateAdded': '2026-09-01T00:00:00Z',
        'dateModified': '2026-09-01T00:00:00Z',
        'filename': 'paper.pdf',
        'itemType': 'attachment',
        'key': 'ATTACH01',
        'linkMode': 'imported_file',
        'parentItem': 'ITEMKEY1',
        'relations': <String, dynamic>{},
        'tags': <dynamic>[],
        'title': 'PDF',
      },
    ],
    'meta': <String, dynamic>{
      'attachments': <dynamic>[
        <String, dynamic>{
          'annotationCount': 0,
          'contentType': 'application/pdf',
          'filename': 'paper.pdf',
          'files': <dynamic>[
            <String, dynamic>{
              'path': 'attachments/AT/ATTACH01/paper.pdf',
              'size': 1234,
              'storage': 'git',
            },
          ],
          'key': 'ATTACH01',
          'linkMode': 'imported_file',
          'status': 'ok',
          'title': 'PDF',
          'url': null,
        },
      ],
      'collections': <dynamic>['PhD/Crypto'],
      'creators': <dynamic>['Naether, Christian'],
      'itemType': 'journalArticle',
      'libraryID': 1,
      'libraryName': 'My Library',
      'notes': <dynamic>[],
      'title': 'Migrasi PQC',
      'year': '2024',
      'zoteroURI': 'zotero://select/library/items/ITEMKEY1',
    },
    'zotero': <String, dynamic>{
      'DOI': '10.1000/demo',
      'collections': <dynamic>['CHILD001'],
      'creators': <dynamic>[
        <String, dynamic>{'creatorType': 'author', 'firstName': 'Christian', 'lastName': 'Naether'},
      ],
      'date': '2024',
      'dateAdded': '2026-09-01T00:00:00Z',
      'dateModified': '2026-09-01T00:00:00Z',
      'itemType': 'journalArticle',
      'key': 'ITEMKEY1',
      'publicationTitle': 'Journal of Demo',
      'relations': <String, dynamic>{},
      'tags': <dynamic>[
        <String, dynamic>{'tag': 'pqc'},
      ],
      'title': 'Migrasi PQC',
    },
  };

  final itemFile = File(p.join(library.path, 'items', 'IT', 'ITEMKEY1.json'))
    ..createSync(recursive: true);
  itemFile.writeAsStringSync(ZoteroJson.encodeFile(item));

  File(p.join(library.path, 'notes', 'M', 'Migrasi PQC (ITEMKEY1).md'))
    ..createSync(recursive: true)
    ..writeAsStringSync('''---
title: "Migrasi PQC"
zotero-key: "ITEMKEY1"
---

# Migrasi PQC

## Attachments

- [paper.pdf](../../attachments/AT/ATTACH01/paper.pdf)

---

[Open in Zotero](zotero://select/library/items/ITEMKEY1)
''');

  File(p.join(library.path, 'attachments', 'AT', 'ATTACH01', 'paper.pdf'))
    ..createSync(recursive: true)
    ..writeAsStringSync('%PDF-1.4 dummy');

  return root;
}

ZoteroAnnotation _highlight({String key = 'ANNKEY01', String comment = 'catatan uji'}) =>
    ZoteroAnnotation(
      key: key,
      parentItemKey: 'ATTACH01',
      type: AnnotationType.highlight,
      color: '#ff6666',
      pageIndex: 2,
      rects: const <AnnotationRect>[AnnotationRect(72, 600, 500, 612)],
      text: 'crypto agility belum ada di produksi',
      comment: comment,
      pageLabel: '3',
      sortIndex: ZoteroAnnotation.buildSortIndex(
        pageIndex: 2,
        textOffset: 412,
        topFromPageTop: 180,
      ),
      dateAdded: DateTime.utc(2026, 9, 16, 10),
      dateModified: DateTime.utc(2026, 9, 16, 10),
    );

void main() {
  late Directory root;
  late String libraryDir;
  late String itemPath;

  setUp(() {
    root = _buildFixture();
    libraryDir = p.join(root.path, 'zotero', 'my-library');
    itemPath = p.join(libraryDir, 'items', 'IT', 'ITEMKEY1.json');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('parses collections, tree and items', () {
    final index = parseLibrarySync(libraryDir, 'My Library', 'my-library', 'user');

    expect(index.itemCount, 1);
    expect(index.collectionCount, 2);
    expect(index.roots, hasLength(1));
    expect(index.roots.single.name, 'PhD');
    expect(index.roots.single.children.single.name, 'Crypto');
    expect(index.roots.single.totalItemCount, 1, reason: 'parent counts sub-collection items');
    expect(index.itemsIn('PARENT01'), hasLength(1));
    expect(index.itemsIn('PARENT01', includeSubcollections: false), isEmpty);

    final item = index.items['ITEMKEY1']!;
    expect(item.title, 'Migrasi PQC');
    expect(item.creators, <String>['Naether, Christian']);
    expect(item.publication, 'Journal of Demo');
    expect(item.attachments.single.isPdf, isTrue);
    expect(item.attachments.single.relativePath, 'attachments/AT/ATTACH01/paper.pdf');
  });

  test('writes an annotation in the plugin format and updates the note', () async {
    const writer = ZoteroWriter();
    final touched = await writer.upsertAnnotation(
      itemFilePath: itemPath,
      libraryDir: libraryDir,
      annotation: _highlight(),
    );

    expect(touched, hasLength(2), reason: 'item json + note markdown');

    final raw = File(itemPath).readAsStringSync();
    expect(raw.endsWith('}\n'), isTrue);
    expect(raw.contains('\t\t\t"annotationColor": "#ff6666",'), isTrue);
    expect(
      raw.contains('"annotationPosition": "{\\"pageIndex\\":2,\\"rects\\":[[72,600,500,612]]}"'),
      isTrue,
    );
    expect(raw.contains('"annotationSortIndex": "00002|000412|00180"'), isTrue);

    final detail = buildItemDetail(ZoteroJson.decodeObject(raw), itemPath);
    expect(detail.annotations, hasLength(1));
    expect(detail.annotationsFor('ATTACH01'), hasLength(1));
    final parsed = detail.annotations.single;
    expect(parsed.type, AnnotationType.highlight);
    expect(parsed.pageIndex, 2);
    expect(parsed.rects.single.left, 72);
    expect(parsed.comment, 'catatan uji');

    // The attachment's annotation counter is kept in step.
    final meta = ZoteroJson.decodeObject(raw)['meta'] as Map<String, dynamic>;
    expect((meta['attachments'] as List).first['annotationCount'], 1);

    final note = File(
      p.join(libraryDir, 'notes', 'M', 'Migrasi PQC (ITEMKEY1).md'),
    ).readAsStringSync();
    expect(note.contains('## Annotations'), isTrue);
    expect(note.contains('- **p. 3, highlight** “crypto agility'), isTrue);
    expect(note.contains('  catatan uji'), isTrue);
    expect(note.contains('[Open in Zotero]'), isTrue, reason: 'footer survives the rewrite');
  });

  test('multi-line comments are rendered on one line like the plugin', () {
    final lines = ZoteroWriter.renderAnnotationsSection(<ZoteroAnnotation>[
      _highlight(comment: 'need & kesulitan \n1- kitchenham'),
    ]);
    expect(lines, contains('  need & kesulitan 1- kitchenham'));
  });

  test('children stay sorted by key so diffs stay small', () async {
    const writer = ZoteroWriter();
    for (final key in <String>['ZZZZ0001', 'AAAA0001', 'MMMM0001']) {
      await writer.upsertAnnotation(
        itemFilePath: itemPath,
        libraryDir: libraryDir,
        annotation: _highlight(key: key),
      );
    }
    final children = ZoteroJson.decodeObject(File(itemPath).readAsStringSync())['children'] as List;
    final keys = children.map((c) => (c as Map)['key'] as String).toList();
    expect(keys, <String>['AAAA0001', 'ATTACH01', 'MMMM0001', 'ZZZZ0001']);
  });

  test('editing an annotation replaces it instead of duplicating', () async {
    const writer = ZoteroWriter();
    await writer.upsertAnnotation(
      itemFilePath: itemPath,
      libraryDir: libraryDir,
      annotation: _highlight(),
    );
    await writer.upsertAnnotation(
      itemFilePath: itemPath,
      libraryDir: libraryDir,
      annotation: _highlight(comment: 'komentar baru'),
    );

    final detail = buildItemDetail(
      ZoteroJson.decodeObject(File(itemPath).readAsStringSync()),
      itemPath,
    );
    expect(detail.annotations, hasLength(1));
    expect(detail.annotations.single.comment, 'komentar baru');
  });

  test('deleting an annotation cleans the item and the note', () async {
    const writer = ZoteroWriter();
    await writer.upsertAnnotation(
      itemFilePath: itemPath,
      libraryDir: libraryDir,
      annotation: _highlight(),
    );
    await writer.deleteAnnotation(
      itemFilePath: itemPath,
      libraryDir: libraryDir,
      annotationKey: 'ANNKEY01',
    );

    final raw = File(itemPath).readAsStringSync();
    expect(raw.contains('ANNKEY01'), isFalse);
    expect(raw.contains('"itemType": "attachment"'), isTrue, reason: 'attachment child stays');

    final meta = ZoteroJson.decodeObject(raw)['meta'] as Map<String, dynamic>;
    expect((meta['attachments'] as List).first['annotationCount'], 0);

    final note = File(
      p.join(libraryDir, 'notes', 'M', 'Migrasi PQC (ITEMKEY1).md'),
    ).readAsStringSync();
    expect(note.contains('crypto agility'), isFalse);
  });
}
