import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/files/presentation/file_browser_pane.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool collapsed}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                if (collapsed)
                  FileBrowserPane(collapsed: true, onToggleCollapsed: () {})
                else
                  Expanded(child: FileBrowserPane(onToggleCollapsed: () {})),
              ],
            ),
          ),
        ),
      ),
    );
    // Panelnya membaca folder kerja sungguhan; cukup satu putaran.
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('kepala panel memuat empat kendali, bukan tujuh', (tester) async {
    // Tujuh ikon berdesakan di panel selebar 300 titik adalah sebab kenapa
    // "buat folder" dan "buka berkas" tidak pernah ketemu.
    await pump(tester, collapsed: false);

    expect(find.byTooltip('Buat baru di folder ini'), findsOneWidget);
    expect(find.byTooltip('Naik satu tingkat'), findsOneWidget);
    expect(find.byTooltip('Salin berkas ke sini — dari mana pun di perangkat'), findsOneWidget);
    expect(find.byTooltip('Buka folder lain'), findsOneWidget);
    // Yang dulu berdiri sendiri sekarang di dalam satu menu.
    expect(find.byTooltip('Papan tulis baru'), findsNothing);
    expect(find.byTooltip('Buku catatan baru'), findsNothing);
  });

  testWidgets('menu buat memuat papan tulis, buku catatan, markdown, dan folder',
      (tester) async {
    await pump(tester, collapsed: false);
    await tester.tap(find.byTooltip('Buat baru di folder ini'));
    await tester.pumpAndSettle();

    for (final label in <String>['Papan tulis', 'Buku catatan', 'Berkas Markdown', 'Folder']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('terlipat: hanya kepalanya, tanpa daftar berkas', (tester) async {
    await pump(tester, collapsed: true);
    expect(find.byType(ListView), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    // Kendali isian panelnya ikut hilang, jadi tidak ada tombol yang menggantung.
    expect(find.byTooltip('Buat baru di folder ini'), findsNothing);
  });
}
