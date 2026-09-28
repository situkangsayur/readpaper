import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/library/data/datasources/zotero_writer.dart';

void main() {
  late Directory library;

  /// Dua koleksi seperti yang ditulis plugin: array beridentasi tab, kunci
  /// terurut, `parentKey: null` untuk akar, `relations: {}`.
  const asli = '[\n'
      '\t{\n'
      '\t\t"key": "EUVLSS2L",\n'
      '\t\t"name": "Astri",\n'
      '\t\t"parentKey": null,\n'
      '\t\t"path": "Astri",\n'
      '\t\t"relations": {}\n'
      '\t},\n'
      '\t{\n'
      '\t\t"key": "BCLHT7HV",\n'
      '\t\t"name": "PhD",\n'
      '\t\t"parentKey": null,\n'
      '\t\t"path": "PhD",\n'
      '\t\t"relations": {\n'
      '\t\t\t"mendeleyDB:remoteFolderUUID": [\n'
      '\t\t\t\t"4fcb2c3e-8383-4b58-b450-5474c5811345"\n'
      '\t\t\t]\n'
      '\t\t}\n'
      '\t}\n'
      ']\n';

  setUp(() {
    library = Directory.systemTemp.createTempSync('rp-koleksi-');
    File(p.join(library.path, 'collections.json')).writeAsStringSync(asli);
  });
  tearDown(() => library.deleteSync(recursive: true));

  String raw() => File(p.join(library.path, 'collections.json')).readAsStringSync();

  test('koleksi baru ditambahkan di ujung, yang lama tidak disentuh', () async {
    // Ini satu-satunya berkas struktur Zotero yang ditulisi ReadPaper: yang
    // sudah ada harus keluar byte-for-byte sama, supaya diff-nya cuma satu blok.
    final created = await const ZoteroWriter().createCollection(
      libraryDir: library.path,
      name: 'Kriptografi',
    );

    expect(created.name, 'Kriptografi');
    expect(created.path, 'Kriptografi');
    expect(created.parentKey, isNull);
    expect(created.key, hasLength(8));

    final after = raw();
    // Bagian awal berkasnya — dua koleksi lama — tidak berubah sedikit pun.
    expect(after.startsWith(asli.substring(0, asli.lastIndexOf('\t}\n]'))), isTrue);
    expect(after, contains('"name": "Kriptografi"'));
    expect(after.indexOf('Kriptografi'), greaterThan(after.indexOf('PhD')));
    expect(after.endsWith('\n'), isTrue);
  });

  test('bentuk tulisannya sama seperti plugin: tab, kunci terurut', () async {
    await const ZoteroWriter().createCollection(libraryDir: library.path, name: 'Baru');
    final after = raw();

    expect(after, contains('\n\t{\n\t\t"key": '));
    final decoded = jsonDecode(after) as List;
    final entry = (decoded.last as Map).cast<String, dynamic>();
    expect(entry.keys.toList(), <String>['key', 'name', 'parentKey', 'path', 'relations']);
    expect(entry['relations'], isEmpty);
    expect(entry['parentKey'], isNull);
  });

  test('sub-koleksi mewarisi jalur induknya', () async {
    final created = await const ZoteroWriter().createCollection(
      libraryDir: library.path,
      name: 'Tesis',
      parentKey: 'BCLHT7HV',
    );
    expect(created.parentKey, 'BCLHT7HV');
    expect(created.path, 'PhD/Tesis');

    final dalam = await const ZoteroWriter().createCollection(
      libraryDir: library.path,
      name: 'Bab 1',
      parentKey: created.key,
    );
    expect(dalam.path, 'PhD/Tesis/Bab 1');
  });

  test('koleksi lama tetap bisa dibaca setelah ditambah', () async {
    await const ZoteroWriter().createCollection(libraryDir: library.path, name: 'Tambahan');
    final decoded = jsonDecode(raw()) as List;
    expect(decoded, hasLength(3));
    expect(
      (decoded.first as Map)['relations'],
      isEmpty,
      reason: 'koleksi tanpa relasi tetap tanpa relasi',
    );
    expect(
      ((decoded[1] as Map)['relations'] as Map).keys.single,
      'mendeleyDB:remoteFolderUUID',
      reason: 'relasi Mendeley yang sudah ada tidak hilang',
    );
  });

  group('yang ditolak', () {
    test('nama kosong', () {
      expect(
        const ZoteroWriter().createCollection(libraryDir: library.path, name: '  '),
        throwsA(isA<Exception>()),
      );
    });

    test('nama bergaris miring — itu pemisah jalur di berkas ini', () {
      expect(
        const ZoteroWriter().createCollection(libraryDir: library.path, name: 'A/B'),
        throwsA(isA<Exception>()),
      );
    });

    test('nama kembar di bawah induk yang sama', () async {
      await expectLater(
        const ZoteroWriter().createCollection(libraryDir: library.path, name: 'astri'),
        throwsA(
          predicate((Object e) => e.toString().contains('Sudah ada'), 'menyebut sebabnya'),
        ),
      );
      // Nama yang sama di bawah induk berbeda tetap boleh.
      final ok = await const ZoteroWriter().createCollection(
        libraryDir: library.path,
        name: 'Astri',
        parentKey: 'BCLHT7HV',
      );
      expect(ok.path, 'PhD/Astri');
    });

    test('induk yang tidak ada', () {
      expect(
        const ZoteroWriter().createCollection(
          libraryDir: library.path,
          name: 'X',
          parentKey: 'TIDAKADA',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('berkas yang isinya bukan daftar koleksi', () async {
      File(p.join(library.path, 'collections.json')).writeAsStringSync('{"bukan":"daftar"}');
      await expectLater(
        const ZoteroWriter().createCollection(libraryDir: library.path, name: 'X'),
        throwsA(
          predicate((Object e) => e.toString().contains('menolak'), 'menolak menulisinya'),
        ),
      );
    });

    test('library yang belum punya collections.json boleh dimulai', () async {
      File(p.join(library.path, 'collections.json')).deleteSync();
      final created = await const ZoteroWriter().createCollection(
        libraryDir: library.path,
        name: 'Pertama',
      );
      expect(created.path, 'Pertama');
      expect(jsonDecode(raw()), hasLength(1));
    });
  });
}
