import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../files/domain/table_data.dart';
import '../domain/office_document.dart';
import 'emf_picture.dart';

/// Mengubah dokumen Office ke PDF di dalam ReadPaper sendiri, tanpa
/// LibreOffice — supaya di Android pun dokumen Word, PowerPoint, dan Excel
/// bisa disimpan sebagai PDF, dan presentasi bisa diputar dengan mode
/// menyajikan dan mode baca milik pembaca PDF.
///
/// Slide menjadi gambar per halaman (seperti tampil di layar) dengan teksnya
/// ditulis tak terlihat di atasnya, jadi tetap bisa dicari dan disalin.
/// Dokumen Word dan lembar Excel ditulis sebagai teks dan tabel sungguhan.
class OfficePdf {
  const OfficePdf._();

  static pw.ThemeData? _theme;

  /// Huruf TrueType dari sistem bila ada: font baku PDF (Helvetica) hanya
  /// kenal Latin-1, sehingga huruf Yunani, tanda pisah, atau kutip melengkung
  /// hilang tanpa jejak.
  static Future<pw.ThemeData> _loadTheme() async {
    final cached = _theme;
    if (cached != null) return cached;
    pw.Font? load(List<String> paths) {
      for (final path in paths) {
        final file = File(path);
        if (file.existsSync()) {
          try {
            return pw.Font.ttf(ByteData.sublistView(file.readAsBytesSync()));
          } on Object {
            // Font rusak atau bukan TrueType; coba yang lain.
          }
        }
      }
      return null;
    }

    final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final regular = load(<String>[
      '/system/fonts/Roboto-Regular.ttf',
      '/system/fonts/NotoSans-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/TTF/DejaVuSans.ttf',
      '/usr/share/fonts/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
      '/usr/share/fonts/noto/NotoSans-Regular.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
      '$windows\\Fonts\\arial.ttf',
      '$windows\\Fonts\\segoeui.ttf',
      '/Library/Fonts/Arial Unicode.ttf',
      '/System/Library/Fonts/Supplemental/Arial.ttf',
    ]);
    final bold = load(<String>[
      '/system/fonts/Roboto-Bold.ttf',
      '/system/fonts/NotoSans-Bold.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
      '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
      '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf',
      '/usr/share/fonts/noto/NotoSans-Bold.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
      '$windows\\Fonts\\arialbd.ttf',
      '$windows\\Fonts\\segoeuib.ttf',
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ]);
    final italic = load(<String>[
      '/system/fonts/Roboto-Italic.ttf',
      '/system/fonts/NotoSans-Italic.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf',
      '/usr/share/fonts/TTF/DejaVuSans-Oblique.ttf',
      '/usr/share/fonts/dejavu/DejaVuSans-Oblique.ttf',
      '/usr/share/fonts/truetype/noto/NotoSans-Italic.ttf',
      '/usr/share/fonts/noto/NotoSans-Italic.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Italic.ttf',
      '$windows\\Fonts\\ariali.ttf',
      '$windows\\Fonts\\segoeuii.ttf',
      '/System/Library/Fonts/Supplemental/Arial Italic.ttf',
    ]);
    final theme = regular == null
        ? pw.ThemeData.base()
        : pw.ThemeData.withFont(
            base: regular,
            bold: bold ?? regular,
            italic: italic ?? regular,
            boldItalic: bold ?? italic ?? regular,
          );
    return _theme = theme;
  }

  // ------------------------------------------------------------ presentasi

  /// PDF dari gambar slide [images] (PNG, urutan sama dengan [doc].slides),
  /// satu halaman per slide seukuran slidenya.
  static Future<Uint8List> slides(OfficeDocument doc, List<Uint8List> images) async {
    final theme = await _loadTheme();
    final font = theme.defaultTextStyle.font!;
    final pdf = pw.Document(theme: theme);
    final size = doc.slideSize;
    for (var i = 0; i < images.length && i < doc.slides.length; i++) {
      final slide = doc.slides[i];
      final picture = pw.MemoryImage(images[i]);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(size.width, size.height),
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Stack(
            children: <pw.Widget>[
              pw.Positioned.fill(child: pw.Image(picture, fit: pw.BoxFit.fill)),
              pw.Positioned.fill(child: _InvisibleText(font, slide, size)),
            ],
          ),
        ),
      );
    }
    return pdf.save();
  }

  // ------------------------------------------------------------ dokumen Word

  /// PDF A4 dari dokumen teks: judul, paragraf, butir, tabel, gambar.
  static Future<Uint8List> document(OfficeDocument doc) async {
    final theme = await _loadTheme();
    final pdf = pw.Document(theme: theme);
    final children = <pw.Widget>[];
    for (final block in doc.blocks) {
      final widget = await _block(block);
      if (widget != null) children.add(widget);
    }
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 60),
        build: (context) => children.isEmpty ? <pw.Widget>[pw.SizedBox()] : children,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ),
    );
    return pdf.save();
  }

  static Future<pw.Widget?> _block(OfficeBlock block) async {
    switch (block) {
      case OfficeParagraph():
        return _paragraph(block, 11);
      case OfficeTable():
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: _table(block),
        );
      case OfficeImage():
        final bytes = await _imageBytes(block.bytes);
        if (bytes == null) return null;
        final width = block.width;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Image(
            pw.MemoryImage(bytes),
            width: width == null ? null : (width > 483 ? 483 : width),
            fit: pw.BoxFit.contain,
          ),
        );
    }
  }

  /// PNG/JPEG apa adanya; EMF digambar dulu jadi PNG; sisanya dilewati.
  static Future<Uint8List?> _imageBytes(Uint8List bytes) async {
    final emf = EmfPicture.of(bytes);
    if (emf != null) {
      await prepareEmfImages(emf);
      return emf.toPng();
    }
    final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final jpeg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    return png || jpeg ? bytes : null;
  }

  static pw.Widget _paragraph(OfficeParagraph para, double base) {
    final factor = switch (para.heading) {
      1 => 1.75,
      2 => 1.4,
      3 => 1.2,
      0 => 1.0,
      _ => 1.08,
    };
    final spans = <pw.InlineSpan>[
      for (final run in para.runs)
        pw.TextSpan(
          text: run.caps ? run.text.toUpperCase() : run.text,
          baseline: run.script == 0 ? 0 : (run.script > 0 ? base * 0.35 : -base * 0.15),
          style: pw.TextStyle(
            fontSize: (run.size ?? base * factor) * (run.script == 0 ? 1 : 0.65),
            fontWeight: run.bold || para.heading > 0 ? pw.FontWeight.bold : null,
            fontStyle: run.italic ? pw.FontStyle.italic : null,
            decoration: pw.TextDecoration.combine(<pw.TextDecoration>[
              if (run.underline || run.link != null) pw.TextDecoration.underline,
              if (run.strike) pw.TextDecoration.lineThrough,
            ]),
            color: run.link != null
                ? PdfColor.fromInt(0xFF1A56B0)
                : (run.color == null ? null : PdfColor.fromInt(run.color!.toARGB32())),
          ),
        ),
    ];
    final text = pw.RichText(
      text: pw.TextSpan(
        children: spans,
        style: pw.TextStyle(fontSize: base * factor),
      ),
      textAlign: switch (para.align) {
        OfficeAlign.center => pw.TextAlign.center,
        OfficeAlign.end => pw.TextAlign.right,
        OfficeAlign.justify => pw.TextAlign.justify,
        OfficeAlign.start => pw.TextAlign.left,
      },
    );
    final spacing = pw.EdgeInsets.only(
      top: para.heading > 0 ? 10 : 0,
      bottom: para.heading > 0 ? 4 : 5,
      left: para.level * 16.0,
    );
    if (para.bullet == null) return pw.Padding(padding: spacing, child: text);
    return pw.Padding(
      padding: spacing,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 18,
            child: pw.Text(para.bullet!, style: pw.TextStyle(fontSize: base)),
          ),
          pw.Expanded(child: text),
        ],
      ),
    );
  }

  static pw.Widget _table(OfficeTable table) {
    final columns = table.rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (columns == 0) return pw.SizedBox();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      children: <pw.TableRow>[
        for (final row in table.rows)
          pw.TableRow(
            children: <pw.Widget>[
              for (var c = 0; c < columns; c++)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      if (c < row.length)
                        for (final para in row[c]) _paragraph(para, 9.5),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // ------------------------------------------------------------ lembar Excel

  /// PDF dari lembar-lembar tabel: tiap lembar mulai di halaman baru, mendatar,
  /// dengan huruf mengecil bila kolomnya banyak.
  static Future<Uint8List> sheets(List<TableSheet> sheets) async {
    final theme = await _loadTheme();
    final pdf = pw.Document(theme: theme);
    for (final sheet in sheets) {
      final rows = sheet.rows;
      final columns = sheet.columnCount;
      if (rows.isEmpty || columns == 0) continue;
      final fontSize = columns <= 8 ? 9.0 : (columns <= 14 ? 7.5 : 6.0);
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              sheet.name,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (context) => <pw.Widget>[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
              children: <pw.TableRow>[
                for (final row in rows)
                  pw.TableRow(
                    children: <pw.Widget>[
                      for (var c = 0; c < columns; c++)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          child: pw.Text(
                            c < row.length ? row[c] : '',
                            style: pw.TextStyle(fontSize: fontSize),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return pdf.save();
  }
}

/// Teks slide ditulis tak terlihat di letak kotaknya: pembaca PDF bisa
/// mencarinya dan menyalinnya, tetapi yang tampil tetap gambar slidenya.
class _InvisibleText extends pw.Widget {
  _InvisibleText(this.font, this.slide, this.size);

  final pw.Font font;
  final OfficeSlide slide;
  final Size size;

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    box = PdfRect(0, 0, constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final canvas = context.canvas;
    final pdfFont = font.getFont(context);
    for (final shape in slide.shapes) {
      final frame = shape.frame;
      if (frame == null || shape.paragraphs.isEmpty) continue;
      var y = frame.top;
      for (final para in shape.paragraphs) {
        final text = para.text.trim();
        if (text.isEmpty) continue;
        final fontSize = para.runs
            .map((r) => r.size ?? 18)
            .fold<double>(0, (m, s) => s > m ? s : m)
            .clamp(6, 96)
            .toDouble();
        y += fontSize * 1.2;
        if (y > size.height) break;
        try {
          canvas.drawString(
            pdfFont,
            fontSize,
            text,
            box!.left + frame.left + 4,
            box!.bottom + size.height - y,
            mode: PdfTextRenderingMode.invisible,
          );
        } on Object {
          // Huruf yang tidak ada di font; lapisan teks hanya pelengkap.
        }
      }
    }
  }
}
