import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../domain/office_document.dart';
import 'compound_file.dart';

/// Berkas "Word" atau "Excel" yang sebenarnya teks: RTF, HTML yang disimpan
/// dengan akhiran `.doc`/`.xls` (ekspor banyak aplikasi web), atau teks biasa.
class TextFormats {
  const TextFormats._();

  static bool isRtf(Uint8List bytes) =>
      bytes.length > 5 && ascii.decode(bytes.sublist(0, 5), allowInvalid: true) == r'{\rtf';

  static bool isHtml(Uint8List bytes) {
    final head = latin1
        .decode(bytes.sublist(0, bytes.length < 512 ? bytes.length : 512))
        .trimLeft()
        .replaceFirst('﻿', '')
        .replaceFirst('ï»¿', '')
        .toLowerCase();
    return head.startsWith('<html') ||
        head.startsWith('<!doctype html') ||
        head.startsWith('<table') ||
        (head.startsWith('<?xml') && head.contains('<html'));
  }

  /// Teks tanpa byte nol dan sebagian besar bisa dicetak.
  static bool isPlainText(Uint8List bytes) {
    final sample = bytes.length < 4096 ? bytes : bytes.sublist(0, 4096);
    if (sample.isEmpty) return true;
    var odd = 0;
    for (final b in sample) {
      if (b == 0) return false;
      if (b < 0x09 || (b > 0x0D && b < 0x20)) odd++;
    }
    return odd * 20 < sample.length;
  }

  static String decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return decodeCp1252(bytes);
    }
  }

  static OfficeDocument plain(Uint8List bytes) => OfficeDocument(
    blocks: <OfficeBlock>[
      for (final line in decodeText(bytes).split(RegExp(r'\r\n|\r|\n')))
        OfficeParagraph(runs: <OfficeRun>[OfficeRun(line)]),
    ],
  );

  /// HTML → paragraf, judul, butir, dan tabel.
  static OfficeDocument htmlDocument(Uint8List bytes) {
    final document = html.parse(decodeText(bytes));
    final blocks = <OfficeBlock>[];
    final body = document.body;
    if (body != null) _htmlBlocks(body, blocks);
    return OfficeDocument(blocks: blocks);
  }

  static void _htmlBlocks(dom.Element parent, List<OfficeBlock> out) {
    final inline = StringBuffer();
    void flush() {
      final text = inline.toString().replaceAll(RegExp(r'[ \t\r\n]+'), ' ').trim();
      if (text.isNotEmpty) out.add(OfficeParagraph(runs: <OfficeRun>[OfficeRun(text)]));
      inline.clear();
    }

    for (final node in parent.nodes) {
      if (node is dom.Text) {
        inline.write(node.text);
        continue;
      }
      if (node is! dom.Element) continue;
      final tag = node.localName ?? '';
      switch (tag) {
        case 'script' || 'style' || 'head' || 'title' || 'xml':
          continue;
        case 'br':
          flush();
        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          flush();
          out.add(
            OfficeParagraph(
              runs: <OfficeRun>[OfficeRun(_squash(node.text))],
              heading: int.parse(tag.substring(1)),
            ),
          );
        case 'li':
          flush();
          out.add(OfficeParagraph(runs: <OfficeRun>[OfficeRun(_squash(node.text))], bullet: '•'));
        case 'table':
          flush();
          out.add(OfficeTable(_tableRows(node)));
        case 'p' ||
            'div' ||
            'ul' ||
            'ol' ||
            'section' ||
            'article' ||
            'blockquote' ||
            'pre' ||
            'center' ||
            'body' ||
            'tbody' ||
            'main':
          flush();
          _htmlBlocks(node, out);
        default:
          inline.write(node.text);
      }
    }
    flush();
  }

  static String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<List<List<OfficeParagraph>>> _tableRows(
    dom.Element table,
  ) => <List<List<OfficeParagraph>>>[
    for (final tr in table.querySelectorAll('tr'))
      if (_closestTable(tr) == table)
        <List<OfficeParagraph>>[
          for (final cell in tr.children)
            if (cell.localName == 'td' || cell.localName == 'th')
              <OfficeParagraph>[
                OfficeParagraph(
                  runs: <OfficeRun>[OfficeRun(_squash(cell.text), bold: cell.localName == 'th')],
                ),
              ],
        ],
  ];

  static dom.Element? _closestTable(dom.Element e) {
    dom.Element? p = e.parent;
    while (p != null && p.localName != 'table') {
      p = p.parent;
    }
    return p;
  }

  /// Tabel-tabel di HTML sebagai lembar: (nama, baris).
  static List<(String, List<List<String>>)> htmlTables(Uint8List bytes) {
    final document = html.parse(decodeText(bytes));
    final out = <(String, List<List<String>>)>[];
    for (final table in document.querySelectorAll('table')) {
      if (_closestTable(table) != null) continue;
      final rows = <List<String>>[
        for (final tr in table.querySelectorAll('tr'))
          if (_closestTable(tr) == table)
            <String>[
              for (final cell in tr.children)
                if (cell.localName == 'td' || cell.localName == 'th') _squash(cell.text),
            ],
      ];
      out.add(('Tabel ${out.length + 1}', rows));
    }
    return out;
  }

  /// RTF → paragraf. Kelompok tujuan (`{\*…}`, tabel huruf, warna, gaya,
  /// info, gambar) dilewati; `\par` mengakhiri paragraf, `\cell` sel tabel.
  static OfficeDocument rtf(Uint8List bytes) {
    final text = latin1.decode(bytes);
    final paragraphs = <OfficeBlock>[];
    final buf = StringBuffer();
    final skipStack = <bool>[false];
    var skipUnicodeFallback = 0;
    var ucSkip = 1;

    void endParagraph() {
      paragraphs.add(OfficeParagraph(runs: <OfficeRun>[OfficeRun(buf.toString())]));
      buf.clear();
    }

    const destinations = <String>{
      'fonttbl', 'colortbl', 'stylesheet', 'info', 'pict', 'object', 'header', 'footer', //
      'headerl', 'headerr', 'footerl', 'footerr', 'fldinst', 'themedata', 'colorschememapping',
      'datastore', 'latentstyles', 'listtable', 'listoverridetable', 'rsidtbl', 'xmlnstbl',
      'generator', 'pgdsctbl', 'filetbl', 'revtbl', 'shppict', 'nonshppict', 'bkmkstart',
    };

    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      final skipping = skipStack.last;
      if (ch == '{') {
        skipStack.add(skipping);
        i++;
        continue;
      }
      if (ch == '}') {
        if (skipStack.length > 1) skipStack.removeLast();
        i++;
        continue;
      }
      if (ch == '\\') {
        i++;
        if (i >= text.length) break;
        final next = text[i];
        if (next == '\\' || next == '{' || next == '}') {
          if (!skipping) buf.write(next);
          i++;
          continue;
        }
        if (next == '*') {
          skipStack[skipStack.length - 1] = true;
          i++;
          continue;
        }
        if (next == "'") {
          final hex = i + 3 <= text.length ? text.substring(i + 1, i + 3) : '';
          i += 3;
          if (skipUnicodeFallback > 0) {
            skipUnicodeFallback--;
            continue;
          }
          final code = int.tryParse(hex, radix: 16);
          if (!skipping && code != null) buf.writeCharCode(cp1252Unit(code));
          continue;
        }
        if (next == '~') {
          if (!skipping) buf.write(' ');
          i++;
          continue;
        }
        if (next == '\n' || next == '\r') {
          if (!skipping) endParagraph();
          i++;
          continue;
        }
        final match = RegExp(r'([a-zA-Z]+)(-?\d+)? ?').matchAsPrefix(text, i);
        if (match == null) {
          i++;
          continue;
        }
        i = match.end;
        final word = match.group(1)!;
        final param = int.tryParse(match.group(2) ?? '');
        if (destinations.contains(word)) {
          skipStack[skipStack.length - 1] = true;
          continue;
        }
        if (skipping) continue;
        switch (word) {
          case 'par' || 'sect' || 'page':
            endParagraph();
          case 'line':
            buf.write('\n');
          case 'tab':
            buf.write('\t');
          case 'cell':
            buf.write('\t');
          case 'row':
            endParagraph();
          case 'uc':
            ucSkip = param ?? 1;
          case 'u':
            if (param != null) buf.writeCharCode(param < 0 ? param + 65536 : param);
            skipUnicodeFallback = ucSkip;
          case 'emdash':
            buf.write('—');
          case 'endash':
            buf.write('–');
          case 'bullet':
            buf.write('•');
          case 'lquote':
            buf.write('‘');
          case 'rquote':
            buf.write('’');
          case 'ldblquote':
            buf.write('“');
          case 'rdblquote':
            buf.write('”');
        }
        continue;
      }
      if (ch == '\r' || ch == '\n') {
        i++;
        continue;
      }
      if (skipUnicodeFallback > 0) {
        skipUnicodeFallback--;
        i++;
        continue;
      }
      if (!skipping) buf.write(ch);
      i++;
    }
    if (buf.isNotEmpty) endParagraph();
    return OfficeDocument(blocks: paragraphs);
  }
}
