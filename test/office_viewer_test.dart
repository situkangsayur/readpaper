import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/widgets/find_bar.dart';
import 'package:readpaper/src/features/epub/data/epub_search.dart';
import 'package:readpaper/src/features/files/presentation/open_any_file.dart';
import 'package:readpaper/src/features/files/presentation/screens/table_viewer_screen.dart';
import 'package:readpaper/src/features/office/presentation/office_viewer_screen.dart';

String fixture(String name) => File('test/fixtures/office/$name').absolute.path;

/// Pembacaan berkas berjalan di isolat dan I/O sungguhan: ditunggu di luar
/// waktu palsu uji.
Future<void> settle(WidgetTester tester, Finder until) async {
  for (var i = 0; i < 100 && until.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Widget app(Widget child) => MaterialApp(home: child);

void main() {
  test('jenis berkas: Word, PowerPoint, dan Excel lama dikenali', () {
    expect(fileKindOf('a.docx'), FileKind.office);
    expect(fileKindOf('a.DOC'), FileKind.office);
    expect(fileKindOf('a.pptx'), FileKind.office);
    expect(fileKindOf('a.ppt'), FileKind.office);
    expect(fileKindOf('a.rtf'), FileKind.office);
    expect(fileKindOf('a.xls'), FileKind.table);
    expect(fileKindOf('a.odt'), FileKind.office);
    expect(fileKindOf('a.ODP'), FileKind.office);
    expect(fileKindOf('a.ods'), FileKind.table);
    expect(canOpenInApp('a.zip'), isFalse);
  });

  testWidgets('docx: isi tampil, Ctrl+F menemukan dan menghitung hasil', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(OfficeViewerScreen(path: fixture('contoh.docx'))));
    await settle(tester, find.textContaining('Laporan Uji Kuantum', findRichText: true));
    expect(find.textContaining('Laporan Uji Kuantum', findRichText: true), findsOneWidget);
    expect(find.textContaining('12 ms', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Cari di dokumen (Ctrl+F)'));
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey<String>('find-field')), 'latensi');
    await tester.pumpAndSettle();
    expect(find.text('1 dari 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Berikutnya (Enter)'));
    await tester.pumpAndSettle();
    expect(find.text('2 dari 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Sebelumnya (Shift+Enter)'));
    await tester.tap(find.byTooltip('Sebelumnya (Shift+Enter)'));
    await tester.pumpAndSettle();
    expect(find.text('3 dari 3'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('find-field')), 'tidakada');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ditemukan'), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup pencarian (Esc)'));
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsNothing);
  });

  testWidgets('pptx: slide bernomor dan catatan pembicara', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(OfficeViewerScreen(path: fixture('contoh.pptx'))));
    await settle(tester, find.text('Slide 1'));
    expect(find.text('Slide 1'), findsOneWidget);
    expect(find.textContaining('Migrasi Pascakuantum', findRichText: true), findsOneWidget);
    expect(find.text('Catatan pembicara'), findsOneWidget);
    expect(find.textContaining('Sapa audiens dulu.', findRichText: true), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Slide 2'), 200);
    expect(find.textContaining('Kyber tercepat', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doc lama: pemberitahuan hanya-teks', (tester) async {
    await tester.pumpWidget(app(OfficeViewerScreen(path: fixture('contoh.doc'))));
    await settle(tester, find.textContaining('Laporan Uji Kuantum', findRichText: true));
    expect(find.textContaining('Format Office lama'), findsOneWidget);
  });

  testWidgets('berkas rusak: pesan, bukan layar merah', (tester) async {
    final dir = Directory.systemTemp.createTempSync('rp-office');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/rusak.pptx')..writeAsBytesSync(<int>[0, 1, 2, 3, 4, 5, 6]);
    await tester.pumpWidget(app(OfficeViewerScreen(path: bad.path)));
    await settle(tester, find.textContaining('tidak bisa dibaca'));
    expect(find.textContaining('tidak bisa dibaca'), findsOneWidget);
  });

  testWidgets('xls lama di penampil tabel, dan dicari', (tester) async {
    await tester.pumpWidget(app(TableViewerScreen(path: fixture('contoh.xls'))));
    await settle(tester, find.text('Kyber'));
    expect(find.text('Dilithium'), findsOneWidget);
    await tester.tap(find.byTooltip('Cari di dokumen (Ctrl+F)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('find-field')), 'kyb');
    await tester.pumpAndSettle();
    expect(find.text('1 dari 1'), findsOneWidget);
  });

  test('EPUB: hitungan dan tanda sama, hasil aktif berkelas', () {
    const html = '<p>Latensi rendah. <b>latensi</b> tinggi.</p><p>Tanpa la<i>tensi</i>.</p>';
    expect(EpubSearch.count(html, 'LATENSI'), 2);
    final marked = EpubSearch.mark(html, 'latensi', active: 1);
    expect('<mark>'.allMatches(marked).length + '<mark class'.allMatches(marked).length, 2);
    expect(marked, contains('<mark class="${EpubSearch.activeClass}">latensi</mark>'));
    expect(marked, contains('<mark>Latensi</mark>'));
    expect(EpubSearch.mark(html, '  '), html);
  });
}
