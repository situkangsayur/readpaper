import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/reader/presentation/widgets/annotation_move_layer.dart';

void main() {
  Future<({List<double> rotations, List<double> scales, List<int> taps})> pump(
    WidgetTester tester,
  ) async {
    final rotations = <double>[];
    final scales = <double>[];
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 600,
            child: Stack(
              children: <Widget>[
                AnnotationMoveLayer(
                  bounds: const Rect.fromLTWH(200, 200, 120, 40),
                  limit: const Size(600, 600),
                  onMoved: (_) {},
                  onDelete: () {},
                  onTap: () => taps.add(1),
                  onTransformed: ({double scale = 1, double rotation = 0}) {
                    scales.add(scale);
                    rotations.add(rotation);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return (rotations: rotations, scales: scales, taps: taps);
  }

  testWidgets('pegangan putar memutar, juga bila bingkainya bisa diketuk', (tester) async {
    final r = await pump(tester);
    await tester.drag(find.byTooltip('Seret untuk memutar'), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(r.rotations, hasLength(1));
    expect(r.rotations.single, isNot(0));
    expect(r.taps, isEmpty);
  });

  testWidgets('pegangan ukuran memperbesar', (tester) async {
    final r = await pump(tester);
    await tester.drag(find.byTooltip('Seret untuk mengubah ukuran'), const Offset(40, 40));
    await tester.pumpAndSettle();
    expect(r.scales.single, greaterThan(1));
  });

  testWidgets('ketukan di anotasi terpilih sampai ke onTap', (tester) async {
    final r = await pump(tester);
    await tester.tapAt(const Offset(260, 220), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(r.taps, hasLength(1));
  });
}
