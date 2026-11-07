import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/reader/domain/page_insertion.dart';

void main() {
  ZoteroAnnotation inkOn(int pageIndex, {String? label}) => ZoteroAnnotation(
    key: 'INK$pageIndex',
    parentItemKey: 'PARENT01',
    type: AnnotationType.ink,
    color: '#ff0000',
    pageIndex: pageIndex,
    paths: <InkPath>[
      InkPath(<double>[10, 20, 30, 40]),
    ],
    pageLabel: label ?? '${pageIndex + 1}',
    sortIndex: ZoteroAnnotation.buildSortIndex(
      pageIndex: pageIndex,
      textOffset: 0,
      topFromPageTop: 120,
    ),
  );

  // Slide 1..5 masing-masing punya satu coretan; satu halaman kosong
  // disisipkan setelah slide 3 (indeks 3).
  final slides = <ZoteroAnnotation>[for (var i = 0; i < 5; i++) inkOn(i)];

  test('coretan sebelum halaman sisipan tidak bergeser', () {
    final after = PageInsertion.apply(slides, at: 3, count: 1);
    expect(after.take(3).map((a) => a.pageIndex), <int>[0, 1, 2]);
    expect(identical(after[0], slides[0]), isTrue);
  });

  test('coretan sesudahnya mundur sebanyak halaman yang disisipkan', () {
    final after = PageInsertion.apply(slides, at: 3, count: 2);
    expect(after.map((a) => a.pageIndex), <int>[0, 1, 2, 5, 6]);
    // Tidak ada yang tertinggal di halaman kosong yang baru.
    expect(after.where((a) => a.pageIndex == 3 || a.pageIndex == 4), isEmpty);
  });

  test('hanya yang terdampak dikembalikan untuk disimpan', () {
    final moved = PageInsertion.shifted(slides, at: 3, count: 1);
    expect(moved.map((a) => a.key), <String>['INK3', 'INK4']);
  });

  test('label, indeks urut, dan posisi tersimpan ikut nomor halaman baru', () {
    final moved = PageInsertion.shift(slides[3], by: 1);
    expect(moved.pageLabel, '5');
    expect(moved.sortIndex, startsWith('00004|'));
    expect(moved.sortIndex.substring(5), slides[3].sortIndex.substring(5));
    final position = jsonDecode(moved.toJson()['annotationPosition'] as String) as Map;
    expect(position['pageIndex'], 4);
    expect(moved.paths.single.points, slides[3].paths.single.points);
  });

  test('label yang bukan nomor halaman dibiarkan', () {
    final moved = PageInsertion.shift(inkOn(2, label: 'iii'), by: 1);
    expect(moved.pageLabel, 'iii');
    expect(moved.pageIndex, 3);
  });

  test('disisipkan di depan: semuanya bergeser', () {
    final after = PageInsertion.apply(slides, at: 0, count: 1);
    expect(after.map((a) => a.pageIndex), <int>[1, 2, 3, 4, 5]);
  });

  test('ditambahkan di akhir: tidak ada yang bergeser', () {
    expect(PageInsertion.shifted(slides, at: 5, count: 3), isEmpty);
  });

  test('catatan presenter ikut bergeser, bernomor mulai 1', () {
    final notes = PageInsertion.notes(<int, String>{1: 'a', 3: 'c', 4: 'd'}, at: 3, count: 1);
    expect(notes, <int, String>{1: 'a', 3: 'c', 5: 'd'});
  });
}
