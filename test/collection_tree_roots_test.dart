import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/entities/library_index.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_collection.dart';
import 'package:readpaper/src/features/library/presentation/controllers/library_controllers.dart';
import 'package:readpaper/src/features/library/presentation/widgets/collection_tree_pane.dart';
import 'package:readpaper/src/features/notes/domain/note_entities.dart';
import 'package:readpaper/src/features/notes/presentation/controllers/notes_controller.dart';
import 'package:readpaper/src/features/workspace/domain/entities/workspace_state.dart';
import 'package:readpaper/src/features/workspace/presentation/controllers/workspace_controller.dart';

/// Ruang kerja yang sudah berisi satu library, tanpa menyentuh disk.
class _FakeWorkspace extends WorkspaceController {
  _FakeWorkspace(this._state);

  final WorkspaceState _state;

  @override
  WorkspaceState build() => _state;
}

class _FakeNotes extends NotesController {
  _FakeNotes(this._index);

  final NotesIndex _index;

  @override
  Future<NotesIndex> build() async => _index;
}

void main() {
  LibraryIndex libraryWith(List<ZoteroCollection> collections) {
    final nodes = <String, CollectionNode>{
      for (final c in collections) c.key: CollectionNode(collection: c),
    };
    final roots = <CollectionNode>[];
    for (final c in collections) {
      final node = nodes[c.key]!;
      final parent = c.parentKey == null ? null : nodes[c.parentKey];
      if (parent == null) {
        roots.add(node);
      } else {
        parent.children.add(node);
      }
    }
    return LibraryIndex(
      library: const LibraryRef(
        name: 'Library Uji',
        directoryName: 'my-library',
        directoryPath: '/tmp/uji/zotero/my-library',
      ),
      collections: <String, ZoteroCollection>{for (final c in collections) c.key: c},
      roots: roots,
      items: const <String, dynamic>{}.cast(),
      itemsByCollection: const <String, List<String>>{},
      unfiledItemKeys: const <String>[],
      builtAt: DateTime(2026),
    );
  }

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required LibraryIndex index,
    required NotesIndex notes,
  }) async {
    final container = ProviderContainer(
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => _FakeWorkspace(WorkspaceState(index: index)),
        ),
        notesControllerProvider.overrideWith(() => _FakeNotes(notes)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 320, height: 600, child: CollectionTreePane())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  NotesIndex notesWith(List<NoteCollection> collections, {List<NoteItem> items = const []}) =>
      NotesIndex(collections: collections, items: items, directory: '/tmp/uji/catatan');

  testWidgets('pohonnya punya dua akar: paper dan catatan', (tester) async {
    await pump(
      tester,
      index: libraryWith(<ZoteroCollection>[
        const ZoteroCollection(key: 'PAPER001', name: 'Kriptografi', path: 'Kriptografi'),
      ]),
      notes: notesWith(<NoteCollection>[
        const NoteCollection(key: 'CATATAN1', name: 'Rapat'),
      ]),
    );

    // Akar paper memakai nama library-nya, akar catatan bernama "Catatan".
    expect(find.text('Library Uji'), findsWidgets);
    expect(find.text('Catatan'), findsOneWidget);
    // Keduanya terbuka sejak awal, jadi isi masing-masing ikut terlihat.
    expect(find.text('Kriptografi'), findsOneWidget);
    expect(find.text('Rapat'), findsOneWidget);
  });

  testWidgets('memilih koleksi catatan melepas koleksi paper', (tester) async {
    final container = await pump(
      tester,
      index: libraryWith(<ZoteroCollection>[
        const ZoteroCollection(key: 'PAPER001', name: 'Kriptografi', path: 'Kriptografi'),
      ]),
      notes: notesWith(<NoteCollection>[
        const NoteCollection(key: 'CATATAN1', name: 'Rapat'),
      ]),
    );

    await tester.tap(find.text('Kriptografi'));
    await tester.pump();
    expect(container.read(selectionProvider).kind, SelectionKind.collection);
    expect(container.read(selectionProvider).isNotes, isFalse);

    await tester.tap(find.text('Rapat'));
    await tester.pump();
    final selection = container.read(selectionProvider);
    expect(selection.kind, SelectionKind.noteCollection);
    expect(selection.collectionKey, 'CATATAN1');
    expect(selection.isNotes, isTrue, reason: 'satu pilihan untuk dua akar');
  });

  testWidgets('akar catatan yang kosong menjelaskan diri, bukan diam', (tester) async {
    await pump(
      tester,
      index: libraryWith(const <ZoteroCollection>[]),
      notes: notesWith(const <NoteCollection>[]),
    );
    expect(find.textContaining('Belum ada koleksi catatan'), findsOneWidget);
    expect(find.textContaining('terpisah dari paper'), findsOneWidget);
  });

  testWidgets('akar paper bisa ditutup tanpa menutup akar catatan', (tester) async {
    final container = await pump(
      tester,
      index: libraryWith(<ZoteroCollection>[
        const ZoteroCollection(key: 'PAPER001', name: 'Kriptografi', path: 'Kriptografi'),
      ]),
      notes: notesWith(<NoteCollection>[
        const NoteCollection(key: 'CATATAN1', name: 'Rapat'),
      ]),
    );

    container.read(expandedCollectionsProvider.notifier).toggle(paperRootNodeKey);
    await tester.pump();

    expect(find.text('Kriptografi'), findsNothing);
    expect(find.text('Rapat'), findsOneWidget, reason: 'akar yang lain tidak terpengaruh');
  });

  testWidgets('sub-koleksi catatan tampil satu tingkat di dalam', (tester) async {
    final container = await pump(
      tester,
      index: libraryWith(const <ZoteroCollection>[]),
      notes: notesWith(<NoteCollection>[
        const NoteCollection(key: 'CATATAN1', name: 'Kuliah'),
        const NoteCollection(key: 'CATATAN2', name: 'Semester 1', parentKey: 'CATATAN1'),
      ]),
    );

    // Tertutup dulu: kunci simpulnya diberi awalan supaya tidak bertabrakan
    // dengan kunci koleksi Zotero yang memakai abjad yang sama.
    expect(find.text('Semester 1'), findsNothing);
    container.read(expandedCollectionsProvider.notifier).toggle(noteNodeKey('CATATAN1'));
    await tester.pump();
    expect(find.text('Semester 1'), findsOneWidget);
  });
}
