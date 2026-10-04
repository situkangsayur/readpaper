import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/epub/data/epub_book.dart';

List<int> _epub(Map<String, String> files, {Map<String, List<int>> binary = const {}}) {
  final archive = Archive();
  void add(String name, List<int> data) => archive.addFile(ArchiveFile(name, data.length, data));
  add('mimetype', utf8.encode('application/epub+zip'));
  add(
    'META-INF/container.xml',
    utf8.encode(
      '<?xml version="1.0"?><container version="1.0" '
      'xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>'
      '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>'
      '</rootfiles></container>',
    ),
  );
  files.forEach((name, text) => add(name, utf8.encode(text)));
  binary.forEach(add);
  return ZipEncoder().encode(archive);
}

const _opf3 = '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Buku Uji</dc:title><dc:creator>Hendri</dc:creator>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="c1" href="teks/bab1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="teks/bab%202.xhtml" media-type="application/xhtml+xml"/>
    <item id="img" href="gambar/a.png" media-type="image/png"/>
  </manifest>
  <spine><itemref idref="c1"/><itemref idref="c2"/></spine>
</package>''';

const _nav =
    '''<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body><nav epub:type="toc"><ol>
  <li><a href="teks/bab1.xhtml">Pendahuluan</a>
    <ol><li><a href="teks/bab1.xhtml#latar">Latar</a></li></ol></li>
  <li><a href="teks/bab%202.xhtml">Metode</a></li>
</ol></nav></body></html>''';

void main() {
  test('EPUB 3: judul, urutan bab, daftar isi bertingkat, dan jalur gambar', () {
    final book = EpubBook.parse(
      _epub(
        <String, String>{
          'OEBPS/content.opf': _opf3,
          'OEBPS/nav.xhtml': _nav,
          'OEBPS/teks/bab1.xhtml':
              '<html><head><title>x</title></head><body class="b"><p>Halo</p>'
              '<img src="../gambar/a.png"/><a href="bab%202.xhtml">lanjut</a></body></html>',
          'OEBPS/teks/bab 2.xhtml': '<html><body><p>Dua</p></body></html>',
        },
        binary: <String, List<int>>{
          'OEBPS/gambar/a.png': <int>[1, 2, 3],
        },
      ),
    );

    expect(book.title, 'Buku Uji');
    expect(book.author, 'Hendri');
    expect(book.chapters.map((c) => c.href), <String>[
      'OEBPS/teks/bab1.xhtml',
      'OEBPS/teks/bab 2.xhtml',
    ]);
    expect(book.chapters.first.title, 'Pendahuluan');
    expect(book.toc.map((e) => (e.title, e.depth)), <(String, int)>[
      ('Pendahuluan', 0),
      ('Latar', 1),
      ('Metode', 0),
    ]);
    expect(book.chapters.first.html, isNot(contains('<title>')));
    expect(book.chapters.first.html, contains('src="epub:OEBPS/gambar/a.png"'));
    expect(book.resources['OEBPS/gambar/a.png'], <int>[1, 2, 3]);
    expect(book.chapterIndexOf('OEBPS/teks/bab 2.xhtml'), 1);
    expect(book.chapterIndexOf('OEBPS/teks/bab1.xhtml#latar'), 0);
  });

  test('EPUB 2: daftar isi dari NCX', () {
    final book = EpubBook.parse(
      _epub(<String, String>{
        'OEBPS/content.opf': '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Lama</dc:title></metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="c1" href="bab1.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx"><itemref idref="c1"/></spine>
</package>''',
        'OEBPS/toc.ncx': '''<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><navMap>
  <navPoint id="n1"><navLabel><text>Satu</text></navLabel><content src="bab1.html"/></navPoint>
</navMap></ncx>''',
        'OEBPS/bab1.html': '<html><body><p>Isi</p></body></html>',
      }),
    );
    expect(book.title, 'Lama');
    expect(book.toc.single.title, 'Satu');
    expect(book.chapters.single.title, 'Satu');
  });

  test('yang bukan EPUB ditolak dengan penjelasan', () {
    final archive = Archive()..addFile(ArchiveFile('a.txt', 1, <int>[65]));
    expect(
      () => EpubBook.parse(ZipEncoder().encode(archive)),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'message', contains('container.xml')),
      ),
    );
  });

  test('jangkar XHTML yang menutup sendiri dan sampul SVG', () {
    final book = EpubBook.parse(
      _epub(<String, String>{
        'OEBPS/content.opf': _opf3,
        'OEBPS/nav.xhtml': _nav,
        'OEBPS/teks/bab1.xhtml':
            '<html><body><svg viewBox="0 0 8 11"><image width="8" xlink:href="../gambar/a.png"/></svg>'
            '<h2><a id="bab1"/>BAB I</h2><p>Teks biasa<br/>baris dua</p></body></html>',
        'OEBPS/teks/bab 2.xhtml': '<html><body/></html>',
      }),
    );
    final html = book.chapters.first.html;
    expect(
      html,
      contains('<a id="bab1"></a>BAB I'),
      reason: 'bukan tautan yang tak pernah ditutup',
    );
    expect(html, contains('<br/>'), reason: 'elemen kosong tetap apa adanya');
    expect(html, contains('<img src="epub:OEBPS/gambar/a.png"/>'));
    expect(html, isNot(contains('<svg')));
  });
}
