import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_item.dart';
import 'package:readpaper/src/features/library/domain/library_stats.dart';

ZoteroItem item({
  String key = 'K',
  String title = 'Judul',
  String itemType = 'journalArticle',
  String year = '',
  String date = '',
  List<String> authors = const <String>[],
  List<String> tags = const <String>[],
  int annotations = 0,
  bool withFile = false,
}) => ZoteroItem(
  key: key,
  title: title,
  itemType: itemType,
  filePath: '/tmp/$key.json',
  year: year,
  date: date,
  tags: tags,
  annotationCount: annotations,
  creatorDetails: <ZoteroCreator>[
    for (final a in authors) ZoteroCreator(creatorType: 'author', lastName: a),
  ],
  attachments: withFile
      ? <ZoteroAttachment>[
          const ZoteroAttachment(
            key: 'A',
            parentItemKey: 'K',
            title: 'PDF',
            filename: 'x.pdf',
            contentType: 'application/pdf',
            relativePath: 'attachments/x.pdf',
            status: 'ok',
          ),
        ]
      : const <ZoteroAttachment>[],
);

void main() {
  test('library kosong menghasilkan ringkasan kosong, bukan galat', () {
    final stats = LibraryStats.of(const <ZoteroItem>[]);
    expect(stats.isEmpty, isTrue);
    expect(stats.itemCount, 0);
    expect(stats.byYear, isEmpty);
    expect(stats.filePercent, 0);
    expect(stats.earliestYear, isNull);
  });

  group('hitungan pokok', () {
    test('berkas, anotasi, dan persentasenya', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A', withFile: true, annotations: 3),
        item(key: 'B', withFile: true),
        item(key: 'C'),
        item(key: 'D'),
      ]);

      expect(stats.itemCount, 4);
      expect(stats.withFile, 2);
      expect(stats.filePercent, 50);
      expect(stats.withAnnotations, 1);
      expect(stats.annotationTotal, 3);
    });

    test('item tanpa judul dihitung — biasanya impor yang gagal', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A', title: '(tanpa judul)'),
        item(key: 'B', title: '   '),
        item(key: 'C', title: 'Ada judulnya'),
      ]);
      expect(stats.untitledCount, 2);
    });
  });

  group('tahun', () {
    test('dari tahun langsung maupun dari tanggal', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A', year: '2020'),
        item(key: 'B', date: '2020-05-13'),
        item(key: 'C', date: 'Mei 2019'),
      ]);

      expect(stats.byYear, <StatTally>[
        (label: '2020', count: 2),
        (label: '2019', count: 1),
      ]);
      expect(stats.earliestYear, 2019);
      expect(stats.latestYear, 2020);
    });

    test(
      'item tanpa tahun dihitung terpisah, bukan dipaksa masuk satu tahun',
      () {
        final stats = LibraryStats.of(<ZoteroItem>[
          item(key: 'A', year: '2020'),
          item(key: 'B'),
          item(key: 'C', date: 'tanpa tanggal'),
        ]);
        expect(stats.withoutYear, 2);
        expect(stats.byYear, hasLength(1));
      },
    );

    test('tahun yang mustahil tidak dipercaya', () {
      final stats = LibraryStats.of(<ZoteroItem>[item(key: 'A', year: '99')]);
      expect(stats.withoutYear, 1);
    });

    test('terurut dari yang terbaru', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A', year: '1999'),
        item(key: 'B', year: '2024'),
        item(key: 'C', year: '2011'),
      ]);
      expect(stats.byYear.map((t) => t.label), <String>[
        '2024',
        '2011',
        '1999',
      ]);
    });
  });

  group('jenis', () {
    test('terbanyak lebih dulu, dan namanya enak dibaca', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A'),
        item(key: 'B'),
        item(key: 'C', itemType: 'book'),
      ]);

      expect(stats.byType.first, (label: 'journalArticle', count: 2));
      expect(LibraryStats.labelForType('journalArticle'), 'Artikel jurnal');
      expect(LibraryStats.labelForType('bookSection'), 'Bab buku');
    });

    test('jenis yang tidak dikenal tetap ditampilkan apa adanya', () {
      expect(LibraryStats.labelForType('sesuatuBaru'), 'sesuatuBaru');
    });
  });

  group('pengarang', () {
    test('dihitung per karya, bukan per baris nama', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A', authors: <String>['Karisma', 'Lovelace']),
        item(key: 'B', authors: <String>['Karisma']),
        item(key: 'C', authors: <String>['Karisma', 'Karisma']),
      ]);

      expect(stats.topCreators.first, (label: 'Karisma', count: 3));
      expect(stats.topCreators[1], (label: 'Lovelace', count: 1));
    });

    test('daftarnya dibatasi supaya tetap jadi ringkasan', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        for (var i = 0; i < 40; i++)
          item(key: 'K$i', authors: <String>['Orang$i']),
      ], topCount: 5);
      expect(stats.topCreators, hasLength(5));
    });

    test('yang sama banyaknya diurutkan menurut abjad, bukan acak', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A', authors: <String>['Zubair']),
        item(key: 'B', authors: <String>['Adi']),
        item(key: 'C', authors: <String>['Mira']),
      ]);
      expect(stats.topCreators.map((t) => t.label), <String>[
        'Adi',
        'Mira',
        'Zubair',
      ]);
    });
  });

  group('tag', () {
    test('dihitung sekali per item walau tertulis dua kali', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A', tags: <String>['ginjal', 'ginjal', 'ml']),
        item(key: 'B', tags: <String>['ginjal']),
      ]);
      expect(stats.topTags.first, (label: 'ginjal', count: 2));
      expect(stats.topTags[1], (label: 'ml', count: 1));
    });

    test('tag kosong diabaikan', () {
      final stats = LibraryStats.of(<ZoteroItem>[
        item(key: 'A', tags: <String>['  ', 'nyata']),
      ]);
      expect(stats.topTags, hasLength(1));
    });
  });
}
