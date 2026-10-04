import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/errors/failure.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_json.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_writer.dart';

/// Ganti nama, pindah, dan hapus koleksi paper — struktur yang harus tetap
/// terbaca plugin dan aplikasi Zotero.
void main() {
  late Directory library;
  const writer = ZoteroWriter();

  Map<String, Object?> col(String key, String name, String? parent, String path) =>
      <String, Object?>{
        'key': key,
        'name': name,
        'parentKey': parent,
        'path': path,
        'relations': <String, Object?>{},
      };

  void item(String key, List<String> keys, List<String> paths) {
    File(p.join(library.path, 'items', key.substring(0, 2), '$key.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        ZoteroJson.encodeFile(<String, dynamic>{
          'meta': <String, dynamic>{'collections': paths, 'title': key},
          'zotero': <String, dynamic>{
            'key': key,
            'collections': keys,
            'dateModified': '2026-01-01T00:00:00Z',
          },
        }),
      );
  }

  Map<String, dynamic> readItem(String key) => ZoteroJson.decodeObject(
    File(p.join(library.path, 'items', key.substring(0, 2), '$key.json')).readAsStringSync(),
  );

  List<Map<String, dynamic>> collections() =>
      (jsonDecode(File(p.join(library.path, 'collections.json')).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  setUp(() {
    library = Directory.systemTemp.createTempSync('rp-ubah-koleksi-');
    File(p.join(library.path, 'collections.json')).writeAsStringSync(
      '${const JsonEncoder.withIndent('\t').convert(ZoteroJson.sortKeys(<Object?>[col('PHDPHDPH', 'PhD', null, 'PhD'), col('QMLQMLQM', 'QML', 'PHDPHDPH', 'PhD/QML'), col('GNNGNNGN', 'GNN', 'QMLQMLQM', 'PhD/QML/GNN'), col('LAINLAIN', 'Lain', null, 'Lain')]))}\n',
    );
    item('AAAAAAAA', <String>['GNNGNNGN'], <String>['PhD/QML/GNN']);
    item('BBBBBBBB', <String>['QMLQMLQM', 'LAINLAIN'], <String>['PhD/QML', 'Lain']);
    item('CCCCCCCC', <String>['LAINLAIN'], <String>['Lain']);
  });
  tearDown(() => library.deleteSync(recursive: true));

  test('ganti nama: jalur keturunan dan item ikut, keanggotaan Zotero tetap', () async {
    final before = File(p.join(library.path, 'items', 'CC', 'CCCCCCCC.json')).readAsStringSync();
    await writer.renameCollection(libraryDir: library.path, key: 'QMLQMLQM', name: 'Quantum ML');

    final byKey = {for (final c in collections()) c['key']: c};
    expect(byKey['QMLQMLQM']!['path'], 'PhD/Quantum ML');
    expect(byKey['GNNGNNGN']!['path'], 'PhD/Quantum ML/GNN');
    expect(byKey['QMLQMLQM']!['relations'], isEmpty, reason: 'relations dipertahankan');

    final a = readItem('AAAAAAAA');
    expect((a['meta'] as Map)['collections'], <String>['PhD/Quantum ML/GNN']);
    expect((a['zotero'] as Map)['collections'], <String>['GNNGNNGN']);
    expect(
      (a['zotero'] as Map)['dateModified'],
      '2026-01-01T00:00:00Z',
      reason: 'keanggotaan di Zotero tidak berubah, jadi itemnya tidak dianggap diubah',
    );
    expect(
      File(p.join(library.path, 'items', 'CC', 'CCCCCCCC.json')).readAsStringSync(),
      before,
      reason: 'item yang tidak tersentuh tidak ditulis ulang',
    );
    expect(
      File(p.join(library.path, 'collections.json')).readAsStringSync(),
      contains('\t\t"name": "Quantum ML",'),
      reason: 'format plugin: identasi tab, kunci terurut',
    );
  });

  test('nama kembar, kosong, atau bergaris miring ditolak', () async {
    for (final name in <String>['lain', '  ', 'a/b']) {
      await expectLater(
        writer.renameCollection(libraryDir: library.path, key: 'PHDPHDPH', name: name),
        throwsA(isA<LibraryFailure>()),
        reason: name,
      );
    }
  });

  test('pindah: ke akar, dan tidak ke dalam keturunannya sendiri', () async {
    await expectLater(
      writer.moveCollection(libraryDir: library.path, key: 'PHDPHDPH', newParentKey: 'GNNGNNGN'),
      throwsA(isA<LibraryFailure>()),
    );
    await writer.moveCollection(libraryDir: library.path, key: 'GNNGNNGN', newParentKey: null);
    final gnn = collections().firstWhere((c) => c['key'] == 'GNNGNNGN');
    expect(gnn['parentKey'], isNull);
    expect(gnn['path'], 'GNN');
    expect((readItem('AAAAAAAA')['meta'] as Map)['collections'], <String>['GNN']);
  });

  test('hapus beserta sub-koleksi: item tetap ada, hanya dilepas', () async {
    final reach = await writer.collectionReach(library.path, 'QMLQMLQM');
    expect(reach.children, 1);
    expect(reach.items, 2);

    await writer.deleteCollection(libraryDir: library.path, key: 'QMLQMLQM', withChildren: true);
    expect(collections().map((c) => c['key']), <String>[
      'PHDPHDPH',
      'LAINLAIN',
    ], reason: 'urutan yang ada tidak diubah, supaya diff-nya kecil');

    final a = readItem('AAAAAAAA');
    expect((a['zotero'] as Map)['collections'], isEmpty);
    expect((a['meta'] as Map)['collections'], isEmpty);
    expect((a['zotero'] as Map)['dateModified'], isNot('2026-01-01T00:00:00Z'));
    final b = readItem('BBBBBBBB');
    expect((b['zotero'] as Map)['collections'], <String>['LAINLAIN']);
    expect((b['meta'] as Map)['collections'], <String>['Lain']);
  });

  test('hapus tanpa sub-koleksi: anaknya naik satu tingkat', () async {
    await writer.deleteCollection(libraryDir: library.path, key: 'QMLQMLQM', withChildren: false);
    final gnn = collections().firstWhere((c) => c['key'] == 'GNNGNNGN');
    expect(gnn['parentKey'], 'PHDPHDPH');
    expect(gnn['path'], 'PhD/GNN');
    final a = readItem('AAAAAAAA');
    expect((a['zotero'] as Map)['collections'], <String>['GNNGNNGN']);
    expect((a['meta'] as Map)['collections'], <String>['PhD/GNN']);
  });
}
