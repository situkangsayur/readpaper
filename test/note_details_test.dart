import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/library/domain/entities/library_index.dart';
import 'package:readpaper/src/features/library/presentation/controllers/library_controllers.dart';
import 'package:readpaper/src/features/notes/data/notes_store.dart';
import 'package:readpaper/src/features/notes/domain/note_entities.dart';
import 'package:readpaper/src/features/notes/presentation/controllers/notes_controller.dart';
import 'package:readpaper/src/features/notes/presentation/widgets/note_detail_pane.dart';
import 'package:readpaper/src/features/notes/presentation/widgets/note_list_pane.dart';

/// Catatan punya keterangan sendiri — penulis, tanggal, tag, sumber, uraian —
/// dan mengetuknya menampilkan keterangan itu, bukan langsung membukanya.
class _FakeNotes extends NotesController {
  _FakeNotes(this._index);

  NotesIndex _index;
  Map<String, Object?>? saved;

  @override
  Future<NotesIndex> build() async => _index;

  @override
  Future<String?> updateDetails({
    required String itemKey,
    required String title,
    List<String> authors = const <String>[],
    String date = '',
    List<String> tags = const <String>[],
    String source = '',
    String description = '',
  }) async {
    saved = <String, Object?>{
      'title': title,
      'authors': authors,
      'date': date,
      'tags': tags,
      'source': source,
    };
    _index = NotesIndex(
      collections: _index.collections,
      items: <NoteItem>[
        for (final n in _index.items)
          n.key == itemKey
              ? n.copyWith(
                  title: title,
                  authors: authors.where((a) => a.trim().isNotEmpty).map((a) => a.trim()).toList(),
                  date: date,
                  tags: tags.where((t) => t.trim().isNotEmpty).map((t) => t.trim()).toList(),
                  source: source,
                )
              : n,
      ],
      directory: _index.directory,
    );
    state = AsyncValue<NotesIndex>.data(_index);
    return itemKey;
  }
}

void main() {
  test('keterangan kosong tidak ditulis, yang terisi terbaca kembali', () {
    final bare = NoteItem(
      key: 'N1',
      title: 'silabus',
      file: 'silabus.md',
      dateAdded: DateTime.utc(2026),
      dateModified: DateTime.utc(2026),
    );
    expect(bare.toJson().keys, isNot(contains('authors')));
    expect(bare.toJson().keys, isNot(contains('tags')));

    final full = bare.copyWith(
      authors: <String>['Bishop, C. M.'],
      date: 'Minggu 3',
      tags: <String>['ml', 'attention'],
      source: 'https://example.org/kuliah',
      description: 'Self-attention',
    );
    final back = NoteItem.fromJson(jsonDecode(jsonEncode(full.toJson())) as Map<String, dynamic>);
    expect(back.authors, <String>['Bishop, C. M.']);
    expect(back.date, 'Minggu 3');
    expect(back.tags, <String>['ml', 'attention']);
    expect(back.source, 'https://example.org/kuliah');
    expect(back.description, 'Self-attention');
    expect(back.hasDetails, isTrue);
  });

  test('store menyimpan keterangan dan merapikan isian', () async {
    final root = Directory.systemTemp.createTempSync('rp_ket_');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = NotesStore(p.join(root.path, 'catatan'));
    final source = File(p.join(root.path, 'kuliah.pptx'))..writeAsStringSync('x');
    final note = await store.addFile(sourcePath: source.path, title: 'kuliah');

    await store.updateDetails(
      itemKey: note.key,
      title: '  Kuliah 1  ',
      authors: <String>['Dr. A', '', 'Dr. A', ' Dr. B '],
      tags: <String>[' ml', '', 'ml'],
      date: ' 14 Okt 2026 ',
    );
    final read = (await store.read()).items.single;
    expect(read.title, 'Kuliah 1');
    expect(read.authors, <String>['Dr. A', 'Dr. B']);
    expect(read.tags, <String>['ml']);
    expect(read.date, '14 Okt 2026');
    expect(read.file, note.file, reason: 'berkasnya tidak ikut berubah');
  });

  final notes = NotesIndex(
    collections: const <NoteCollection>[NoteCollection(key: 'KULIAH01', name: 'Kuliah')],
    items: <NoteItem>[
      NoteItem(
        key: 'N2',
        title: 'transformer',
        file: 'transformer.pptx',
        collectionKeys: const <String>['KULIAH01'],
        dateAdded: DateTime(2026),
        dateModified: DateTime(2026),
      ),
    ],
    directory: '/tmp/uji/catatan',
  );

  testWidgets('ketuk catatan menampilkan keterangannya, dan keterangannya bisa diubah', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeNotes(notes);
    final container = ProviderContainer(overrides: [notesControllerProvider.overrideWith(() => fake)]);
    addTearDown(container.dispose);
    container.read(selectionProvider.notifier).select(const LibrarySelection.noteCollection('KULIAH01'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                SizedBox(width: 420, child: NoteListPane()),
                Expanded(child: NoteDetailPane()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih catatan untuk melihat keterangannya.'), findsOneWidget);

    await tester.tap(find.text('transformer'));
    await tester.pumpAndSettle();
    expect(container.read(selectedNoteKeyProvider), 'N2');
    expect(find.byType(NoteDetailPane), findsOneWidget);
    expect(find.text('transformer.pptx'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Buka'), findsOneWidget);
    expect(find.textContaining('Belum ada keterangan'), findsOneWidget);

    await tester.tap(find.text('Tambah keterangan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Penulis / pengajar'), 'Dr. A\nDr. B');
    await tester.enterText(find.widgetWithText(TextField, 'Tag'), 'ml, attention');
    await tester.enterText(find.widgetWithText(TextField, 'Tanggal'), 'Minggu 3');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(fake.saved!['authors'], <String>['Dr. A', 'Dr. B']);
    expect(fake.saved!['tags'], <String>['ml', ' attention']);
    expect(find.text('Dr. A; Dr. B'), findsOneWidget);
    expect(find.text('attention'), findsOneWidget);
    expect(find.text('Minggu 3'), findsOneWidget);

    // Pindah koleksi: keterangan catatan dari daftar sebelumnya ditutup.
    container.read(selectionProvider.notifier).select(const LibrarySelection.notes());
    await tester.pumpAndSettle();
    expect(container.read(selectedNoteKeyProvider), isNull);
  });
}
