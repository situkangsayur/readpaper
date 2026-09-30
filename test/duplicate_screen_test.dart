import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/duplicate_finder.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_item.dart';
import 'package:readpaper/src/features/library/presentation/controllers/library_controllers.dart';
import 'package:readpaper/src/features/library/presentation/screens/duplicate_screen.dart';

ZoteroItem item({
  required String key,
  String title = 'Judul yang sama',
  int annotations = 0,
  String year = '2024',
}) => ZoteroItem(
  key: key,
  title: title,
  itemType: 'journalArticle',
  filePath: '/tmp/$key.json',
  creatorDetails: const <ZoteroCreator>[
    ZoteroCreator(creatorType: 'author', lastName: 'Karisma', firstName: 'H'),
  ],
  creators: const <String>['Karisma, H'],
  year: year,
  annotationCount: annotations,
);

void main() {
  Future<void> pump(WidgetTester tester, List<DuplicateGroup> groups, {int items = 100}) async {
    await tester.pumpWidget(
      ProviderScope(
        // Riverpod 3 tidak mengekspor tipe `Override`, jadi daftarnya ditulis
        // tanpa tipe.
        overrides: [
          duplicateGroupsProvider.overrideWithValue(groups),
          libraryItemCountProvider.overrideWithValue(items),
        ],
        child: const MaterialApp(home: DuplicateScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('tanpa duplikat, layarnya mengatakan berapa yang diperiksa', (tester) async {
    await pump(tester, const <DuplicateGroup>[], items: 1741);

    expect(find.text('Tidak ada yang tampak ganda.'), findsOneWidget);
    expect(find.textContaining('1741 item diperiksa'), findsOneWidget);
  });

  testWidgets('tiap kelompok menyebut alasannya dan berapa salinannya', (tester) async {
    await pump(tester, <DuplicateGroup>[
      DuplicateGroup(
        items: <ZoteroItem>[item(key: 'A'), item(key: 'B'), item(key: 'C')],
        reasons: const <DuplicateReason>{DuplicateReason.doi},
      ),
    ], items: 10);

    expect(find.text('DOI-nya sama'), findsOneWidget);
    expect(find.text('3 salinan'), findsOneWidget);
    expect(find.textContaining('1 kelompok · 3 salinan dari 10 item'), findsOneWidget);
    // Tiap salinan disebut kuncinya, supaya bisa dicocokkan di Zotero.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('salinan pertama ditandai bintang penuh sebagai calon yang dipertahankan', (
    tester,
  ) async {
    await pump(tester, <DuplicateGroup>[
      DuplicateGroup(
        items: <ZoteroItem>[item(key: 'A', annotations: 5), item(key: 'B')],
        reasons: const <DuplicateReason>{DuplicateReason.doi},
      ),
    ]);

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.textContaining('5 anotasi'), findsOneWidget);
  });

  testWidgets('anotasi di lebih dari satu salinan diberi peringatan', (tester) async {
    await pump(tester, <DuplicateGroup>[
      DuplicateGroup(
        items: <ZoteroItem>[item(key: 'A', annotations: 3), item(key: 'B', annotations: 2)],
        reasons: const <DuplicateReason>{DuplicateReason.titleYearAuthor},
      ),
    ]);

    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    expect(find.textContaining('perlu hati-hati'), findsOneWidget);
  });

  testWidgets('kelompok tanpa risiko tidak diberi peringatan', (tester) async {
    await pump(tester, <DuplicateGroup>[
      DuplicateGroup(
        items: <ZoteroItem>[item(key: 'A', annotations: 3), item(key: 'B')],
        reasons: const <DuplicateReason>{DuplicateReason.doi},
      ),
    ]);

    expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
    expect(find.textContaining('perlu hati-hati'), findsNothing);
  });

  testWidgets('layarnya mengatakan bahwa ia tidak menghapus apa pun', (tester) async {
    // Janji yang harus terbaca di layar, bukan hanya ada di komentar kode:
    // library Zotero adalah pekerjaan bertahun-tahun.
    await pump(tester, <DuplicateGroup>[
      DuplicateGroup(
        items: <ZoteroItem>[item(key: 'A'), item(key: 'B')],
        reasons: const <DuplicateReason>{DuplicateReason.doi},
      ),
    ]);

    expect(find.textContaining('Tidak ada yang dihapus dari sini'), findsOneWidget);
  });
}
