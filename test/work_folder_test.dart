import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/utils/work_folder.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('rp-kerja-'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('nama berkas baru tidak menimpa yang sudah ada', () {
    // Menyimpan dua kali dari dokumen yang sama tidak boleh membuat yang
    // pertama hilang tanpa ditanya.
    final satu = WorkFolder.freshFile(dir, 'paper-terisi', '.pdf');
    expect(p.basename(satu.path), 'paper-terisi.pdf');
    satu.writeAsStringSync('x');

    final dua = WorkFolder.freshFile(dir, 'paper-terisi', '.pdf');
    expect(p.basename(dua.path), 'paper-terisi-2.pdf');
    dua.writeAsStringSync('x');

    expect(p.basename(WorkFolder.freshFile(dir, 'paper-terisi', '.pdf').path),
        'paper-terisi-3.pdf');
    expect(satu.readAsStringSync(), 'x', reason: 'yang pertama utuh');
  });

  test('akar folder kerja disebut namanya, sub-folder memakai nama sendiri', () {
    expect(WorkFolder.label(Directory('/a/b/${WorkFolder.name}')), 'Folder kerja');
    expect(WorkFolder.label(Directory('/a/b/${WorkFolder.name}/Rapat')), 'Rapat');
  });
}
