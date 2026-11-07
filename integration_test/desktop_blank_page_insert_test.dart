import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:readpaper/main.dart' as app;
import 'package:readpaper/src/core/utils/work_folder.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/reader/data/pdf_page_editor.dart';

import 'support.dart';

/// Halaman kosong disisipkan di tengah slide yang sudah dicoreti.
///
///   flutter test integration_test/desktop_blank_page_insert_test.dart -d linux
///
/// Dulu halaman kosongnya hanya ada di salinan kerja sementara, sedangkan
/// coretannya tersimpan ke library dengan nomor halaman salinan itu — dan
/// coretan yang sudah ada tidak digeser sama sekali. Dibuka lagi, halaman
/// kosongnya hilang dan coretannya jatuh di slide sebelum atau sesudahnya.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fx;
  late String pdf;
  final keptBefore = <String>{};

  setUpAll(() async {
    fx = await Fixture.create();
    pdf = p.join(fx.library, 'attachments', 'AT', 'ATTACH01', 'paper.pdf');
    File(pdf).writeAsBytesSync(await _slides());

    // Satu coretan di setiap slide.
    final item = fx.readJson(fx.itemFile('ITEMKEY1'));
    (item['children'] as List<dynamic>).addAll(<dynamic>[
      for (var i = 0; i < 3; i++)
        ZoteroAnnotation(
          key: 'INKSLID$i',
          parentItemKey: 'ATTACH01',
          type: AnnotationType.ink,
          color: '#ff0000',
          pageIndex: i,
          paths: <InkPath>[
            InkPath(<double>[100, 100, 300, 300]),
          ],
          pageLabel: '${i + 1}',
          sortIndex: ZoteroAnnotation.buildSortIndex(
            pageIndex: i,
            textOffset: 0,
            topFromPageTop: 240,
          ),
          dateAdded: DateTime.utc(2026, 11, 1),
          dateModified: DateTime.utc(2026, 11, 1),
        ).toJson(),
    ]);
    Fixture.write(fx.itemFile('ITEMKEY1'), const JsonEncoder.withIndent('\t').convert(item));
    await fx.git(<String>['add', '-A']);
    await fx.git(<String>['commit', '-q', '-m', 'slide bercoret']);

    final work = await WorkFolder.dir();
    keptBefore.addAll(work.listSync().map((e) => e.path));
  });

  tearDownAll(() async {
    // Salinan asli yang dibuat uji ini ada di folder kerja sungguhan.
    final work = await WorkFolder.dir();
    for (final e in work.listSync()) {
      if (!keptBefore.contains(e.path) && e.path.contains('-asli')) e.deleteSync();
    }
  });

  List<Map<String, dynamic>> inks() {
    final item = fx.readJson(fx.itemFile('ITEMKEY1'));
    return (item['children'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((c) => c['itemType'] == 'annotation')
        .toList();
  }

  int pageOf(Map<String, dynamic> a) =>
      (jsonDecode(a['annotationPosition'] as String) as Map<String, dynamic>)['pageIndex'] as int;

  testWidgets('halaman kosong di tengah: tersimpan di PDF, coretan ikut bergeser', (tester) async {
    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    await tester.tap(find.text('Migrasi kriptografi pascakuantum').first);
    await pumpUntil(tester, find.text('Baca'));
    await tester.tap(find.text('Baca'));
    await pumpUntil(tester, find.byType(PdfViewer));
    await pumpFor(tester, const Duration(seconds: 3));

    await tester.tap(find.byTooltip('Tambah lembar kosong'));
    await pumpFor(tester, const Duration(seconds: 1));
    await shot(tester, 'sisip-pilihan');
    await tester.tap(find.textContaining('setelah halaman 1').first);
    await pumpUntil(tester, find.text('Simpan versi aslinya?'));
    await shot(tester, 'sisip-tawaran-asli');
    await tester.tap(find.text('Simpan salinan asli'));
    await pumpFor(tester, const Duration(seconds: 6));
    await shot(tester, 'sisip-sesudah');

    // PDF di library sendiri sekarang punya halaman kosongnya.
    expect(PdfPageEditor.pageCount(pdf), 4);

    // Slide 1 tetap; slide 2 dan 3 sekarang halaman 3 dan 4.
    final byKey = <String, int>{for (final a in inks()) a['key'] as String: pageOf(a)};
    diag('halaman coretan: $byKey');
    expect(byKey, <String, int>{'INKSLID0': 0, 'INKSLID1': 2, 'INKSLID2': 3});
    final labels = <String, String>{
      for (final a in inks()) a['key'] as String: a['annotationPageLabel'] as String,
    };
    expect(labels['INKSLID1'], '3');

    // Versi aslinya, tiga slide, tersimpan di folder kerja.
    final work = await WorkFolder.dir();
    final kept = work
        .listSync()
        .whereType<File>()
        .where((f) => !keptBefore.contains(f.path) && f.path.contains('-asli'))
        .toList();
    expect(kept, hasLength(1));
    expect(PdfPageEditor.pageCount(kept.single.path), 3);

    // Semuanya masuk satu perubahan git yang sama — PDF dan anotasinya.
    final status = await fx.status();
    diag('status git: $status');
  });
}

/// Tiga slide 4:3.
Future<Uint8List> _slides() async {
  final doc = pw.Document();
  for (var i = 1; i <= 3; i++) {
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(720, 540),
        build: (_) =>
            pw.Center(child: pw.Text('Slide $i', style: const pw.TextStyle(fontSize: 64))),
      ),
    );
  }
  return doc.save();
}
