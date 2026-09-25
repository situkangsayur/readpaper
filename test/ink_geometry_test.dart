import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';

void main() {
  group('InkPath', () {
    test('round-trips through the flat list Zotero stores', () {
      const stroke = InkPath(<double>[10, 20, 30.5, 40.25]);
      expect(stroke.length, 2);
      expect(stroke.xAt(0), 10);
      expect(stroke.yAt(0), 20);
      expect(stroke.xAt(1), 30.5);
      expect(stroke.yAt(1), 40.25);
      expect(InkPath.fromList(stroke.toList()).points, stroke.points);
    });

    test('whole numbers stay whole, as the plugin writes them', () {
      // A trailing .0 turns a one-line edit into a whole-file diff.
      expect(const InkPath(<double>[72, 144]).toList(), <num>[72, 144]);
      expect(const InkPath(<double>[72, 144]).toList().first is int, isTrue);
    });
  });

  group('ink annotation', () {
    ZoteroAnnotation build() => ZoteroAnnotation(
      key: 'INKKEY01',
      parentItemKey: 'ATTACH01',
      type: AnnotationType.ink,
      color: '#ff6666',
      pageIndex: 2,
      paths: const <InkPath>[
        InkPath(<double>[10, 20, 30, 40]),
        InkPath(<double>[50, 60, 70, 80]),
      ],
      inkWidth: 4,
      pageLabel: '3',
      sortIndex: '00002|000000|00100',
      dateAdded: DateTime.utc(2026, 9, 25, 10),
      dateModified: DateTime.utc(2026, 9, 25, 10),
    );

    test('writes paths and width into the position, and no rects', () {
      final json = build().toJson();
      final position = json['annotationPosition'] as String;
      expect(position, contains('"paths"'));
      expect(position, contains('"width":4'));
      expect(position, isNot(contains('"rects"')));
      expect(json['annotationType'], 'ink');
    });

    test('survives a round trip through fromJson', () {
      final original = build();
      final restored = ZoteroAnnotation.fromJson(original.toJson());
      expect(restored.type, AnnotationType.ink);
      expect(restored.inkWidth, 4);
      expect(restored.paths.length, 2);
      expect(restored.paths.first.points, <double>[10, 20, 30, 40]);
      expect(restored.paths.last.points, <double>[50, 60, 70, 80]);
    });
  });
}
