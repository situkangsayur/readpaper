import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/files/domain/table_data.dart';

Uint8List xlsx(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('CSV', () {
    test('kutip, kutip ganda, dan baris baru di dalam sel', () {
      final rows = TableData.csv('nama,catatan\n"Hendri, K","kata ""ya""\nbaris dua"\r\nx,y');
      expect(rows, <List<String>>[
        <String>['nama', 'catatan'],
        <String>['Hendri, K', 'kata "ya"\nbaris dua'],
        <String>['x', 'y'],
      ]);
    });

    test('titik koma dari Excel berbahasa Indonesia dikenali sendiri', () {
      final sheets = TableData.read(
        'data.csv',
        Uint8List.fromList(utf8.encode('a;b;c\n1,5;2;3\n')),
      );
      expect(sheets.single.rows, <List<String>>[
        <String>['a', 'b', 'c'],
        <String>['1,5', '2', '3'],
      ]);
    });

    test('TSV', () {
      final sheets = TableData.read('data.tsv', Uint8List.fromList(utf8.encode('a\tb\n1\t2')));
      expect(sheets.single.rows.last, <String>['1', '2']);
    });
  });

  test('xlsx: string bersama, angka, sel yang dilompati, dua lembar', () {
    final bytes = xlsx(<String, String>{
      'xl/workbook.xml':
          '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="Data" sheetId="1" r:id="rId1"/>'
          '<sheet name="Ringkas" sheetId="2" r:id="rId2"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Target="worksheets/sheet2.xml"/></Relationships>',
      'xl/sharedStrings.xml': '<sst><si><t>Judul</t></si><si><r><t>Tahun</t></r></si></sst>',
      'xl/worksheets/sheet1.xml':
          '<worksheet><sheetData>'
          '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="s"><v>1</v></c></row>'
          '<row r="3"><c r="A3" t="inlineStr"><is><t>Kuantum</t></is></c><c r="C3"><v>2024</v></c></row>'
          '</sheetData></worksheet>',
      'xl/worksheets/sheet2.xml':
          '<worksheet><sheetData><row r="1"><c r="B1" t="b"><v>1</v></c></row></sheetData></worksheet>',
    });
    final sheets = TableData.read('paper.xlsx', bytes);
    expect(sheets.map((s) => s.name), <String>['Data', 'Ringkas']);
    expect(sheets.first.rows, <List<String>>[
      <String>['Judul', '', 'Tahun'],
      <String>[],
      <String>['Kuantum', '', '2024'],
    ]);
    expect(sheets.first.columnCount, 3);
    expect(sheets.last.rows.single, <String>['', 'TRUE']);
  });
}
