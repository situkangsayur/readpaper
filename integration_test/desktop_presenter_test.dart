import 'dart:convert';
import 'dart:io';

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;
import 'package:readpaper/src/features/presenter/data/audience_link.dart';
import 'package:readpaper/src/features/presenter/domain/audience_state.dart';

import 'support.dart';

/// Mode presenter dengan layar audiens: slide berpindah dengan tombol
/// clicker, coretan dan penunjuk tampil di layar audiens, layar hitam, dan
/// catatan presenter tersimpan di repositori.
///
///   flutter test integration_test/desktop_presenter_test.dart -d windows
///
/// Layar audiens di sini berjalan di proses yang sama (pesannya tetap lewat
/// JSON, persis seperti antarjendela): `flutter test` hanya menjalankan uji di
/// isolate utama, sedangkan jendela kedua yang sungguhan menjalankan `main`
/// aplikasinya sendiri.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fx;
  late _LocalAudience screen;

  setUpAll(() async {
    fx = await Fixture.create();
    // Tiga slide mendatar menggantikan PDF satu halaman di paper pertama.
    final pdf = p.join(fx.library, 'attachments', 'AT', 'ATTACH01', 'paper.pdf');
    File(pdf).writeAsBytesSync(await _slides(3));
    AudienceLink.debugFactory = () => screen = _LocalAudience();
  });

  Map<String, dynamic> describe() => screen.describe();

  Future<void> audienceShows(
    WidgetTester tester,
    bool Function(Map<String, dynamic> s) check,
    String what,
  ) async {
    await pumpUntilTrue(tester, () => check(describe()), what);
    diag('audiens: $what — ${describe()}');
  }

  testWidgets('presenter dan layar audiens', (tester) async {
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    await tester.tap(find.text('Migrasi kriptografi pascakuantum').first);
    await pumpUntil(tester, find.text('Baca'));
    await tester.tap(find.text('Baca'));
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpFor(tester, const Duration(seconds: 3));

    await tester.tap(find.byTooltip('Sajikan — satu halaman penuh layar'));
    await pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Tampilkan di layar lain (monitor kedua / proyektor)'));
    await audienceShows(
      tester,
      (s) => s['page'] == 1 && (s['path'] as String? ?? '').endsWith('paper.pdf'),
      'slide 1 tampil',
    );
    expect(screen.isOpen, isTrue);
    await pumpUntil(tester, find.text('Slide berikutnya'));
    await shot(tester, 'p1-presenter');

    // Tombol clicker: Page Down / panah kanan maju, Page Up mundur.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await audienceShows(tester, (s) => s['page'] == 2, 'Page Down ke slide 2');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await audienceShows(tester, (s) => s['page'] == 3, 'panah kanan ke slide 3');
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await audienceShows(tester, (s) => s['page'] == 2, 'Page Up ke slide 2');
    // Mundur tidak boleh melompat kembali ke slide semula.
    await pumpFor(tester, const Duration(seconds: 2));
    expect(describe()['page'], 2);
    expect(find.text('Slide 2 dari 3'), findsOneWidget);

    // Layar hitam lewat B, lalu kembali.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await audienceShows(tester, (s) => s['blank'] == true, 'layar hitam');
    await shot(tester, 'p1b-hitam');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await audienceShows(tester, (s) => s['blank'] == false, 'layar kembali');
    await shot(tester, 'p1c-kembali');

    // Catatan presenter: hanya di panel, tersimpan di repositori.
    await tester.enterText(
      find.widgetWithText(TextField, 'Tulis catatan untuk slide ini…'),
      'Sebutkan angka migrasi',
    );
    final notes = p.join(fx.repo, 'presenter', 'ATTACH01.json');
    await pumpUntilTrue(tester, () => File(notes).existsSync(), 'catatan presenter');
    final saved = fx.readJson(notes);
    expect((saved['notes'] as Map)['2'], 'Sebutkan angka migrasi');
    // Spasi di catatan bukan "slide berikutnya".
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(describe()['page'], 2);
    // Fokus keluar dari catatan, supaya tombol berikutnya milik slide.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    // Coretan: goresan yang sedang ditarik ikut tampil, lalu jadi anotasi.
    await tester.tap(find.byTooltip('Coret-coret di halaman'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    final viewer = tester.getRect(find.byType(PdfViewer));
    final pen = await tester.startGesture(
      Offset(viewer.left + viewer.width * 0.3, viewer.top + viewer.height * 0.5),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 12; i++) {
      await pen.moveTo(
        Offset(viewer.left + viewer.width * (0.3 + 0.02 * i), viewer.top + viewer.height * 0.5),
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
    await audienceShows(tester, (s) => (s['live'] as int) > 4, 'goresan sedang ditarik');
    await pen.up();
    await audienceShows(tester, (s) => s['pending'] == 1 && s['live'] == 0, 'goresan selesai');
    await shot(tester, 'p2-coretan');
    await tester.tap(find.text('Selesai'));
    await audienceShows(
      tester,
      (s) => s['annotations'] == 1 && s['pending'] == 0,
      'coretan tersimpan',
    );

    // Penunjuk: mouse yang bergerak di slide tampil di layar audiens.
    await tester.tap(find.byTooltip('Penunjuk'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    // Tanpa addPointer: mouse uji sudah terdaftar sejak goresan pena tadi.
    for (var i = 0; i < 6; i++) {
      await mouse.moveTo(viewer.center + Offset(10.0 * i, 4.0 * i));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await audienceShows(tester, (s) => s['pointerPage'] == 2, 'penunjuk');
    await shot(tester, 'p3-penunjuk');
    // SnackBar "coretan disimpan" masih menutupi bilah bawah.
    // Setiap tab punya ScaffoldMessenger sendiri; pesannya bisa di mana saja.
    for (final m in tester.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
      m.clearSnackBars();
    }
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Penunjuk'));
    await mouse.moveTo(Offset(viewer.left - 40, viewer.top + 10));
    await audienceShows(tester, (s) => s['pointerPage'] == null, 'penunjuk padam');

    // Menutup layar audiens dari panel presenter.
    // Setiap tab punya ScaffoldMessenger sendiri; pesannya bisa di mana saja.
    for (final m in tester.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
      m.clearSnackBars();
    }
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Tutup layar audiens'));
    await pumpUntilTrue(tester, () => !screen.isOpen, 'layar audiens tertutup');
    expect(find.text('Slide berikutnya'), findsNothing);
  });
}

/// Layar audiens di proses yang sama: pesan presenter dikodekan ke JSON dan
/// diterapkan ke [AudienceController] yang juga dipakai jendela audiens.
class _LocalAudience implements AudienceLink {
  final AudienceController controller = AudienceController();
  final _closed = StreamController<void>.broadcast();
  final _keys = StreamController<PresenterKey>.broadcast();
  bool isOpen = false;

  @override
  Stream<void> get closed => _closed.stream;

  @override
  Stream<PresenterKey> get keys => _keys.stream;

  @override
  Future<bool> open() async => isOpen = true;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (!isOpen) return;
    await controller.handle((jsonDecode(jsonEncode(message)) as Map).cast<String, dynamic>());
  }

  @override
  Future<void> close() async {
    await send(AudienceMessage.close);
    isOpen = false;
  }

  Map<String, dynamic> describe() {
    final s = controller.state.value;
    return <String, dynamic>{
      'path': s.path,
      'page': s.page,
      'annotations': s.annotations.length,
      'pending': s.pending.length,
      'live': s.live.length,
      'blank': s.blank,
      'pointerPage': controller.pointer.head == null ? null : controller.pointer.page,
    };
  }
}

/// PDF slide mendatar 16:9 bernomor.
Future<Uint8List> _slides(int count) async {
  final doc = pw.Document();
  for (var i = 1; i <= count; i++) {
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(960, 540),
        build: (_) =>
            pw.Center(child: pw.Text('Slide $i', style: const pw.TextStyle(fontSize: 64))),
      ),
    );
  }
  return doc.save();
}
