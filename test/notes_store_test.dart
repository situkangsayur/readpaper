import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/library/domain/entities/library_index.dart';
import 'package:readpaper/src/features/notes/data/notes_store.dart';
import 'package:readpaper/src/features/notes/domain/note_target.dart';

void main() {
  late Directory repo;
  late NotesStore store;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('readpaper-catatan-');
    store = NotesStore(NotesStore.directoryFor(repo.path));
  });

  tearDown(() => repo.deleteSync(recursive: true));

  /// Sebuah berkas yang pantas jadi catatan.
  File sample(String name, [String body = 'catatan']) {
    final file = File(p.join(repo.path, name))..writeAsStringSync(body);
    return file;
  }

  group('tempat catatan', () {
    test('foldernya di luar struktur Zotero', () {
      // Inilah sebabnya seluruh kelas ini ada: berkas di dalam `zotero/`
      // ditulis byte-for-byte oleh plugin, dan catatan tidak punya
      // bibliografi. Kalau jalurnya pernah masuk ke sana, ekspor Zotero yang
      // jadi taruhannya.
      expect(p.basename(store.directory), 'catatan');
      expect(p.isWithin(p.join(repo.path, 'zotero'), store.directory), isFalse);
    });

    test('folder yang belum ada berarti kosong, bukan galat', () async {
      final index = await store.read();
      expect(index.isEmpty, isTrue);
      expect(Directory(store.directory).existsSync(), isFalse);
    });
  });

  group('koleksi', () {
    test('dibuat, dibaca ulang, dan bersarang', () async {
      final atas = await store.createCollection(name: 'Kuliah');
      final bawah = await store.createCollection(name: 'Semester 1', parentKey: atas.key);

      final index = await store.read();
      expect(index.childrenOf(null).map((c) => c.name), <String>['Kuliah']);
      expect(index.childrenOf(atas.key).map((c) => c.name), <String>['Semester 1']);
      expect(bawah.parentKey, atas.key);
    });

    test('nama kosong ditolak', () {
      expect(store.createCollection(name: '   '), throwsA(isA<Exception>()));
    });

    test('ganti nama tidak mengubah kunci', () async {
      final made = await store.createCollection(name: 'Rapat');
      await store.renameCollection(key: made.key, name: 'Rapat Tim');
      final index = await store.read();
      expect(index.collections.single.key, made.key);
      expect(index.collections.single.name, 'Rapat Tim');
    });

    test('menghapus koleksi tidak menghapus catatannya', () async {
      final made = await store.createCollection(name: 'Sementara');
      final note = await store.addFile(
        sourcePath: sample('rapat.md').path,
        title: 'Rapat',
        collectionKey: made.key,
      );

      await store.deleteCollection(made.key);
      final index = await store.read();

      expect(index.collections, isEmpty);
      expect(index.items.single.key, note.key);
      expect(index.unfiled.single.key, note.key, reason: 'pindah ke tanpa koleksi');
      expect(File(store.absolutePathOf(index.items.single)).existsSync(), isTrue);
    });

    test('keturunan ikut terbuang saat induknya dihapus', () async {
      final atas = await store.createCollection(name: 'Kuliah');
      final tengah = await store.createCollection(name: 'Semester 1', parentKey: atas.key);
      await store.createCollection(name: 'Aljabar', parentKey: tengah.key);

      await store.deleteCollection(atas.key);
      expect((await store.read()).collections, isEmpty);
    });

    test('koleksi yatim dikembalikan ke akar, tidak hilang', () async {
      final atas = await store.createCollection(name: 'Kuliah');
      final bawah = await store.createCollection(name: 'Semester 1', parentKey: atas.key);

      // Induknya dicoret langsung dari berkas — seperti hasil merge git yang
      // meleset. Anaknya tidak boleh lenyap dari pohon tanpa jejak.
      final file = File(p.join(store.directory, 'koleksi.json'));
      final kept = (jsonDecode(file.readAsStringSync()) as List)
          .where((e) => (e as Map)['key'] == bawah.key)
          .toList();
      file.writeAsStringSync(jsonEncode(kept));

      final index = await store.read();
      expect(index.childrenOf(null).map((c) => c.name), <String>['Semester 1']);
      expect(index.collections.single.parentKey, isNull);
      expect(atas.key, isNot(bawah.key));
    });
  });

  group('catatan', () {
    test('berkasnya disalin ke dalam repositori', () async {
      final source = sample('coretan.pdf', 'isi');
      final note = await store.addFile(sourcePath: source.path, title: 'Coretan');

      final target = File(store.absolutePathOf(note));
      expect(target.existsSync(), isTrue);
      expect(p.isWithin(p.join(store.directory, 'berkas'), target.path), isTrue);
      expect(target.readAsStringSync(), 'isi');

      // Disalin, bukan dirujuk: berkas asal boleh hilang.
      source.deleteSync();
      expect(File(store.absolutePathOf((await store.read()).items.single)).existsSync(), isTrue);
    });

    test('bertahan setelah dibaca ulang', () async {
      final koleksi = await store.createCollection(name: 'Rapat');
      await store.addFile(
        sourcePath: sample('senin.md').path,
        title: 'Rapat Senin',
        collectionKey: koleksi.key,
      );

      final index = await store.read();
      expect(index.items.single.title, 'Rapat Senin');
      expect(index.inCollection(koleksi.key), hasLength(1));
      expect(index.countIn(koleksi.key), 1);
      expect(index.items.single.isMarkdown, isTrue);
    });

    test('hitungan koleksi mencakup keturunannya', () async {
      final atas = await store.createCollection(name: 'Kuliah');
      final bawah = await store.createCollection(name: 'Semester 1', parentKey: atas.key);
      await store.addFile(sourcePath: sample('a.md').path, title: 'A', collectionKey: bawah.key);

      final index = await store.read();
      expect(index.countIn(atas.key), 1);
      expect(index.inCollection(atas.key), isEmpty, reason: 'langsung saja, tanpa keturunan');
    });

    test('dipindahkan antar koleksi', () async {
      final satu = await store.createCollection(name: 'Satu');
      final dua = await store.createCollection(name: 'Dua');
      final note = await store.addFile(
        sourcePath: sample('pindah.md').path,
        title: 'Pindah',
        collectionKey: satu.key,
      );

      await store.fileInto(itemKey: note.key, collectionKey: dua.key);
      var index = await store.read();
      expect(index.inCollection(satu.key), isEmpty);
      expect(index.inCollection(dua.key), hasLength(1));

      await store.fileInto(itemKey: note.key);
      index = await store.read();
      expect(index.unfiled, hasLength(1));
    });

    test('dihapus beserta berkasnya', () async {
      final note = await store.addFile(sourcePath: sample('buang.md').path, title: 'Buang');
      final file = File(store.absolutePathOf(note));
      expect(file.existsSync(), isTrue);

      await store.deleteItem(note.key);
      expect(file.existsSync(), isFalse);
      expect(file.parent.existsSync(), isFalse, reason: 'folder kosong tidak ditinggalkan');
      expect((await store.read()).items, isEmpty);
    });

    test('koleksi tujuan yang tidak ada ditolak', () {
      expect(
        store.addFile(sourcePath: sample('x.md').path, title: 'X', collectionKey: 'TIDAKADA'),
        throwsA(isA<Exception>()),
      );
    });

    test('berkas yang tidak ada ditolak', () {
      expect(
        store.addFile(sourcePath: p.join(repo.path, 'hantu.md'), title: 'Hantu'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('bentuk di disk', () {
    test('JSON beridentasi tab dengan kunci terurut, seperti di sebelah', () async {
      final note = await store.addFile(sourcePath: sample('bentuk.md').path, title: 'Bentuk');
      final raw = File(
        p.join(store.directory, 'item', note.key.substring(0, 2), '${note.key}.json'),
      ).readAsStringSync();

      expect(raw, contains('\n\t"'));
      expect(raw.endsWith('\n'), isTrue);
      final keys = (jsonDecode(raw) as Map).keys.toList();
      expect(keys, List<String>.from(keys)..sort());
    });

    test('jalur berkas dicatat relatif, dengan garis miring maju', () async {
      final note = await store.addFile(sourcePath: sample('relatif.md').path, title: 'R');
      expect(note.file.startsWith('berkas/'), isTrue);
      expect(note.file.contains('\\'), isFalse);
    });
  });

  group('aturan akar', () {
    test('akar paper menolak catatan, dengan penjelasan', () {
      for (final selection in <LibrarySelection>[
        const LibrarySelection.all(),
        const LibrarySelection.unfiled(),
        const LibrarySelection.collection('ABCD1234'),
      ]) {
        final target = NoteTarget.of(selection);
        expect(target.isAllowed, isFalse);
        expect(target.refusal, contains('akar "Catatan"'));
        expect(target.refusal, contains('Zotero'), reason: 'sebabnya ikut disebut');
      }
    });

    test('akar catatan menerima, dan menyerahkan koleksinya', () {
      expect(NoteTarget.of(const LibrarySelection.notes()).isAllowed, isTrue);
      expect(NoteTarget.of(const LibrarySelection.notes()).collectionKey, isNull);
      expect(NoteTarget.of(const LibrarySelection.notesUnfiled()).isAllowed, isTrue);

      final target = NoteTarget.of(const LibrarySelection.noteCollection('KOLEKSI1'));
      expect(target.isAllowed, isTrue);
      expect(target.collectionKey, 'KOLEKSI1');
    });
  });
}
