import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/library/data/datasources/library_transfer.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_json.dart';

/// Menyalin item dan koleksi antar library di dua repositori berbeda.
void main() {
  late Directory root;
  late String asal;
  late String tujuan;
  const transfer = LibraryTransfer();

  void write(String path, String text) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  void collections(String lib, List<(String, String, String?, String)> rows) => write(
    p.join(lib, 'collections.json'),
    '${const JsonEncoder.withIndent('\t').convert(ZoteroJson.sortKeys(<Object?>[
      for (final (k, n, parent, path) in rows) <String, Object?>{'key': k, 'name': n, 'parentKey': parent, 'path': path, 'relations': <String, Object?>{}},
    ]))}\n',
  );

  /// Satu item dengan satu lampiran PDF dan catatan Markdown.
  void item(
    String key,
    String attachment,
    List<String> keys,
    List<String> paths, {
    bool pdf = true,
  }) {
    write(
      p.join(asal, 'items', key.substring(0, 2), '$key.json'),
      ZoteroJson.encodeFile(<String, dynamic>{
        'children': <dynamic>[
          <String, dynamic>{'itemType': 'attachment', 'key': attachment, 'parentItem': key},
          <String, dynamic>{'itemType': 'annotation', 'key': 'AN$key'.substring(0, 8)},
        ],
        'meta': <String, dynamic>{
          'attachments': <dynamic>[
            <String, dynamic>{
              'key': attachment,
              'files': <dynamic>[
                <String, dynamic>{'path': 'attachments/x/paper.pdf'},
              ],
            },
          ],
          'collections': paths,
          'libraryID': 1,
          'libraryName': 'Asal',
          'title': 'Judul $key',
          'zoteroURI': 'zotero://select/library/items/$key',
        },
        'zotero': <String, dynamic>{'key': key, 'collections': keys},
      }),
    );
    if (pdf) {
      write(
        p.join(asal, 'attachments', attachment.substring(0, 2), attachment, 'paper.pdf'),
        '%PDF $key',
      );
    }
    write(p.join(asal, 'notes', 'J', 'Judul $key ($key).md'), '# Judul $key\n');
  }

  Map<String, dynamic> read(String lib, String key) => ZoteroJson.decodeObject(
    File(p.join(lib, 'items', key.substring(0, 2), '$key.json')).readAsStringSync(),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('rp_pindah_');
    asal = p.join(root.path, 'asal', 'zotero', 'lib');
    tujuan = p.join(root.path, 'tujuan', 'zotero', 'grup');
    collections(asal, <(String, String, String?, String)>[
      ('PHDPHDPH', 'PhD', null, 'PhD'),
      ('QMLQMLQM', 'QML', 'PHDPHDPH', 'PhD/QML'),
      ('LAINLAIN', 'Lain', null, 'Lain'),
    ]);
    collections(tujuan, <(String, String, String?, String)>[('ARSIPARS', 'Arsip', null, 'Arsip')]);
    write(p.join(tujuan, 'library.json'), '{"id": 7, "name": "Grup Lab", "type": "group"}\n');
    item('AAAAAAAA', 'PDFAAAAA', <String>['QMLQMLQM'], <String>['PhD/QML']);
    item('BBBBBBBB', 'PDFBBBBB', <String>['PHDPHDPH', 'LAINLAIN'], <String>['PhD', 'Lain']);
    item('CCCCCCCC', 'PDFCCCCC', <String>['LAINLAIN'], <String>['Lain']);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('satu item: berkas, lampiran, catatan, dan identitas library tujuan', () async {
    final result = await transfer.copyItem(
      sourceDir: asal,
      targetDir: tujuan,
      itemFilePath: p.join(asal, 'items', 'CC', 'CCCCCCCC.json'),
      collectionKeys: <String>['ARSIPARS'],
      collectionPaths: <String>['Arsip'],
    );
    final copied = read(tujuan, 'CCCCCCCC');
    expect((copied['zotero'] as Map)['collections'], <String>['ARSIPARS']);
    final meta = copied['meta'] as Map;
    expect(meta['collections'], <String>['Arsip']);
    expect(meta['libraryID'], 7);
    expect(meta['libraryName'], 'Grup Lab');
    expect(meta['zoteroURI'], 'zotero://select/groups/7/items/CCCCCCCC');
    expect((copied['children'] as List), hasLength(2), reason: 'anotasinya ikut');
    expect(File(p.join(tujuan, 'attachments', 'PD', 'PDFCCCCC', 'paper.pdf')).existsSync(), isTrue);
    expect(File(p.join(tujuan, 'notes', 'J', 'Judul CCCCCCCC (CCCCCCCC).md')).existsSync(), isTrue);
    expect(result.touched, hasLength(3));
    expect(
      File(p.join(asal, 'items', 'CC', 'CCCCCCCC.json')).existsSync(),
      isTrue,
      reason: 'library asal tidak disentuh',
    );
  });

  test('item yang PDF-nya belum diunduh tidak disalin sama sekali', () async {
    item('DDDDDDDD', 'PDFDDDDD', <String>['LAINLAIN'], <String>['Lain'], pdf: false);
    await expectLater(
      transfer.copyItem(
        sourceDir: asal,
        targetDir: tujuan,
        itemFilePath: p.join(asal, 'items', 'DD', 'DDDDDDDD.json'),
        collectionKeys: const <String>[],
        collectionPaths: const <String>[],
      ),
      throwsA(isA<MissingAttachments>()),
    );
    expect(File(p.join(tujuan, 'items', 'DD', 'DDDDDDDD.json')).existsSync(), isFalse);
  });

  test('penunjuk Git LFS bukan isi lampiran', () async {
    write(
      p.join(asal, 'attachments-lfs', 'PD', 'PDFAAAAA', 'paper.pdf'),
      'version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 10\n',
    );
    Directory(p.join(asal, 'attachments', 'PD', 'PDFAAAAA')).deleteSync(recursive: true);
    final missing = await transfer.missingAttachments(
      asal,
      p.join(asal, 'items', 'AA', 'AAAAAAAA.json'),
    );
    expect(missing, hasLength(1));
  });

  test('koleksi beserta sub-koleksi dan itemnya, di bawah koleksi tujuan', () async {
    final result = await transfer.copyCollection(
      sourceDir: asal,
      targetDir: tujuan,
      collectionKey: 'PHDPHDPH',
      targetParentKey: 'ARSIPARS',
    );
    final cols = {
      for (final c
          in (jsonDecode(File(p.join(tujuan, 'collections.json')).readAsStringSync()) as List))
        (c as Map)['key']: c,
    };
    expect(cols['PHDPHDPH']!['parentKey'], 'ARSIPARS');
    expect(cols['PHDPHDPH']!['path'], 'Arsip/PhD');
    expect(cols['QMLQMLQM']!['path'], 'Arsip/PhD/QML');
    expect(cols.containsKey('LAINLAIN'), isFalse, reason: 'koleksi lain tidak ikut');

    expect(
      result.itemFiles.map(p.basename),
      unorderedEquals(<String>['AAAAAAAA.json', 'BBBBBBBB.json']),
    );
    expect(
      result.alsoElsewhere.map(p.basename),
      <String>['BBBBBBBB.json'],
      reason: 'B juga di koleksi Lain: saat memindah, ia hanya dilepas',
    );
    final b = read(tujuan, 'BBBBBBBB');
    expect((b['zotero'] as Map)['collections'], <String>[
      'PHDPHDPH',
    ], reason: 'di tujuan hanya keanggotaan yang ikut pindah');
    expect((b['meta'] as Map)['collections'], <String>['Arsip/PhD']);
    expect(File(p.join(tujuan, 'items', 'CC', 'CCCCCCCC.json')).existsSync(), isFalse);
  });

  test('kunci koleksi yang sudah terpakai di tujuan diberi kunci baru', () async {
    collections(tujuan, <(String, String, String?, String)>[
      ('QMLQMLQM', 'Lain sama sekali', null, 'X'),
    ]);
    final result = await transfer.copyCollection(
      sourceDir: asal,
      targetDir: tujuan,
      collectionKey: 'PHDPHDPH',
      targetParentKey: null,
    );
    final newKey = result.collectionKeys['QMLQMLQM']!;
    expect(newKey, isNot('QMLQMLQM'));
    expect((read(tujuan, 'AAAAAAAA')['zotero'] as Map)['collections'], <String>[newKey]);
  });

  test('koleksi tidak disalin sebagian bila satu PDF belum ada', () async {
    File(p.join(asal, 'attachments', 'PD', 'PDFAAAAA', 'paper.pdf')).deleteSync();
    Directory(p.join(asal, 'attachments', 'PD', 'PDFAAAAA')).deleteSync();
    final before = File(p.join(tujuan, 'collections.json')).readAsStringSync();
    await expectLater(
      transfer.copyCollection(
        sourceDir: asal,
        targetDir: tujuan,
        collectionKey: 'PHDPHDPH',
        targetParentKey: null,
      ),
      throwsA(isA<MissingAttachments>()),
    );
    expect(File(p.join(tujuan, 'collections.json')).readAsStringSync(), before);
    expect(Directory(p.join(tujuan, 'items')).existsSync(), isFalse);
  });
}
