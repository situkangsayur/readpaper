import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../domain/office_document.dart';
import 'ooxml_package.dart';

/// Membaca `.docx`: paragraf, judul bagian, butir dan nomor, tabel, gambar,
/// tautan, dan gaya huruf dasar (tebal, miring, garis bawah, coret, warna,
/// ukuran). Header, footer, catatan kaki, dan kotak teks melayang tidak ikut.
class DocxReader {
  DocxReader._(this._pkg);

  final OoxmlPackage _pkg;
  final Map<String, _Style> _styles = <String, _Style>{};
  final Map<String, Map<int, _Level>> _numbering = <String, Map<int, _Level>>{};
  final Map<String, List<int>> _counters = <String, List<int>>{};
  late final Map<String, String> _rels;

  static const String _main = 'word/document.xml';

  static OfficeDocument read(Uint8List bytes) => DocxReader._(OoxmlPackage(bytes))._read();

  OfficeDocument _read() {
    final doc = _pkg.xml(_main);
    if (doc == null) throw const FormatException('word/document.xml tidak ada');
    _rels = _pkg.rels(_main);
    _readStyles();
    _readNumbering();
    final body = descendant(doc.rootElement, 'body');
    final blocks = <OfficeBlock>[];
    _blocks(body, blocks);
    return OfficeDocument(blocks: blocks);
  }

  void _blocks(XmlElement? parent, List<OfficeBlock> out) {
    if (parent == null) return;
    for (final e in parent.childElements) {
      switch (e.name.local) {
        case 'p':
          _paragraph(e, out);
        case 'tbl':
          out.add(_table(e));
        case 'sdt':
          _blocks(child(e, 'sdtContent'), out);
        case 'customXml' || 'ins' || 'smartTag':
          _blocks(e, out);
      }
    }
  }

  OfficeTable _table(XmlElement tbl) {
    final rows = <List<List<OfficeParagraph>>>[];
    for (final tr in tbl.descendantElements.where((e) => e.name.local == 'tr')) {
      // Tabel bersarang dibaca dari tabel terluar saja; isinya ikut sebagai
      // paragraf sel tempat ia berada.
      if (tr.ancestorElements.firstWhere((a) => a.name.local == 'tbl') != tbl) continue;
      final cells = <List<OfficeParagraph>>[];
      for (final tc in tr.descendantElements.where((e) => e.name.local == 'tc')) {
        if (tc.ancestorElements.firstWhere((a) => a.name.local == 'tr') != tr) continue;
        final inside = <OfficeBlock>[];
        for (final p in tc.descendantElements.where((e) => e.name.local == 'p')) {
          _paragraph(p, inside);
        }
        cells.add(inside.whereType<OfficeParagraph>().toList());
      }
      rows.add(cells);
    }
    return OfficeTable(rows);
  }

  void _paragraph(XmlElement p, List<OfficeBlock> out) {
    final pPr = child(p, 'pPr');
    final styleId = val(child(pPr, 'pStyle'));
    final style = styleId == null ? null : _styles[styleId];

    var heading = style?.heading ?? 0;
    final outline = child(pPr, 'outlineLvl');
    if (outline != null) heading = (int.tryParse(attr(outline, 'val') ?? '') ?? 9) + 1;
    if (heading > 6) heading = 0;

    // Nomor butir dari paragrafnya sendiri, atau dari gayanya ("List Bullet").
    final numPr = child(pPr, 'numPr');
    final numId = numPr != null ? val(child(numPr, 'numId')) : style?.numId;
    final ilvl = numPr != null
        ? int.tryParse(val(child(numPr, 'ilvl')) ?? '') ?? 0
        : style?.ilvl ?? 0;
    final bullet = numId == null || numId == '0' ? null : _bullet(numId, ilvl);

    final align = switch (val(child(pPr, 'jc'))) {
      'center' => OfficeAlign.center,
      'right' || 'end' => OfficeAlign.end,
      'both' || 'distribute' => OfficeAlign.justify,
      _ => OfficeAlign.start,
    };

    final runs = <OfficeRun>[];
    final images = <OfficeImage>[];
    _runs(p, runs, images, style, null);
    out.add(
      OfficeParagraph(
        runs: runs,
        heading: heading,
        bullet: bullet,
        level: bullet == null ? 0 : ilvl,
        align: align,
      ),
    );
    out.addAll(images);
  }

  void _runs(
    XmlElement parent,
    List<OfficeRun> runs,
    List<OfficeImage> images,
    _Style? style,
    String? link,
  ) {
    for (final e in parent.childElements) {
      switch (e.name.local) {
        case 'r':
          _run(e, runs, images, style, link);
        case 'hyperlink':
          final id = relId(e);
          final anchor = attr(e, 'anchor');
          _runs(
            e,
            runs,
            images,
            style,
            id != null ? _rels[id] : (anchor == null ? null : '#$anchor'),
          );
        case 'del' || 'moveFrom' || 'pPr':
          break;
        default:
          // ins, smartTag, sdt/sdtContent, fldSimple, customXml, …
          _runs(e, runs, images, style, link);
      }
    }
  }

  void _run(
    XmlElement r,
    List<OfficeRun> runs,
    List<OfficeImage> images,
    _Style? style,
    String? link,
  ) {
    final rPr = child(r, 'rPr');
    final text = StringBuffer();
    for (final e in r.childElements) {
      switch (e.name.local) {
        case 't':
          text.write(e.innerText);
        case 'tab':
          text.write('\t');
        case 'br' || 'cr':
          text.write('\n');
        case 'noBreakHyphen':
          text.write('-');
        case 'sym':
          final code = int.tryParse(attr(e, 'char') ?? '', radix: 16);
          if (code != null && code >= 0xF000) text.write(' ');
        case 'drawing' || 'pict' || 'object':
          final image = _image(e);
          if (image != null) images.add(image);
      }
    }
    if (text.isEmpty) return;
    final size = int.tryParse(val(child(rPr, 'sz')) ?? '');
    final underline = child(rPr, 'u');
    runs.add(
      OfficeRun(
        text.toString(),
        bold: rPr != null && child(rPr, 'b') != null
            ? onOff(child(rPr, 'b'))
            : style?.bold ?? false,
        italic: rPr != null && child(rPr, 'i') != null
            ? onOff(child(rPr, 'i'))
            : style?.italic ?? false,
        underline: underline != null && attr(underline, 'val') != 'none' || link != null,
        strike: onOff(child(rPr, 'strike')) || onOff(child(rPr, 'dstrike')),
        caps: onOff(child(rPr, 'caps')),
        script: switch (val(child(rPr, 'vertAlign'))) {
          'superscript' => 1,
          'subscript' => -1,
          _ => 0,
        },
        color: hexColor(val(child(rPr, 'color'))),
        size: size == null ? null : size / 2,
        link: link,
      ),
    );
  }

  OfficeImage? _image(XmlElement drawing) {
    // DrawingML (<a:blip r:embed>) atau VML lama (<v:imagedata r:id>).
    final blip = descendant(drawing, 'blip');
    final id = blip != null
        ? relId(blip, 'embed')
        : relId(descendant(drawing, 'imagedata') ?? drawing);
    if (id == null) return null;
    final target = _rels[id];
    final bytes = target == null ? null : _pkg.bytes(target);
    if (bytes == null) return null;
    final extent = descendant(drawing, 'extent');
    final cx = int.tryParse(extent?.getAttribute('cx') ?? '');
    final cy = int.tryParse(extent?.getAttribute('cy') ?? '');
    return OfficeImage(
      bytes,
      width: cx == null ? null : emuToPt(cx),
      height: cy == null ? null : emuToPt(cy),
    );
  }

  void _readStyles() {
    final doc = _pkg.xml('word/styles.xml');
    if (doc == null) return;
    final raw = <String, XmlElement>{};
    for (final s in all(doc, 'style')) {
      final id = attr(s, 'styleId');
      if (id != null) raw[id] = s;
    }
    _Style resolve(String id, int depth) {
      final cached = _styles[id];
      if (cached != null) return cached;
      final s = raw[id];
      if (s == null || depth > 10) return const _Style();
      final basedOn = val(child(s, 'basedOn'));
      final parent = basedOn == null ? const _Style() : resolve(basedOn, depth + 1);
      final name = (val(child(s, 'name')) ?? '').toLowerCase();
      final pPr = child(s, 'pPr');
      final rPr = child(s, 'rPr');
      var heading = parent.heading;
      final match = RegExp(r'^heading (\d)$').firstMatch(name);
      if (match != null) {
        heading = int.parse(match.group(1)!);
      } else if (name == 'title') {
        heading = 1;
      } else if (name == 'subtitle') {
        heading = 3;
      }
      final outline = child(pPr, 'outlineLvl');
      if (outline != null) heading = (int.tryParse(attr(outline, 'val') ?? '') ?? 9) + 1;
      final numPr = child(pPr, 'numPr');
      final style = _Style(
        heading: heading,
        numId: numPr != null ? val(child(numPr, 'numId')) : parent.numId,
        ilvl: numPr != null ? int.tryParse(val(child(numPr, 'ilvl')) ?? '') ?? 0 : parent.ilvl,
        bold: child(rPr, 'b') != null ? onOff(child(rPr, 'b')) : parent.bold,
        italic: child(rPr, 'i') != null ? onOff(child(rPr, 'i')) : parent.italic,
      );
      return _styles[id] = style;
    }

    raw.keys.toList().forEach((id) => resolve(id, 0));
  }

  void _readNumbering() {
    final doc = _pkg.xml('word/numbering.xml');
    if (doc == null) return;
    final abstract = <String, Map<int, _Level>>{};
    for (final a in all(doc, 'abstractNum')) {
      final levels = <int, _Level>{};
      for (final lvl in children(a, 'lvl')) {
        final i = int.tryParse(attr(lvl, 'ilvl') ?? '') ?? 0;
        levels[i] = _Level(
          format: val(child(lvl, 'numFmt')) ?? 'bullet',
          text: val(child(lvl, 'lvlText')) ?? '',
          start: int.tryParse(val(child(lvl, 'start')) ?? '') ?? 1,
        );
      }
      final id = attr(a, 'abstractNumId');
      if (id != null) abstract[id] = levels;
    }
    for (final n in all(doc, 'num')) {
      final id = attr(n, 'numId');
      final ref = val(child(n, 'abstractNumId'));
      if (id != null && ref != null && abstract[ref] != null) _numbering[id] = abstract[ref]!;
    }
  }

  /// Penanda butir: "•" untuk butir, nomor berurutan untuk daftar bernomor.
  String _bullet(String numId, int ilvl) {
    final levels = _numbering[numId];
    final level = levels?[ilvl];
    if (level == null || level.format == 'bullet' || level.format == 'none') {
      return level?.format == 'none' ? '' : _bulletGlyphs[ilvl % _bulletGlyphs.length];
    }
    final counters = _counters.putIfAbsent(numId, () => List<int>.filled(9, 0));
    if (ilvl < 9) {
      counters[ilvl]++;
      for (var i = ilvl + 1; i < 9; i++) {
        counters[i] = 0;
      }
    }
    // "%1.%2." → angka tiap tingkat menurut formatnya masing-masing.
    return level.text.replaceAllMapped(RegExp(r'%(\d)'), (m) {
      final i = int.parse(m.group(1)!) - 1;
      final l = levels![i] ?? level;
      final value = (i < 9 ? counters[i] : 1) + l.start - 1;
      return _format(l.format, value < 1 ? 1 : value);
    });
  }

  static const List<String> _bulletGlyphs = <String>['•', '◦', '▪'];

  static String _format(String format, int n) => switch (format) {
    'lowerLetter' => _letters(n).toLowerCase(),
    'upperLetter' => _letters(n),
    'lowerRoman' => _roman(n).toLowerCase(),
    'upperRoman' => _roman(n),
    _ => '$n',
  };

  static String _letters(int n) {
    var s = '';
    while (n > 0) {
      n--;
      s = String.fromCharCode(65 + n % 26) + s;
      n ~/= 26;
    }
    return s;
  }

  static String _roman(int n) {
    const values = <int>[1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const symbols = <String>['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    final out = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      while (n >= values[i]) {
        out.write(symbols[i]);
        n -= values[i];
      }
    }
    return out.toString();
  }
}

class _Style {
  const _Style({
    this.heading = 0,
    this.numId,
    this.ilvl = 0,
    this.bold = false,
    this.italic = false,
  });

  final int heading;
  final String? numId;
  final int ilvl;
  final bool bold;
  final bool italic;
}

class _Level {
  const _Level({required this.format, required this.text, required this.start});

  final String format;
  final String text;
  final int start;
}
