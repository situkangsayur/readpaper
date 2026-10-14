import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;
import 'package:readpaper/src/core/utils/work_folder.dart';
import 'package:readpaper/src/features/files/presentation/file_browser_pane.dart';
import 'package:readpaper/src/features/library/presentation/widgets/recent_papers_card.dart';
import 'package:readpaper/src/features/library/presentation/widgets/collection_tree_pane.dart';
import 'package:readpaper/src/features/notes/presentation/widgets/note_detail_pane.dart';
import 'package:readpaper/src/features/notes/presentation/widgets/note_list_pane.dart';

import 'support.dart';

/// Fitur desktop di aplikasi asli (CI menjalankannya di Windows): koleksi,
/// tambah berkas dan impor folder, ekspor BibTeX, catatan dan Markdown,
/// pencarian, statistik, garis bawah, pena, urungkan/ulangi, warna halaman,
/// panel berkas, lalu kirim dan tarik ke remote git.
///
///   flutter test integration_test/desktop_features_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fx;
  final picker = FakePicker();

  setUpAll(() async {
    fx = await Fixture.create();
    FilePickerPlatform.instance = picker;
  });

  Finder tooltipStarting(String prefix) =>
      find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith(prefix));

  /// Pohon koleksi terlihat: di jendela sempit ia ada di laci menu.
  Future<void> showTree(WidgetTester tester) async {
    if (find.byTooltip('Koleksi paper baru').hitTestable().evaluate().isNotEmpty) return;
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await pumpFor(tester, const Duration(milliseconds: 800));
  }

  Future<void> closeDrawer(WidgetTester tester) async {
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    if (scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      await pumpFor(tester, const Duration(milliseconds: 800));
    }
  }

  /// Tombol ⋮ di baris pohon yang memuat [name].
  Finder rowMenu(String name) => find
      .descendant(
        of: find
            .ancestor(
              of: find.descendant(of: find.byType(CollectionTreePane), matching: find.text(name)),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byTooltip('Ubah nama, pindahkan, atau hapus'),
      )
      .first;

  /// Menggulir pohon koleksi sampai baris [name] terbangun dan terlihat:
  /// pohonnya daftar malas, baris di luar layar belum ada.
  Future<void> revealInTree(WidgetTester tester, String name) async {
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).clearSnackBars();
    for (var i = 0; i < 25 && find.text(name).evaluate().isEmpty; i++) {
      final tree = find.descendant(
        of: find.byType(CollectionTreePane),
        matching: find.byType(Scrollable),
      );
      final up = i < 12; // turun dulu, lalu naik lagi bila belum ketemu
      await tester.drag(tree.first, Offset(0, up ? -60 : 60));
      await pumpFor(tester, const Duration(milliseconds: 200));
    }
    // Terbangun belum berarti bisa diketuk: di jendela pendek barisnya bisa
    // tepat di tepi bawah, di balik kepala panel berkas.
    if (find.text(name).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text(name).first);
      await pumpFor(tester, const Duration(milliseconds: 300));
    }
  }

  Future<void> treeTop(WidgetTester tester) async {
    final tree = find.descendant(
      of: find.byType(CollectionTreePane),
      matching: find.byType(Scrollable),
    );
    await tester.drag(tree.first, const Offset(0, 2000));
    await pumpFor(tester, const Duration(milliseconds: 300));
  }

  /// Membuka lipatan baris pohon [name] bila masih terlipat.
  Future<void> expand(WidgetTester tester, String name) async {
    final chevron = find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.keyboard_arrow_right),
    );
    if (chevron.evaluate().isNotEmpty) {
      await tester.tap(chevron.first);
      await pumpFor(tester, const Duration(milliseconds: 500));
    }
  }

  /// Kembali, setelah animasi masuk halamannya selesai: menekan Kembali di
  /// tengah transisi memicu asersi Hero Flutter (mode debug), dan manusia
  /// memang tidak secepat itu.
  Future<void> back(WidgetTester tester) async {
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byType(BackButton).last);
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  Future<void> typeAndConfirm(WidgetTester tester, String text, String confirm) async {
    await pumpUntil(tester, find.text(confirm));
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pump();
    await tester.tap(find.text(confirm).last);
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  testWidgets('fitur desktop ujung ke ujung', (tester) async {
    // RP_E2E_WINDOW=1028x681 meniru jendela runner Windows (tata letak
    // menengah, pohon di laci) di mesin lain.
    final size = Platform.environment['RP_E2E_WINDOW'];
    if (size != null) {
      final wh = size.split('x').map(double.parse).toList();
      tester.view.physicalSize = Size(wh[0], wh[1]);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    diag('jendela ${tester.view.physicalSize} dpr=${tester.view.devicePixelRatio}');
    await shot(tester, 'f0-awal');

    // ---------------------------------------------------------------- koleksi
    await showTree(tester);
    final c0 = await fx.commitCount();
    await treeTop(tester);
    await tester.tap(find.byTooltip('Koleksi paper baru'));
    await typeAndConfirm(tester, 'Uji E2E', 'Simpan');
    await pumpUntilTrue(
      tester,
      () => fx.collections().any((c) => c['name'] == 'Uji E2E'),
      'koleksi-dibuat',
    );
    expect(await fx.commitCount(), c0, reason: 'tidak ada commit otomatis');
    diag('koleksi dibuat');

    await showTree(tester);
    await revealInTree(tester, 'Uji E2E');
    await pumpUntil(tester, find.text('Uji E2E'));
    await tester.tap(rowMenu('Uji E2E'));
    await pumpUntil(tester, find.text('Ubah nama'));
    await tester.tap(find.text('Ubah nama'));
    await typeAndConfirm(tester, 'Uji E2E 2', 'Simpan');
    await pumpUntilTrue(
      tester,
      () => fx.collections().any((c) => c['name'] == 'Uji E2E 2'),
      'koleksi-ganti-nama',
    );
    diag('koleksi diganti nama');

    // Tambah berkas ke koleksi lewat ⋮.
    await showTree(tester);
    await revealInTree(tester, 'Uji E2E 2');
    await pumpUntil(tester, find.text('Uji E2E 2'));
    picker.files.add(<String>[p.join(fx.outside, 'tambahan.pdf')]);
    await tester.tap(rowMenu('Uji E2E 2'));
    await pumpUntil(tester, find.text('Tambahkan berkas ke sini…'));
    await tester.tap(find.text('Tambahkan berkas ke sini…'));
    final ujiKey = fx.collections().firstWhere((c) => c['name'] == 'Uji E2E 2')['key'];
    await pumpUntilTrue(
      tester,
      () => fx.items().any(
        (i) =>
            (i['zotero'] as Map)['title'] == 'tambahan' &&
            ((i['zotero'] as Map)['collections'] as List).contains(ujiKey),
      ),
      'berkas-ke-koleksi',
    );
    diag('berkas masuk ke koleksi');

    // Pindahkan koleksi ke bawah "Kripto".
    await showTree(tester);
    await tester.tap(rowMenu('Uji E2E 2'));
    await pumpUntil(tester, find.text('Pindahkan ke…'));
    await tester.tap(find.text('Pindahkan ke…'));
    await pumpUntil(tester, find.text('Kripto').last);
    await tester.tap(find.text('Kripto').last);
    await pumpUntilTrue(
      tester,
      () => fx.collections().any((c) => c['name'] == 'Uji E2E 2' && c['parentKey'] == 'COLL0001'),
      'koleksi-dipindah',
    );
    diag('koleksi dipindah ke Kripto');

    // Ekspor BibTeX koleksi Kripto ke folder kerja.
    await showTree(tester);
    await revealInTree(tester, 'Kripto');
    await tester.tap(rowMenu('Kripto'));
    await pumpUntil(tester, find.text('Ekspor ke BibTeX (.bib)'));
    await tester.tap(find.text('Ekspor ke BibTeX (.bib)'));
    final bib = File(p.join((await tester.runAsync(WorkFolder.dir))!.path, 'Kripto.bib'));
    await pumpUntilTrue(tester, bib.existsSync, 'bibtex');
    expect(bib.readAsStringSync(), contains('Naether'));
    diag('BibTeX: ${bib.path}');

    // Impor folder ke library: folder jadi koleksi, subfolder jadi sub-koleksi.
    await showTree(tester);
    picker.directories.add(p.join(fx.outside, 'bahan-seminar'));
    await treeTop(tester);
    await tester.tap(find.byTooltip('Tambahkan berkas atau folder ke library'));
    await pumpUntil(tester, find.text('Tambahkan folder (jadi koleksi)…'));
    await tester.tap(find.text('Tambahkan folder (jadi koleksi)…'));
    await pumpUntil(tester, find.text('Impor'));
    await tester.tap(find.text('Impor'));
    await pumpUntilTrue(
      tester,
      () =>
          fx.collections().any((c) => c['name'] == 'bahan-seminar') &&
          fx.collections().any((c) => c['name'] == 'data') &&
          fx.items().any((i) => (i['zotero'] as Map)['title'] == 'slide') &&
          fx.items().any((i) => (i['zotero'] as Map)['title'] == 'hasil'),
      'impor-folder',
    );
    diag('folder diimpor jadi koleksi bertingkat');

    // Hapus koleksi: dikonfirmasi, paper di dalamnya tetap ada.
    await showTree(tester);
    await revealInTree(tester, 'Kripto');
    await expand(tester, 'Kripto');
    await revealInTree(tester, 'Uji E2E 2');
    await pumpUntil(tester, find.text('Uji E2E 2'));
    await tester.tap(rowMenu('Uji E2E 2'));
    await pumpUntil(tester, find.text('Hapus koleksi'));
    await tester.tap(find.text('Hapus koleksi'));
    await pumpUntil(tester, find.text('Ya, hapus'));
    await tester.tap(find.text('Ya, hapus'));
    await pumpUntilTrue(
      tester,
      () => !fx.collections().any((c) => c['name'] == 'Uji E2E 2'),
      'koleksi-dihapus',
    );
    expect(fx.items().any((i) => (i['zotero'] as Map)['title'] == 'tambahan'), isTrue);
    diag('koleksi dihapus, paper tetap');

    // ---------------------------------------------------------------- catatan
    await showTree(tester);
    await revealInTree(tester, 'Catatan');
    await tester.tap(find.byTooltip('Koleksi catatan baru'));
    await typeAndConfirm(tester, 'Catatan E2E', 'Simpan');
    final notesDir = p.join(fx.repo, 'catatan');
    await pumpUntilTrue(
      tester,
      () =>
          File(p.join(notesDir, 'koleksi.json')).existsSync() &&
          File(p.join(notesDir, 'koleksi.json')).readAsStringSync().contains('Catatan E2E'),
      'koleksi-catatan',
    );
    await showTree(tester);
    await revealInTree(tester, 'Catatan E2E');
    await tester.tap(
      find
          .descendant(of: find.byType(CollectionTreePane), matching: find.text('Catatan E2E'))
          .first,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    await closeDrawer(tester);

    picker.files.add(<String>[p.join(fx.outside, 'tambahan.pdf')]);
    await pumpUntil(tester, find.byTooltip('Tambahkan berkas atau folder ke Catatan E2E'));
    await tester.tap(find.byTooltip('Tambahkan berkas atau folder ke Catatan E2E'));
    await pumpUntil(tester, find.text('Tambahkan berkas…'));
    await tester.tap(find.text('Tambahkan berkas…'));
    await pumpUntil(tester, find.text('tambahan'));
    diag('berkas masuk ke koleksi catatan dan tampil');

    await tester.tap(find.byTooltip('Catatan Markdown baru'));
    await typeAndConfirm(tester, 'MD E2E', 'Simpan');
    final editor = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText ?? '').startsWith('Tulis di sini'),
    );
    await pumpUntil(tester, editor);
    await tester.enterText(editor, '# Judul\n\nIsi catatan **uji** windows.');
    await tester.pump();
    await tester.tap(find.byTooltip('Simpan'));
    await pumpFor(tester, const Duration(seconds: 2));
    await back(tester);
    await pumpUntil(tester, find.text('MD E2E'));
    await pumpUntilTrue(
      tester,
      () => Directory(notesDir)
          .listSync(recursive: true)
          .whereType<File>()
          .any((f) => f.path.endsWith('.md') && f.readAsStringSync().contains('uji** windows')),
      'markdown-tersimpan',
    );
    diag('catatan Markdown tersimpan');

    // PDF di Catatan: anotasi tersimpan seketika ke anotasi.json di folder
    // catatannya — tanpa "Simpan sebagai", dan tetap ada saat dibuka lagi.
    await openNoteFromList(tester, 'tambahan');
    await pumpUntil(tester, find.text('Tandai'));
    await pumpFor(tester, const Duration(seconds: 4));
    await tester.tap(find.text('Tandai'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    final noteViewer = tester.getRect(find.byType(PdfViewer));
    final ny = noteViewer.top + noteViewer.height * 0.45;
    final noteDrag = await tester.startGesture(
      Offset(noteViewer.left + noteViewer.width * 0.2, ny),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 20; i++) {
      await noteDrag.moveTo(Offset(noteViewer.left + noteViewer.width * (0.2 + 0.03 * i), ny));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await noteDrag.up();
    File? sidecar() => Directory(notesDir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.basename(f.path) == 'anotasi.json')
        .firstOrNull;
    await pumpUntilTrue(
      tester,
      () => sidecar()?.readAsStringSync().contains('"highlight"') ?? false,
      'anotasi-catatan-tersimpan',
    );
    await tester.tap(find.text('Menandai'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Supaya terbaca di Zotero: PDF catatan ditambahkan ke library, dan
    // anotasinya ikut ke item Zotero barunya.
    await tester.tap(find.byTooltip('Simpan dan bagikan'));
    await pumpUntil(tester, find.text('Tambahkan ke koleksi…'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Tambahkan ke koleksi…'));
    await pumpUntil(tester, find.text('Tanpa koleksi'));
    await tester.tap(find.text('Tanpa koleksi').last);
    await typeAndConfirm(tester, 'Catatan ke Zotero', 'Tambahkan');
    Map<String, dynamic>? toZotero() =>
        fx.items().where((i) => (i['zotero'] as Map)['title'] == 'Catatan ke Zotero').firstOrNull;
    await pumpUntilTrue(
      tester,
      () =>
          toZotero() != null &&
          (toZotero()!['children'] as List).any(
            (c) => (c as Map)['itemType'] == 'annotation' && c['annotationType'] == 'highlight',
          ),
      'catatan-ke-zotero',
    );
    final created = toZotero()!;
    final attachment = (created['children'] as List).cast<Map<String, dynamic>>().firstWhere(
      (c) => c['itemType'] == 'attachment',
    );
    final carried = (created['children'] as List).cast<Map<String, dynamic>>().firstWhere(
      (c) => c['itemType'] == 'annotation',
    );
    expect(carried['parentItem'], attachment['key'], reason: 'anotasi menempel di lampiran baru');
    diag('PDF catatan ke library: anotasinya ikut ke item Zotero');
    await back(tester);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(
      find.text('Simpan perubahan dulu?'),
      findsNothing,
      reason: 'anotasi catatan sudah tersimpan, tidak perlu Simpan sebagai',
    );
    await pumpUntil(tester, find.text('tambahan'));
    await openNoteFromList(tester, 'tambahan');
    await pumpUntil(tester, find.textContaining('1 anotasi'));
    await back(tester);
    await pumpUntil(tester, find.text('tambahan'));
    diag('anotasi PDF catatan tersimpan dan terbaca lagi');

    // ------------------------------------------------------------- pencarian
    await showTree(tester);
    await treeTop(tester);
    // Baris akar library (ikonnya), bukan teks "uji" di kepala panel.
    await tester.tap(find.byIcon(Icons.local_library_outlined).first);
    await pumpFor(tester, const Duration(seconds: 1));
    await closeDrawer(tester);
    final search = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText ?? '').startsWith('Cari judul'),
    );
    diag('kolom cari: ${search.evaluate().length}');
    await shot(tester, 'f1-sebelum-cari');
    await tester.enterText(search, 'pengarang:Karisma');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Sinkronisasi Zotero lewat Git'), findsWidgets);
    expect(find.text('Migrasi kriptografi pascakuantum'), findsNothing);
    await tester.enterText(search, 'tahun:2024');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Migrasi kriptografi pascakuantum'), findsWidgets);
    expect(find.text('Sinkronisasi Zotero lewat Git'), findsNothing);
    await tester.enterText(search, '');
    await pumpFor(tester, const Duration(seconds: 1));
    diag('pencarian beroperator');

    await tester.tap(find.byTooltip('Statistik library'));
    await pumpFor(tester, const Duration(seconds: 2));
    await shot(tester, 'f1-statistik');
    await back(tester);
    await pumpFor(tester, const Duration(seconds: 1));
    diag('statistik terbuka');

    // ------------------------------------------------- pembaca lewat "Baca"
    await tester.tap(find.text('Sinkronisasi Zotero lewat Git').first);
    await pumpUntil(tester, find.text('Baca'));
    await tester.tap(find.text('Baca'));
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpFor(tester, const Duration(seconds: 4));

    // Cari kata: 26 baris PDF-nya memuat "commit"; Enter maju satu hasil.
    await tester.tap(find.byTooltip('Cari di dokumen (Ctrl+F)'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey<String>('find-field')), 'commit');
    await pumpUntil(tester, find.text('1 dari 26'));
    await tester.tap(find.byTooltip('Berikutnya (Enter)'));
    await pumpUntil(tester, find.text('2 dari 26'));
    await shot(tester, 'f2-cari');
    await tester.tap(find.byTooltip('Tutup pencarian (Esc)'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    diag('cari di PDF');

    var viewer = tester.getRect(find.byType(PdfViewer));
    final item2 = fx.itemFile('ITEMKEY2');
    List<Map<String, dynamic>> annotations() => (fx.readJson(item2)['children'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((c) => c['itemType'] == 'annotation')
        .toList();

    // Garis bawah: pilih teks dengan seret mouse, lalu "Garis bawah".
    final y = viewer.top + viewer.height * 0.45;
    final sel = await tester.startGesture(
      Offset(viewer.left + viewer.width * 0.2, y),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 20; i++) {
      await sel.moveTo(Offset(viewer.left + viewer.width * (0.2 + 0.03 * i), y));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await sel.up();
    await pumpFor(tester, const Duration(seconds: 1));
    await shot(tester, 'f2-seleksi');
    final underline = find.text('Garis bawah').evaluate().isNotEmpty
        ? find.text('Garis bawah').last
        : find.byTooltip('Garis bawah').last;
    await tester.tap(underline);
    await pumpUntilTrue(
      tester,
      () => annotations().any((a) => a['annotationType'] == 'underline'),
      'garis-bawah',
    );
    diag('garis bawah tersimpan');

    // Pena: satu goresan, lalu selesai menggambar.
    final stylusOnly = tooltipStarting('Stylus saja');
    if (stylusOnly.evaluate().isNotEmpty) {
      await tester.tap(stylusOnly.first);
      await tester.pump();
    }
    await tester.tap(find.byTooltip('Tulis atau gambar di halaman'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    viewer = tester.getRect(find.byType(PdfViewer));
    final pen = await tester.startGesture(
      Offset(viewer.left + viewer.width * 0.3, viewer.top + viewer.height * 0.7),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 15; i++) {
      await pen.moveTo(
        Offset(
          viewer.left + viewer.width * (0.3 + 0.02 * i),
          viewer.top + viewer.height * (0.7 + 0.005 * i),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await pen.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Selesai menggambar'));
    await pumpUntilTrue(
      tester,
      () => annotations().any((a) => a['annotationType'] == 'ink'),
      'tinta',
    );
    diag('goresan pena tersimpan');

    // Urungkan lalu ulangi goresan itu.
    diag(
      'tinta sebelum urungkan: ${annotations().where((a) => a['annotationType'] == 'ink').map((a) => a['key']).toList()}',
    );
    diag(
      'tombol urungkan: ${tooltipStarting('Urungkan').evaluate().map((e) => (e.widget as Tooltip).message).toList()}',
    );
    await tester.tap(tooltipStarting('Urungkan').first);
    await pumpUntilTrue(
      tester,
      () => !annotations().any((a) => a['annotationType'] == 'ink'),
      'urungkan',
      seconds: 8,
    ).catchError((Object e) {
      diag(
        'tinta sesudah urungkan: ${annotations().where((a) => a['annotationType'] == 'ink').map((a) => a['key']).toList()}',
      );
      throw e;
    });
    await tester.tap(tooltipStarting('Ulangi').first);
    await pumpUntilTrue(
      tester,
      () => annotations().any((a) => a['annotationType'] == 'ink'),
      'ulangi',
    );
    diag('urungkan dan ulangi');

    await tester.tap(find.byTooltip('Warna halaman: Normal'));
    await pumpUntil(tester, find.byTooltip('Warna halaman: Sepia'));
    diag('warna halaman berganti');

    // Catatan gaya Zotero: penanda kecil; balonnya terbuka saat dibuat,
    // ditutup, lalu dibuka lagi dengan mengetuk penandanya.
    await tester.tap(find.byTooltip('Tempel catatan di halaman'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    viewer = tester.getRect(find.byType(PdfViewer));
    final notePoint = Offset(viewer.left + viewer.width * 0.6, viewer.top + viewer.height * 0.3);
    await tester.tapAt(notePoint, kind: PointerDeviceKind.mouse);
    await pumpUntil(tester, find.text('Simpan'));
    await tester.enterText(find.byType(TextField).last, 'Catatan uji Zotero');
    await tester.tap(find.text('Simpan'));
    await pumpUntilTrue(
      tester,
      () => annotations().any(
        (a) => a['annotationType'] == 'note' && a['annotationComment'] == 'Catatan uji Zotero',
      ),
      'catatan-zotero',
    );
    final noteJson = annotations().singleWhere((a) => a['annotationType'] == 'note');
    expect(noteJson['annotationPosition'], contains('"rects"'));
    await pumpUntil(tester, find.byTooltip('Tutup catatan'));
    await shot(tester, 'f3a-catatan-terbuka');
    await tester.tap(find.byTooltip('Tutup catatan'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byTooltip('Tutup catatan'), findsNothing, reason: 'balon tertutup');
    // Tengah ikonnya, dihitung dari bingkai pilihannya sekarang: halamannya
    // sudah bergeser sejak catatan dibuat (bilah petunjuk mode catatan hilang).
    // Ikon ada 26 px di dalam pojok kiri atas bingkai, selebar ~22 pt.
    final frame = tester.getTopLeft(find.byTooltip('Seret untuk memindahkan'));
    await tester.tapAt(frame + const Offset(26 + 16, 26 + 16), kind: PointerDeviceKind.mouse);
    await pumpUntil(tester, find.byTooltip('Tutup catatan'));
    await tester.tap(find.byTooltip('Tutup catatan'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    diag('catatan gaya Zotero: dibuat, ditutup, dibuka lagi');

    // Teks di halaman (Tt): diputar dan diperbesar lewat pegangannya.
    await tester.tap(find.byTooltip('Isi teks di halaman — untuk mengisi formulir'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    final textPoint = Offset(viewer.left + viewer.width * 0.3, viewer.top + viewer.height * 0.55);
    await tester.tapAt(textPoint, kind: PointerDeviceKind.mouse);
    await pumpUntil(tester, find.text('Simpan'));
    await tester.enterText(find.byType(TextField).last, 'Teks diputar');
    await tester.tap(find.text('Simpan'));
    Map<String, dynamic>? textJson() => annotations()
        .where((a) => a['annotationType'] == 'text' && a['annotationComment'] == 'Teks diputar')
        .firstOrNull;
    await pumpUntilTrue(tester, () => textJson() != null, 'teks-dibuat');
    // Mengetuknya memilihnya (dan membuka penyunting, yang dibatalkan).
    await tester.tapAt(textPoint + const Offset(8, 6), kind: PointerDeviceKind.mouse);
    await pumpUntil(tester, find.text('Batal'));
    await tester.tap(find.text('Batal'));
    await pumpUntil(tester, find.byTooltip('Seret untuk memutar'));
    await tester.drag(find.byTooltip('Seret untuk memutar'), const Offset(80, 0));

    await pumpUntilTrue(
      tester,
      () => (jsonDecode(textJson()!['annotationPosition'] as String)['rotation'] as num) != 0,
      'teks-diputar',
    );
    await pumpUntil(tester, find.byTooltip('Seret untuk mengubah ukuran'));
    await tester.drag(find.byTooltip('Seret untuk mengubah ukuran'), const Offset(40, 40));
    await pumpUntilTrue(
      tester,
      () => (jsonDecode(textJson()!['annotationPosition'] as String)['fontSize'] as num) > 12,
      'teks-diperbesar',
    );
    final turned = jsonDecode(textJson()!['annotationPosition'] as String) as Map;
    expect(turned['rotation'], isNot(0), reason: 'memperbesar tidak boleh menghapus sudutnya');
    await shot(tester, 'f3b-teks-diputar');
    diag('teks di halaman: diputar dan diperbesar ${textJson()!['annotationPosition']}');
    await shot(tester, 'f3-pembaca');

    await back(tester);
    await pumpFor(tester, const Duration(seconds: 1));
    if (find.text('Keluar tanpa menyimpan').evaluate().isNotEmpty) {
      fail('Paper library tidak boleh meminta simpan: anotasinya sudah tersimpan');
    }
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));

    // PDF catatan dibuka lagi dari "Terakhir dibaca": anotasinya tetap ada.
    final recent = find.descendant(
      of: find.byType(RecentPapersCard),
      matching: find.text('tambahan'),
    );
    await pumpUntil(tester, recent);
    await tester.tap(recent.first);
    await pumpUntil(tester, find.textContaining('1 anotasi'));
    await back(tester);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    diag('PDF catatan dari Terakhir dibaca: anotasinya terbaca');

    // ----------------------------------------------------------- panel berkas
    // Pesan di bawah menutupi kepala panel berkas yang terlipat.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).clearSnackBars();
    await pumpFor(tester, const Duration(milliseconds: 500));
    await showTree(tester);
    if (find.byTooltip('Buat baru di folder ini').hitTestable().evaluate().isEmpty) {
      // Di laci, panel berkas terlipat secara bawaan.
      await tester.tap(find.byType(FileBrowserPane).last);
      await pumpFor(tester, const Duration(milliseconds: 600));
    }
    await tester.tap(find.byTooltip('Buat baru di folder ini'));
    await pumpUntil(tester, find.text('Berkas Markdown'));
    await tester.tap(find.text('Berkas Markdown'));
    await typeAndConfirm(tester, 'berkas-e2e', 'Buat');
    await pumpUntil(tester, find.byType(BackButton));
    await back(tester);
    await pumpFor(tester, const Duration(seconds: 1));
    final work = (await tester.runAsync(WorkFolder.dir))!.path;
    expect(File(p.join(work, 'berkas-e2e.md')).existsSync(), isTrue);
    diag('berkas Markdown dibuat di folder kerja');

    await showTree(tester);
    if (find.text('berkas-e2e.md').evaluate().isEmpty) {
      await tester.tap(find.byType(FileBrowserPane).last);
      await pumpFor(tester, const Duration(milliseconds: 600));
    }
    await pumpUntil(tester, find.text('berkas-e2e.md'));
    Finder entryMenu(String name) => find
        .descendant(
          of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
          matching: find.byTooltip('Tindakan berkas'),
        )
        .first;
    await tester.tap(entryMenu('berkas-e2e.md'));
    await pumpUntil(tester, find.text('Ganti nama'));
    await tester.tap(find.text('Ganti nama'));
    await typeAndConfirm(tester, 'berkas-e2e-2.md', 'Simpan');
    await pumpUntilTrue(
      tester,
      () => File(p.join(work, 'berkas-e2e-2.md')).existsSync(),
      'berkas-ganti-nama',
    );
    await pumpUntil(tester, find.text('berkas-e2e-2.md'));
    await tester.tap(entryMenu('berkas-e2e-2.md'));
    await pumpUntil(tester, find.text('Hapus berkas'));
    await pumpFor(tester, const Duration(milliseconds: 500)); // menu selesai terbuka
    await tester.tap(find.text('Hapus berkas'));
    await pumpUntil(tester, find.text('Hapus'));
    await tester.tap(find.text('Hapus').last);
    await pumpUntilTrue(
      tester,
      () => !File(p.join(work, 'berkas-e2e-2.md')).existsSync(),
      'berkas-dihapus',
    );
    File(p.join(work, 'Kripto.bib')).deleteSync();
    await closeDrawer(tester);
    diag('panel berkas: buat, ganti nama, hapus');

    // ------------------------------------------------------------ sinkronisasi
    // Semua perubahan di atas menunggu sebagai perubahan lokal; Kirim
    // meng-commit semuanya sekaligus dengan ringkasan, lalu mengirim.
    expect(await fx.status(), isNotEmpty, reason: 'perubahan menunggu Kirim');
    expect(await fx.commitCount(), 1, reason: 'belum ada commit selain awal');
    await tester.tap(find.byTooltip('Kirim perubahan ke GitHub'));
    await pumpUntil(tester, find.text('Commit & kirim'));
    final message = tester
        .widget<TextField>(
          find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
        )
        .controller!
        .text;
    diag('pesan commit usulan: ${message.split('\n').first}');
    expect(message, contains('Tambah koleksi'));
    expect(message, contains('Hapus koleksi'));
    await tester.tap(find.text('Commit & kirim'));
    await pumpUntilTrue(
      tester,
      () async => await fx.commitCount(fx.remote) == 2 && (await fx.status()).isEmpty,
      'kirim',
      seconds: 60,
    );
    final local = await fx.commitCount();
    diag('kirim: remote menerima $local commit');

    // Perubahan dari "mesin lain", lalu tarik.
    final other = p.join(fx.root.path, 'lain');
    await tester.runAsync(() async {
      await Process.run('git', <String>[
        'clone',
        '-q',
        fx.remote,
        other,
      ], runInShell: Platform.isWindows);
      await Fixture.gitIn(other, <String>['config', 'user.email', 'lain@readpaper.test']);
      await Fixture.gitIn(other, <String>['config', 'user.name', 'Lain']);
      final cols = p.join(other, 'zotero', 'uji', 'collections.json');
      // Di Windows git meng-checkout dengan CRLF (autocrlf); polanya harus
      // menerima keduanya, kalau tidak tidak ada yang berubah untuk di-commit.
      final before = File(cols).readAsStringSync();
      final after = before.replaceFirst(
        RegExp(r'^\[\r?\n'),
        '[\n\t{\n\t\t"key": "LAIN0001",\n\t\t"name": "Dari mesin lain",\n\t\t"parentKey": null,'
        '\n\t\t"path": "Dari mesin lain",\n\t\t"relations": {}\n\t},\n',
      );
      expect(after, isNot(before), reason: 'collections.json mesin lain harus berubah');
      File(cols).writeAsStringSync(after);
      final commit = await Fixture.gitIn(other, <String>[
        'commit',
        '-qam',
        'Koleksi dari mesin lain',
      ]);
      expect(commit.exitCode, 0, reason: '${commit.stdout}${commit.stderr}');
      final push = await Fixture.gitIn(other, <String>['push', '-q']);
      expect(push.exitCode, 0, reason: '${push.stderr}');
    });
    diag(
      'remote setelah mesin lain: ${await tester.runAsync(() => fx.commitCount(fx.remote))} commit',
    );
    // Bila sinkronisasi lain masih berjalan, aplikasi menolak dengan "tunggu
    // sampai selesai" — seperti pengguna, uji ini mencoba lagi.
    for (var i = 0; i < 5 && tooltipStarting('Tarik 1 commit baru').evaluate().isEmpty; i++) {
      await tester.tap(find.byTooltip('Periksa perubahan di remote'));
      await pumpFor(tester, const Duration(seconds: 5));
    }
    diag(
      'tombol tarik: ${tooltipStarting('Tarik').evaluate().map((e) => (e.widget as Tooltip).message).toList()} | ${snackText()}',
    );
    await pumpUntil(tester, tooltipStarting('Tarik 1 commit baru'), seconds: 60);
    await tester.tap(tooltipStarting('Tarik').first);
    await pumpUntilTrue(
      tester,
      () => fx.collections().any((c) => c['name'] == 'Dari mesin lain'),
      'tarik',
      seconds: 60,
    );
    await showTree(tester);
    await revealInTree(tester, 'Dari mesin lain');
    await pumpUntil(tester, find.text('Dari mesin lain'));
    diag('tarik: koleksi dari mesin lain tampil');
    await shot(tester, 'f4-akhir');
  });
}

/// Mengetuk catatan menampilkan keterangannya; berkasnya dibuka dengan
/// tombol Buka di panel keterangan.
Future<void> openNoteFromList(WidgetTester tester, String title) async {
  await tester.tap(find.descendant(of: find.byType(NoteListPane), matching: find.text(title)).first);
  final open = find.descendant(
    of: find.byType(NoteDetailPane),
    matching: find.widgetWithText(FilledButton, 'Buka'),
  );
  await pumpUntil(tester, open);
  await tester.tap(open);
}
