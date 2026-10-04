import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Satu bab dalam urutan baca (spine) sebuah EPUB.
class EpubChapter {
  const EpubChapter({required this.href, required this.html, this.title});

  /// Jalur bab di dalam arsip, relatif terhadap akarnya.
  final String href;

  /// Isi `<body>`-nya, sudah dibersihkan dari kepala dokumen.
  final String html;

  /// Judul dari daftar isi, kalau bab ini disebut di sana.
  final String? title;
}

/// Satu baris daftar isi.
class EpubTocEntry {
  const EpubTocEntry({required this.title, required this.href, this.depth = 0});

  final String title;

  /// Jalur bab di dalam arsip, boleh membawa `#jangkar`.
  final String href;
  final int depth;
}

/// Isi sebuah EPUB yang siap ditampilkan.
///
/// Pengurainya ditulis sendiri, bukan diambil dari paket: paket EPUB yang ada
/// menuntut versi `image` dan `xml` yang lebih tua daripada yang dipakai
/// ReadPaper, dan EPUB sebenarnya sederhana — sebuah ZIP dengan
/// `META-INF/container.xml` yang menunjuk ke berkas OPF, yang menyebut urutan
/// bab (spine) dan daftar isinya.
class EpubBook {
  const EpubBook({
    required this.title,
    required this.author,
    required this.chapters,
    required this.toc,
    required this.resources,
  });

  final String title;
  final String author;
  final List<EpubChapter> chapters;
  final List<EpubTocEntry> toc;

  /// Gambar dan berkas lain di dalam arsip, per jalur.
  final Map<String, Uint8List> resources;

  /// Indeks bab untuk [href] (tanpa jangkar), atau -1.
  int chapterIndexOf(String href) {
    final bare = href.split('#').first;
    return chapters.indexWhere((c) => c.href == bare);
  }

  static Future<EpubBook> open(String path) async => parse(await File(path).readAsBytes());

  static EpubBook parse(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, ArchiveFile>{
      for (final file in archive.files)
        if (file.isFile) file.name: file,
    };

    Uint8List? read(String name) {
      final file = files[name];
      return file == null ? null : Uint8List.fromList(file.content as List<int>);
    }

    String? text(String name) {
      final data = read(name);
      return data == null ? null : utf8.decode(data, allowMalformed: true);
    }

    final container = text('META-INF/container.xml');
    if (container == null) {
      throw const FormatException('Bukan EPUB: META-INF/container.xml tidak ada.');
    }
    final opfPath = XmlDocument.parse(container)
        .findAllElements('rootfile')
        .map((e) => e.getAttribute('full-path'))
        .whereType<String>()
        .firstOrNull;
    final opfText = opfPath == null ? null : text(opfPath);
    if (opfPath == null || opfText == null) {
      throw const FormatException('Bukan EPUB: berkas OPF tidak ditemukan.');
    }
    final opfDir = p.posix.dirname(opfPath);
    String resolve(String href, [String? base]) {
      final from = base ?? opfDir;
      final joined = from == '.' || from.isEmpty ? href : p.posix.join(from, href);
      return p.posix.normalize(Uri.decodeFull(joined));
    }

    final opf = XmlDocument.parse(opfText);
    String meta(String local) => opf.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == local)
        .map((e) => e.innerText.trim())
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');

    final manifest = <String, ({String href, String type, String props})>{};
    for (final item in opf.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'item',
    )) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) continue;
      manifest[id] = (
        href: resolve(href),
        type: item.getAttribute('media-type') ?? '',
        props: item.getAttribute('properties') ?? '',
      );
    }

    // Daftar isi: nav EPUB 3 kalau ada, kalau tidak NCX EPUB 2.
    final toc = <EpubTocEntry>[];
    final nav = manifest.values.where((m) => m.props.split(' ').contains('nav')).firstOrNull;
    final navText = nav == null ? null : text(nav.href);
    if (nav != null && navText != null) {
      final doc = XmlDocument.parse(navText);
      final tocNav = doc.descendants.whereType<XmlElement>().where((e) {
        return e.name.local == 'nav' &&
            (e.getAttribute('epub:type') == 'toc' || e.getAttribute('type') == 'toc');
      }).firstOrNull;
      void walk(XmlElement list, int depth) {
        for (final li in list.childElements.where((e) => e.name.local == 'li')) {
          final a = li.childElements.where((e) => e.name.local == 'a').firstOrNull;
          final href = a?.getAttribute('href');
          if (a != null && href != null) {
            toc.add(
              EpubTocEntry(
                title: a.innerText.trim(),
                href: resolve(href, p.posix.dirname(nav.href)),
                depth: depth,
              ),
            );
          }
          for (final sub in li.childElements.where((e) => e.name.local == 'ol')) {
            walk(sub, depth + 1);
          }
        }
      }

      final ol = (tocNav ?? doc.rootElement).descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'ol')
          .firstOrNull;
      if (ol != null) walk(ol, 0);
    }
    if (toc.isEmpty) {
      final ncx = manifest.values.where((m) => m.type == 'application/x-dtbncx+xml').firstOrNull;
      final ncxText = ncx == null ? null : text(ncx.href);
      if (ncx != null && ncxText != null) {
        void walk(XmlElement parent, int depth) {
          for (final point in parent.childElements.where((e) => e.name.local == 'navPoint')) {
            final label = point.descendants
                .whereType<XmlElement>()
                .where((e) => e.name.local == 'text')
                .firstOrNull
                ?.innerText
                .trim();
            final src = point.childElements
                .where((e) => e.name.local == 'content')
                .firstOrNull
                ?.getAttribute('src');
            if (label != null && src != null) {
              toc.add(
                EpubTocEntry(
                  title: label,
                  href: resolve(src, p.posix.dirname(ncx.href)),
                  depth: depth,
                ),
              );
            }
            walk(point, depth + 1);
          }
        }

        final map = XmlDocument.parse(
          ncxText,
        ).descendants.whereType<XmlElement>().where((e) => e.name.local == 'navMap').firstOrNull;
        if (map != null) walk(map, 0);
      }
    }
    final titles = <String, String>{};
    for (final entry in toc) {
      titles.putIfAbsent(entry.href.split('#').first, () => entry.title);
    }

    final chapters = <EpubChapter>[];
    for (final ref in opf.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'itemref',
    )) {
      final item = manifest[ref.getAttribute('idref')];
      if (item == null) continue;
      final source = text(item.href);
      if (source == null) continue;
      chapters.add(
        EpubChapter(
          href: item.href,
          html: _bodyOf(source, base: p.posix.dirname(item.href)),
          title: titles[item.href],
        ),
      );
    }

    final resources = <String, Uint8List>{
      for (final entry in files.entries)
        if (_isImage(entry.key)) entry.key: Uint8List.fromList(entry.value.content as List<int>),
    };

    return EpubBook(
      title: meta('title'),
      author: meta('creator'),
      chapters: chapters,
      toc: toc,
      resources: resources,
    );
  }

  static bool _isImage(String name) => const <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.svg',
  }.contains(p.extension(name).toLowerCase());

  /// Isi `<body>` dengan setiap `src`/`href` relatif dijadikan jalur arsip.
  ///
  /// Jalurnya diselesaikan di sini, sekali, supaya penampil tidak perlu tahu
  /// bab mana yang sedang ia gambar untuk menemukan gambarnya.
  static String _bodyOf(String source, {required String base}) {
    final open = RegExp(r'<body[^>]*>', caseSensitive: false).firstMatch(source);
    final close = source.toLowerCase().lastIndexOf('</body>');
    var body = open == null
        ? source
        : source.substring(open.end, close > open.end ? close : source.length);
    body = body.replaceAllMapped(
      RegExp(r'''(src|href|xlink:href)\s*=\s*(["'])(.*?)\2''', caseSensitive: false),
      (m) {
        final value = m.group(3)!;
        if (value.startsWith('#') || value.contains('://') || value.startsWith('data:')) {
          return m.group(0)!;
        }
        final joined = base == '.' || base.isEmpty ? value : p.posix.join(base, value);
        final attr = m.group(1)!.toLowerCase() == 'xlink:href' ? 'src' : m.group(1);
        return '$attr="epub:${p.posix.normalize(joined)}"';
      },
    );
    return _htmlFriendly(body);
  }

  static const Set<String> _voidTags = <String>{
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source',
    'track', 'wbr', 'image',
  };

  /// Menyesuaikan XHTML dengan pembaca HTML.
  ///
  /// Dua hal yang terbukti pada EPUB Project Gutenberg. Pertama, XHTML boleh
  /// menutup elemen apa pun dengan `/>` — `<a id="bab1"/>` — sedangkan HTML
  /// membacanya sebagai `<a>` yang tidak pernah ditutup, sehingga seluruh sisa
  /// bab menjadi satu tautan biru. Kedua, sampul sering dibungkus
  /// `<svg><image xlink:href=…>`, yang tidak digambar; gambarnya diangkat jadi
  /// `<img>` biasa.
  static String _htmlFriendly(String body) {
    var out = body.replaceAllMapped(
      RegExp(r'<svg\b[^>]*>.*?<image\b[^>]*\bsrc="(epub:[^"]+)"[^>]*>.*?</svg>',
          caseSensitive: false, dotAll: true),
      (m) => '<img src="${m.group(1)}"/>',
    );
    out = out.replaceAllMapped(
      RegExp(r'<([a-zA-Z][\w:-]*)(\s[^<>]*?)?\s*/>'),
      (m) {
        final tag = m.group(1)!;
        if (_voidTags.contains(tag.toLowerCase())) return m.group(0)!;
        return '<$tag${m.group(2) ?? ''}></$tag>';
      },
    );
    return out;
  }
}
