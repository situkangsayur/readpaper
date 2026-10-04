import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/reader/presentation/widgets/annotation_move_layer.dart';

void main() {
  /// Kotak geser di dalam ruang seukuran halaman.
  Future<void> pump(
    WidgetTester tester, {
    required Rect bounds,
    required VoidCallback onDelete,
    Size limit = const Size(300, 400),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: limit.width,
              height: limit.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const Positioned.fill(child: ColoredBox(color: Colors.white)),
                  AnnotationMoveLayer(
                    bounds: bounds,
                    limit: limit,
                    onMoved: (_) {},
                    onDelete: onDelete,
                    onTransformed: ({double scale = 1, double rotation = 0}) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hapus bisa ditekan untuk anotasi di tengah halaman', (tester) async {
    var deleted = 0;
    await pump(tester, bounds: const Rect.fromLTWH(100, 150, 80, 40), onDelete: () => deleted++);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('hapus tetap bisa ditekan untuk anotasi yang menempel di sudut', (tester) async {
    // Inilah keluhannya: tong sampahnya terlihat tetapi tidak bisa ditekan.
    // Pegangan yang jatuh di luar induknya tidak pernah menerima sentuhan.
    var deleted = 0;
    await pump(tester, bounds: const Rect.fromLTWH(0, 0, 60, 30), onDelete: () => deleted++);

    final chip = tester.getRect(find.byIcon(Icons.delete_outline));
    expect(chip.top, greaterThanOrEqualTo(tester.getRect(find.byType(Stack).first).top - 0.01));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('pegangan di sudut kanan bawah juga tetap di dalam halaman', (tester) async {
    var deleted = 0;
    await pump(tester, bounds: const Rect.fromLTWH(240, 360, 60, 40), onDelete: () => deleted++);

    final page = tester.getRect(find.byType(Stack).first);
    for (final tooltip in <String>['Seret untuk mengubah ukuran', 'Seret untuk memutar']) {
      final grip = tester.getRect(find.byTooltip(tooltip));
      expect(grip.right, lessThanOrEqualTo(page.right + 0.01), reason: tooltip);
      expect(grip.bottom, lessThanOrEqualTo(page.bottom + 0.01), reason: tooltip);
    }

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('bingkainya tetap menempel di anotasinya meski kotaknya digeser masuk', (
    tester,
  ) async {
    await pump(tester, bounds: const Rect.fromLTWH(0, 0, 60, 30), onDelete: () {});
    // Bingkai dalamnya digambar oleh DecoratedBox di dalam Padding; letaknya
    // harus tetap sama dengan batas anotasinya, bukan ikut bergeser.
    final page = tester.getRect(find.byType(Stack).first);
    final frame = tester.getRect(find.byType(DecoratedBox).last);
    expect(frame.left - page.left, closeTo(0, 0.5));
    expect(frame.top - page.top, closeTo(0, 0.5));
    expect(frame.width, closeTo(60, 0.5));
    expect(frame.height, closeTo(30, 0.5));
  });
}
