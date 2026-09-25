import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/src/features/reader/presentation/widgets/navigation_sheet.dart';

PdfOutlineNode node(String title, int page, {List<PdfOutlineNode> children = const []}) =>
    PdfOutlineNode(title: title, dest: PdfDest(page, PdfDestCommand.fit, null), children: children);

void main() {
  /// Opens the sheet and hands back whatever it returns.
  Future<NavigationTarget?> open(
    WidgetTester tester, {
    required List<PdfOutlineNode> outline,
    int currentPage = 1,
    int pageCount = 42,
  }) async {
    NavigationTarget? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showNavigationSheet(
                    context,
                    currentPage: currentPage,
                    pageCount: pageCount,
                    outline: outline,
                  );
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('says so plainly when the document carries no table of contents', (tester) async {
    await open(tester, outline: const <PdfOutlineNode>[]);
    expect(find.text('Berkas ini tidak membawa daftar isi.'), findsOneWidget);
    expect(find.text('dari 42'), findsOneWidget);
  });

  testWidgets('typing a page number returns that page', (tester) async {
    await open(tester, outline: const <PdfOutlineNode>[]);
    await tester.enterText(find.byType(TextField), '17');
    await tester.tap(find.text('Pergi'));
    await tester.pumpAndSettle();
    // The sheet is gone, which only happens when a target was returned.
    expect(find.text('Lompat ke halaman'), findsNothing);
  });

  testWidgets('a page outside the document is refused, with the range named', (tester) async {
    await open(tester, outline: const <PdfOutlineNode>[]);
    await tester.enterText(find.byType(TextField), '99');
    await tester.tap(find.text('Pergi'));
    await tester.pump();
    expect(find.text('Halaman harus antara 1 dan 42'), findsOneWidget);
    // Still open: nothing was navigated to.
    expect(find.text('Lompat ke halaman'), findsOneWidget);
  });

  testWidgets('nested headings are shown and indented by depth', (tester) async {
    await open(
      tester,
      outline: <PdfOutlineNode>[
        node('1 Pendahuluan', 1),
        node('2 Metode', 4, children: <PdfOutlineNode>[node('2.1 Data', 5), node('2.2 Model', 7)]),
      ],
    );

    expect(find.text('1 Pendahuluan'), findsOneWidget);
    expect(find.text('2 Metode'), findsOneWidget);
    // Top level starts expanded, so the children are already on screen.
    expect(find.text('2.1 Data'), findsOneWidget);

    final parent = tester.getTopLeft(find.text('2 Metode')).dx;
    final child = tester.getTopLeft(find.text('2.1 Data')).dx;
    expect(child, greaterThan(parent), reason: 'anak harus menjorok lebih dalam');
  });

  testWidgets('tapping a heading returns its destination, not just its page', (tester) async {
    NavigationTarget? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await showNavigationSheet(
                    context,
                    currentPage: 1,
                    pageCount: 42,
                    outline: <PdfOutlineNode>[node('3 Hasil', 12)],
                  );
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 Hasil'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.dest, isNotNull);
    expect(captured!.dest!.pageNumber, 12);
    expect(captured!.pageNumber, isNull);
  });

  testWidgets('a heading with no destination is not tappable', (tester) async {
    await open(
      tester,
      outline: const <PdfOutlineNode>[
        PdfOutlineNode(title: 'Bagian tanpa tujuan', dest: null, children: <PdfOutlineNode>[]),
      ],
    );
    final tile = tester.widget<ListTile>(find.byType(ListTile).first);
    expect(tile.onTap, isNull);
  });
}
