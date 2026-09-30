import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/duplicate_finder.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_item.dart';

ZoteroItem item({
  required String key,
  String title = 'Judul',
  String itemType = 'journalArticle',
  String doi = '',
  String date = '',
  String year = '',
  String isbn = '',
  List<String> authors = const <String>['Karisma'],
  int annotations = 0,
  String abstractNote = '',
  List<ZoteroAttachment> attachments = const <ZoteroAttachment>[],
}) => ZoteroItem(
  key: key,
  title: title,
  itemType: itemType,
  filePath: '/tmp/$key.json',
  creatorDetails: <ZoteroCreator>[
    for (final a in authors)
      ZoteroCreator(creatorType: 'author', lastName: a, firstName: 'X'),
  ],
  year: year,
  date: date,
  doi: doi,
  abstractNote: abstractNote,
  annotationCount: annotations,
  attachments: attachments,
  extraFields: isbn.isEmpty
      ? const <String, dynamic>{}
      : <String, dynamic>{'ISBN': isbn},
);

void main() {
  group('tanpa duplikat', () {
    test('library kosong tidak menghasilkan kelompok', () {
      expect(DuplicateFinder.find(const <ZoteroItem>[]), isEmpty);
    });

    test('satu item tidak bisa jadi duplikat dirinya sendiri', () {
      expect(DuplicateFinder.find(<ZoteroItem>[item(key: 'A')]), isEmpty);
    });

    test('dua karya yang berbeda tidak dikelompokkan', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'A', title: 'Belajar mesin', year: '2020', doi: '10.1/a'),
        item(key: 'B', title: 'Jaringan saraf', year: '2021', doi: '10.1/b'),
      ]);
      expect(groups, isEmpty);
    });
  });

  group('DOI', () {
    test('DOI yang sama mengelompokkan walau judulnya ditulis berbeda', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'A', title: 'Attention is all you need', doi: '10.5555/xyz'),
        item(key: 'B', title: 'ATTENTION IS ALL YOU NEED.', doi: '10.5555/XYZ'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.strongest, DuplicateReason.doi);
      expect(groups.single.items.map((i) => i.key).toSet(), <String>{'A', 'B'});
    });

    test('awalan alamat web pada DOI tidak membuatnya tampak berbeda', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'A', doi: 'https://doi.org/10.1000/abc'),
        item(key: 'B', doi: '10.1000/abc'),
        item(key: 'C', doi: 'doi:10.1000/abc'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.items, hasLength(3));
    });

    test('titik yang terbawa saat menyalin dari kalimat dibuang', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'A', doi: '10.1000/abc.'),
        item(key: 'B', doi: '10.1000/abc'),
      ]);
      expect(groups, hasLength(1));
    });

    test('teks yang bukan DOI tidak dipakai mencocokkan', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'A', title: 'Satu', year: '2001', doi: 'belum ada'),
        item(key: 'B', title: 'Dua', year: '2002', doi: 'belum ada'),
      ]);
      expect(groups, isEmpty);
    });
  });

  group('ISBN', () {
    test('ISBN-10 dan ISBN-13 buku yang sama dikenali sama', () {
      // 0-306-40615-2 adalah ISBN-10 dari 978-0-306-40615-7.
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'A', itemType: 'book', title: 'Buku', isbn: '0-306-40615-2'),
        item(
          key: 'B',
          itemType: 'book',
          title: 'Buku cetakan lain',
          isbn: '978-0-306-40615-7',
        ),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.strongest, DuplicateReason.isbn);
    });

    test('ISBN yang tidak lengkap diabaikan', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'A', title: 'Satu', year: '2001', isbn: '123'),
        item(key: 'B', title: 'Dua', year: '2002', isbn: '123'),
      ]);
      expect(groups, isEmpty);
    });
  });

  group('judul, tahun, dan pengarang', () {
    test('tanpa DOI pun salinan yang sama tetap ketemu', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(
          key: 'A',
          title: 'The Elements of Style',
          year: '1999',
          authors: <String>['Strunk'],
        ),
        item(
          key: 'B',
          title: 'Elements of style',
          date: '1999-05',
          authors: <String>['Strunk'],
        ),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.strongest, DuplicateReason.titleYearAuthor);
    });

    test('tahun yang berbeda memisahkan edisi', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(
          key: 'A',
          title: 'Belajar mesin',
          year: '2019',
          authors: <String>['Ng'],
        ),
        item(
          key: 'B',
          title: 'Belajar mesin',
          year: '2023',
          authors: <String>['Ng'],
        ),
      ]);
      expect(groups, isEmpty);
    });

    test('pengarang yang berbeda memisahkan karya berjudul sama', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(
          key: 'A',
          title: 'Pendahuluan',
          year: '2020',
          authors: <String>['Karisma'],
        ),
        item(
          key: 'B',
          title: 'Pendahuluan',
          year: '2020',
          authors: <String>['Lovelace'],
        ),
      ]);
      expect(groups, isEmpty);
    });

    test('judul yang terlalu pendek tidak dipakai mencocokkan', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'A', title: 'AI', year: '2020', authors: <String>['Ng']),
        item(key: 'B', title: 'AI', year: '2020', authors: <String>['Ng']),
      ]);
      expect(groups, isEmpty);
    });

    test('item tanpa tahun tidak dikelompokkan lewat judul', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(
          key: 'A',
          title: 'Catatan panjang tanpa tahun',
          authors: <String>['Ng'],
        ),
        item(
          key: 'B',
          title: 'Catatan panjang tanpa tahun',
          authors: <String>['Ng'],
        ),
      ]);
      expect(groups, isEmpty);
    });
  });

  group('rantai kecocokan', () {
    test(
      'tiga salinan yang bertaut lewat jalan berbeda jadi satu kelompok',
      () {
        // A–B lewat DOI, B–C lewat judul: C tidak pernah dibandingkan dengan A,
        // tetapi ketiganya tetap satu karya.
        final groups = DuplicateFinder.find(<ZoteroItem>[
          item(
            key: 'A',
            title: 'Deteksi anomali graf',
            year: '2022',
            doi: '10.9/q',
            authors: <String>['Karisma'],
          ),
          item(
            key: 'B',
            title: 'Deteksi anomali graf',
            year: '2022',
            doi: '10.9/q',
            authors: <String>['Karisma'],
          ),
          item(
            key: 'C',
            title: 'Deteksi anomali graf',
            year: '2022',
            authors: <String>['Karisma'],
          ),
        ]);
        expect(groups, hasLength(1));
        expect(groups.single.items, hasLength(3));
        expect(
          groups.single.reasons,
          containsAll(<DuplicateReason>[
            DuplicateReason.doi,
            DuplicateReason.titleYearAuthor,
          ]),
        );
      },
    );
  });

  group('urutan di dalam kelompok', () {
    test('salinan yang punya anotasi didahulukan — itu pekerjaan orang', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(key: 'KOSONG', doi: '10.1/x', abstractNote: 'lengkap sekali'),
        item(key: 'ADA-CORETAN', doi: '10.1/x', annotations: 12),
      ]);
      expect(groups.single.items.first.key, 'ADA-CORETAN');
      expect(groups.single.totalAnnotations, 12);
      expect(groups.single.annotationsOnMoreThanOne, isFalse);
    });

    test(
      'anotasi di lebih dari satu salinan ditandai sebagai perlu hati-hati',
      () {
        final groups = DuplicateFinder.find(<ZoteroItem>[
          item(key: 'A', doi: '10.1/x', annotations: 3),
          item(key: 'B', doi: '10.1/x', annotations: 5),
        ]);
        expect(groups.single.annotationsOnMoreThanOne, isTrue);
        expect(groups.single.totalAnnotations, 8);
      },
    );

    test(
      'kalau tidak ada anotasi, yang metadatanya lebih lengkap didahulukan',
      () {
        final groups = DuplicateFinder.find(<ZoteroItem>[
          item(key: 'TIPIS', doi: '10.1/x'),
          item(
            key: 'TEBAL',
            doi: '10.1/x',
            abstractNote: 'ada',
            date: '2020-01-01',
          ),
        ]);
        expect(groups.single.items.first.key, 'TEBAL');
      },
    );
  });

  group('urutan antar kelompok', () {
    test('yang dicocokkan lewat DOI muncul sebelum yang hanya lewat judul', () {
      final groups = DuplicateFinder.find(<ZoteroItem>[
        item(
          key: 'J1',
          title: 'Judul yang panjang sekali',
          year: '2020',
          authors: <String>['Adi'],
        ),
        item(
          key: 'J2',
          title: 'Judul yang panjang sekali',
          year: '2020',
          authors: <String>['Adi'],
        ),
        item(key: 'D1', title: 'Lainnya', doi: '10.2/z'),
        item(key: 'D2', title: 'Lainnya beda tulisan', doi: '10.2/z'),
      ]);
      expect(groups, hasLength(2));
      expect(groups.first.strongest, DuplicateReason.doi);
      expect(groups.last.strongest, DuplicateReason.titleYearAuthor);
    });
  });

  test('lampiran dan catatan tidak pernah ikut dibandingkan', () {
    final groups = DuplicateFinder.find(<ZoteroItem>[
      item(key: 'A', itemType: 'attachment', doi: '10.1/x'),
      item(key: 'B', itemType: 'attachment', doi: '10.1/x'),
      item(key: 'C', itemType: 'note', doi: '10.1/x'),
    ]);
    expect(groups, isEmpty);
  });
}
