import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/l10n/app_localizations.dart';
import 'package:readpaper/src/features/tabs/presentation/document_tabs.dart';

/// Layar dokumen palsu: tombol untuk membuka dokumen lain, dan penghitung
/// untuk membuktikan isinya tetap hidup saat tab berpindah.
class _Doc extends StatefulWidget {
  const _Doc(this.name, {this.guard = false});

  final String name;

  /// Menolak ditutup, seperti penyunting dengan perubahan yang belum disimpan.
  final bool guard;

  @override
  State<_Doc> createState() => _DocState();
}

class _DocState extends State<_Doc> {
  var taps = 0;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.guard,
    child: Scaffold(
      appBar: AppBar(title: Text('isi ${widget.name}')),
      body: Center(
        child: TextButton(
          onPressed: () => setState(() => taps++),
          child: Text('${widget.name}: $taps'),
        ),
      ),
    ),
  );
}

class _Library extends StatelessWidget {
  const _Library();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final name in <String>['A', 'B'])
            TextButton(
              onPressed: () =>
                  openDocument<void>(context, _Doc(name), title: name, dedupeKey: name),
              child: Text('buka $name'),
            ),
          TextButton(
            onPressed: () => openDocument<void>(context, const _Doc('C', guard: true), title: 'C'),
            child: const Text('buka C'),
          ),
        ],
      ),
    ),
  );
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        locale: Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DocumentTabsHost(library: _Library()),
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(DocumentTabsHost)));
}

void main() {
  testWidgets('tanpa dokumen terbuka tidak ada bilah tab', (tester) async {
    await _pump(tester);
    expect(find.text('Library'), findsNothing);
    expect(find.text('buka A'), findsOneWidget);
  });

  testWidgets('dokumen terbuka sebagai tab; berkas yang sama memilih tab yang ada', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('buka A'));
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('isi A'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka A'));
    await tester.pumpAndSettle();
    final state = container.read(documentTabsProvider);
    expect(state.tabs.map((t) => t.title), <String>['A', 'B']);
    expect(state.byId(state.activeLeft)?.title, 'A');
  });

  testWidgets('tab pindah ke kanan: dua dokumen berdampingan, isinya tetap', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('buka A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A: 0'));
    await tester.pump();

    final a = container.read(documentTabsProvider).tabs.single;
    container.read(documentTabsProvider.notifier).moveTo(a.id, TabSide.right);
    await tester.pumpAndSettle();
    // Kiri kembali ke library, kanan memperlihatkan A — dengan hitungannya.
    expect(find.text('buka B'), findsOneWidget);
    expect(find.text('A: 1'), findsOneWidget);
    final left = tester.getCenter(find.text('buka B')).dx;
    final right = tester.getCenter(find.text('A: 1')).dx;
    expect(left, lessThan(800));
    expect(right, greaterThan(800));

    // Tab baru terbuka di panel yang terakhir disentuh: kiri.
    await tester.tap(find.text('buka B'));
    await tester.pumpAndSettle();
    final state = container.read(documentTabsProvider);
    expect(state.byId(state.activeLeft)?.title, 'B');
    expect(state.byId(state.activeRight!)?.title, 'A');
  });

  testWidgets('tombol kembali di layar menutup tabnya', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('buka A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(container.read(documentTabsProvider).tabs, isEmpty);
    expect(find.text('buka A'), findsOneWidget);
  });

  testWidgets('layar yang menolak ditutup tetap terbuka', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('buka C'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tutup tab'));
    await tester.pumpAndSettle();
    expect(container.read(documentTabsProvider).tabs, hasLength(1));
    expect(find.text('isi C'), findsOneWidget);
  });

  testWidgets('menu "Buka di panel kanan" membelah layar; yang sudah terbuka pindah', (
    tester,
  ) async {
    final container = await _pump(tester);
    await tester.tap(find.text('buka A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    // Tekan lama "buka B" lalu pilih panel kanan.
    final library = tester.element(find.text('buka B'));
    showOpenMenu(
      library,
      tester.getCenter(find.text('buka B')),
      () => openDocument<void>(library, const _Doc('B'), title: 'B', dedupeKey: 'B'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buka di tab baru'), findsOneWidget);
    await tester.tap(find.text('Buka di panel kanan'));
    await tester.pumpAndSettle();
    var state = container.read(documentTabsProvider);
    expect(state.byId(state.activeRight!)?.title, 'B');
    expect(tester.getCenter(find.text('B: 0')).dx, greaterThan(800));

    // A sudah terbuka di kiri: "buka di panel kanan" memindahkannya, bukan
    // membuat tab kembar.
    showOpenMenu(
      library,
      Offset.zero,
      () => openDocument<void>(library, const _Doc('A'), title: 'A', dedupeKey: 'A'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka di panel kanan'));
    await tester.pumpAndSettle();
    state = container.read(documentTabsProvider);
    expect(state.tabs, hasLength(2));
    expect(state.on(TabSide.right).map((t) => t.title), unorderedEquals(<String>['A', 'B']));
    expect(state.byId(state.activeRight!)?.title, 'A');

    // Pilihan panel hanya untuk satu kali buka.
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka C'));
    await tester.pumpAndSettle();
    expect(container.read(documentTabsProvider).on(TabSide.left).single.title, 'C');
  });

  testWidgets('bilah tab bisa dipindah ke bawah lewat menu tab', (tester) async {
    final container = await _pump(tester);
    bool? saved;
    container.read(documentTabsProvider.notifier).onBarPositionChanged = (v) => saved = v;
    await tester.tap(find.text('buka A'));
    await tester.pumpAndSettle();
    final top = tester.getCenter(find.text('Library')).dy;
    expect(top, lessThan(100));

    await tester.longPress(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pindahkan bilah tab ke bawah'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(tester.getCenter(find.text('Library')).dy, greaterThan(900));
    // Layar dokumen tetap di atasnya, utuh.
    expect(tester.getTopLeft(find.text('isi A')).dy, lessThan(100));

    await tester.longPress(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pindahkan bilah tab ke atas'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(tester.getCenter(find.text('Library')).dy, lessThan(100));
  });

  testWidgets('di ponsel dokumen didorong ke Navigator, bukan jadi tab', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DocumentTabsHost(library: _Library()),
        ),
      ),
    );
    await tester.tap(find.text('buka A'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DocumentTabsHost, skipOffstage: false)),
    );
    expect(container.read(documentTabsProvider).tabs, isEmpty);
    expect(find.text('isi A'), findsOneWidget);
  });
}
