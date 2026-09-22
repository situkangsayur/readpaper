import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/utils/layout_size.dart';

void main() {
  group('LayoutSize.fromWidth', () {
    test('a phone in portrait shows one pane', () {
      expect(LayoutSize.fromWidth(360), LayoutSize.compact);
      expect(LayoutSize.fromWidth(411), LayoutSize.compact);
      expect(LayoutSize.fromWidth(599), LayoutSize.compact);
    });

    test('a phone in landscape and a tablet in portrait share the middle size', () {
      expect(LayoutSize.fromWidth(600), LayoutSize.medium);
      expect(LayoutSize.fromWidth(800), LayoutSize.medium, reason: 'tablet at 240dpi');
      expect(LayoutSize.fromWidth(901), LayoutSize.medium, reason: 'tablet at 213dpi');
      expect(LayoutSize.fromWidth(960), LayoutSize.medium, reason: 'tablet at 200dpi');
      expect(LayoutSize.fromWidth(1099), LayoutSize.medium);
    });

    test('a tablet in landscape and a desktop get all three panes', () {
      expect(LayoutSize.fromWidth(1100), LayoutSize.expanded);
      expect(LayoutSize.fromWidth(1280), LayoutSize.expanded, reason: 'tablet at 240dpi');
      expect(LayoutSize.fromWidth(1536), LayoutSize.expanded, reason: 'tablet at 200dpi');
      expect(LayoutSize.fromWidth(1920), LayoutSize.expanded);
    });

    test('the collection tree only stays on screen at the largest size', () {
      expect(LayoutSize.compact.treeInDrawer, isTrue);
      expect(LayoutSize.medium.treeInDrawer, isTrue);
      expect(LayoutSize.expanded.treeInDrawer, isFalse);
    });

    test('list and detail sit together from the middle size up', () {
      expect(LayoutSize.compact.showsListAndDetail, isFalse);
      expect(LayoutSize.medium.showsListAndDetail, isTrue);
      expect(LayoutSize.expanded.showsListAndDetail, isTrue);
    });
  });

  group('LayoutSize.of', () {
    /// Builds a widget under a forced window size and reports what it saw.
    Future<LayoutSize> measure(WidgetTester tester, Size size) async {
      late LayoutSize seen;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: Builder(
            builder: (context) {
              seen = LayoutSize.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return seen;
    }

    testWidgets('reads the window width, not the height', (tester) async {
      // A tablet held in portrait is tall but only ~960dp across.
      expect(await measure(tester, const Size(960, 1536)), LayoutSize.medium);
      // The same tablet turned sideways.
      expect(await measure(tester, const Size(1536, 960)), LayoutSize.expanded);
      // A phone.
      expect(await measure(tester, const Size(411, 914)), LayoutSize.compact);
    });
  });
}
