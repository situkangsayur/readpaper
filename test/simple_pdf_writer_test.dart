import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/utils/simple_pdf_writer.dart';

/// The shortest thing a PDF reader will accept as a JPEG body; the writer
/// never looks inside it, so its contents do not matter here.
final _jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);

PdfImagePage page({double w = 612, double h = 792}) =>
    PdfImagePage(jpeg: _jpeg, pixelWidth: 100, pixelHeight: 130, widthPt: w, heightPt: h);

void main() {
  test('refuses to write a PDF with no pages', () {
    expect(() => writeImagePdf(<PdfImagePage>[]), throwsArgumentError);
  });

  group('a one-page PDF', () {
    late Uint8List bytes;
    late String text;

    setUp(() {
      bytes = writeImagePdf(<PdfImagePage>[page()]);
      text = latin1.decode(bytes);
    });

    test('starts with a header and ends with the end marker', () {
      expect(text.startsWith('%PDF-1.4\n'), isTrue);
      expect(text.trimRight().endsWith('%%EOF'), isTrue);
      // The binary comment keeps tools from treating the file as text.
      expect(bytes.sublist(9, 14), <int>[0x25, 0xE2, 0xE3, 0xCF, 0xD3]);
    });

    test('declares the page size in points, without a trailing .0', () {
      expect(text, contains('/MediaBox [0 0 612 792]'));
    });

    test('embeds the JPEG untouched, as DCTDecode', () {
      expect(text, contains('/Filter /DCTDecode'));
      expect(text, contains('/Length ${_jpeg.length}'));
      final start = text.indexOf('/DCTDecode');
      final streamAt = text.indexOf('stream\n', start) + 'stream\n'.length;
      expect(bytes.sublist(streamAt, streamAt + _jpeg.length), _jpeg);
    });

    test('every xref offset points at the object that claims that number', () {
      final startxref = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!);
      expect(text.substring(startxref, startxref + 4), 'xref');

      final header = RegExp(r'xref\n0 (\d+)\n').firstMatch(text.substring(startxref))!;
      final count = int.parse(header.group(1)!);
      // Catalog, page tree, then page + contents + image for the one page.
      expect(count, 6);

      final entries = RegExp(r'(\d{10}) 00000 n ').allMatches(text.substring(startxref)).toList();
      expect(entries.length, count - 1);
      for (var i = 0; i < entries.length; i++) {
        final offset = int.parse(entries[i].group(1)!);
        expect(
          text.startsWith('${i + 1} 0 obj', offset),
          isTrue,
          reason: 'entri xref ${i + 1} menunjuk ke posisi yang salah',
        );
      }
    });
  });

  test('a three-page PDF lists every page in the tree', () {
    final text = latin1.decode(writeImagePdf(<PdfImagePage>[page(), page(), page()]));
    expect(text, contains('/Count 3'));
    expect(RegExp(r'/Type /Page[^s]').allMatches(text).length, 3);
    expect(text, contains('/Kids [3 0 R 6 0 R 9 0 R]'));
  });
}
