import 'dart:typed_data';
import 'dart:ui';

/// Isi dokumen Word atau PowerPoint yang sudah dibaca, untuk ditampilkan dan
/// dicari. Hanya untuk dibaca: tata letak halaman Word tidak ditiru — teksnya
/// mengalir selebar layar — sedangkan slide memakai posisi aslinya.
class OfficeDocument {
  const OfficeDocument({
    this.blocks = const <OfficeBlock>[],
    this.slides = const <OfficeSlide>[],
    this.slideSize = const Size(960, 540),
  });

  /// Isi dokumen teks (Word), berurutan.
  final List<OfficeBlock> blocks;

  /// Slide presentasi, berurutan. Kosong untuk dokumen teks.
  final List<OfficeSlide> slides;

  /// Ukuran slide dalam poin.
  final Size slideSize;

  bool get isPresentation => slides.isNotEmpty;

  /// Semua paragraf dalam urutan baca, termasuk sel tabel, isi slide, dan
  /// catatan pembicara. Indeks di sini yang dipakai hasil pencarian.
  List<OfficeParagraph> get paragraphs {
    final all = <OfficeParagraph>[];
    void addBlock(OfficeBlock block) {
      switch (block) {
        case OfficeParagraph():
          all.add(block);
        case OfficeTable():
          for (final row in block.rows) {
            for (final cell in row) {
              all.addAll(cell);
            }
          }
        case OfficeImage():
          break;
      }
    }

    blocks.forEach(addBlock);
    for (final slide in slides) {
      for (final shape in slide.shapes) {
        all.addAll(shape.paragraphs);
        final table = shape.table;
        if (table != null) addBlock(table);
      }
      all.addAll(slide.notes);
    }
    return all;
  }
}

sealed class OfficeBlock {
  const OfficeBlock();
}

enum OfficeAlign { start, center, end, justify }

class OfficeParagraph extends OfficeBlock {
  OfficeParagraph({
    required this.runs,
    this.heading = 0,
    this.bullet,
    this.level = 0,
    this.align = OfficeAlign.start,
  });

  final List<OfficeRun> runs;

  /// 1–6 untuk judul bagian, 0 untuk paragraf biasa. Judul dokumen ("Title")
  /// dihitung 1.
  final int heading;

  /// Penanda butir: "•", "1.", "a)"; null bila bukan butir.
  final String? bullet;
  final int level;
  final OfficeAlign align;

  late final String text = runs.map((r) => r.text).join();

  bool get isEmpty => text.trim().isEmpty;
}

class OfficeRun {
  const OfficeRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color,
    this.size,
    this.link,
    this.caps = false,
    this.script = 0,
  });

  final String text;

  /// Ditampilkan dalam huruf kapital semua (gaya `cap="all"`), teks aslinya
  /// tetap — pencarian dan salin memakai yang asli.
  final bool caps;

  /// 1 superskrip, -1 subskrip, 0 biasa.
  final int script;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final Color? color;

  /// Ukuran huruf dalam poin, bila ditulis di berkasnya.
  final double? size;
  final String? link;
}

class OfficeTable extends OfficeBlock {
  const OfficeTable(this.rows);

  /// Baris → sel → paragraf di dalam sel.
  final List<List<List<OfficeParagraph>>> rows;
}

class OfficeImage extends OfficeBlock {
  const OfficeImage(this.bytes, {this.width, this.height});

  final Uint8List bytes;

  /// Ukuran tampil dalam poin, bila diketahui.
  final double? width;
  final double? height;
}

class OfficeSlide {
  const OfficeSlide({
    required this.number,
    required this.shapes,
    this.notes = const <OfficeParagraph>[],
    this.background,
    this.backgroundImage,
  });

  final int number;
  final List<OfficeShape> shapes;
  final List<OfficeParagraph> notes;
  final Color? background;
  final Uint8List? backgroundImage;

  /// Slide dari `.ppt` lama hanya membawa teks, tanpa posisi.
  bool get hasLayout => shapes.any((s) => s.frame != null);
}

/// Satu kotak di slide: teks, gambar, atau bidang berwarna.
class OfficeShape {
  const OfficeShape({
    this.frame,
    this.paragraphs = const <OfficeParagraph>[],
    this.image,
    this.table,
    this.fill,
    this.line,
    this.geometry = OfficeGeometry.rect,
    this.rotation = 0,
    this.isTitle = false,
    this.anchor = OfficeAnchor.top,
    this.wrap = true,
  });

  /// Posisi dan ukuran di slide dalam poin; null bila tidak diketahui.
  final Rect? frame;
  final List<OfficeParagraph> paragraphs;
  final Uint8List? image;
  final OfficeTable? table;
  final Color? fill;
  final Color? line;
  final OfficeGeometry geometry;

  /// Putaran searah jarum jam, dalam derajat.
  final double rotation;
  final bool isTitle;
  final OfficeAnchor anchor;

  /// false: teks tidak dibungkus selebar kotaknya (`wrap="none"`).
  final bool wrap;
}

enum OfficeAnchor { top, center, bottom }

enum OfficeGeometry { rect, rounded, ellipse }

/// Satu kecocokan pencarian: paragraf ke-[paragraph] dalam
/// [OfficeDocument.paragraphs], dari karakter [start] sampai [end].
class OfficeMatch {
  const OfficeMatch(this.paragraph, this.start, this.end);

  final int paragraph;
  final int start;
  final int end;
}

/// Semua kemunculan [query] (tanpa membedakan huruf besar-kecil).
List<OfficeMatch> searchParagraphs(List<OfficeParagraph> paragraphs, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const <OfficeMatch>[];
  final matches = <OfficeMatch>[];
  for (var i = 0; i < paragraphs.length; i++) {
    final haystack = paragraphs[i].text.toLowerCase();
    var from = 0;
    while (true) {
      final at = haystack.indexOf(needle, from);
      if (at < 0) break;
      matches.add(OfficeMatch(i, at, at + needle.length));
      from = at + needle.length;
    }
  }
  return matches;
}
