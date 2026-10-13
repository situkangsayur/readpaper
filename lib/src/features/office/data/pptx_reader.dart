import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;
import 'package:xml/xml.dart';

import '../domain/office_document.dart';
import 'ooxml_package.dart';

/// Membaca `.pptx`: tiap slide dengan kotak teks, gambar, bidang berwarna,
/// dan tabel di posisi aslinya, latar slide, serta catatan pembicara.
///
/// Gaya diwarisi seperti di PowerPoint: slide ← tata letak ← master, dengan
/// warna tema. Bagan, SmartArt, animasi, dan efek tidak ikut; yang
/// dibutuhkan untuk membaca isinya ada.
class PptxReader {
  PptxReader._(this._pkg);

  final OoxmlPackage _pkg;
  final Map<String, _Theme> _themes = <String, _Theme>{};

  static OfficeDocument read(Uint8List bytes) => PptxReader._(OoxmlPackage(bytes))._read();

  OfficeDocument _read() {
    const main = 'ppt/presentation.xml';
    final pres = _pkg.xml(main);
    if (pres == null) throw const FormatException('ppt/presentation.xml tidak ada');
    final size = descendant(pres.rootElement, 'sldSz');
    final width = emuToPt(int.tryParse(size?.getAttribute('cx') ?? '') ?? 9144000);
    final height = emuToPt(int.tryParse(size?.getAttribute('cy') ?? '') ?? 6858000);

    final rels = _pkg.rels(main);
    final slides = <OfficeSlide>[];
    for (final id in all(pres, 'sldId')) {
      final part = rels[relId(id)];
      if (part == null) continue;
      final slide = _slide(part, slides.length + 1);
      if (slide != null) slides.add(slide);
    }
    return OfficeDocument(slides: slides, slideSize: Size(width, height));
  }

  OfficeSlide? _slide(String part, int number) {
    final xml = _pkg.xml(part);
    if (xml == null) return null;
    final layoutPart = _pkg.relOfType(part, 'slideLayout');
    final layout = layoutPart == null ? null : _pkg.xml(layoutPart)?.rootElement;
    final masterPart = layoutPart == null ? null : _pkg.relOfType(layoutPart, 'slideMaster');
    final master = masterPart == null ? null : _pkg.xml(masterPart)?.rootElement;
    final theme = _themes.putIfAbsent(masterPart ?? '', () => _Theme.of(_pkg, masterPart, master));

    final ctx = _Context(
      pkg: _pkg,
      theme: theme,
      master: master,
      layout: layout,
      masterPart: masterPart,
      layoutPart: layoutPart,
    );

    final shapes = <OfficeShape>[];
    // Hiasan master dan tata letak (logo, garis, bidang warna) ada di bawah
    // isi slide, kecuali slide atau tata letaknya menyembunyikannya.
    final root = xml.rootElement;
    final hideMaster =
        root.getAttribute('showMasterSp') == '0' || layout?.getAttribute('showMasterSp') == '0';
    if (master != null && masterPart != null && !hideMaster) {
      ctx.tree(child(child(master, 'cSld'), 'spTree'), masterPart, shapes, decorOnly: true);
    }
    if (layout != null && layoutPart != null && root.getAttribute('showMasterSp') != '0') {
      ctx.tree(child(child(layout, 'cSld'), 'spTree'), layoutPart, shapes, decorOnly: true);
    }
    ctx.tree(child(child(root, 'cSld'), 'spTree'), part, shapes);

    // Latar: slide, lalu tata letak, lalu master.
    Color? background;
    Uint8List? backgroundImage;
    for (final (source, sourcePart) in <(XmlElement?, String?)>[
      (root, part),
      (layout, layoutPart),
      (master, masterPart),
    ]) {
      final bg = child(child(source, 'cSld'), 'bg');
      if (bg == null || sourcePart == null) continue;
      final bgPr = child(bg, 'bgPr');
      if (bgPr != null) {
        final blip = descendant(child(bgPr, 'blipFill'), 'blip');
        if (blip != null) {
          final target = _pkg.rels(sourcePart)[relId(blip, 'embed')];
          backgroundImage = target == null ? null : _pkg.bytes(target);
        }
        background = ctx.fill(bgPr);
      } else {
        background = ctx.theme.color(child(bg, 'bgRef'));
      }
      if (background != null || backgroundImage != null) break;
    }

    // Catatan pembicara: placeholder isi di halaman catatan.
    final notes = <OfficeParagraph>[];
    final notesPart = _pkg.relOfType(part, 'notesSlide');
    final notesXml = notesPart == null ? null : _pkg.xml(notesPart);
    if (notesXml != null) {
      for (final sp in all(notesXml, 'sp')) {
        final ph = descendant(child(sp, 'nvSpPr'), 'ph');
        if (ph?.getAttribute('type') != 'body') continue;
        for (final para in all(sp, 'p')) {
          final runs = <OfficeRun>[
            for (final r in para.childElements)
              if (r.name.local == 'r' || r.name.local == 'fld')
                OfficeRun(child(r, 't')?.innerText ?? '')
              else if (r.name.local == 'br')
                const OfficeRun('\n'),
          ];
          final paragraph = OfficeParagraph(runs: runs);
          if (!paragraph.isEmpty) notes.add(paragraph);
        }
      }
    }

    return OfficeSlide(
      number: number,
      shapes: shapes,
      notes: notes,
      background: background ?? (backgroundImage == null ? theme.color(null, 'bg1') : null),
      backgroundImage: backgroundImage,
    );
  }
}

/// Tingkat gaya paragraf yang diwarisi dari master dan tata letak.
class _Level {
  _Level();

  OfficeAlign? align;
  String? bullet;
  bool? noBullet;
  double? size;
  Color? color;
  bool? bold;
  bool? italic;
  bool? caps;

  _Level merged(_Level? over) {
    if (over == null) return this;
    return _Level()
      ..align = over.align ?? align
      ..bullet = over.noBullet == true ? null : (over.bullet ?? bullet)
      ..noBullet = over.noBullet ?? (over.bullet != null ? false : noBullet)
      ..size = over.size ?? size
      ..color = over.color ?? color
      ..bold = over.bold ?? bold
      ..italic = over.italic ?? italic
      ..caps = over.caps ?? caps;
  }
}

class _Context {
  _Context({
    required this.pkg,
    required this.theme,
    required this.master,
    required this.layout,
    required this.masterPart,
    required this.layoutPart,
  });

  final OoxmlPackage pkg;
  final _Theme theme;
  final XmlElement? master;
  final XmlElement? layout;
  final String? masterPart;
  final String? layoutPart;

  /// Menelusuri pohon bentuk. [map] mengubah koordinat anak grup ke
  /// koordinat slide. [decorOnly]: master dan tata letak — placeholder-nya
  /// hanya teks contoh ("Klik untuk menambah judul") dan tidak digambar.
  void tree(
    XmlElement? spTree,
    String part,
    List<OfficeShape> out, {
    bool decorOnly = false,
    Rect Function(Rect)? map,
  }) {
    if (spTree == null) return;
    for (final e in spTree.childElements) {
      switch (e.name.local) {
        case 'sp':
          final ph = descendant(child(e, 'nvSpPr'), 'ph');
          if (decorOnly && ph != null) continue;
          final shape = _shape(e, part, ph, map);
          if (shape != null) out.add(shape);
        case 'pic':
          final shape = _picture(e, part, map);
          if (shape != null) out.add(shape);
        case 'graphicFrame':
          final shape = _graphicFrame(e, map);
          if (shape != null) out.add(shape);
        case 'grpSp':
          final xfrm = child(child(e, 'grpSpPr'), 'xfrm');
          final outer = _rect(xfrm, 'off', 'ext');
          final inner = _rect(xfrm, 'chOff', 'chExt');
          Rect Function(Rect)? childMap = map;
          if (outer != null && inner != null && inner.width > 0 && inner.height > 0) {
            final sx = outer.width / inner.width;
            final sy = outer.height / inner.height;
            Rect local(Rect r) => Rect.fromLTWH(
              outer.left + (r.left - inner.left) * sx,
              outer.top + (r.top - inner.top) * sy,
              r.width * sx,
              r.height * sy,
            );
            childMap = map == null ? local : (r) => map(local(r));
          }
          tree(e, part, out, decorOnly: decorOnly, map: childMap);
        case 'AlternateContent':
          // Konten baru dengan cadangan lama; cadangannya yang terbaca.
          tree(child(e, 'Fallback'), part, out, decorOnly: decorOnly, map: map);
      }
    }
  }

  Rect? _rect(XmlElement? xfrm, String off, String ext) {
    final o = child(xfrm, off);
    final x = child(xfrm, ext);
    if (o == null || x == null) return null;
    double n(XmlElement e, String a) => emuToPt(int.tryParse(e.getAttribute(a) ?? '') ?? 0);
    return Rect.fromLTWH(n(o, 'x'), n(o, 'y'), n(x, 'cx'), n(x, 'cy'));
  }

  /// Placeholder padanannya di tata letak dan master: menurut `idx`, lalu
  /// menurut tipenya.
  (XmlElement?, XmlElement?) _inherited(XmlElement? ph) {
    if (ph == null) return (null, null);
    final type = ph.getAttribute('type') ?? 'body';
    final idx = ph.getAttribute('idx');
    XmlElement? find(XmlElement? root) {
      if (root == null) return null;
      final candidates = all(root, 'sp')
          .map((sp) => (sp, descendant(child(sp, 'nvSpPr'), 'ph')))
          .where((c) => c.$2 != null)
          .toList();
      if (idx != null) {
        for (final (sp, p) in candidates) {
          if (p!.getAttribute('idx') == idx) return sp;
        }
      }
      final wanted = _family(type);
      for (final (sp, p) in candidates) {
        if (_family(p!.getAttribute('type') ?? 'body') == wanted) return sp;
      }
      return null;
    }

    return (find(layout), find(master));
  }

  static String _family(String type) => switch (type) {
    'title' || 'ctrTitle' => 'title',
    'subTitle' || 'body' || 'obj' => 'body',
    _ => type,
  };

  OfficeShape? _shape(XmlElement sp, String part, XmlElement? ph, Rect Function(Rect)? map) {
    _autoNumber = 0;
    final (fromLayout, fromMaster) = _inherited(ph);
    final spPr = child(sp, 'spPr');
    var xfrm = child(spPr, 'xfrm');
    xfrm ??= child(child(fromLayout, 'spPr'), 'xfrm');
    xfrm ??= child(child(fromMaster, 'spPr'), 'xfrm');
    var frame = _rect(xfrm, 'off', 'ext');
    if (frame != null && map != null) frame = map(frame);
    final rotation = (int.tryParse(xfrm?.getAttribute('rot') ?? '') ?? 0) / 60000;

    final type = ph?.getAttribute('type');
    final isTitle = type == 'title' || type == 'ctrTitle';
    final family = ph == null ? 'other' : _family(type ?? 'body');

    // Gaya teks: txStyles master → lstStyle master → lstStyle tata letak →
    // lstStyle bentuk ini.
    final txStyles = child(master, 'txStyles');
    final base = switch (family) {
      'title' => child(txStyles, 'titleStyle'),
      'body' => child(txStyles, 'bodyStyle'),
      _ => child(txStyles, 'otherStyle'),
    };
    final styleChain = <XmlElement?>[
      base,
      descendant(child(fromMaster, 'txBody'), 'lstStyle'),
      descendant(child(fromLayout, 'txBody'), 'lstStyle'),
      child(child(sp, 'txBody'), 'lstStyle'),
    ];

    // Warna teks dan isi dari gaya bentuk (p:style), dipakai bentuk otomatis
    // yang dibuat PowerPoint: isi aksen, teks putih.
    final style = child(sp, 'style');
    final fontColor = theme.color(child(style, 'fontRef'));

    final body = child(sp, 'txBody');
    final bodyPr =
        child(body, 'bodyPr') ??
        child(child(fromLayout, 'txBody'), 'bodyPr') ??
        child(child(fromMaster, 'txBody'), 'bodyPr');
    final anchorValue =
        child(body, 'bodyPr')?.getAttribute('anchor') ??
        child(child(fromLayout, 'txBody'), 'bodyPr')?.getAttribute('anchor') ??
        child(child(fromMaster, 'txBody'), 'bodyPr')?.getAttribute('anchor');
    final scale =
        (int.tryParse(
              descendant(child(body, 'bodyPr'), 'normAutofit')?.getAttribute('fontScale') ?? '',
            ) ??
            100000) /
        100000;

    final paragraphs = <OfficeParagraph>[];
    if (body != null) {
      for (final p in children(body, 'p')) {
        paragraphs.add(_paragraph(p, styleChain, fontColor, scale, isTitle));
      }
    }
    // Paragraf kosong di ujung hanya ruang kosong.
    while (paragraphs.isNotEmpty && paragraphs.last.isEmpty) {
      paragraphs.removeLast();
    }

    final geometry = switch (descendant(spPr, 'prstGeom')?.getAttribute('prst')) {
      'ellipse' => OfficeGeometry.ellipse,
      'roundRect' => OfficeGeometry.rounded,
      _ => OfficeGeometry.rect,
    };
    final isTextBox = descendant(child(sp, 'nvSpPr'), 'cNvSpPr')?.getAttribute('txBox') == '1';
    final fillColor =
        fill(spPr) ?? (isTextBox || ph != null ? null : theme.color(child(style, 'fillRef')));
    final ln = child(spPr, 'ln');
    final lineColor = ln != null
        ? (child(ln, 'noFill') != null ? null : theme.color(child(ln, 'solidFill')))
        : (isTextBox || ph != null ? null : theme.color(child(style, 'lnRef')));

    if (paragraphs.isEmpty && fillColor == null && lineColor == null) return null;
    return OfficeShape(
      frame: frame,
      paragraphs: paragraphs,
      fill: fillColor,
      line: lineColor,
      geometry: geometry,
      rotation: rotation,
      isTitle: isTitle,
      wrap: bodyPr?.getAttribute('wrap') != 'none',
      anchor: switch (anchorValue) {
        'ctr' => OfficeAnchor.center,
        'b' => OfficeAnchor.bottom,
        _ => OfficeAnchor.top,
      },
    );
  }

  _Level _levelFrom(XmlElement? pPr) {
    final level = _Level();
    if (pPr == null) return level;
    level.align = switch (pPr.getAttribute('algn')) {
      'ctr' => OfficeAlign.center,
      'r' => OfficeAlign.end,
      'just' || 'dist' => OfficeAlign.justify,
      'l' => OfficeAlign.start,
      _ => null,
    };
    if (child(pPr, 'buNone') != null) level.noBullet = true;
    final buChar = child(pPr, 'buChar');
    if (buChar != null) level.bullet = buChar.getAttribute('char') ?? '•';
    if (child(pPr, 'buAutoNum') != null) level.bullet = '#';
    final defRPr = child(pPr, 'defRPr');
    _runInto(level, defRPr);
    return level;
  }

  void _runInto(_Level level, XmlElement? rPr) {
    if (rPr == null) return;
    final sz = int.tryParse(rPr.getAttribute('sz') ?? '');
    if (sz != null) level.size = sz / 100;
    final b = rPr.getAttribute('b');
    if (b != null) level.bold = b == '1' || b == 'true';
    final i = rPr.getAttribute('i');
    if (i != null) level.italic = i == '1' || i == 'true';
    final cap = rPr.getAttribute('cap');
    if (cap != null) level.caps = cap == 'all';
    final color = theme.color(child(rPr, 'solidFill'));
    if (color != null) level.color = color;
  }

  int _autoNumber = 0;

  OfficeParagraph _paragraph(
    XmlElement p,
    List<XmlElement?> styleChain,
    Color? fontColor,
    double scale,
    bool isTitle,
  ) {
    final pPr = child(p, 'pPr');
    final lvl = int.tryParse(pPr?.getAttribute('lvl') ?? '') ?? 0;
    var level = _Level()..color = fontColor;
    for (final list in styleChain) {
      level = level.merged(_levelFrom(child(list, 'lvl${lvl + 1}pPr')));
    }
    level = level.merged(_levelFrom(pPr));

    final runs = <OfficeRun>[];
    for (final r in p.childElements) {
      switch (r.name.local) {
        case 'r' || 'fld':
          final runLevel = _Level()
            ..size = level.size
            ..color = level.color
            ..bold = level.bold
            ..italic = level.italic
            ..caps = level.caps;
          final rPr = child(r, 'rPr');
          _runInto(runLevel, rPr);
          runs.add(
            OfficeRun(
              child(r, 't')?.innerText ?? '',
              bold: runLevel.bold ?? false,
              italic: runLevel.italic ?? false,
              underline: (rPr?.getAttribute('u') ?? 'none') != 'none',
              strike: (rPr?.getAttribute('strike') ?? 'noStrike') != 'noStrike',
              color: runLevel.color,
              caps: runLevel.caps ?? false,
              script: (int.tryParse(rPr?.getAttribute('baseline') ?? '') ?? 0).sign,
              size: (runLevel.size ?? (isTitle ? 44 : 18)) * scale,
            ),
          );
        case 'br':
          runs.add(OfficeRun('\n', size: (level.size ?? 18) * scale));
      }
    }
    final text = runs.map((r) => r.text).join().trim();
    String? bullet;
    if (text.isNotEmpty && level.noBullet != true && level.bullet != null) {
      bullet = level.bullet == '#' ? '${++_autoNumber}.' : level.bullet;
    }
    return OfficeParagraph(
      runs: runs,
      bullet: bullet,
      level: lvl,
      align: level.align ?? OfficeAlign.start,
    );
  }

  OfficeShape? _picture(XmlElement pic, String part, Rect Function(Rect)? map) {
    final blip = descendant(child(pic, 'blipFill'), 'blip');
    final target = blip == null ? null : pkg.rels(part)[relId(blip, 'embed')];
    final bytes = target == null ? null : pkg.bytes(target);
    final xfrm = child(child(pic, 'spPr'), 'xfrm');
    var frame = _rect(xfrm, 'off', 'ext');
    if (bytes == null || frame == null) return null;
    if (map != null) frame = map(frame);
    return OfficeShape(
      frame: frame,
      image: bytes,
      rotation: (int.tryParse(xfrm?.getAttribute('rot') ?? '') ?? 0) / 60000,
    );
  }

  /// Tabel PowerPoint. Bagan dan SmartArt juga `graphicFrame`, tetapi isinya
  /// di bagian lain dan tidak dibaca.
  OfficeShape? _graphicFrame(XmlElement frame, Rect Function(Rect)? map) {
    final tbl = descendant(frame, 'tbl');
    var rect = _rect(child(frame, 'xfrm'), 'off', 'ext');
    if (tbl == null || rect == null) return null;
    if (map != null) rect = map(rect);
    final rows = <List<List<OfficeParagraph>>>[
      for (final tr in children(tbl, 'tr'))
        <List<OfficeParagraph>>[
          for (final tc in children(tr, 'tc'))
            if (tc.getAttribute('hMerge') != '1' && tc.getAttribute('vMerge') != '1')
              <OfficeParagraph>[
                for (final p in all(tc, 'p')) _paragraph(p, const <XmlElement?>[], null, 1, false),
              ],
        ],
    ];
    return OfficeShape(frame: rect, table: OfficeTable(rows));
  }

  /// Isi bidang: warna padat, atau warna pertama gradasi. Null bila tidak
  /// diisi atau tidak dinyatakan.
  Color? fill(XmlElement? spPr) {
    if (spPr == null || child(spPr, 'noFill') != null) return null;
    final solid = child(spPr, 'solidFill');
    if (solid != null) return theme.color(solid);
    final grad = child(spPr, 'gradFill');
    if (grad != null) return theme.color(descendant(grad, 'gs'));
    return null;
  }
}

/// Warna tema dan pemetaannya (`bg1` → `lt1`, `tx1` → `dk1`, …).
class _Theme {
  _Theme(this._scheme, this._map);

  final Map<String, Color> _scheme;
  final Map<String, String> _map;

  static _Theme of(OoxmlPackage pkg, String? masterPart, XmlElement? master) {
    final scheme = <String, Color>{};
    final themePart = masterPart == null ? null : pkg.relOfType(masterPart, 'theme');
    final theme = themePart == null ? null : pkg.xml(themePart);
    final clrScheme = theme == null ? null : descendant(theme.rootElement, 'clrScheme');
    for (final c in clrScheme?.childElements ?? const <XmlElement>[]) {
      final srgb = child(c, 'srgbClr');
      final sys = child(c, 'sysClr');
      final color = srgb != null ? hexColor(val(srgb)) : hexColor(sys?.getAttribute('lastClr'));
      if (color != null) scheme[c.name.local] = color;
    }
    final map = <String, String>{'bg1': 'lt1', 'tx1': 'dk1', 'bg2': 'lt2', 'tx2': 'dk2'};
    final clrMap = child(master, 'clrMap');
    for (final a in clrMap?.attributes ?? const <XmlAttribute>[]) {
      map[a.name.local] = a.value;
    }
    return _Theme(scheme, map);
  }

  /// Warna di dalam [holder] (`solidFill`, `fontRef`, `bgRef`, `gs`, …), atau
  /// warna skema [fallback].
  Color? color(XmlElement? holder, [String? fallback]) {
    if (holder == null) return fallback == null ? null : _schemeColor(fallback);
    for (final c in holder.childElements) {
      Color? base;
      switch (c.name.local) {
        case 'srgbClr':
          base = hexColor(val(c));
        case 'schemeClr':
          base = _schemeColor(val(c) ?? '');
        case 'sysClr':
          base = hexColor(c.getAttribute('lastClr'));
        case 'prstClr':
          base = switch (val(c)) {
            'black' => const Color(0xFF000000),
            'white' => const Color(0xFFFFFFFF),
            'red' => const Color(0xFFFF0000),
            _ => null,
          };
        default:
          continue;
      }
      if (base == null) return null;
      return _modify(base, c);
    }
    return null;
  }

  Color? _schemeColor(String name) => _scheme[_map[name] ?? name];

  /// `lumMod`/`lumOff` (lebih terang/gelap), `tint`, `shade`, `alpha`.
  static Color _modify(Color base, XmlElement c) {
    var hsl = HSLColor.fromColor(base);
    var alpha = 1.0;
    for (final m in c.childElements) {
      final v = (int.tryParse(val(m) ?? '') ?? 100000) / 100000;
      switch (m.name.local) {
        case 'lumMod':
          hsl = hsl.withLightness((hsl.lightness * v).clamp(0, 1));
        case 'lumOff':
          hsl = hsl.withLightness((hsl.lightness + v).clamp(0, 1));
        case 'tint':
          hsl = hsl.withLightness((hsl.lightness + (1 - hsl.lightness) * (1 - v)).clamp(0, 1));
        case 'shade':
          hsl = hsl.withLightness((hsl.lightness * v).clamp(0, 1));
        case 'alpha':
          alpha = v;
      }
    }
    return hsl.toColor().withValues(alpha: alpha);
  }
}
