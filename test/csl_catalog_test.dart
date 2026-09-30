import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/citation/domain/csl_catalog.dart';
import 'package:readpaper/src/features/citation/domain/csl_locale.dart';
import 'package:xml/xml.dart';

/// Daftar gaya yang sungguhan ikut di dalam aplikasi.
CslCatalog catalog() => CslCatalog.parse(File('assets/csl/styles.json').readAsStringSync());

void main() {
  late CslCatalog all;

  setUpAll(() => all = catalog());

  group('keutuhan daftar', () {
    test('setiap berkas gaya yang tercatat benar-benar ada', () {
      for (final style in all.styles) {
        expect(
          File('assets/csl/${style.file}').existsSync(),
          isTrue,
          reason: '${style.id}: ${style.file} tidak ada',
        );
      }
    });

    test('setiap berkas gaya terbaca sebagai XML dan ber-id sesuai catatannya', () {
      for (final style in all.styles) {
        final doc = XmlDocument.parse(File('assets/csl/${style.file}').readAsStringSync());
        final id = doc.rootElement
            .getElement('info', namespaceUri: 'http://purl.org/net/xbiblio/csl')
            ?.getElement('id', namespaceUri: 'http://purl.org/net/xbiblio/csl')
            ?.innerText
            .split('/')
            .last;
        expect(id, style.id, reason: 'isi ${style.file} ber-id berbeda');
      }
    });

    test('setiap locale yang tercatat benar-benar ada dan terbaca', () {
      for (final language in all.locales) {
        final file = File('assets/csl/locales/locales-$language.xml');
        expect(file.existsSync(), isTrue, reason: 'locale $language tidak ada');
        expect(CslLocale.parse(file.readAsStringSync()).language, language);
      }
    });
  });

  group('gaya dependen', () {
    test('Vancouver ada dua, dan keduanya dependen', () {
      // Ini bukan kerewelan: `https://www.zotero.org/styles/vancouver`
      // mengalihkan diam-diam ke NLM, jadi mengunduhnya sebagai "vancouver"
      // menghasilkan berkas yang isinya bukan yang tertulis di namanya.
      final vancouver = all.styles.where((s) => s.id.startsWith('vancouver')).toList();
      expect(vancouver.map((s) => s.id).toSet(), <String>{'vancouver-ama', 'vancouver-nlm'});
      expect(vancouver.every((s) => s.isDependent), isTrue);
    });

    test('keduanya menunjuk induk yang berbeda', () {
      expect(all.byId('vancouver-nlm')!.parent, 'nlm-citation-sequence');
      expect(all.byId('vancouver-ama')!.parent, 'american-medical-association');
    });

    test('setiap gaya dependen punya induk yang ikut terbawa', () {
      for (final style in all.styles.where((s) => s.isDependent)) {
        expect(
          all.byId(style.parent!),
          isNotNull,
          reason: '${style.id}: induknya ${style.parent} tidak ikut',
        );
      }
    });

    test('menelusuri induk menghasilkan gaya yang benar-benar berisi aturan', () {
      final resolved = all.resolve('vancouver-nlm');
      expect(resolved, isNotNull);
      expect(resolved!.id, 'nlm-citation-sequence');
      expect(resolved.isDependent, isFalse);
    });

    test('gaya independen menelusuri ke dirinya sendiri', () {
      expect(all.resolve('ieee')!.id, 'ieee');
    });

    test('gaya yang tidak ada menghasilkan null, bukan daftar pustaka kosong', () {
      expect(all.resolve('gaya-yang-tidak-pernah-ada'), isNull);
    });

    test('rantai induk yang putus menghasilkan null', () {
      final broken = CslCatalog.parse('''
{"styles":[{"id":"anak","file":"x.csl","title":"Anak","kind":"dependent","parent":"induk-hilang"}],
 "locales":[]}
''');
      expect(broken.resolve('anak'), isNull);
    });

    test('rantai induk yang berputar tidak menggantung selamanya', () {
      final loop = CslCatalog.parse('''
{"styles":[{"id":"a","file":"a.csl","title":"A","kind":"dependent","parent":"b"},
           {"id":"b","file":"b.csl","title":"B","kind":"dependent","parent":"a"}],
 "locales":[]}
''');
      expect(loop.resolve('a'), isNull);
    });
  });

  group('pilihan untuk penulis', () {
    test('gaya dependen ikut ditawarkan dengan namanya sendiri', () {
      final titles = all.choices.map((s) => s.title).toList();
      expect(titles, contains('Vancouver - NLM (citation-sequence)'));
      expect(titles, contains('Vancouver - AMA'));
    });

    test('terurut menurut judul, bukan menurut id', () {
      final titles = all.choices.map((s) => s.title.toLowerCase()).toList();
      final sorted = <String>[...titles]..sort();
      expect(titles, sorted);
    });

    test('gaya bernomor dan gaya pengarang-tahun sama-sama ada', () {
      final formats = all.styles.map((s) => s.format).toSet();
      expect(formats, containsAll(<String>['numeric', 'author-date']));
    });
  });
}
