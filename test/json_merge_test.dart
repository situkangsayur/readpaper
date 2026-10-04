import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/sync/domain/json_merge.dart';

String _koleksi(List<(String, String, String?)> rows) => JsonMerge.encode(<Object?>[
  for (final (key, name, parent) in rows)
    <String, Object?>{'key': key, 'name': name, 'parentKey': parent},
]);

void main() {
  test('koleksi catatan dari dua perangkat disatukan — kasus nyata di p14s', () {
    // Laptop membuat "phd" lalu "proposal" di dalamnya; tablet, sementara itu,
    // membuat koleksi-koleksinya sendiri. git menyebutnya bentrok.
    final base = _koleksi(<(String, String, String?)>[]);
    final remote = _koleksi(<(String, String, String?)>[
      ('3D5UVKG8', 'ml-2026', 'GDHJB9MU'),
      ('79MRPNSW', 'phd', null),
      ('GDHJB9MU', 'stmik-tazkia', null),
    ]);
    final local = _koleksi(<(String, String, String?)>[
      ('9B4SWSJG', 'phd', null),
      ('I6KF894R', 'proposal', '9B4SWSJG'),
    ]);

    final merged = JsonMerge.mergeText(base: base, remote: remote, local: local)!;
    final keys = (jsonDecode(merged) as List).map((e) => (e as Map)['key']).toList();
    expect(keys, <String>['3D5UVKG8', '79MRPNSW', '9B4SWSJG', 'GDHJB9MU', 'I6KF894R']);
    expect(merged, contains('\t\t"name": "proposal"'), reason: 'format plugin: identasi tab');
    expect(merged.endsWith(']\n'), isTrue);
  });

  test('penghapusan di satu sisi dihormati, perubahan di sisi lain ikut', () {
    final base = _koleksi(<(String, String, String?)>[('A', 'satu', null), ('B', 'dua', null)]);
    final remote = _koleksi(<(String, String, String?)>[('B', 'dua', null)]);
    final local = _koleksi(<(String, String, String?)>[
      ('A', 'satu', null),
      ('B', 'dua (diubah)', null),
    ]);
    final merged = jsonDecode(JsonMerge.mergeText(base: base, remote: remote, local: local)!);
    expect(merged, <Object?>[
      <String, Object?>{'key': 'B', 'name': 'dua (diubah)', 'parentKey': null},
    ]);
  });

  test('anotasi item Zotero dari dua perangkat, metadata dari Zotero', () {
    Map<String, Object?> annotation(String key, String text) => <String, Object?>{
      'key': key,
      'annotationText': text,
      'itemType': 'annotation',
    };
    final base = JsonMerge.encode(<String, Object?>{
      'zotero': <String, Object?>{'title': 'Judul lama'},
      'children': <Object?>[annotation('AAAA', 'pertama')],
    });
    final remote = JsonMerge.encode(<String, Object?>{
      'zotero': <String, Object?>{'title': 'Judul dari Zotero'},
      'children': <Object?>[annotation('AAAA', 'pertama'), annotation('BBBB', 'dari tablet')],
    });
    final local = JsonMerge.encode(<String, Object?>{
      'zotero': <String, Object?>{'title': 'Judul lama'},
      'children': <Object?>[annotation('AAAA', 'pertama'), annotation('CCCC', 'dari laptop')],
    });
    final merged =
        jsonDecode(JsonMerge.mergeText(base: base, remote: remote, local: local)!) as Map;
    expect((merged['zotero'] as Map)['title'], 'Judul dari Zotero');
    expect((merged['children'] as List).map((e) => (e as Map)['key']), <String>[
      'AAAA',
      'BBBB',
      'CCCC',
    ]);
  });

  test('kolom yang diubah di dua sisi: lokal menang', () {
    final merged = JsonMerge.mergeText(base: '{"a": 1}', remote: '{"a": 2}', local: '{"a": 3}');
    expect(jsonDecode(merged!), <String, Object?>{'a': 3});
  });

  test('yang bukan JSON tidak digabung', () {
    expect(JsonMerge.mergeText(base: '# a', remote: '# b', local: '# c'), isNull);
  });
}
