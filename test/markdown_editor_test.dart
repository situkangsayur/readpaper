import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/markdown/presentation/screens/markdown_editor_screen.dart';
import 'package:readpaper/src/features/markdown/presentation/widgets/markdown_view.dart';
import 'package:readpaper/src/features/markdown/presentation/widgets/mermaid_view.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('readpaper-md-'));
  tearDown(() => dir.deleteSync(recursive: true));

  const sample = '''
# Catatan Rapat

Yang disepakati **hari ini**.

- satu
- dua

```mermaid
graph TD
  A[Mulai] --> B{Sudah?}
```
''';

  File write(String name, String body) =>
      File(p.join(dir.path, name))..writeAsStringSync(body);

  /// Menunggu pekerjaan berkas yang sungguhan selesai.
  ///
  /// Penyuntingnya membaca dan menulis berkas betulan; `pumpAndSettle` saja
  /// tidak pernah sampai ke sana karena waktu di dalam uji widget palsu.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String path, {bool startInEdit = false}) async {
    await tester.pumpWidget(
      MaterialApp(home: MarkdownEditorScreen(path: path, startInEdit: startInEdit)),
    );
    await settle(tester);
  }

  testWidgets('berkas yang ada dibuka sebagai pratinjau', (tester) async {
    final file = write('rapat.md', sample);
    await open(tester, file.path);

    expect(find.byType(MarkdownView), findsOneWidget);
    expect(find.textContaining('Catatan Rapat'), findsWidgets);
    expect(find.textContaining('hari ini'), findsWidgets);
    // Diagramnya digambar, bukan ditulis sebagai kode.
    expect(find.byType(MermaidView), findsOneWidget);
    expect(find.textContaining('graph TD'), findsNothing);
  });

  testWidgets('berkas baru dibuka langsung di mode sunting', (tester) async {
    await open(tester, p.join(dir.path, 'belum-ada.md'), startInEdit: true);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('mengetik lalu menyimpan menulis berkasnya', (tester) async {
    final file = write('isi.md', '# Awal\n');
    await open(tester, file.path);

    await tester.tap(find.byTooltip('Sunting'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '# Awal\n\nBaris baru.\n');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Simpan'));
    await settle(tester);
    expect(file.readAsStringSync(), contains('Baris baru.'));
  });

  testWidgets('menyimpan mati sampai ada yang berubah', (tester) async {
    final file = write('utuh.md', '# Utuh\n');
    await open(tester, file.path);
    final save = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('Simpan'), matching: find.byType(IconButton)).first,
    );
    expect(save.onPressed, isNull, reason: 'belum ada yang perlu disimpan');
  });

  testWidgets('mengetuk diagram membawa kursor ke sumbernya', (tester) async {
    // Inilah yang membuat diagram "bisa disunting" dan bukan hanya dilihat.
    final file = write('diagram.md', sample);
    await open(tester, file.path);

    await tester.tap(find.byType(MermaidView));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    final controller = field.controller!;
    final selected = controller.text.substring(
      controller.selection.start,
      controller.selection.end,
    );
    expect(selected, startsWith('```mermaid'));
    expect(selected, contains('graph TD'));
    expect(selected, endsWith('```'));
  });

  testWidgets('tombol sisip menambahkan diagram baru', (tester) async {
    final file = write('sisip.md', '# Judul\n');
    await open(tester, file.path, startInEdit: true);

    await tester.tap(find.byTooltip('Diagram mermaid'));
    await tester.pumpAndSettle();

    final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(controller.text, contains('```mermaid'));
    expect(controller.text, contains('graph TD'));
  });

  testWidgets('keluar selagi ada perubahan menanyakannya dulu', (tester) async {
    final file = write('tanya.md', '# Ada\n');
    await open(tester, file.path, startInEdit: true);
    await tester.enterText(find.byType(TextField), '# Ada\n\nberubah\n');
    await tester.pumpAndSettle();

    final state = tester.state<NavigatorState>(find.byType(Navigator));
    state.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Simpan dulu?'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await settle(tester);
    expect(file.readAsStringSync(), contains('berubah'));
  });
}
