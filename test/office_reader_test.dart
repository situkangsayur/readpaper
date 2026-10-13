import 'dart:io';

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:readpaper/src/features/files/domain/table_data.dart';
import 'package:readpaper/src/features/office/data/doc_reader.dart';
import 'package:readpaper/src/features/office/data/docx_reader.dart';
import 'package:readpaper/src/features/office/data/office_loader.dart';
import 'package:readpaper/src/features/office/data/ppt_reader.dart';
import 'package:readpaper/src/features/office/data/pptx_reader.dart';
import 'package:readpaper/src/features/office/domain/office_document.dart';

List<int> fixture(String name) => File('test/fixtures/office/$name').readAsBytesSync();

void main() {
  test('docx: judul, gaya huruf, butir, nomor, tabel, gambar', () {
    final doc = DocxReader.read(File('test/fixtures/office/contoh.docx').readAsBytesSync());
    final paragraphs = doc.blocks.whereType<OfficeParagraph>().toList();
    expect(paragraphs.first.text, 'Laporan Uji Kuantum');
    expect(paragraphs.first.heading, 1);
    expect(paragraphs[1].heading, 1);
    final styled = paragraphs[2];
    expect(styled.runs.firstWhere((r) => r.text == 'tebal').bold, isTrue);
    final red = styled.runs.firstWhere((r) => r.text == 'miring merah');
    expect(red.italic, isTrue);
    expect(red.color, const Color(0xFFC00000));
    expect(paragraphs.firstWhere((p) => p.text == 'Butir satu').bullet, '•');
    expect(paragraphs.firstWhere((p) => p.text == 'Langkah pertama').bullet, '1.');
    expect(paragraphs.firstWhere((p) => p.text == 'Langkah kedua').bullet, '2.');
    final table = doc.blocks.whereType<OfficeTable>().single;
    expect(table.rows[1][1].single.text, '12 ms');
    expect(doc.blocks.whereType<OfficeImage>(), hasLength(1));
    expect(searchParagraphs(doc.paragraphs, 'LATENSI'), hasLength(3));
  });

  test('pptx: slide, posisi warisan tata letak, gambar, catatan', () {
    final doc = PptxReader.read(File('test/fixtures/office/contoh.pptx').readAsBytesSync());
    expect(doc.slides, hasLength(2));
    expect(doc.slideSize.width, closeTo(960, 1));
    final first = doc.slides.first;
    final title = first.shapes.firstWhere((s) => s.isTitle);
    expect(title.paragraphs.single.text, 'Migrasi Pascakuantum');
    expect(title.frame, isNotNull);
    expect(first.notes.single.text, 'Sapa audiens dulu.');
    final second = doc.slides[1];
    final body = second.shapes.firstWhere(
      (s) => s.paragraphs.any((p) => p.text == 'Kyber tercepat'),
    );
    expect(body.paragraphs.first.bullet, '•');
    expect(body.paragraphs[1].level, 1);
    expect(second.shapes.where((s) => s.image != null), hasLength(1));
    final source = second.shapes.firstWhere(
      (s) => s.paragraphs.any((p) => p.text.startsWith('Sumber')),
    );
    expect(source.paragraphs.single.runs.single.size, 14);
    expect(second.background, const Color(0xFFFFFFFF));
  });

  test('doc lama: paragraf dan tabel', () {
    final doc = DocReader.read(Uint8List.fromList(fixture('contoh.doc')));
    final texts = doc.paragraphs.map((p) => p.text).toList();
    expect(texts, contains('Laporan Uji Kuantum'));
    expect(texts.any((t) => t.contains('miring merah')), isTrue);
    final table = doc.blocks.whereType<OfficeTable>().single;
    expect(table.rows, hasLength(2));
    expect(table.rows[1][1].single.text, '12 ms');
    expect(texts, contains('Latensi turun pada semua uji.'));
  });

  test('xls lama: lembar dan sel', () {
    final sheets = TableData.read('contoh.xls', Uint8List.fromList(fixture('contoh.xls')));
    expect(sheets.first.rows[0], <String>['Algoritma', 'Latensi', 'Ukuran']);
    expect(sheets.first.rows[1], <String>['Kyber', '12', '800']);
    expect(sheets.first.rows[2][1], '15,5');
    expect(sheets.first.rows[2][2], '2420');
  });

  test('ppt lama: teks per slide, judul dulu', () {
    final bytes = Uint8List.fromList(GZipDecoder().decodeBytes(fixture('contoh.ppt.gz')));
    final doc = PptReader.read(bytes);
    expect(doc.slides, hasLength(2));
    expect(doc.slides.first.shapes.first.isTitle, isTrue);
    expect(doc.slides.first.shapes.first.paragraphs.single.text, 'Migrasi Pascakuantum');
    final texts = doc.slides[1].shapes.expand((s) => s.paragraphs).map((p) => p.text).toList();
    expect(texts, containsAll(<String>['Hasil Latensi', 'Kyber tercepat', 'Dilithium stabil']));
  });

  test('isi berkas yang menentukan, bukan akhirannya', () {
    final docx = Uint8List.fromList(fixture('contoh.docx'));
    expect(readOffice('salah-nama.doc', docx).paragraphs.first.text, 'Laporan Uji Kuantum');
    expect(
      () => readOffice('x.docx', Uint8List.fromList(<int>[1, 2, 3, 4, 5])),
      throwsFormatException,
    );
  });
}
