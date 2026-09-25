import 'dart:convert';
import 'dart:typed_data';

/// One page of a flattened export: a JPEG that fills the whole page.
class PdfImagePage {
  const PdfImagePage({
    required this.jpeg,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.widthPt,
    required this.heightPt,
  });

  /// JPEG bytes, embedded as-is — PDF reads them natively as `DCTDecode`.
  final Uint8List jpeg;

  final int pixelWidth;
  final int pixelHeight;

  /// The page size in PDF points, so the export keeps the paper's real size
  /// however finely it was rendered.
  final double widthPt;
  final double heightPt;
}

/// Writes the smallest PDF that can hold a sequence of full-page images.
///
/// This exists instead of a PDF library because that is all a flattened
/// export needs: one image XObject per page, drawn to fill it. The JPEG bytes
/// go in untouched, so the file is no bigger than the images themselves.
///
/// What it deliberately does not do is preserve the original text layer —
/// pages come out as pictures. The export that keeps text and real PDF
/// annotations is a separate job; see docs/anotasi-ekspor-pdf.md.
Uint8List writeImagePdf(List<PdfImagePage> pages) {
  if (pages.isEmpty) throw ArgumentError('PDF tanpa halaman tidak bisa ditulis');

  final out = BytesBuilder(copy: false);
  // Byte offset of every object, indexed by object number; entry 0 is the
  // free-list head the xref table always starts with.
  final offsets = <int>[0];

  void put(String s) => out.add(ascii.encode(s));
  void putBytes(List<int> b) => out.add(b);

  int begin() {
    offsets.add(out.length);
    return offsets.length - 1;
  }

  // A binary comment on line two tells tools the file is not plain text.
  put('%PDF-1.4\n');
  putBytes(<int>[0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

  // Object numbers are laid out first so the page tree can reference pages
  // that have not been written yet.
  const catalogNum = 1;
  const pagesNum = 2;
  final pageNums = <int>[];
  final contentNums = <int>[];
  final imageNums = <int>[];
  var next = 3;
  for (var i = 0; i < pages.length; i++) {
    pageNums.add(next++);
    contentNums.add(next++);
    imageNums.add(next++);
  }

  var n = begin();
  assert(n == catalogNum);
  put('$catalogNum 0 obj\n<< /Type /Catalog /Pages $pagesNum 0 R >>\nendobj\n');

  n = begin();
  assert(n == pagesNum);
  final kids = pageNums.map((p) => '$p 0 R').join(' ');
  put('$pagesNum 0 obj\n<< /Type /Pages /Kids [$kids] /Count ${pages.length} >>\nendobj\n');

  for (var i = 0; i < pages.length; i++) {
    final page = pages[i];
    final w = _num(page.widthPt);
    final h = _num(page.heightPt);

    begin();
    put(
      '${pageNums[i]} 0 obj\n'
      '<< /Type /Page /Parent $pagesNum 0 R /MediaBox [0 0 $w $h] '
      '/Resources << /XObject << /Im0 ${imageNums[i]} 0 R >> >> '
      '/Contents ${contentNums[i]} 0 R >>\nendobj\n',
    );

    // Scale the unit image square up to the page, then draw it.
    final content = 'q\n$w 0 0 $h 0 0 cm\n/Im0 Do\nQ\n';
    begin();
    put(
      '${contentNums[i]} 0 obj\n<< /Length ${content.length} >>\nstream\n'
      '$content'
      'endstream\nendobj\n',
    );

    begin();
    put(
      '${imageNums[i]} 0 obj\n'
      '<< /Type /XObject /Subtype /Image /Width ${page.pixelWidth} '
      '/Height ${page.pixelHeight} /ColorSpace /DeviceRGB /BitsPerComponent 8 '
      '/Filter /DCTDecode /Length ${page.jpeg.length} >>\nstream\n',
    );
    putBytes(page.jpeg);
    put('\nendstream\nendobj\n');
  }

  final xrefStart = out.length;
  final count = offsets.length;
  put('xref\n0 $count\n');
  put('0000000000 65535 f \n');
  for (var i = 1; i < count; i++) {
    put('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
  }
  put(
    'trailer\n<< /Size $count /Root $catalogNum 0 R >>\n'
    'startxref\n$xrefStart\n%%EOF\n',
  );

  return out.takeBytes();
}

/// PDF numbers have no exponent form and no trailing `.0`.
String _num(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(3);
}
