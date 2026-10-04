import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/citation/domain/csl_json.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_item.dart';

ZoteroItem item({
  String key = 'ABCD1234',
  String title = 'Judul',
  String itemType = 'journalArticle',
  List<ZoteroCreator> creators = const <ZoteroCreator>[],
  List<String> creatorNames = const <String>[],
  String date = '',
  String publication = '',
  String publisher = '',
  String doi = '',
  String url = '',
  Map<String, dynamic> extra = const <String, dynamic>{},
}) => ZoteroItem(
  key: key,
  title: title,
  itemType: itemType,
  filePath: '/tmp/$key.json',
  creators: creatorNames,
  creatorDetails: creators,
  date: date,
  publication: publication,
  publisher: publisher,
  doi: doi,
  url: url,
  extraFields: extra,
);

void main() {
  group('jenis dan medan', () {
    test('artikel jurnal jadi article-journal dengan wadah dan halamannya', () {
      final csl = CslJson.of(
        item(
          itemType: 'journalArticle',
          publication: 'Nature',
          extra: <String, dynamic>{'volume': '620', 'issue': '7973', 'pages': '301-310'},
        ),
      );

      expect(csl['type'], 'article-journal');
      expect(csl['container-title'], 'Nature');
      expect(csl['volume'], '620');
      expect(csl['issue'], '7973');
      expect(csl['page'], '301-310');
      expect(csl['id'], 'ABCD1234');
    });

    test('bab buku mengambil wadah dari bookTitle', () {
      final csl = CslJson.of(
        item(itemType: 'bookSection', extra: <String, dynamic>{'bookTitle': 'Buku Besar'}),
      );
      expect(csl['type'], 'chapter');
      expect(csl['container-title'], 'Buku Besar');
    });

    test('makalah konferensi mengambil wadah dari proceedingsTitle', () {
      final csl = CslJson.of(
        item(
          itemType: 'conferencePaper',
          extra: <String, dynamic>{
            'proceedingsTitle': 'Prosiding NeurIPS',
            'conferenceName': 'NeurIPS',
          },
        ),
      );
      expect(csl['type'], 'paper-conference');
      expect(csl['container-title'], 'Prosiding NeurIPS');
      expect(csl['event-title'], 'NeurIPS');
    });

    test('disertasi memakai universitas sebagai penerbit dan jenisnya sebagai genre', () {
      final csl = CslJson.of(
        item(
          itemType: 'thesis',
          extra: <String, dynamic>{'university': 'ITB', 'thesisType': 'Disertasi Doktor'},
        ),
      );
      expect(csl['type'], 'thesis');
      expect(csl['publisher'], 'ITB');
      expect(csl['genre'], 'Disertasi Doktor');
    });

    test('laporan memakai institusi sebagai penerbit dan nomornya sebagai number', () {
      final csl = CslJson.of(
        item(
          itemType: 'report',
          extra: <String, dynamic>{'institution': 'BPS', 'reportNumber': '12/2024'},
        ),
      );
      expect(csl['publisher'], 'BPS');
      expect(csl['number'], '12/2024');
    });

    test('jenis yang tidak dikenal tetap menghasilkan entri, bukan entri kosong', () {
      final csl = CslJson.of(item(itemType: 'sesuatuYangBaru', title: 'Tetap ada'));
      expect(csl['type'], 'document');
      expect(csl['title'], 'Tetap ada');
    });

    test('medan kosong tidak ikut ditulis', () {
      final csl = CslJson.of(item(publication: '   ', doi: '', url: ''));
      expect(csl.containsKey('container-title'), isFalse);
      expect(csl.containsKey('DOI'), isFalse);
      expect(csl.containsKey('URL'), isFalse);
    });
  });

  group('DOI', () {
    test('awalan alamat web dibuang supaya tidak tertulis dua kali', () {
      expect(CslJson.of(item(doi: 'https://doi.org/10.1000/xyz'))['DOI'], '10.1000/xyz');
      expect(CslJson.of(item(doi: 'doi:10.1000/xyz'))['DOI'], '10.1000/xyz');
      expect(CslJson.of(item(doi: '10.1000/xyz'))['DOI'], '10.1000/xyz');
    });
  });

  group('nama', () {
    test('pengarang dan penyunting dipisahkan menurut perannya', () {
      final csl = CslJson.of(
        item(
          creators: const <ZoteroCreator>[
            ZoteroCreator(creatorType: 'author', firstName: 'Hendri', lastName: 'Karisma'),
            ZoteroCreator(creatorType: 'editor', firstName: 'Ada', lastName: 'Lovelace'),
          ],
        ),
      );

      expect(csl['author'], <Map<String, String>>[
        <String, String>{'family': 'Karisma', 'given': 'Hendri'},
      ]);
      expect(csl['editor'], <Map<String, String>>[
        <String, String>{'family': 'Lovelace', 'given': 'Ada'},
      ]);
    });

    test('penyunting seri jadi collection-editor', () {
      final csl = CslJson.of(
        item(
          creators: const <ZoteroCreator>[
            ZoteroCreator(creatorType: 'seriesEditor', firstName: 'B', lastName: 'C'),
          ],
        ),
      );
      expect(csl.containsKey('collection-editor'), isTrue);
    });

    test('peran yang tidak dikenal tetap muncul sebagai pengarang', () {
      final csl = CslJson.of(
        item(
          creators: const <ZoteroCreator>[
            ZoteroCreator(creatorType: 'peranAneh', firstName: 'X', lastName: 'Y'),
          ],
        ),
      );
      expect(csl['author'], hasLength(1));
    });

    test('lembaga dan nama satu kata ditulis utuh, tidak dibalik', () {
      final csl = CslJson.of(
        item(
          creators: const <ZoteroCreator>[
            ZoteroCreator(creatorType: 'author', name: 'Badan Pusat Statistik'),
            ZoteroCreator(creatorType: 'author', lastName: 'Soekarno'),
          ],
        ),
      );
      expect(csl['author'], <Map<String, String>>[
        <String, String>{'literal': 'Badan Pusat Statistik'},
        <String, String>{'literal': 'Soekarno'},
      ]);
    });

    test('item lama yang hanya menyimpan nama sebagai teks tidak kehilangan pengarangnya', () {
      final csl = CslJson.of(item(creatorNames: const <String>['Karisma, Hendri']));
      expect(csl['author'], <Map<String, String>>[
        <String, String>{'literal': 'Karisma, Hendri'},
      ]);
    });
  });

  group('tanggal', () {
    List<int>? partsOf(String raw) {
      final parsed = CslJson.parseDate(raw);
      final parts = parsed?['date-parts'] as List?;
      return parts == null ? null : (parts.first as List).cast<int>();
    }

    test('tahun saja', () => expect(partsOf('2024'), <int>[2024]));
    test('tahun dan bulan', () => expect(partsOf('2024-05'), <int>[2024, 5]));
    test('tanggal penuh', () => expect(partsOf('2024-05-13'), <int>[2024, 5, 13]));

    test('bulan yang ditulis dalam bahasa Indonesia', () {
      expect(partsOf('Mei 2024'), <int>[2024, 5]);
      expect(partsOf('13 Agustus 2021'), <int>[2021, 8, 13]);
    });

    test('bulan yang ditulis dalam bahasa Inggris', () {
      expect(partsOf('September 2019'), <int>[2019, 9]);
    });

    test('tanggal yang tidak terbaca tetap dibawa apa adanya', () {
      final parsed = CslJson.parseDate('tanpa tahun');
      expect(parsed, isNotNull);
      expect(parsed!['raw'], 'tanpa tahun');
      expect(parsed.containsKey('date-parts'), isFalse);
    });

    test('teks aslinya selalu ikut, supaya tidak ada yang hilang', () {
      expect(CslJson.parseDate('2024-05-13')!['raw'], '2024-05-13');
    });

    test('tanggal kosong tidak menghasilkan apa-apa', () {
      expect(CslJson.parseDate('   '), isNull);
    });

    test('bulan yang mustahil tidak dipaksakan jadi angka bulan', () {
      expect(partsOf('2024-19'), <int>[2024]);
    });

    test('tanggal terbit dan tanggal akses dibedakan', () {
      final csl = CslJson.of(
        item(date: '2020-01-02', extra: <String, dynamic>{'accessDate': '2024-03-04'}),
      );
      expect((csl['issued'] as Map)['date-parts'], <List<int>>[
        <int>[2020, 1, 2],
      ]);
      expect((csl['accessed'] as Map)['date-parts'], <List<int>>[
        <int>[2024, 3, 4],
      ]);
    });
  });

  test('banyak item sekaligus mempertahankan urutannya', () {
    final all = CslJson.ofAll(<ZoteroItem>[item(key: 'SATU'), item(key: 'DUA'), item(key: 'TIGA')]);
    expect(all.map((e) => e['id']), <String>['SATU', 'DUA', 'TIGA']);
  });
}
