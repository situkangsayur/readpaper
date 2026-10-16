import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../domain/office_document.dart';
import 'ooxml_package.dart' show attr, child, children, hexColor;

/// Jenis dokumen OpenDocument menurut berkas `mimetype` di dalam zip-nya.
enum OdfKind { text, spreadsheet, presentation, other }

/// Membaca OpenDocument dari LibreOffice/OpenOffice: `.odt` (Writer) dan
/// `.odp` (Impress). `.ods` (Calc) dibaca sebagai tabel di `TableData`.
///
/// Isinya ada di `content.xml`; gaya bernama di `styles.xml`, gaya otomatis
/// (yang ditempel langsung pada teks) di `content.xml` sendiri. Gaya diwarisi
/// lewat `style:parent-style-name`, lalu gaya bawaan keluarganya.
class OdfReader {
  OdfReader._(this._archive);

  final Archive _archive;
  final Map<String, XmlElement> _styles = <String, XmlElement>{};
  final Set<String> _automatic = <String>{};
  final Map<String, XmlElement> _defaults = <String, XmlElement>{};
  final Map<String, XmlElement> _listStyles = <String, XmlElement>{};
  final Map<String, XmlElement> _pageLayouts = <String, XmlElement>{};
  final Map<String, XmlElement> _masterPages = <String, XmlElement>{};
  final Map<String, XmlElement> _fillImages = <String, XmlElement>{};
  final Map<String, List<int>> _counters = <String, List<int>>{};

  /// Dokumen teks: ukuran dan warna huruf hanya dari gaya otomatis, seperti
  /// pembaca Word yang hanya membaca ukuran yang ditulis pada teksnya.
  bool _textMode = true;

  static OdfKind kindOf(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) return OdfKind.other;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final mime = archive.findFile('mimetype');
      if (mime == null || archive.findFile('content.xml') == null) return OdfKind.other;
      final type = utf8.decode(mime.content, allowMalformed: true).trim();
      if (type.startsWith('application/vnd.oasis.opendocument.text')) return OdfKind.text;
      if (type.startsWith('application/vnd.oasis.opendocument.spreadsheet')) {
        return OdfKind.spreadsheet;
      }
      if (type.startsWith('application/vnd.oasis.opendocument.presentation')) {
        return OdfKind.presentation;
      }
    } on Object {
      return OdfKind.other;
    }
    return OdfKind.other;
  }

  static OfficeDocument read(Uint8List bytes) =>
      OdfReader._(ZipDecoder().decodeBytes(bytes))._read();

  Uint8List? _bytes(String path) {
    final file = _archive.findFile(path.startsWith('./') ? path.substring(2) : path);
    if (file == null) return null;
    return Uint8List.fromList(file.content as List<int>);
  }

  XmlDocument? _xml(String path) {
    final data = _bytes(path);
    if (data == null) return null;
    return XmlDocument.parse(utf8.decode(data, allowMalformed: true));
  }

  OfficeDocument _read() {
    final content = _xml('content.xml');
    if (content == null) throw const FormatException('content.xml tidak ada');
    final styles = _xml('styles.xml');
    if (styles != null) _collectStyles(styles.rootElement, automatic: false);
    _collectStyles(content.rootElement, automatic: true);

    final body = child(content.rootElement, 'body');
    final presentation = child(body, 'presentation');
    if (presentation != null) {
      _textMode = false;
      return _presentation(presentation);
    }
    final text = child(body, 'text');
    if (text == null) throw const FormatException('Bukan dokumen teks atau presentasi');
    final blocks = <OfficeBlock>[];
    _blocks(text, blocks, null);
    return OfficeDocument(blocks: blocks);
  }

  void _collectStyles(XmlElement root, {required bool automatic}) {
    for (final e in root.descendantElements) {
      final name = attr(e, 'name');
      switch (e.name.local) {
        case 'style':
          final family = attr(e, 'family');
          if (name == null || family == null) break;
          final key = '$family|$name';
          _styles[key] = e;
          // Gaya otomatis di styles.xml (milik master/halaman) juga dihitung
          // otomatis; yang penting di sini adalah gaya yang ditempel langsung.
          if (automatic || e.parentElement?.name.local == 'automatic-styles') {
            _automatic.add(key);
          }
        case 'default-style':
          final family = attr(e, 'family');
          if (family != null) _defaults[family] = e;
        case 'list-style':
          if (name != null) _listStyles[name] = e;
        case 'page-layout':
          if (name != null) _pageLayouts[name] = e;
        case 'master-page':
          if (name != null) _masterPages[name] = e;
        case 'fill-image':
          if (name != null) _fillImages[name] = e;
      }
    }
  }

  // ---------------------------------------------------------------- gaya

  /// Rantai gaya [name] keluarga [family]: dirinya, induk-induknya, lalu gaya
  /// bawaan keluarga itu.
  Iterable<XmlElement> _chain(String family, String? name, {bool automaticOnly = false}) sync* {
    var current = name;
    final seen = <String>{};
    while (current != null && seen.add(current)) {
      final key = '$family|$current';
      final style = _styles[key];
      if (style == null) break;
      if (automaticOnly && !_automatic.contains(key)) return;
      yield style;
      current = attr(style, 'parent-style-name');
    }
    if (automaticOnly) return;
    final fallback = _defaults[family];
    if (fallback != null) yield fallback;
  }

  /// Nilai atribut [local] di dalam `style:<properties>` pertama yang menulisnya.
  String? _prop(
    List<(String, String?)> sources,
    String properties,
    String local, {
    bool automaticOnly = false,
  }) {
    for (final (family, name) in sources) {
      for (final style in _chain(family, name, automaticOnly: automaticOnly)) {
        for (final props in children(style, properties)) {
          final value = attr(props, local);
          if (value != null) return value;
        }
      }
    }
    return null;
  }

  OfficeRun _run(String text, List<(String, String?)> sources, String? link) {
    String? textProp(String local, {bool automaticOnly = false}) =>
        _prop(sources, 'text-properties', local, automaticOnly: automaticOnly);
    final weight = textProp('font-weight');
    final style = textProp('font-style');
    final underline = textProp('text-underline-style');
    final strike = textProp('text-line-through-style');
    final position = textProp('text-position');
    final sized = _length(textProp('font-size', automaticOnly: _textMode));
    final color = textProp('color', automaticOnly: _textMode);
    var script = 0;
    if (position != null) {
      final first = position.trim().split(RegExp(r'\s+')).first;
      if (first == 'super') {
        script = 1;
      } else if (first == 'sub') {
        script = -1;
      } else {
        final percent = double.tryParse(first.replaceAll('%', '')) ?? 0;
        script = percent > 0 ? 1 : (percent < 0 ? -1 : 0);
      }
    }
    return OfficeRun(
      text,
      bold: weight == 'bold' || (int.tryParse(weight ?? '') ?? 0) >= 600,
      italic: style == 'italic' || style == 'oblique',
      underline: (underline != null && underline != 'none') || link != null,
      strike: strike != null && strike != 'none',
      caps: textProp('text-transform') == 'uppercase',
      script: script,
      color: color != null && color.startsWith('#') ? hexColor(color.substring(1)) : null,
      size: sized,
      link: link,
    );
  }

  /// `2.5cm`, `10mm`, `1in`, `12pt`, `1pc`, `16px` → poin. Persen tidak.
  static double? _length(String? value) {
    if (value == null) return null;
    final m = RegExp(r'^(-?[\d.]+)\s*(cm|mm|in|pt|pc|px)?$').firstMatch(value.trim());
    if (m == null) return null;
    final n = double.tryParse(m.group(1)!);
    if (n == null) return null;
    return switch (m.group(2)) {
      'cm' => n * 72 / 2.54,
      'mm' => n * 72 / 25.4,
      'in' => n * 72,
      'pc' => n * 12,
      'px' => n * 0.75,
      _ => n,
    };
  }

  // ----------------------------------------------------------- teks (odt)

  /// Paragraf, judul, daftar, tabel, dan bingkai di bawah [parent].
  void _blocks(XmlElement parent, List<OfficeBlock> out, _ListContext? list) {
    for (final e in parent.childElements) {
      switch (e.name.local) {
        case 'p' || 'h':
          _paragraph(e, out, list);
        case 'list':
          _list(e, out, list);
        case 'table':
          out.add(_table(e));
        case 'section' || 'index-body':
          _blocks(e, out, list);
        case 'table-of-content' ||
            'alphabetical-index' ||
            'illustration-index' ||
            'table-index' ||
            'object-index' ||
            'user-index' ||
            'bibliography':
          final body = child(e, 'index-body');
          if (body != null) _blocks(body, out, list);
        case 'frame':
          _frameBlocks(e, out);
      }
    }
  }

  void _list(XmlElement e, List<OfficeBlock> out, _ListContext? outer) {
    final styleName = attr(e, 'style-name') ?? outer?.style;
    final level = outer == null ? 0 : outer.level + 1;
    if (outer == null &&
        styleName != null &&
        attr(e, 'continue-numbering') != 'true' &&
        attr(e, 'continue-list') == null) {
      _counters.remove(styleName);
    }
    for (final item in e.childElements) {
      final header = item.name.local == 'list-header';
      if (item.name.local != 'list-item' && !header) continue;
      final ctx = _ListContext(
        styleName,
        level,
        header ? null : int.tryParse(attr(item, 'start-value') ?? ''),
        header: header,
      );
      _blocks(item, out, ctx);
    }
  }

  void _paragraph(XmlElement e, List<OfficeBlock> out, _ListContext? list) {
    final styleName = attr(e, 'style-name');
    var heading = 0;
    if (e.name.local == 'h') {
      heading = int.tryParse(attr(e, 'outline-level') ?? '') ?? 1;
    } else if (_chain('paragraph', styleName).any((s) => attr(s, 'name') == 'Title')) {
      heading = 1;
    }
    if (heading > 6) heading = 6;

    final align = _align(_prop([('paragraph', styleName)], 'paragraph-properties', 'text-align'));
    final bullet = list == null ? null : _bullet(list, styleName);

    final runs = <OfficeRun>[];
    final images = <OfficeBlock>[];
    _inline(e, runs, images, [('paragraph', styleName)], null);
    out.add(
      OfficeParagraph(
        runs: runs,
        heading: heading,
        bullet: bullet,
        level: list?.level ?? 0,
        align: align,
      ),
    );
    out.addAll(images);
  }

  static OfficeAlign _align(String? value) => switch (value) {
    'center' => OfficeAlign.center,
    'end' || 'right' => OfficeAlign.end,
    'justify' => OfficeAlign.justify,
    _ => OfficeAlign.start,
  };

  /// Penanda butir atau nomor paragraf pertama sebuah butir daftar. Paragraf
  /// berikutnya di butir yang sama tidak bernomor lagi.
  String? _bullet(_ListContext list, String? paragraphStyle) {
    if (list.header || list.used) return null;
    list.used = true;
    final styleName =
        list.style ??
        _chain(
          'paragraph',
          paragraphStyle,
        ).map((s) => attr(s, 'list-style-name')).whereType<String>().firstOrNull;
    final listStyle = styleName == null ? null : _listStyles[styleName];
    return _levelLabel(listStyle, styleName ?? '', list.level, list.startValue);
  }

  String? _levelLabel(XmlElement? listStyle, String key, int level, int? startValue) {
    XmlElement? levelStyle;
    if (listStyle != null) {
      for (final l in listStyle.childElements) {
        if (attr(l, 'level') == '${level + 1}') {
          levelStyle = l;
          break;
        }
      }
    }
    if (levelStyle == null || levelStyle.name.local == 'list-level-style-bullet') {
      final char = levelStyle == null ? '' : attr(levelStyle, 'bullet-char') ?? '';
      return _bulletChar(char);
    }
    if (levelStyle.name.local != 'list-level-style-number') return null;
    final counters = _counters.putIfAbsent(key, () => <int>[]);
    while (counters.length <= level) {
      counters.add(0);
    }
    counters.length = level + 1;
    final start = startValue ?? int.tryParse(attr(levelStyle, 'start-value') ?? '') ?? 1;
    counters[level] = startValue != null || counters[level] == 0 ? start : counters[level] + 1;
    final format = attr(levelStyle, 'num-format') ?? '1';
    if (format.isEmpty) return null;
    final prefix = attr(levelStyle, 'num-prefix') ?? '';
    final suffix = attr(levelStyle, 'num-suffix') ?? '';
    return '$prefix${_number(counters[level], format)}$suffix';
  }

  /// Simbol butir dari huruf Symbol/Wingdings (area pribadi Unicode) tidak
  /// bisa digambar huruf biasa; diganti titik.
  static String _bulletChar(String char) {
    if (char.isEmpty) return '•';
    final code = char.runes.first;
    if (code >= 0xE000 && code <= 0xF8FF) return '•';
    return char;
  }

  static String _number(int n, String format) {
    switch (format) {
      case 'a' || 'A':
        var value = n;
        final out = StringBuffer();
        while (value > 0) {
          value--;
          out.write(String.fromCharCode(97 + value % 26));
          value ~/= 26;
        }
        final s = out.toString().split('').reversed.join();
        return format == 'A' ? s.toUpperCase() : s;
      case 'i' || 'I':
        const numerals = <(int, String)>[
          (1000, 'm'),
          (900, 'cm'),
          (500, 'd'),
          (400, 'cd'),
          (100, 'c'),
          (90, 'xc'), //
          (50, 'l'),
          (40, 'xl'),
          (10, 'x'),
          (9, 'ix'),
          (5, 'v'),
          (4, 'iv'),
          (1, 'i'),
        ];
        var value = n;
        final out = StringBuffer();
        for (final (v, s) in numerals) {
          while (value >= v) {
            out.write(s);
            value -= v;
          }
        }
        return format == 'I' ? out.toString().toUpperCase() : out.toString();
      default:
        return '$n';
    }
  }

  void _inline(
    XmlElement parent,
    List<OfficeRun> runs,
    List<OfficeBlock> images,
    List<(String, String?)> sources,
    String? link,
  ) {
    for (final node in parent.children) {
      if (node is XmlText || node is XmlCDATA) {
        // Spasi beruntun di ODF ditulis sebagai <text:s/>; spasi di XML-nya
        // sendiri (lekukan) dirapatkan seperti HTML.
        final text = node.value!.replaceAll(RegExp(r'[\t\r\n ]+'), ' ');
        if (text.isNotEmpty) runs.add(_run(text, sources, link));
        continue;
      }
      if (node is! XmlElement) continue;
      switch (node.name.local) {
        case 'span':
          _inline(node, runs, images, [('text', attr(node, 'style-name')), ...sources], link);
        case 'a':
          _inline(node, runs, images, sources, attr(node, 'href'));
        case 's':
          final count = int.tryParse(attr(node, 'c') ?? '') ?? 1;
          runs.add(_run(' ' * count, sources, link));
        case 'tab':
          runs.add(_run('\t', sources, link));
        case 'line-break':
          runs.add(_run('\n', sources, link));
        case 'note':
          final citation = child(node, 'note-citation')?.innerText.trim();
          if (citation != null && citation.isNotEmpty) {
            runs.add(OfficeRun(citation, script: 1));
          }
        case 'frame':
          _frameBlocks(node, images);
        case 'annotation' ||
            'annotation-end' ||
            'bookmark' ||
            'bookmark-start' ||
            'bookmark-end' ||
            'soft-page-break' ||
            'change' ||
            'change-start' ||
            'change-end' ||
            'reference-mark' ||
            'reference-mark-start' ||
            'reference-mark-end' ||
            'sequence-decls' ||
            'custom-shape' ||
            'rect' ||
            'line' ||
            'g':
          break;
        default:
          // Isian (nomor halaman, tanggal, rujukan), ruby, meta: teksnya.
          _inline(node, runs, images, sources, link);
      }
    }
  }

  /// Bingkai di dokumen teks: gambar, atau kotak teks yang isinya ikut
  /// mengalir sebagai paragraf.
  void _frameBlocks(XmlElement frame, List<OfficeBlock> out) {
    final image = _frameImage(frame);
    if (image != null) {
      out.add(
        OfficeImage(
          image,
          width: _length(attr(frame, 'width')),
          height: _length(attr(frame, 'height')),
        ),
      );
      return;
    }
    final box = child(frame, 'text-box');
    if (box != null) _blocks(box, out, null);
  }

  /// Gambar di dalam bingkai. Objek tertanam (rumus, bagan) membawa gambar
  /// pengganti; yang dipilih yang bukan SVM, karena SVM tidak bisa digambar.
  Uint8List? _frameImage(XmlElement frame) {
    final candidates = children(frame, 'image').toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      int rank(XmlElement e) {
        final href = attr(e, 'href') ?? '';
        if (href.startsWith('ObjectReplacements/')) return 2;
        if (href.toLowerCase().endsWith('.svm')) return 1;
        return 0;
      }

      return rank(a).compareTo(rank(b));
    });
    for (final image in candidates) {
      final href = attr(image, 'href');
      if (href != null && !href.contains('://')) {
        final bytes = _bytes(href);
        if (bytes != null) return bytes;
      }
      final data = child(image, 'binary-data')?.innerText;
      if (data != null) {
        try {
          return base64.decode(data.replaceAll(RegExp(r'\s'), ''));
        } on FormatException {
          continue;
        }
      }
    }
    return null;
  }

  OfficeTable _table(XmlElement table) {
    final rows = <List<List<OfficeParagraph>>>[];
    void readRows(XmlElement parent) {
      for (final e in parent.childElements) {
        switch (e.name.local) {
          case 'table-row':
            final cells = <List<OfficeParagraph>>[];
            for (final cell in e.childElements) {
              if (cell.name.local != 'table-cell' && cell.name.local != 'covered-table-cell') {
                continue;
              }
              final inside = <OfficeBlock>[];
              _blocks(cell, inside, null);
              final paragraphs = inside.whereType<OfficeParagraph>().toList();
              final repeat = int.tryParse(attr(cell, 'number-columns-repeated') ?? '') ?? 1;
              for (var i = 0; i < math.min(repeat, 64); i++) {
                cells.add(paragraphs);
              }
            }
            final repeat = int.tryParse(attr(e, 'number-rows-repeated') ?? '') ?? 1;
            for (var i = 0; i < math.min(repeat, 64); i++) {
              rows.add(cells);
            }
          case 'table-header-rows' || 'table-rows' || 'table-row-group':
            readRows(e);
        }
      }
    }

    readRows(table);
    return OfficeTable(rows);
  }

  // ------------------------------------------------------- presentasi (odp)

  OfficeDocument _presentation(XmlElement presentation) {
    var slideSize = const Size(960, 540);
    final slides = <OfficeSlide>[];
    for (final page in children(presentation, 'page')) {
      final masterName = attr(page, 'master-page-name');
      final master = masterName == null ? null : _masterPages[masterName];
      if (slides.isEmpty) slideSize = _pageSize(master) ?? slideSize;

      final shapes = <OfficeShape>[];
      final pageStyle = attr(page, 'style-name');
      final showMasterObjects =
          _prop(
            [('drawing-page', pageStyle)],
            'drawing-page-properties',
            'background-objects-visible',
          ) !=
          'false';
      if (master != null && showMasterObjects) {
        // Hiasan master (logo, garis, bidang warna), bukan placeholder-nya.
        _shapes(master, shapes, masterName, decorOnly: true);
      }
      _shapes(page, shapes, masterName);

      final notes = <OfficeParagraph>[];
      final notesPage = child(page, 'notes');
      if (notesPage != null) {
        for (final frame in children(notesPage, 'frame')) {
          if (attr(frame, 'class') != 'notes') continue;
          final box = child(frame, 'text-box');
          if (box == null) continue;
          final blocks = <OfficeBlock>[];
          _blocks(box, blocks, null);
          for (final p in blocks.whereType<OfficeParagraph>()) {
            if (!p.isEmpty) notes.add(OfficeParagraph(runs: <OfficeRun>[OfficeRun(p.text)]));
          }
        }
      }

      final (background, backgroundImage) = _background(pageStyle, master);
      slides.add(
        OfficeSlide(
          number: slides.length + 1,
          shapes: shapes,
          notes: notes,
          background: background ?? (backgroundImage == null ? const Color(0xFFFFFFFF) : null),
          backgroundImage: backgroundImage,
        ),
      );
    }
    return OfficeDocument(slides: slides, slideSize: slideSize);
  }

  Size? _pageSize(XmlElement? master) {
    final layoutName = master == null ? null : attr(master, 'page-layout-name');
    final layout = layoutName == null ? null : _pageLayouts[layoutName];
    final props = child(layout, 'page-layout-properties');
    final width = _length(props == null ? null : attr(props, 'page-width'));
    final height = _length(props == null ? null : attr(props, 'page-height'));
    if (width == null || height == null || width <= 0 || height <= 0) return null;
    return Size(width, height);
  }

  (Color?, Uint8List?) _background(String? pageStyle, XmlElement? master) {
    final sources = <(String, String?)>[
      ('drawing-page', pageStyle),
      if (master != null) ('drawing-page', attr(master, 'style-name')),
    ];
    for (final source in sources) {
      final fill = _prop([source], 'drawing-page-properties', 'fill');
      if (fill == 'solid') {
        final color = _prop([source], 'drawing-page-properties', 'fill-color');
        return (_color(color), null);
      }
      if (fill == 'bitmap') {
        final name = _prop([source], 'drawing-page-properties', 'fill-image-name');
        final image = name == null ? null : _fillImages[name];
        final href = image == null ? null : attr(image, 'href');
        final bytes = href == null ? null : _bytes(href);
        if (bytes != null) return (null, bytes);
      }
      if (fill == 'none') return (null, null);
    }
    return (null, null);
  }

  static Color? _color(String? value) =>
      value != null && value.startsWith('#') ? hexColor(value.substring(1)) : null;

  void _shapes(
    XmlElement parent,
    List<OfficeShape> out,
    String? masterName, {
    bool decorOnly = false,
  }) {
    for (final e in parent.childElements) {
      final local = e.name.local;
      if (local == 'g') {
        _shapes(e, out, masterName, decorOnly: decorOnly);
        continue;
      }
      const drawn = <String>{
        'frame',
        'custom-shape',
        'rect',
        'ellipse',
        'circle',
        'polygon',
        'path',
        'regular-polygon',
        'caption',
      };
      if (!drawn.contains(local)) continue;
      final shapeClass = attr(e, 'class');
      if (decorOnly && shapeClass != null) continue;
      // Placeholder kosong ("Klik untuk menambah judul") tidak tampil saat
      // presentasi diputar.
      if (attr(e, 'placeholder') == 'true') continue;
      final shape = _shape(e, shapeClass, masterName);
      if (shape != null) out.add(shape);
    }
  }

  OfficeShape? _shape(XmlElement e, String? shapeClass, String? masterName) {
    final width = _length(attr(e, 'width')) ?? 0;
    final height = _length(attr(e, 'height')) ?? 0;
    var x = _length(attr(e, 'x')) ?? 0;
    var y = _length(attr(e, 'y')) ?? 0;
    var rotation = 0.0;
    final transform = attr(e, 'transform');
    if (transform != null) {
      final rotate = RegExp(r'rotate\s*\(\s*([-\d.eE]+)\s*\)').firstMatch(transform);
      final translate = RegExp(
        r'translate\s*\(\s*(\S+?)\s*[ ,]\s*(\S+?)\s*\)',
      ).firstMatch(transform);
      // ODF memutar berlawanan jarum jam di sekitar sudut kiri atas, lalu
      // menggeser; di sini kotaknya diputar searah jarum jam di tengahnya.
      final phi = -(double.tryParse(rotate?.group(1) ?? '') ?? 0);
      final tx = _length(translate?.group(1));
      final ty = _length(translate?.group(2));
      if (tx != null && ty != null) {
        final cx = tx + math.cos(phi) * width / 2 - math.sin(phi) * height / 2;
        final cy = ty + math.sin(phi) * width / 2 + math.cos(phi) * height / 2;
        x = cx - width / 2;
        y = cy - height / 2;
      }
      rotation = (phi * 180 / math.pi) % 360;
    }
    final frame = Rect.fromLTWH(x, y, width, height);

    final graphicStyle = attr(e, 'style-name');
    final presentationStyle = e.attributes
        .where((a) => a.name.local == 'style-name' && a.name.prefix == 'presentation')
        .map((a) => a.value)
        .firstOrNull;
    final shapeSources = <(String, String?)>[
      if (presentationStyle != null) ('presentation', presentationStyle),
      if (graphicStyle != null && graphicStyle != presentationStyle) ('graphic', graphicStyle),
    ];
    final isFrame = e.name.local == 'frame';
    // Gaya bawaan Impress mengisi bentuk dengan biru; bingkai teks dan gambar
    // hanya berwarna bila gayanya sendiri menulisnya.
    String? graphic(String local, {bool fallback = true}) {
      for (final (family, name) in shapeSources) {
        final value = _prop([(family, name)], 'graphic-properties', local);
        if (value != null) return value;
      }
      return fallback ? _prop([('graphic', null)], 'graphic-properties', local) : null;
    }

    final image = isFrame ? _frameImage(e) : null;
    if (image != null) {
      return OfficeShape(frame: frame, image: image, rotation: rotation);
    }

    OfficeTable? table;
    final tableElement = isFrame ? child(e, 'table') : null;
    if (tableElement != null) table = _table(tableElement);

    final textParent = isFrame ? child(e, 'text-box') : e;
    final paragraphs = <OfficeParagraph>[];
    if (textParent != null) {
      final textStyle = attr(e, 'text-style-name');
      _slideBlocks(
        textParent,
        paragraphs,
        null,
        _SlideText(
          shapeSources: shapeSources,
          textStyle: textStyle,
          outline: shapeClass == 'outline' ? masterName : null,
          shapeListStyle: _shapeListStyle(shapeSources),
        ),
      );
    }

    final fill = graphic('fill', fallback: !isFrame);
    final stroke = graphic('stroke', fallback: !isFrame);
    final geometry = switch (e.name.local) {
      'ellipse' || 'circle' => OfficeGeometry.ellipse,
      'custom-shape' => switch (attr(child(e, 'enhanced-geometry') ?? e, 'type')) {
        'ellipse' || 'ooxml-ellipse' => OfficeGeometry.ellipse,
        'round-rectangle' || 'ooxml-roundRect' => OfficeGeometry.rounded,
        _ => OfficeGeometry.rect,
      },
      'rect' => attr(e, 'corner-radius') != null ? OfficeGeometry.rounded : OfficeGeometry.rect,
      _ => OfficeGeometry.rect,
    };
    final anchor = switch (graphic('textarea-vertical-align')) {
      'middle' => OfficeAnchor.center,
      'bottom' => OfficeAnchor.bottom,
      _ => OfficeAnchor.top,
    };

    final fillColor = fill == 'solid' ? _color(graphic('fill-color')) : null;
    final lineColor = stroke != null && stroke != 'none' ? _color(graphic('stroke-color')) : null;
    if (paragraphs.isEmpty && table == null && fillColor == null && lineColor == null) {
      return null;
    }
    return OfficeShape(
      frame: frame,
      paragraphs: paragraphs,
      table: table,
      fill: fillColor,
      line: lineColor,
      geometry: geometry,
      rotation: rotation,
      isTitle: shapeClass == 'title',
      anchor: anchor,
      wrap: graphic('wrap-option') != 'no-wrap',
    );
  }

  /// Gaya daftar yang dibawa gaya bentuknya sendiri — placeholder isi di
  /// Impress menulis butirnya di sana, bukan di `text:list`.
  String? _shapeListStyle(List<(String, String?)> sources) {
    for (final (family, name) in sources) {
      for (final style in _chain(family, name)) {
        final named = attr(style, 'list-style-name');
        if (named != null) return named;
        final embedded = child(style, 'list-style');
        if (embedded != null) {
          final key = '${attr(style, 'name')}#list';
          _listStyles.putIfAbsent(key, () => embedded);
          return key;
        }
      }
    }
    return null;
  }

  void _slideBlocks(
    XmlElement parent,
    List<OfficeParagraph> out,
    _ListContext? list,
    _SlideText ctx,
  ) {
    for (final e in parent.childElements) {
      switch (e.name.local) {
        case 'p' || 'h':
          final styleName = attr(e, 'style-name');
          final level = list?.level ?? 0;
          final sources = <(String, String?)>[
            ('paragraph', styleName),
            if (ctx.textStyle != null) ('paragraph', ctx.textStyle),
            if (ctx.outline != null) ('presentation', '${ctx.outline}-outline${level + 1}'),
            ...ctx.shapeSources,
            ('graphic', null),
          ];
          String? bullet;
          if (list != null && !list.header && !list.used) {
            list.used = true;
            final styleName = list.style ?? ctx.shapeListStyle;
            bullet = _levelLabel(
              styleName == null ? null : _listStyles[styleName],
              '${identityHashCode(ctx)}|${styleName ?? ''}',
              level,
              list.startValue,
            );
          }
          final runs = <OfficeRun>[];
          _inline(e, runs, <OfficeBlock>[], sources, null);
          out.add(
            OfficeParagraph(
              runs: runs,
              bullet: bullet,
              level: level,
              align: _align(_prop(sources, 'paragraph-properties', 'text-align')),
            ),
          );
        case 'list':
          final level = list == null ? 0 : list.level + 1;
          final styleName = attr(e, 'style-name') ?? list?.style;
          for (final item in e.childElements) {
            final header = item.name.local == 'list-header';
            if (item.name.local != 'list-item' && !header) continue;
            _slideBlocks(
              item,
              out,
              _ListContext(
                styleName,
                level,
                int.tryParse(attr(item, 'start-value') ?? ''),
                header: header,
              ),
              ctx,
            );
          }
      }
    }
  }
}

class _ListContext {
  _ListContext(this.style, this.level, this.startValue, {this.header = false});

  final String? style;
  final int level;
  final int? startValue;
  final bool header;

  /// Penanda hanya untuk paragraf pertama butirnya.
  bool used = false;
}

class _SlideText {
  const _SlideText({
    required this.shapeSources,
    required this.textStyle,
    required this.outline,
    required this.shapeListStyle,
  });

  final List<(String, String?)> shapeSources;
  final String? textStyle;

  /// Nama master untuk placeholder isi: gaya `<master>-outline<n>` memberi
  /// ukuran dan warna tiap tingkat butir.
  final String? outline;
  final String? shapeListStyle;
}
