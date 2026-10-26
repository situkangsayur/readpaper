import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/utils/tree_signature.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('rp_sig_'));
  tearDown(() => root.deleteSync(recursive: true));

  String sig() => treeSignatureSync(<String>[
    p.join(root.path, 'collections.json'),
    p.join(root.path, 'items'),
  ]);

  test('berubah saat berkas di sub-folder ditambah, diubah, atau dihapus', () async {
    File(p.join(root.path, 'collections.json')).writeAsStringSync('[]');
    final item = File(p.join(root.path, 'items', 'AB', 'ABCD1234.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"key":"ABCD1234"}');
    final first = sig();
    expect(sig(), first, reason: 'tanpa perubahan, sidiknya tetap');

    // Folder ember baru dengan paper baru — yang dulu baru tampil setelah
    // aplikasi ditutup.
    final added = File(p.join(root.path, 'items', 'ZQ', 'ZQ998877.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"key":"ZQ998877"}');
    final second = sig();
    expect(second, isNot(first));

    // Ditulis ulang dengan ukuran yang sama (pull mengubah satu bidang). Di
    // Windows waktu ubahnya hanya sampai detik, jadi tulisan berikutnya harus
    // jatuh di detik lain — seperti pemeriksaan sungguhan, tiap 3 detik.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    item.writeAsStringSync('{"key":"ABCD1235"}');
    final third = sig();
    expect(third, isNot(second));

    added.deleteSync();
    expect(sig(), isNot(third));
  });

  test('berkas atau folder yang belum ada tidak membuatnya gagal', () {
    final empty = sig();
    File(p.join(root.path, 'collections.json')).writeAsStringSync('[]');
    expect(sig(), isNot(empty));
  });
}
