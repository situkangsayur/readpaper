import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/notebook/data/note_document_store.dart';
import 'package:readpaper/src/features/notebook/domain/note_document.dart';
import 'package:readpaper/src/features/notebook/presentation/screens/notebook_screen.dart';
import 'package:readpaper/src/features/notebook/presentation/widgets/component_frame.dart';
import 'package:readpaper/src/features/notebook/presentation/widgets/note_canvas.dart';

void main() {
  _pressureTests();

  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rp-buku-');
    path = p.join(dir.path, 'rapat${NoteDocumentStore.extension}');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: NotebookScreen(path: path, title: 'Rapat')),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pusat kanvasnya di koordinat layar.
  Offset centre(WidgetTester tester) => tester.getCenter(find.byType(NoteCanvas));

  Future<void> draw(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(from);
    // Beberapa langkah, supaya goresannya punya lebih dari satu titik.
    for (var i = 1; i <= 4; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 4)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Menekan Simpan, lalu menunggu snackbar-nya hilang.
  ///
  /// Kalau tidak ditunggu, "Tersimpan" menutup bilah halaman dan ketukan
  /// berikutnya mendarat di snackbar-nya, bukan di tombolnya.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Simpan'));
    await tester.pumpAndSettle();
    // Snackbar "Tersimpan" menutup bilah halaman kalau dibiarkan, dan ketukan
    // berikutnya mendarat di snackbar-nya alih-alih di tombolnya.
    ScaffoldMessenger.of(tester.element(find.byType(NotebookScreen))).removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  NoteDocument saved() => NoteDocumentStore.decodeSync(File(path).readAsStringSync());

  testWidgets('menulis satu goresan membuat satu komponen tinta', (tester) async {
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(60, 0), at + const Offset(60, 0));

    await save(tester);

    final document = saved();
    expect(document.pages, hasLength(1));
    final ink = document.pages.first.components.single as NoteInk;
    expect(ink.strokes.single.points.length, greaterThan(2));
    // Titiknya disimpan lokal, jadi mulai dari dekat nol.
    expect(ink.strokes.single.points.first.dx, lessThan(5));
    expect(ink.position.dx, greaterThan(0));
  });

  testWidgets('urungkan mengembalikan goresan terakhir, ulangi membawanya lagi', (tester) async {
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(80, 20), at);
    await draw(tester, at, at + const Offset(80, 20));

    await tester.tap(find.byTooltip('Urungkan'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(saved().pages.first.components, hasLength(1));

    await tester.tap(find.byTooltip('Ulangi'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(saved().pages.first.components, hasLength(2));
  });

  testWidgets('penghapus goresan membuang seluruh goresan yang disentuh', (tester) async {
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(60, 0), at + const Offset(60, 0));

    await tester.tap(find.byTooltip('Hapus goresan'));
    await tester.pumpAndSettle();
    // Seretannya harus melewati ambang gerak Flutter, kalau tidak tidak ada
    // gerakan yang dikenali sama sekali.
    await draw(tester, at - const Offset(14, 0), at + const Offset(14, 0));

    await save(tester);
    expect(saved().pages.first.components, isEmpty);
  });

  testWidgets('penghapus sebagian menyisakan potongan di kedua sisinya', (tester) async {
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(120, 0), at + const Offset(120, 0));

    await tester.tap(find.byTooltip('Hapus sebagian'));
    await tester.pumpAndSettle();
    await draw(tester, at - const Offset(12, 0), at + const Offset(12, 0));

    await save(tester);
    final ink = saved().pages.first.components.single as NoteInk;
    expect(ink.strokes.length, greaterThanOrEqualTo(2), reason: 'goresannya terbelah');
  });

  testWidgets('komponen bisa dipilih lalu digeser', (tester) async {
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(60, 0), at + const Offset(60, 0));

    await tester.tap(find.byTooltip('Pilih'));
    await tester.pumpAndSettle();
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.byType(ComponentFrame), findsOneWidget);

    await save(tester);
    final sebelum = saved().pages.first.components.single.position;

    await tester.drag(find.byTooltip('Seret untuk memindahkan'), const Offset(40, 30));
    await tester.pumpAndSettle();
    await save(tester);

    final sesudah = saved().pages.first.components.single.position;
    expect(sesudah.dx, greaterThan(sebelum.dx));
    expect(sesudah.dy, greaterThan(sebelum.dy));
  });

  testWidgets('memutar tidak menulis ulang titik tintanya', (tester) async {
    // Memutar dua kali dengan menulis ulang titik akan kehilangan ketelitian.
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(60, 0), at + const Offset(60, 0));
    await tester.tap(find.byTooltip('Pilih'));
    await tester.pumpAndSettle();
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    await save(tester);
    final sebelum = (saved().pages.first.components.single as NoteInk).strokes.single.points;

    await tester.drag(find.byTooltip('Seret untuk memutar'), const Offset(60, 0));
    await tester.pumpAndSettle();
    await save(tester);

    final sesudah = saved().pages.first.components.single as NoteInk;
    expect(sesudah.rotation, isNot(0));
    expect(sesudah.strokes.single.points, sebelum);
  });

  testWidgets('menghapus komponen lewat bingkainya, dan itu bisa diurungkan', (tester) async {
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(60, 0), at + const Offset(60, 0));
    await tester.tap(find.byTooltip('Pilih'));
    await tester.pumpAndSettle();
    await tester.tapAt(at);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await save(tester);
    expect(saved().pages.first.components, isEmpty);

    await tester.tap(find.byTooltip('Urungkan'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(saved().pages.first.components, hasLength(1));
  });

  testWidgets('lembar baru, berpindah lembar, dan tiap lembar isinya sendiri', (tester) async {
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(40, 0), at + const Offset(40, 0));

    await tester.tap(find.byTooltip('Lembar kosong baru'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await draw(tester, at - const Offset(0, 40), at + const Offset(0, 40));
    await save(tester);

    final document = saved();
    expect(document.pages, hasLength(2));
    expect(document.pages.first.components, hasLength(1));
    expect(document.pages.last.components, hasLength(1));

    await tester.tap(find.byTooltip('Lembar sebelumnya'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('lembar terakhir tidak dihapus melainkan dikosongkan', (tester) async {
    await open(tester);
    final at = centre(tester);
    await draw(tester, at - const Offset(40, 0), at + const Offset(40, 0));

    await tester.tap(find.byTooltip('Hapus lembar ini'));
    await tester.pumpAndSettle();
    await save(tester);

    final document = saved();
    expect(document.pages, hasLength(1), reason: 'bukunya tidak ditutup');
    expect(document.pages.single.components, isEmpty);
  });

  testWidgets('kertas dan arahnya terlihat, dan tidak tertutup bilah sistem', (tester) async {
    // Dua sebab kenapa dulu tidak ketemu: tombolnya paling ujung di bilah yang
    // bisa tergulir, dan bilahnya sendiri duduk di bawah bilah navigasi
    // Android — terlihat, tetapi sentuhannya diambil sistem.
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1
      ..viewPadding = const FakeViewPadding(bottom: 48)
      ..padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: NotebookScreen(path: path, title: 'Rapat'))),
    );
    await tester.pumpAndSettle();

    // Terlihat tanpa digulir: label ukuran dan arahnya ada di layar.
    expect(find.text('A4'), findsOneWidget);
    expect(find.text('Tegak'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Tegak')).dx, lessThan(400));
    // Dan di atas bilah navigasi, bukan di bawahnya.
    expect(tester.getBottomLeft(find.text('Tegak')).dy, lessThan(800 - 48));

    await tester.tap(find.text('Tegak'));
    await tester.pumpAndSettle();
    expect(find.text('Mendatar'), findsOneWidget);

    await save(tester);
    final document = NoteDocumentStore.decodeSync(File(path).readAsStringSync());
    expect(document.pages.single.orientation, NoteOrientation.mendatar);
    expect(document.pages.single.size.width, greaterThan(document.pages.single.size.height));
  });

  testWidgets('ukuran kertas bisa diganti dari kepingnya', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: NotebookScreen(path: path, title: 'Rapat'))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('A4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A3').last);
    await tester.pumpAndSettle();

    await save(tester);
    expect(
      NoteDocumentStore.decodeSync(File(path).readAsStringSync()).pages.single.paper,
      NotePaper.a3,
    );
  });

  testWidgets('tombol hapus tetap bisa ditekan untuk benda di tepi atas lembar', (tester) async {
    // Bug yang dilaporkan: ikon tong sampahnya terlihat tetapi tidak bisa
    // ditekan. Sebabnya anak yang digambar di luar batas induknya tidak pernah
    // menerima sentuhan — dan pegangan bingkai duduk di luar kotak benda.
    await NoteDocumentStore.write(
      path,
      const NoteDocument(
        pages: <NotePage>[
          NotePage(
            components: <NoteComponent>[
              NoteText(
                id: 'atas',
                position: Offset(0, 0),
                size: Size(200, 40),
                text: 'Menempel di tepi atas',
              ),
            ],
          ),
        ],
      ),
    );
    await open(tester);

    await tester.tap(find.byTooltip('Pilih'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getRect(find.byType(NoteCanvas)).topLeft + const Offset(40, 20));
    await tester.pumpAndSettle();
    expect(find.byType(ComponentFrame), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await save(tester);
    expect(
      NoteDocumentStore.decodeSync(File(path).readAsStringSync()).pages.single.components,
      isEmpty,
    );
  });

  testWidgets('kotak pilih memilih beberapa benda sekaligus, lalu menghapusnya', (tester) async {
    await NoteDocumentStore.write(
      path,
      const NoteDocument(
        pages: <NotePage>[
          NotePage(
            components: <NoteComponent>[
              NoteText(id: 't1', position: Offset(60, 60), size: Size(120, 30), text: 'satu'),
              NoteText(id: 't2', position: Offset(60, 120), size: Size(120, 30), text: 'dua'),
              NoteText(id: 'jauh', position: Offset(60, 700), size: Size(120, 30), text: 'jauh'),
            ],
          ),
        ],
      ),
    );
    await open(tester);

    await tester.tap(find.byTooltip('Pilih'));
    await tester.pumpAndSettle();

    // Kotak pilih ditarik di ruang kosong, melewati dua benda teratas.
    final canvas = tester.getRect(find.byType(NoteCanvas));
    final scale = canvas.width / 595.276;
    await tester.dragFrom(
      canvas.topLeft + Offset(40 * scale, 40 * scale),
      Offset(200 * scale, 130 * scale),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 benda dipilih'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await save(tester);

    final left = NoteDocumentStore.decodeSync(File(path).readAsStringSync()).pages.single.components;
    expect(left.map((c) => c.id), <String>['jauh'], reason: 'yang di luar kotak tetap ada');
  });

  testWidgets('buku yang sudah ada dibuka dengan isinya', (tester) async {
    await NoteDocumentStore.write(
      path,
      NoteDocument(
        title: 'Rapat',
        pages: <NotePage>[
          const NotePage(
            components: <NoteComponent>[
              NoteText(
                id: 't1',
                position: Offset(60, 80),
                size: Size(300, 50),
                text: 'Sudah ditulis sebelumnya',
              ),
            ],
          ),
          const NotePage(),
        ],
      ),
    );
    await open(tester);

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Sudah ditulis sebelumnya'), findsOneWidget);
    // Belum ada yang berubah, jadi tombol simpan mati.
    final save = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('Simpan'), matching: find.byType(IconButton)).first,
    );
    expect(save.onPressed, isNull);
  });
}

/// Uji terpisah: tekanan stylus sungguhan lewat peristiwa pointer mentah.
///
/// `tester.startGesture` tidak bisa membawa tekanan, jadi peristiwanya disusun
/// sendiri — dan justru itu yang perlu diuji: tekanan hanya sampai kalau
/// `Listener` di sekeliling kanvas benar-benar menerimanya.
void _pressureTests() {
  testWidgets('goresan stylus bertekanan keras jadi lebih tebal', (tester) async {
    final dir = Directory.systemTemp.createTempSync('rp-tekanan-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'tekanan${NoteDocumentStore.extension}');

    tester.view
      ..physicalSize = const Size(1200, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: NotebookScreen(path: path, title: 'Tekanan'))),
    );
    await tester.pumpAndSettle();

    final at = tester.getCenter(find.byType(NoteCanvas));
    const kind = PointerDeviceKind.stylus;
    await tester.sendEventToBinding(
      PointerDownEvent(
        pointer: 7,
        kind: kind,
        position: at - const Offset(60, 0),
        pressure: 0.95,
        pressureMin: 0,
        pressureMax: 1,
      ),
    );
    for (var i = 1; i <= 4; i++) {
      await tester.sendEventToBinding(
        PointerMoveEvent(
          pointer: 7,
          kind: kind,
          position: at - Offset(60 - i * 30, 0),
          pressure: 0.95,
          pressureMin: 0,
          pressureMax: 1,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendEventToBinding(
      PointerUpEvent(pointer: 7, kind: kind, position: at + const Offset(60, 0)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Simpan'));
    await tester.pumpAndSettle();

    final ink =
        NoteDocumentStore.decodeSync(File(path).readAsStringSync()).pages.first.components.single
            as NoteInk;
    final widths = ink.strokes.single.widths;
    expect(widths, isNotNull, reason: 'tekanannya tercatat');
    for (final w in widths!) {
      expect(w, greaterThan(ink.strokes.single.width), reason: 'lebih tebal dari tebal dasarnya');
    }
  });
}
