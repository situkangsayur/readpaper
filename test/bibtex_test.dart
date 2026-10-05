import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/citation/domain/bibtex.dart';

Map<String, dynamic> _item(
  String id, {
  String type = 'article-journal',
  String title = 'Barren plateaus in quantum neural network training landscapes',
  List<Map<String, String>> author = const <Map<String, String>>[
    <String, String>{'family': 'McClean', 'given': 'Jarrod R.'},
    <String, String>{'family': 'Boixo', 'given': 'Sergio'},
  ],
  List<int> date = const <int>[2018, 11],
  Map<String, dynamic> extra = const <String, dynamic>{},
}) => <String, dynamic>{
  'id': id,
  'type': type,
  'title': title,
  'author': author,
  'issued': <String, dynamic>{
    'date-parts': <List<int>>[date],
  },
  ...extra,
};

void main() {
  test('entri artikel: pengarang, jurnal, halaman, bulan, DOI', () {
    final item = _item(
      'AAAAAAAA',
      extra: <String, dynamic>{
        'container-title': 'Nature Communications',
        'volume': '9',
        'issue': '1',
        'page': '4812-4820',
        'DOI': '10.1038/s41467-018-07090-4',
      },
    );
    final bib = BibTex.export(<Map<String, dynamic>>[item]);
    expect(bib, startsWith('@article{mcclean2018barren,'));
    expect(bib, contains('author  = {McClean, Jarrod R. and Boixo, Sergio}'));
    expect(bib, contains('journal = {Nature Communications}'));
    expect(bib, contains('pages   = {4812--4820}'));
    expect(bib, contains('month   = {nov}'));
    expect(bib, contains('doi     = {10.1038/s41467-018-07090-4}'));
  });

  test('kunci Citation Key dari Extra dipakai apa adanya', () {
    final item = _item(
      'AAAAAAAA',
      extra: <String, dynamic>{'note': 'Something else\nCitation Key: McClean2018BarrenPlateaus'},
    );
    expect(
      BibTex.citationKeys(<Map<String, dynamic>>[item])['AAAAAAAA'],
      'McClean2018BarrenPlateaus',
    );
  });

  test('kunci kembar dibedakan dengan akhiran, stabil menurut kunci Zotero', () {
    final a = _item('ZZZZZZZZ');
    final b = _item('AAAAAAAA');
    final keys = BibTex.citationKeys(<Map<String, dynamic>>[a, b]);
    expect(keys['AAAAAAAA'], 'mcclean2018barrena');
    expect(keys['ZZZZZZZZ'], 'mcclean2018barrenb');
    // Urutan masukan berbeda, hasil sama: naskah yang sudah memakai \cite{…}
    // tidak patah saat koleksinya diekspor ulang.
    expect(BibTex.citationKeys(<Map<String, dynamic>>[b, a]), keys);
  });

  test('kata judul tanpa kata sambung dan tanpa diakritik', () {
    final item = _item(
      'AAAAAAAA',
      title: 'Deteksi anomali pada ledger',
      author: const <Map<String, String>>[
        <String, String>{'family': 'Müller', 'given': 'Ana'},
      ],
      date: const <int>[2024],
    );
    expect(BibTex.baseKey(item), 'muller2024deteksi');
  });

  test('karakter khusus LaTeX diloloskan, URL tidak', () {
    final item = _item(
      'AAAAAAAA',
      type: 'webpage',
      title: r'R&D: 50% of $cost_total',
      extra: <String, dynamic>{'URL': 'https://example.org/a_b?x=1%20'},
    );
    final bib = BibTex.export(<Map<String, dynamic>>[item]);
    expect(bib, startsWith('@misc{'));
    expect(bib, contains(r'{R\&D: 50\% of \$cost\_total}'));
    expect(bib, contains('{https://example.org/a_b?x=1%20}'));
  });

  test('tesis, bab buku, dan prosiding memakai medan yang benar', () {
    final thesis = BibTex.entry(
      _item('A', type: 'thesis', extra: <String, dynamic>{'publisher': 'ITB'}),
      'k',
    );
    expect(thesis, startsWith('@phdthesis{k,'));
    expect(thesis, contains('school'));
    final chapter = BibTex.entry(
      _item('B', type: 'chapter', extra: <String, dynamic>{'container-title': 'Handbook'}),
      'k',
    );
    expect(chapter, contains('booktitle = {Handbook}'));
    final paper = BibTex.entry(_item('C', type: 'paper-conference'), 'k');
    expect(paper, startsWith('@inproceedings{k,'));
  });

  test('pengarang lembaga ditulis dalam kurung kurawal supaya tidak dipecah', () {
    final item = _item(
      'A',
      author: const <Map<String, String>>[
        <String, String>{'literal': 'World Health Organization'},
      ],
    );
    expect(BibTex.entry(item, 'k'), contains('author = {{World Health Organization}}'));
  });
}
