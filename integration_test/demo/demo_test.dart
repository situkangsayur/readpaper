import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;
import 'package:readpaper/src/features/library/presentation/widgets/collection_tree_pane.dart';

import '../support.dart';
import 'demo_support.dart';

/// Video demo per fitur untuk blog. Bukan uji: tiap bagian direkam menjadi
/// satu MP4 pendek di `build/demo/`.
///
///   DISPLAY=:77 flutter test integration_test/demo/demo_test.dart -d linux
///
/// Mode presenter dengan layar audiens butuh jendela kedua sungguhan, yang
/// tidak bisa dibuat `flutter test`; videonya direkam terpisah dari aplikasi
/// asli.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fx;

  setUpAll(() async {
    fx = await Fixture.create();
    await enrichLibrary(fx);
  });

  Finder inTree(String name) =>
      find.descendant(of: find.byType(CollectionTreePane), matching: find.text(name));

  Finder tooltipStarting(String prefix) =>
      find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith(prefix));

  testWidgets('video demo', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final demo = Demo(tester);
    addTearDown(demo.abort);

    Future<void> back() async {
      await demo.pause(500);
      await demo.tap(find.byType(BackButton).last, after: 900);
    }

    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    await demo.pause(1500);

    // ------------------------------------------------ 1. library dan koleksi
    await demo.start(
      '01-library-koleksi',
      caption: 'Library Zotero dari GitHub, koleksi seperti di Zotero',
    );
    await demo.tap(inTree('Pembelajaran Mesin'), after: 1200);
    await demo.tap(inTree('Kripto'), after: 1200);
    await demo.tap(find.text('Migrasi kriptografi pascakuantum'), after: 1500);
    await demo.say('Buka paper: metadata, lampiran, dan anotasinya');
    await demo.tap(find.text('Baca'));
    await pumpUntil(tester, find.byType(PdfViewer));
    await demo.pause(2500);
    await demo.stop();

    // Titik di halaman pertama dalam koordinat PDF (pt dari kiri atas).
    // Dihitung ulang setiap kali: bilah petunjuk mode Tandai dan mode catatan
    // menggeser penampilnya ke bawah.
    Offset at(double x, double y) {
      final viewer = tester.getRect(find.byType(PdfViewer));
      final scale = (viewer.width - 20) / 595.28;
      return viewer.topLeft + Offset(10 + x * scale, 10 + y * scale);
    }

    // --------------------------------------------------- 2. menandai teks
    await demo.start('02-menandai', caption: 'Tandai: seret di atas teks, langsung berwarna');
    await demo.tap(find.text('Tandai'), after: 1500);
    await demo.drag(Demo.line(at(72, 153), at(500, 153), steps: 30));
    await demo.tap(find.text('Menandai'), after: 1200);
    await demo.say('Tambahkan komentar dari panel anotasi');
    await demo.tap(find.byTooltip('Ubah komentar / warna'));
    await demo.type(find.byType(TextField), 'Bandingkan dengan angka di bagian Evaluation');
    await demo.tap(find.text('Simpan').last, after: 1500);
    await demo.say('Semua anotasi di panel kanan, dalam format Zotero');
    await demo.stop();

    // ----------------------------------------- 3. catatan dan teks di halaman
    await demo.start('03-catatan-dan-teks', caption: 'Catatan tempel gaya Zotero');
    await demo.tap(find.byTooltip('Tempel catatan di halaman'));
    await demo.tapAt(at(470, 300));
    await demo.type(find.byType(TextField), 'Cek ulang sumber data latensi');
    await demo.tap(find.text('Simpan').last, after: 1500);
    await demo.tap(find.byTooltip('Tutup catatan'), after: 1000);
    final frame = tester.getTopLeft(find.byTooltip('Seret untuk memindahkan'));
    await demo.say('Ketuk penandanya untuk membuka lagi');
    await demo.tapAt(frame + const Offset(42, 42), after: 1500);
    await demo.tap(find.byTooltip('Tutup catatan'), after: 800);
    await demo.say('Teks langsung di halaman — bisa diputar dan diperbesar');
    await demo.tap(find.byTooltip('Isi teks di halaman — untuk mengisi formulir'));
    final textPoint = at(330, 98);
    await demo.tapAt(textPoint);
    await demo.type(find.byType(TextField), 'Penting untuk bab 2!');
    await demo.tap(find.text('Simpan').last, after: 1200);
    await demo.tapAt(textPoint + const Offset(8, 6));
    await demo.tap(find.text('Batal'), after: 800);
    final rotate = tester.getCenter(find.byTooltip('Seret untuk memutar'));
    await demo.drag(Demo.line(rotate, rotate + const Offset(18, 26), steps: 16));
    final resize = tester.getCenter(find.byTooltip('Seret untuk mengubah ukuran'));
    await demo.drag(Demo.line(resize, resize + const Offset(70, 34), steps: 20), after: 1500);
    await demo.stop();

    // ------------------------------------------------------- 4. pena
    await demo.start('04-pena', caption: 'Pena: coret dengan mouse, jari, atau stylus');
    final stylusOnly = tooltipStarting('Stylus saja');
    if (stylusOnly.evaluate().isNotEmpty) {
      await tester.tap(stylusOnly.first);
      await tester.pump();
    }
    await demo.tap(find.byTooltip('Tulis atau gambar di halaman'));
    await demo.drag(Demo.circle(at(150, 262), 95, 16), stepMs: 20);
    await demo.drag(Demo.line(at(470, 330), at(400, 280), steps: 16), stepMs: 20);
    await demo.drag(Demo.line(at(250, 368), at(470, 368), steps: 20), stepMs: 20);
    await demo.say('Urungkan dan ulangi per goresan');
    await demo.tap(tooltipStarting('Urungkan').first, after: 900);
    await demo.tap(tooltipStarting('Ulangi').first, after: 900);
    await demo.tap(find.byTooltip('Selesai menggambar'), after: 1500);
    await demo.say('Warna halaman untuk membaca lama');
    await demo.tap(tooltipStarting('Warna halaman').first, after: 1200);
    await demo.tap(tooltipStarting('Warna halaman').first, after: 1200);
    await demo.tap(tooltipStarting('Warna halaman').first, after: 1200);
    await demo.tap(tooltipStarting('Warna halaman').first, after: 800);
    await demo.stop();

    // ------------------------------------- 5. menyajikan, clicker, penunjuk
    await demo.start('05-menyajikan', caption: 'Mode menyajikan: satu halaman penuh layar');
    await demo.tap(find.byTooltip('Sajikan — satu halaman penuh layar'), after: 2000);
    await demo.tap(find.byTooltip('Pas satu halaman ke layar'), after: 1200);
    await demo.say('Clicker atau keyboard: Page Down, panah, Spasi');
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await demo.pause(2800);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await demo.pause(2200);
    await demo.say('Penunjuk dengan buntut yang memudar');
    await demo.tap(find.byTooltip('Penunjuk'));
    final page = tester.getRect(find.byType(PdfViewer));
    await demo.hover(Demo.circle(page.center + const Offset(-80, -120), 160, 50, steps: 70));
    await demo.hover(
      Demo.line(
        page.center + const Offset(80, -120),
        page.center + const Offset(-200, 60),
        steps: 40,
      ),
    );
    await demo.pause(1500);
    await demo.tap(find.byTooltip('Penunjuk'), after: 600);
    await demo.tap(find.byTooltip('Keluar dari mode menyajikan'), after: 1200);
    await demo.stop();
    await back();

    // ------------------------------------------------------- 6. dua bahasa
    await demo.start('06-dua-bahasa', caption: 'Bahasa Indonesia dan English');
    await demo.tap(find.byTooltip('Kelola repositori'), after: 1000);
    await demo.tap(find.byTooltip('Bahasa / Language'));
    await demo.tap(find.text('English').last, after: 1800);
    await back();
    await demo.pause(1800);
    await demo.tap(find.byTooltip('Manage repositories'), after: 1000);
    await demo.tap(find.byTooltip('Language / Language'));
    await demo.tap(find.text('Bahasa Indonesia').last, after: 1500);
    await back();
    await demo.stop();

    // ----------------------------------------------------------- 7. kirim
    await demo.start('07-kirim', caption: 'Perubahan menunggu Kirim: satu commit, lalu push');
    await demo.tap(find.byTooltip('Kirim perubahan ke GitHub'), after: 2000);
    await demo.tap(find.text('Commit & kirim'), after: 3500);
    await demo.say('Anotasi tersimpan di repositori, terbaca di Zotero');
    await demo.stop();
  });
}
