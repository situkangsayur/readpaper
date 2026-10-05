import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/notes/data/notes_store.dart';

/// Catatan pindah ke folder catatan repositori lain.
void main() {
  late Directory root;
  late NotesStore asal;
  late NotesStore tujuan;

  setUp(() {
    root = Directory.systemTemp.createTempSync('rp_catatan_pindah_');
    asal = NotesStore(p.join(root.path, 'asal', 'catatan'));
    tujuan = NotesStore(p.join(root.path, 'tujuan', 'catatan'));
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<String> notebook(String title, {String? collectionKey}) async {
    final source = File(p.join(root.path, '$title.catatan.json'))
      ..writeAsStringSync('{"pages":[]}');
    final item = await asal.addFile(
      sourcePath: source.path,
      title: title,
      collectionKey: collectionKey,
    );
    // Gambar halaman buku catatan hidup di folder yang sama dengan berkasnya.
    final holder = p.dirname(p.join(asal.directory, item.file));
    File(p.join(holder, '$title-berkas', 'halaman-1.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[1, 2, 3]);
    return item.key;
  }

  test('satu catatan: berkas utama dan gambar halamannya ikut', () async {
    final key = await notebook('Kuliah');
    final target = await tujuan.createCollection(name: 'Kuliah 2026');

    final copied = await asal.copyItemTo(
      itemKey: key,
      target: tujuan,
      collectionKeys: <String>[target.key],
    );
    expect(copied.key, key, reason: 'kuncinya dipakai ulang bila belum terpakai');
    final holder = p.dirname(p.join(tujuan.directory, copied.file));
    expect(File(p.join(tujuan.directory, copied.file)).existsSync(), isTrue);
    expect(File(p.join(holder, 'Kuliah-berkas', 'halaman-1.png')).existsSync(), isTrue);
    final index = await tujuan.read();
    expect(index.items.single.collectionKeys, <String>[target.key]);
    expect((await asal.read()).items, hasLength(1), reason: 'asal tidak disentuh');
  });

  test('kunci yang sudah terpakai di tujuan diberi kunci baru', () async {
    final key = await notebook('Rapat');
    await asal.copyItemTo(itemKey: key, target: tujuan);
    final again = await asal.copyItemTo(itemKey: key, target: tujuan);
    expect(again.key, isNot(key));
    expect((await tujuan.read()).items, hasLength(2));
  });

  test('koleksi bersarang beserta catatannya; yang juga di koleksi lain dicatat', () async {
    final phd = await asal.createCollection(name: 'PhD');
    final bab = await asal.createCollection(name: 'Bab 2', parentKey: phd.key);
    final lain = await asal.createCollection(name: 'Lain');
    final a = await notebook('Satu', collectionKey: bab.key);
    final b = await notebook('Dua', collectionKey: phd.key);
    await asal.fileInto(itemKey: b, collectionKey: phd.key);
    // Dua juga anggota "Lain": saat memindah, ia hanya dilepas.
    final index = await asal.read();
    final dua = index.items.firstWhere((i) => i.key == b);
    await File(p.join(asal.directory, 'item', b.substring(0, 2), '$b.json')).writeAsString(
      (await File(
        p.join(asal.directory, 'item', b.substring(0, 2), '$b.json'),
      ).readAsString()).replaceFirst('"${phd.key}"', '"${phd.key}",\n\t\t"${lain.key}"'),
    );
    expect(dua.title, 'Dua');

    final result = await asal.copyCollectionTo(collectionKey: phd.key, target: tujuan);
    expect(result.items, unorderedEquals(<String>[a, b]));
    expect(result.elsewhere, <String>{b});
    final target = await tujuan.read();
    expect(target.collections.map((c) => c.name), unorderedEquals(<String>['PhD', 'Bab 2']));
    final babBaru = target.collections.firstWhere((c) => c.name == 'Bab 2');
    expect(babBaru.parentKey, target.collections.firstWhere((c) => c.name == 'PhD').key);
    expect(target.items.firstWhere((i) => i.title == 'Satu').collectionKeys, <String>[babBaru.key]);
  });

  test('nama koleksi kembar di tujuan ditolak sebelum apa pun ditulis', () async {
    final phd = await asal.createCollection(name: 'PhD');
    await notebook('Satu', collectionKey: phd.key);
    await tujuan.createCollection(name: 'phd');
    await expectLater(
      asal.copyCollectionTo(collectionKey: phd.key, target: tujuan),
      throwsA(anything),
    );
    expect((await tujuan.read()).items, isEmpty);
  });
}
