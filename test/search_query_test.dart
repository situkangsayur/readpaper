import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/entities/search_query.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_item.dart';

ZoteroItem item({
  String title = 'Deep learning for medical imaging',
  List<String> creators = const <String>['Karisma, Hendri', 'Wijaya, Kevin'],
  String year = '2024',
  String type = 'journalArticle',
  List<String> tags = const <String>['radiologi', 'CNN'],
  String publication = 'Journal of Medical Imaging',
  String doi = '10.1000/jmi.2024.42',
  String abstractNote = 'Kami mengusulkan metode segmentasi paru berbasis transformer.',
  List<String> collections = const <String>['Tesis/Bab 2'],
}) => ZoteroItem(
  key: 'K',
  title: title,
  itemType: type,
  filePath: '/x.json',
  creators: creators,
  year: year,
  tags: tags,
  publication: publication,
  doi: doi,
  abstractNote: abstractNote,
  collectionPaths: collections,
);

void main() {
  group('bare words', () {
    test('reach title, creators, journal, tags, collections and abstract', () {
      final it = item();
      for (final word in <String>[
        'medical', // judul
        'hendri', // pengarang
        'radiologi', // tag
        'journal of', // publikasi
        'transformer', // abstrak
        'bab 2', // koleksi
        '10.1000', // doi
      ]) {
        expect(SearchQuery.parse(word).matches(it), isTrue, reason: 'gagal pada "$word"');
      }
      expect(SearchQuery.parse('astrofisika').matches(it), isFalse);
    });

    test('every word must match, so typing more narrows', () {
      final it = item();
      expect(SearchQuery.parse('deep hendri').matches(it), isTrue);
      expect(SearchQuery.parse('deep astrofisika').matches(it), isFalse);
    });

    test('case does not matter', () {
      expect(SearchQuery.parse('DEEP LeArNiNg').matches(item()), isTrue);
    });
  });

  group('field prefixes', () {
    test('accept Indonesian and English names alike', () {
      final it = item();
      expect(SearchQuery.parse('pengarang:hendri').matches(it), isTrue);
      expect(SearchQuery.parse('author:hendri').matches(it), isTrue);
      expect(SearchQuery.parse('penulis:hendri').matches(it), isTrue);
    });

    test('narrow to the named field only', () {
      // "medical" is in the title, not in any creator.
      expect(SearchQuery.parse('pengarang:medical').matches(item()), isFalse);
      expect(SearchQuery.parse('judul:medical').matches(item()), isTrue);
    });

    test('a year is matched exactly, not as a prefix', () {
      expect(SearchQuery.parse('tahun:2024').matches(item()), isTrue);
      expect(SearchQuery.parse('tahun:202').matches(item()), isFalse);
      expect(SearchQuery.parse('tahun:2023').matches(item()), isFalse);
    });

    test('an unknown prefix is treated as ordinary text, not dropped', () {
      // Someone typing "penerbit:" should not silently match everything.
      expect(SearchQuery.parse('nonsense:hendri').matches(item()), isFalse);
      final withColon = item(title: 'Catatan: sebuah studi');
      expect(SearchQuery.parse('catatan:').matches(withColon), isTrue);
    });

    test('abstract and collection have their own prefixes', () {
      expect(SearchQuery.parse('abstrak:segmentasi').matches(item()), isTrue);
      expect(SearchQuery.parse('abstrak:radiologi').matches(item()), isFalse);
      expect(SearchQuery.parse('koleksi:tesis').matches(item()), isTrue);
    });
  });

  group('quotes and exclusion', () {
    test('quotes keep a phrase together', () {
      final it = item();
      expect(SearchQuery.parse('judul:"medical imaging"').matches(it), isTrue);
      expect(SearchQuery.parse('judul:"imaging medical"').matches(it), isFalse);
      // Without quotes those are two separate terms, both of which match.
      expect(SearchQuery.parse('judul:imaging medical').matches(it), isTrue);
    });

    test('an unterminated quote is a half-typed phrase, not an error', () {
      expect(SearchQuery.parse('judul:"medical').matches(item()), isTrue);
    });

    test('a leading minus excludes', () {
      final it = item();
      expect(SearchQuery.parse('-astrofisika').matches(it), isTrue);
      expect(SearchQuery.parse('-hendri').matches(it), isFalse);
      expect(SearchQuery.parse('deep -tahun:2023').matches(it), isTrue);
      expect(SearchQuery.parse('deep -tahun:2024').matches(it), isFalse);
    });
  });

  group('edge cases', () {
    test('an empty or blank query matches everything', () {
      expect(SearchQuery.parse('').isEmpty, isTrue);
      expect(SearchQuery.parse('   ').isEmpty, isTrue);
      expect(SearchQuery.parse('  ').matches(item()), isTrue);
    });

    test('a bare prefix with no value is not a filter', () {
      expect(SearchQuery.parse('pengarang:').isEmpty, isTrue);
    });

    test('filter keeps only the matching items', () {
      final items = <ZoteroItem>[
        item(),
        item(
          title: 'Astrofisika dasar',
          creators: const <String>['Lain, Orang'],
          tags: const <String>[],
          abstractNote: '',
          publication: '',
          doi: '',
          collections: const <String>[],
        ),
      ];
      expect(SearchQuery.parse('pengarang:hendri').filter(items).length, 1);
      expect(SearchQuery.parse('').filter(items).length, 2);
    });
  });
}
