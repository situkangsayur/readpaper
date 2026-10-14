import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/entities/library_index.dart';
import 'package:readpaper/src/features/library/presentation/controllers/library_controllers.dart';
import 'package:readpaper/src/features/notes/domain/note_entities.dart';
import 'package:readpaper/src/features/notes/presentation/controllers/notes_controller.dart';
import 'package:readpaper/src/features/notes/presentation/widgets/note_list_pane.dart';

class _FakeNotes extends NotesController {
  _FakeNotes(this._index);

  final NotesIndex _index;

  @override
  Future<NotesIndex> build() async => _index;
}

void main() {
  final notes = NotesIndex(
    collections: const <NoteCollection>[
      NoteCollection(key: 'KULIAH01', name: 'Kuliah'),
      NoteCollection(key: 'MLADV001', name: 'ml-adv', parentKey: 'KULIAH01'),
      NoteCollection(key: 'MINGGU01', name: 'minggu-1', parentKey: 'MLADV001'),
    ],
    items: <NoteItem>[
      NoteItem(
        key: 'N1',
        title: 'silabus',
        file: 'silabus.md',
        collectionKeys: const <String>['KULIAH01'],
        dateAdded: DateTime(2026),
        dateModified: DateTime(2026),
      ),
      NoteItem(
        key: 'N2',
        title: 'transformer',
        file: 'transformer.pptx',
        collectionKeys: const <String>['MLADV001'],
        dateAdded: DateTime(2026),
        dateModified: DateTime(2026),
      ),
    ],
    directory: '/tmp/uji/catatan',
  );

  Future<ProviderContainer> pump(WidgetTester tester, LibrarySelection selection) async {
    final container = ProviderContainer(
      overrides: [notesControllerProvider.overrideWith(() => _FakeNotes(notes))],
    );
    addTearDown(container.dispose);
    container.read(selectionProvider.notifier).select(selection);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 420, height: 700, child: NoteListPane())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('sub-koleksi tampil di atas berkas, dan bisa dimasuki lalu kembali', (tester) async {
    final container = await pump(tester, const LibrarySelection.noteCollection('KULIAH01'));

    final folder = tester.getTopLeft(find.text('ml-adv'));
    final file = tester.getTopLeft(find.text('silabus'));
    expect(folder.dy, lessThan(file.dy), reason: 'sub-koleksi di paling atas');
    expect(find.text('1 catatan · 1 sub-koleksi'), findsOneWidget);
    expect(find.text('Kembali ke Catatan'), findsOneWidget);

    await tester.tap(find.text('ml-adv'));
    await tester.pumpAndSettle();
    expect(container.read(selectionProvider), const LibrarySelection.noteCollection('MLADV001'));
    // Di dalam sub-koleksi tampilannya sama: sub-koleksinya lalu berkasnya.
    expect(find.text('minggu-1'), findsOneWidget);
    expect(find.text('transformer'), findsOneWidget);

    await tester.tap(find.text('Kembali ke Kuliah'));
    await tester.pumpAndSettle();
    expect(container.read(selectionProvider), const LibrarySelection.noteCollection('KULIAH01'));
  });

  testWidgets('koleksi yang hanya berisi sub-koleksi tidak disebut kosong', (tester) async {
    await pump(tester, const LibrarySelection.noteCollection('MLADV001'));
    expect(find.text('minggu-1'), findsOneWidget);
  });
}
