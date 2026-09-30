import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/library/data/datasources/zotero_fs_datasource.dart';
import 'package:readpaper/src/features/library/data/datasources/zotero_writer.dart';

void main() {
  late Directory library;

  setUp(() {
    library = Directory.systemTemp.createTempSync('rp_newitem_');
    // Library yang sudah memakai catatan: berkas catatan hanya ditulis kalau
    // memang begitu kebiasaan library itu.
    Directory(p.join(library.path, 'notes')).createSync();
    File(p.join(library.path, 'collections.json')).writeAsStringSync(
      '[\n\t{\n\t\t"key": "COLL0001",\n\t\t"name": "Formulir",\n\t\t"parentKey": null,'
      '\n\t\t"path": "Formulir",\n\t\t"relations": {}\n\t}\n]\n',
    );
  });

  tearDown(() => library.deleteSync(recursive: true));

  String makePdf(String name) {
    final path = p.join(library.parent.path, name);
    File(path).writeAsBytesSync(<int>[
      ...utf8.encode('%PDF-1.4\n'),
      ...List<int>.filled(200, 32),
      ...utf8.encode('\n%%EOF\n'),
    ]);
    return path;
  }

  test('item baru terbaca kembali sebagai bagian library', () async {
    final pdf = makePdf('formulir.pdf');

    final created = await const ZoteroWriter().createItemFromPdf(
      libraryDir: library.path,
      libraryName: 'Library Uji',
      libraryId: 1,
      pdfPath: pdf,
      title: 'Formulir Pendaftaran',
      collectionKey: 'COLL0001',
      collectionPath: 'Formulir',
    );

    // Dibaca ulang lewat jalur yang sama dengan yang dipakai aplikasi:
    // kalau bentuknya salah sedikit saja, di sinilah ketahuannya.
    final index = parseLibrarySync(library.path, 'Library Uji', 'uji', 'user');
    final item = index.items[created.itemKey];

    expect(item, isNotNull, reason: 'item barunya harus ikut terbaca');
    expect(item!.title, 'Formulir Pendaftaran');
    expect(item.attachments, hasLength(1));
    expect(item.attachments.single.key, created.attachmentKey);
    expect(item.collectionKeys, contains('COLL0001'));
  });

  test('berkas PDF-nya benar-benar disalin ke lampiran', () async {
    final pdf = makePdf('formulir.pdf');
    final created = await const ZoteroWriter().createItemFromPdf(
      libraryDir: library.path,
      libraryName: 'Library Uji',
      libraryId: 1,
      pdfPath: pdf,
      title: 'Formulir',
    );

    final attachment = File(created.attachmentPath);
    expect(attachment.existsSync(), isTrue);
    expect(attachment.lengthSync(), File(pdf).lengthSync());
    // Selalu garis miring maju: jalur lampiran adalah bagian dari format
    // Zotero, bukan jalur sistem, dan `p.join` akan memakai `\` di Windows.
    expect(created.attachmentPath, contains('attachments/${created.attachmentKey[0]}'));
  });

  test('berkasnya ditulis dengan tab dan kunci berurut, seperti plugin', () async {
    final created = await const ZoteroWriter().createItemFromPdf(
      libraryDir: library.path,
      libraryName: 'Library Uji',
      libraryId: 1,
      pdfPath: makePdf('a.pdf'),
      title: 'Judul',
    );

    final text = File(created.itemFilePath).readAsStringSync();
    expect(text.contains('\n\t"children"'), isTrue, reason: 'indentasi tab');
    // Urutan kunci teratas: children, meta, zotero.
    expect(text.indexOf('"children"'), lessThan(text.indexOf('"meta"')));
    expect(text.indexOf('"meta"'), lessThan(text.indexOf('"zotero"')));
    expect(text.endsWith('\n'), isTrue);
  });

  test('tanpa koleksi pun tetap sah', () async {
    final created = await const ZoteroWriter().createItemFromPdf(
      libraryDir: library.path,
      libraryName: 'Library Uji',
      libraryId: 1,
      pdfPath: makePdf('lepas.pdf'),
      title: 'Lepas',
    );

    final index = parseLibrarySync(library.path, 'Library Uji', 'uji', 'user');
    expect(index.items[created.itemKey]!.collectionKeys, isEmpty);
    expect(index.unfiledItemKeys, contains(created.itemKey));
  });

  test('catatan pendamping ditulis kalau library memakainya', () async {
    final created = await const ZoteroWriter().createItemFromPdf(
      libraryDir: library.path,
      libraryName: 'Library Uji',
      libraryId: 1,
      pdfPath: makePdf('b.pdf'),
      title: 'Catatan Rapat',
    );

    final note = created.touchedFiles.where((f) => f.endsWith('.md')).singleOrNull;
    expect(note, isNotNull);
    final text = File(note!).readAsStringSync();
    expect(text, contains('zotero-key: "${created.itemKey}"'));
    expect(text, contains('## Attachments'));
  });

  test('library tanpa folder catatan tidak tiba-tiba punya catatan', () async {
    Directory(p.join(library.path, 'notes')).deleteSync(recursive: true);
    final created = await const ZoteroWriter().createItemFromPdf(
      libraryDir: library.path,
      libraryName: 'Library Uji',
      libraryId: 1,
      pdfPath: makePdf('c.pdf'),
      title: 'Tanpa Catatan',
    );
    expect(created.touchedFiles.where((f) => f.endsWith('.md')), isEmpty);
  });

  test('PDF yang tidak ada dilaporkan, dan tidak meninggalkan item', () async {
    await expectLater(
      const ZoteroWriter().createItemFromPdf(
        libraryDir: library.path,
        libraryName: 'Library Uji',
        libraryId: 1,
        pdfPath: p.join(library.parent.path, 'entah.pdf'),
        title: 'Hantu',
      ),
      throwsA(isA<Exception>()),
    );
    expect(Directory(p.join(library.path, 'items')).existsSync(), isFalse);
  });

  group('menghapus item', () {
    test('hanya berkas milik item itu yang hilang', () async {
      final tetap = await const ZoteroWriter().createItemFromPdf(
        libraryDir: library.path,
        libraryName: 'Library Uji',
        libraryId: 1,
        pdfPath: makePdf('tetap.pdf'),
        title: 'Yang Tetap',
        collectionKey: 'COLL0001',
        collectionPath: 'Formulir',
      );
      final dibuang = await const ZoteroWriter().createItemFromPdf(
        libraryDir: library.path,
        libraryName: 'Library Uji',
        libraryId: 1,
        pdfPath: makePdf('buang.pdf'),
        title: 'Yang Dibuang',
      );

      await const ZoteroWriter().deleteItem(
        libraryDir: library.path,
        itemFilePath: dibuang.itemFilePath,
      );

      // Yang dihapus benar-benar hilang...
      expect(File(dibuang.itemFilePath).existsSync(), isFalse);
      expect(File(dibuang.attachmentPath).existsSync(), isFalse);

      // ...dan tidak ada yang lain ikut terbawa.
      expect(File(tetap.itemFilePath).existsSync(), isTrue);
      expect(File(tetap.attachmentPath).existsSync(), isTrue);
      expect(File(p.join(library.path, 'collections.json')).existsSync(), isTrue);

      final index = parseLibrarySync(library.path, 'Library Uji', 'uji', 'user');
      expect(index.items.keys, <String>[tetap.itemKey]);
      expect(index.collections['COLL0001'], isNotNull);
    });

    test('menolak jalur di luar items/', () async {
      // Pagar yang menjaga `collections.json` dan akar library: satu jalur
      // yang meleset di sini berarti paper orang yang hilang.
      await expectLater(
        const ZoteroWriter().deleteItem(
          libraryDir: library.path,
          itemFilePath: p.join(library.path, 'collections.json'),
        ),
        throwsA(isA<Exception>()),
      );
      expect(File(p.join(library.path, 'collections.json')).existsSync(), isTrue);
    });

    test('menolak berkas di luar library sama sekali', () async {
      final luar = File(p.join(library.parent.path, 'luar.json'))..writeAsStringSync('{}');
      await expectLater(
        const ZoteroWriter().deleteItem(
          libraryDir: library.path,
          itemFilePath: luar.path,
        ),
        throwsA(isA<Exception>()),
      );
      expect(luar.existsSync(), isTrue);
      luar.deleteSync();
    });

    test('catatan pendampingnya ikut dihapus', () async {
      final created = await const ZoteroWriter().createItemFromPdf(
        libraryDir: library.path,
        libraryName: 'Library Uji',
        libraryId: 1,
        pdfPath: makePdf('d.pdf'),
        title: 'Berkatatan',
      );
      final note = created.touchedFiles.firstWhere((f) => f.endsWith('.md'));
      expect(File(note).existsSync(), isTrue);

      await const ZoteroWriter().deleteItem(
        libraryDir: library.path,
        itemFilePath: created.itemFilePath,
      );
      expect(File(note).existsSync(), isFalse);
    });
  });
}
