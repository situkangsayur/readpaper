import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/markdown/domain/markdown_doc.dart';

void main() {
  MarkdownDoc parse(String source) => MarkdownDoc.parse(source);

  group('blok', () {
    test('tajuk dengan kisi, sampai enam tingkat', () {
      final doc = parse('# Satu\n\n### Tiga\n');
      expect(doc.blocks, hasLength(2));
      expect((doc.blocks[0] as MdHeading).level, 1);
      expect(MarkdownDoc.plain((doc.blocks[0] as MdHeading).spans), 'Satu');
      expect((doc.blocks[1] as MdHeading).level, 3);
    });

    test('tajuk bergaris bawah', () {
      final doc = parse('Judul\n=====\n\nAnak\n-----\n');
      expect((doc.blocks[0] as MdHeading).level, 1);
      expect((doc.blocks[1] as MdHeading).level, 2);
    });

    test('paragraf yang terbungkus digabung jadi satu', () {
      final doc = parse('Baris pertama\nlanjutannya di bawah.\n\nParagraf lain.\n');
      expect(doc.blocks, hasLength(2));
      expect(
        MarkdownDoc.plain((doc.blocks[0] as MdParagraph).spans),
        'Baris pertama lanjutannya di bawah.',
      );
    });

    test('daftar berbutir dan bernomor terpisah', () {
      final doc = parse('- satu\n- dua\n\n1. pertama\n2. kedua\n');
      final bullets = doc.blocks[0] as MdList;
      final numbers = doc.blocks[1] as MdList;
      expect(bullets.ordered, isFalse);
      expect(bullets.items, hasLength(2));
      expect(numbers.ordered, isTrue);
      expect(MarkdownDoc.plain(numbers.items.last.spans), 'kedua');
    });

    test('daftar bersarang mencatat kedalamannya', () {
      final doc = parse('- atas\n  - dalam\n');
      final list = doc.blocks.single as MdList;
      expect(list.items.map((i) => i.depth), <int>[0, 1]);
    });

    test('daftar tugas membaca kotak centangnya', () {
      final doc = parse('- [x] sudah\n- [ ] belum\n');
      final list = doc.blocks.single as MdList;
      expect(list.items.map((i) => i.checked), <bool?>[true, false]);
      expect(MarkdownDoc.plain(list.items.first.spans), 'sudah');
    });

    test('daftar mengakhiri paragraf sebelumnya', () {
      final doc = parse('Pembuka:\n- satu\n');
      expect(doc.blocks[0], isA<MdParagraph>());
      expect(doc.blocks[1], isA<MdList>());
    });

    test('kutipan', () {
      final doc = parse('> satu\n> dua\n');
      final quote = doc.blocks.single as MdQuote;
      expect(quote.lines, hasLength(2));
      expect(MarkdownDoc.plain(quote.lines.first), 'satu');
    });

    test('garis pemisah', () {
      expect(parse('---\n').blocks.single, isA<MdRule>());
      expect(parse('***\n').blocks.single, isA<MdRule>());
    });

    test('tabel dengan kepala dan isi', () {
      final doc = parse('| a | b |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |\n');
      final table = doc.blocks.single as MdTable;
      expect(table.header, <String>['a', 'b']);
      expect(table.rows, <List<String>>[
        <String>['1', '2'],
        <String>['3', '4'],
      ]);
    });

    test('gambar yang berdiri sendiri jadi blok', () {
      final doc = parse('![peta](gambar/peta.png)\n');
      final image = doc.blocks.single as MdImage;
      expect(image.alt, 'peta');
      expect(image.path, 'gambar/peta.png');
    });
  });

  group('kode berpagar', () {
    test('isinya lolos apa adanya', () {
      final doc = parse('```dart\n# bukan tajuk\n- bukan daftar\n```\n');
      final code = doc.blocks.single as MdCode;
      expect(code.language, 'dart');
      expect(code.text, '# bukan tajuk\n- bukan daftar');
      expect(code.isMermaid, isFalse);
    });

    test('pagar yang belum ditutup tetap jadi blok kode', () {
      // Keadaan yang selalu terjadi saat diketik: pagar pembuka sudah ada,
      // penutupnya belum. Pratinjaunya tidak boleh berubah jadi kacau.
      final doc = parse('```\nbaru mulai\n');
      expect(doc.blocks.single, isA<MdCode>());
      expect((doc.blocks.single as MdCode).text, 'baru mulai');
    });

    test('blok mermaid dikenali dan bisa ditemukan', () {
      final doc = parse('Teks\n\n```mermaid\ngraph TD\nA-->B\n```\n');
      expect(doc.mermaidBlocks, hasLength(1));
      expect(doc.mermaidBlocks.single.text, 'graph TD\nA-->B');
    });
  });

  group('gaya sebaris', () {
    test('tebal, miring, coret, kode', () {
      final spans = MarkdownDoc.parseInline('**tebal** *miring* ~~coret~~ `kode`');
      expect(spans.firstWhere((s) => s.text == 'tebal').bold, isTrue);
      expect(spans.firstWhere((s) => s.text == 'miring').italic, isTrue);
      expect(spans.firstWhere((s) => s.text == 'coret').strike, isTrue);
      expect(spans.firstWhere((s) => s.text == 'kode').code, isTrue);
    });

    test('kode sebaris tidak ditafsirkan isinya', () {
      final spans = MarkdownDoc.parseInline('`a **b** c`');
      expect(spans.single.text, 'a **b** c');
      expect(spans.single.code, isTrue);
    });

    test('tautan menyimpan alamatnya', () {
      final spans = MarkdownDoc.parseInline('lihat [situs](https://contoh.id) ini');
      final link = spans.firstWhere((s) => s.link != null);
      expect(link.text, 'situs');
      expect(link.link, 'https://contoh.id');
    });

    test('garis bawah di tengah kata bukan penanda miring', () {
      // `nama_berkas_panjang` adalah nama, bukan tiga potong bergaya.
      final spans = MarkdownDoc.parseInline('nama_berkas_panjang');
      expect(spans.single.text, 'nama_berkas_panjang');
      expect(spans.single.italic, isFalse);
    });

    test('bintang yang dilolosi ditulis apa adanya', () {
      final spans = MarkdownDoc.parseInline(r'2 \* 3');
      expect(MarkdownDoc.plain(spans), '2 * 3');
    });

    test('potongan bergaya sama digabung', () {
      final spans = MarkdownDoc.parseInline('**a****b**');
      expect(spans, hasLength(1));
      expect(spans.single.text, 'ab');
    });
  });

  group('baris asal', () {
    test('tiap blok tahu di baris mana ia berada', () {
      // Inilah yang membuat pratinjau bisa diketuk untuk menyunting: tanpa
      // nomor barisnya, kursor tidak tahu harus ke mana.
      const source = '# Judul\n\nParagraf.\n\n```mermaid\ngraph TD\nA-->B\n```\n';
      final doc = parse(source);
      expect(doc.blocks[0].startLine, 0);
      expect(doc.blocks[1].startLine, 2);
      final diagram = doc.blocks[2] as MdCode;
      expect(diagram.startLine, 4);
      expect(diagram.endLine, 7);
      expect(source.split('\n')[diagram.startLine], '```mermaid');
    });

    test('judul dokumen diambil dari tajuk tingkat satu', () {
      expect(parse('## Bukan\n\n# Ini\n').title, 'Ini');
      expect(parse('tanpa tajuk\n').title, isNull);
    });
  });
}
