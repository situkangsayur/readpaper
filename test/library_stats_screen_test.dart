import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/library_stats.dart';
import 'package:readpaper/src/features/library/presentation/controllers/library_controllers.dart';
import 'package:readpaper/src/features/library/presentation/screens/library_stats_screen.dart';

LibraryStats stats({
  int itemCount = 100,
  int withFile = 80,
  int withAnnotations = 12,
  int annotationTotal = 340,
  int untitled = 0,
  int withoutYear = 0,
  List<StatTally> byYear = const <StatTally>[],
  List<StatTally> byType = const <StatTally>[],
  List<StatTally> creators = const <StatTally>[],
  List<StatTally> tags = const <StatTally>[],
  int? earliest,
  int? latest,
}) => LibraryStats(
  itemCount: itemCount,
  withFile: withFile,
  withAnnotations: withAnnotations,
  annotationTotal: annotationTotal,
  untitledCount: untitled,
  withoutYear: withoutYear,
  byYear: byYear,
  byType: byType,
  topCreators: creators,
  topTags: tags,
  earliestYear: earliest,
  latestYear: latest,
);

void main() {
  Future<void> pump(WidgetTester tester, LibraryStats value) async {
    await tester.pumpWidget(
      ProviderScope(
        // Riverpod 3 tidak mengekspor tipe `Override`.
        overrides: [libraryStatsProvider.overrideWithValue(value)],
        child: const MaterialApp(home: LibraryStatsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('library kosong mengatakannya, bukan menampilkan nol di mana-mana', (tester) async {
    await pump(tester, LibraryStats.of(const []));
    expect(find.text('Belum ada item untuk dihitung.'), findsOneWidget);
  });

  testWidgets('angka pokoknya terbaca', (tester) async {
    await pump(tester, stats(itemCount: 1741, withFile: 900, earliest: 1998, latest: 2026));

    expect(find.text('1741'), findsOneWidget);
    expect(find.text('900'), findsOneWidget);
    expect(find.text('52%'), findsOneWidget);
    expect(find.text('1998–2026'), findsOneWidget);
    expect(find.text('340 anotasi'), findsOneWidget);
  });

  testWidgets('jenis item ditampilkan dengan nama yang enak dibaca', (tester) async {
    await pump(tester, stats(byType: const <StatTally>[(label: 'journalArticle', count: 9)]));

    expect(find.text('Artikel jurnal'), findsOneWidget);
    expect(find.text('journalArticle'), findsNothing);
  });

  testWidgets('item tanpa tahun disebut sebagai catatan, bukan disembunyikan', (tester) async {
    await pump(
      tester,
      stats(withoutYear: 7, byYear: const <StatTally>[(label: '2024', count: 3)]),
    );

    expect(find.textContaining('7 item tanpa tahun'), findsOneWidget);
  });

  testWidgets('bagian tag hilang kalau memang tidak ada tag', (tester) async {
    await pump(tester, stats(byYear: const <StatTally>[(label: '2024', count: 3)]));
    expect(find.text('Tag tersering'), findsNothing);
  });

  testWidgets('item tanpa judul hanya muncul kalau memang ada', (tester) async {
    await pump(tester, stats());
    expect(find.text('Tanpa judul'), findsNothing);

    await pump(tester, stats(untitled: 4));
    expect(find.text('Tanpa judul'), findsOneWidget);
  });
}
