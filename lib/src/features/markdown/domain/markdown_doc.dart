import 'package:meta/meta.dart';

/// Sepotong teks sebaris beserta gayanya.
@immutable
class MdSpan {
  const MdSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.strike = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  final bool strike;

  /// Alamat tautan, kalau potongan ini bagian dari tautan.
  final String? link;

  MdSpan _with(String text) =>
      MdSpan(text, bold: bold, italic: italic, code: code, strike: strike, link: link);

  @override
  bool operator ==(Object other) =>
      other is MdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.code == code &&
      other.strike == strike &&
      other.link == link;

  @override
  int get hashCode => Object.hash(text, bold, italic, code, strike, link);

  @override
  String toString() => 'MdSpan("$text")';
}

/// Satu blok dokumen. Tiap blok tahu baris asalnya, supaya penyunting bisa
/// membawa kursor ke tempat yang benar saat pratinjaunya diketuk — itu yang
/// membuat diagram "bisa disunting" dan bukan hanya dilihat.
@immutable
sealed class MdBlock {
  const MdBlock({required this.startLine, required this.endLine});

  /// Nomor baris pertama dan terakhir blok ini di sumbernya, mulai dari 0.
  final int startLine;
  final int endLine;
}

class MdHeading extends MdBlock {
  const MdHeading({
    required this.level,
    required this.spans,
    required super.startLine,
    required super.endLine,
  });

  final int level;
  final List<MdSpan> spans;
}

class MdParagraph extends MdBlock {
  const MdParagraph({required this.spans, required super.startLine, required super.endLine});

  final List<MdSpan> spans;
}

class MdListItem {
  const MdListItem({required this.spans, this.depth = 0, this.checked});

  final List<MdSpan> spans;

  /// Kedalaman sarang, dihitung dari indentasinya.
  final int depth;

  /// Kotak centang `- [ ]` / `- [x]`; null kalau bukan daftar tugas.
  final bool? checked;
}

class MdList extends MdBlock {
  const MdList({
    required this.ordered,
    required this.items,
    required super.startLine,
    required super.endLine,
  });

  final bool ordered;
  final List<MdListItem> items;
}

class MdQuote extends MdBlock {
  const MdQuote({required this.lines, required super.startLine, required super.endLine});

  /// Tiap baris kutipan sudah dilepas dari tanda `>`-nya.
  final List<List<MdSpan>> lines;
}

class MdCode extends MdBlock {
  const MdCode({
    required this.language,
    required this.text,
    required super.startLine,
    required super.endLine,
  });

  final String language;
  final String text;

  /// Blok kode berbahasa `mermaid` digambar sebagai diagram, bukan dicetak
  /// sebagai teks.
  bool get isMermaid => language.toLowerCase() == 'mermaid';
}

class MdRule extends MdBlock {
  const MdRule({required super.startLine, required super.endLine});
}

class MdTable extends MdBlock {
  const MdTable({
    required this.header,
    required this.rows,
    required super.startLine,
    required super.endLine,
  });

  final List<String> header;
  final List<List<String>> rows;
}

class MdImage extends MdBlock {
  const MdImage({
    required this.alt,
    required this.path,
    required super.startLine,
    required super.endLine,
  });

  final String alt;

  /// Jalur atau URL gambarnya, apa adanya dari sumber.
  final String path;
}

/// Dokumen Markdown yang sudah dibaca jadi blok-blok.
///
/// Ditulis sendiri, bukan memakai pustaka, karena yang dibutuhkan di sini
/// sempit dan harus melayani tiga keluaran sekaligus: widget di layar, PDF,
/// dan penyuntingan balik ke sumbernya. Paket Markdown yang lengkap
/// menghasilkan HTML — yang berarti satu lapisan lagi untuk dibongkar sebelum
/// bisa digambar ke PDF.
@immutable
class MarkdownDoc {
  const MarkdownDoc(this.blocks, this.source);

  static const MarkdownDoc empty = MarkdownDoc(<MdBlock>[], '');

  final List<MdBlock> blocks;
  final String source;

  /// Blok mermaid di dalam dokumen, dalam urutan kemunculannya.
  List<MdCode> get mermaidBlocks => <MdCode>[
    for (final block in blocks)
      if (block is MdCode && block.isMermaid) block,
  ];

  /// Judul dokumen: tajuk tingkat satu pertama, kalau ada.
  String? get title {
    for (final block in blocks) {
      if (block is MdHeading && block.level == 1) return plain(block.spans);
    }
    return null;
  }

  static String plain(List<MdSpan> spans) => spans.map((s) => s.text).join();

  static MarkdownDoc parse(String source) {
    final lines = source.split('\n');
    final blocks = <MdBlock>[];
    var i = 0;

    bool isRule(String line) {
      final t = line.trim();
      if (t.length < 3) return false;
      return RegExp(r'^(\*\s*){3,}$').hasMatch(t) ||
          RegExp(r'^(-\s*){3,}$').hasMatch(t) ||
          RegExp(r'^(_\s*){3,}$').hasMatch(t);
    }

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // Kode berpagar. Dibaca lebih dulu dari apa pun: isinya harus lolos
      // apa adanya, termasuk baris yang kebetulan mirip tajuk atau daftar.
      final fence = RegExp(r'^\s*(`{3,}|~{3,})\s*([A-Za-z0-9_+-]*)\s*$').firstMatch(line);
      if (fence != null) {
        final marker = fence.group(1)!;
        final language = fence.group(2) ?? '';
        final start = i;
        final body = <String>[];
        i++;
        while (i < lines.length) {
          final closing = lines[i].trim();
          if (closing.startsWith(marker[0] * 3) &&
              closing.replaceAll(marker[0], '').trim().isEmpty) {
            break;
          }
          body.add(lines[i]);
          i++;
        }
        // Pagar yang tidak pernah ditutup tetap jadi blok kode sampai akhir
        // berkas — itu yang terlihat di penyunting selagi diketik. Baris
        // kosong di ujungnya dibuang: `split` pada berkas yang diakhiri
        // baris baru selalu menyisakan satu potongan kosong.
        if (i >= lines.length) {
          while (body.isNotEmpty && body.last.trim().isEmpty) {
            body.removeLast();
          }
        }
        final end = i < lines.length ? i : lines.length - 1;
        if (i < lines.length) i++;
        blocks.add(
          MdCode(language: language, text: body.join('\n'), startLine: start, endLine: end),
        );
        continue;
      }

      // Tajuk bergaris bawah: `Judul` lalu `===` atau `---`. Diperiksa lebih
      // dulu dari garis pemisah, karena `---` di bawah sebaris teks adalah
      // tajuk, bukan garis — begitu juga aturan CommonMark.
      if (i + 1 < lines.length &&
          !isRule(line) &&
          !trimmed.startsWith('>') &&
          _bulletOf(line) == null &&
          !RegExp(r'^\s{0,3}#{1,6}\s').hasMatch(line)) {
        final underline = lines[i + 1].trim();
        if (RegExp(r'^=+$').hasMatch(underline) || RegExp(r'^-{2,}$').hasMatch(underline)) {
          blocks.add(
            MdHeading(
              level: underline.startsWith('=') ? 1 : 2,
              spans: parseInline(trimmed),
              startLine: i,
              endLine: i + 1,
            ),
          );
          i += 2;
          continue;
        }
      }

      if (isRule(line)) {
        blocks.add(MdRule(startLine: i, endLine: i));
        i++;
        continue;
      }

      final heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        blocks.add(
          MdHeading(
            level: heading.group(1)!.length,
            spans: parseInline(heading.group(2)!.replaceAll(RegExp(r'\s+#+\s*$'), '')),
            startLine: i,
            endLine: i,
          ),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('>')) {
        final start = i;
        final quoted = <List<MdSpan>>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quoted.add(parseInline(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), '')));
          i++;
        }
        blocks.add(MdQuote(lines: quoted, startLine: start, endLine: i - 1));
        continue;
      }

      // Gambar yang berdiri sendiri di satu baris jadi blok, supaya bisa
      // ditampilkan sebesar ruang yang ada.
      final image = RegExp(r'^\s*!\[([^\]]*)\]\(([^)]+)\)\s*$').firstMatch(line);
      if (image != null) {
        blocks.add(
          MdImage(alt: image.group(1)!, path: image.group(2)!.trim(), startLine: i, endLine: i),
        );
        i++;
        continue;
      }

      final bullet = _bulletOf(line);
      if (bullet != null) {
        final start = i;
        final ordered = bullet.ordered;
        final items = <MdListItem>[];
        while (i < lines.length) {
          final next = _bulletOf(lines[i]);
          if (next == null || next.ordered != ordered) break;
          items.add(
            MdListItem(spans: parseInline(next.text), depth: next.depth, checked: next.checked),
          );
          i++;
          // Baris lanjutan sebuah butir — teks yang dibungkus ke bawah tanpa
          // tanda daftar — digabung ke butir terakhir.
          while (i < lines.length &&
              lines[i].trim().isNotEmpty &&
              _bulletOf(lines[i]) == null &&
              lines[i].startsWith(' ')) {
            final previous = items.removeLast();
            items.add(
              MdListItem(
                spans: <MdSpan>[
                  ...previous.spans,
                  const MdSpan(' '),
                  ...parseInline(lines[i].trim()),
                ],
                depth: previous.depth,
                checked: previous.checked,
              ),
            );
            i++;
          }
        }
        blocks.add(MdList(ordered: ordered, items: items, startLine: start, endLine: i - 1));
        continue;
      }

      // Tabel: baris berpipa yang barisan berikutnya adalah pemisah `---|---`.
      if (trimmed.contains('|') &&
          i + 1 < lines.length &&
          RegExp(r'^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$').hasMatch(lines[i + 1])) {
        final start = i;
        final header = _cells(lines[i]);
        i += 2;
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].contains('|') && lines[i].trim().isNotEmpty) {
          rows.add(_cells(lines[i]));
          i++;
        }
        blocks.add(MdTable(header: header, rows: rows, startLine: start, endLine: i - 1));
        continue;
      }

      // Sisanya paragraf: dikumpulkan sampai baris kosong atau sampai sesuatu
      // yang jelas bukan paragraf lagi.
      final start = i;
      final buffer = <String>[];
      while (i < lines.length) {
        final candidate = lines[i];
        if (candidate.trim().isEmpty) break;
        if (buffer.isNotEmpty &&
            (_bulletOf(candidate) != null ||
                candidate.trim().startsWith('>') ||
                isRule(candidate) ||
                RegExp(r'^\s{0,3}#{1,6}\s').hasMatch(candidate) ||
                RegExp(r'^\s*(`{3,}|~{3,})').hasMatch(candidate))) {
          break;
        }
        buffer.add(candidate.trim());
        i++;
      }
      blocks.add(
        MdParagraph(spans: parseInline(buffer.join(' ')), startLine: start, endLine: i - 1),
      );
    }

    return MarkdownDoc(blocks, source);
  }

  static List<String> _cells(String line) {
    var text = line.trim();
    if (text.startsWith('|')) text = text.substring(1);
    if (text.endsWith('|')) text = text.substring(0, text.length - 1);
    return text.split('|').map((c) => c.trim()).toList();
  }

  static _Bullet? _bulletOf(String line) {
    final unordered = RegExp(r'^(\s*)([-*+])\s+(.*)$').firstMatch(line);
    if (unordered != null) {
      var text = unordered.group(3)!;
      bool? checked;
      final task = RegExp(r'^\[([ xX])\]\s+(.*)$').firstMatch(text);
      if (task != null) {
        checked = task.group(1)!.toLowerCase() == 'x';
        text = task.group(2)!;
      }
      return _Bullet(
        ordered: false,
        depth: unordered.group(1)!.length ~/ 2,
        text: text,
        checked: checked,
      );
    }
    final ordered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$').firstMatch(line);
    if (ordered != null) {
      return _Bullet(ordered: true, depth: ordered.group(1)!.length ~/ 2, text: ordered.group(3)!);
    }
    return null;
  }

  /// Membaca gaya sebaris: tebal, miring, kode, coret, dan tautan.
  static List<MdSpan> parseInline(String source) {
    final spans = <MdSpan>[];
    final buffer = StringBuffer();
    var bold = false;
    var italic = false;
    var strike = false;
    var i = 0;

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(MdSpan(buffer.toString(), bold: bold, italic: italic, strike: strike));
      buffer.clear();
    }

    while (i < source.length) {
      final rest = source.substring(i);

      // Pelolosan: `\*` berarti bintang yang memang mau ditulis.
      if (rest.startsWith(r'\') && rest.length > 1) {
        buffer.write(rest[1]);
        i += 2;
        continue;
      }

      // Kode sebaris menang atas segalanya: isinya tidak ditafsirkan.
      if (rest.startsWith('`')) {
        final close = rest.indexOf('`', 1);
        if (close > 0) {
          flush();
          spans.add(MdSpan(rest.substring(1, close), code: true));
          i += close + 1;
          continue;
        }
      }

      final link = RegExp(r'^\[([^\]]*)\]\(([^)]+)\)').firstMatch(rest);
      if (link != null) {
        flush();
        final label = link.group(1)!;
        final target = link.group(2)!.trim();
        for (final span in parseInline(label)) {
          spans.add(
            MdSpan(
              span.text,
              bold: span.bold || bold,
              italic: span.italic || italic,
              code: span.code,
              strike: span.strike || strike,
              link: target,
            ),
          );
        }
        i += link.group(0)!.length;
        continue;
      }

      if (rest.startsWith('**') || rest.startsWith('__')) {
        flush();
        bold = !bold;
        i += 2;
        continue;
      }
      if (rest.startsWith('~~')) {
        flush();
        strike = !strike;
        i += 2;
        continue;
      }
      if (rest.startsWith('*') || rest.startsWith('_')) {
        // `_` di tengah kata — `snake_case` — bukan penanda gaya.
        final before = i == 0 ? ' ' : source[i - 1];
        final after = i + 1 < source.length ? source[i + 1] : ' ';
        final insideWord =
            rest.startsWith('_') && before.trim().isNotEmpty && after.trim().isNotEmpty;
        if (!insideWord) {
          flush();
          italic = !italic;
          i += 1;
          continue;
        }
      }

      buffer.write(source[i]);
      i++;
    }
    flush();

    // Potongan bersebelahan bergaya sama digabung: pembacanya tidak peduli
    // di mana penandanya dulu berada.
    final merged = <MdSpan>[];
    for (final span in spans) {
      if (span.text.isEmpty) continue;
      if (merged.isNotEmpty) {
        final last = merged.last;
        if (last.bold == span.bold &&
            last.italic == span.italic &&
            last.code == span.code &&
            last.strike == span.strike &&
            last.link == span.link) {
          merged[merged.length - 1] = last._with('${last.text}${span.text}');
          continue;
        }
      }
      merged.add(span);
    }
    return merged;
  }
}

class _Bullet {
  const _Bullet({required this.ordered, required this.depth, required this.text, this.checked});

  final bool ordered;
  final int depth;
  final String text;
  final bool? checked;
}
