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
    expect(created.attachmentPath, contains(p.join('attachments', created.attachmentKey[0])));
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
}
