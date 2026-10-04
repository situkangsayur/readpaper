import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/citation/domain/csl_catalog.dart';
import 'package:readpaper/src/features/citation/domain/csl_style.dart';

CslCatalog catalog() => CslCatalog.parse(File('assets/csl/styles.json').readAsStringSync());

CslStyle load(String id) => CslStyle.parse(File('assets/csl/styles/$id.csl').readAsStringSync());

void main() {
  test('setiap gaya independen yang dibawa benar-benar terbaca', () {
    for (final entry in catalog().styles.where((s) => !s.isDependent)) {
      final style = load(entry.id);
      expect(style.id, entry.id);
      expect(style.citation.children, isNotEmpty, reason: '${entry.id}: layout sitasinya kosong');
      expect(style.macros, isNotEmpty, reason: '${entry.id}: tidak punya makro sama sekali');
    }
  });

  test('gaya dependen ditolak dengan menyebut induknya, bukan diam-diam kosong', () {
    // Ini yang mencegah daftar pustaka kosong muncul di tengah dokumen orang:
    // gaya dependen memang tidak berisi aturan apa pun, dan itu harus
    // terdengar sebagai kesalahan, bukan sebagai hasil.
    expect(
      () => load('vancouver-nlm'),
      throwsA(
        isA<CslStyleIsDependent>()
            .having((e) => e.id, 'id', 'vancouver-nlm')
            .having((e) => e.parent, 'induk', 'nlm-citation-sequence'),
      ),
    );
    expect(
      () => load('vancouver-ama'),
      throwsA(
        isA<CslStyleIsDependent>().having((e) => e.parent, 'induk', 'american-medical-association'),
      ),
    );
  });

  group('IEEE — gaya bernomor', () {
    late CslStyle ieee;
    setUpAll(() => ieee = load('ieee'));

    test('sitasinya memakai nomor urut', () {
      expect(ieee.isNumeric, isTrue);
    });

    test('daftar pustakanya meratakan nomor ke kiri', () {
      // `second-field-align="flush"` itulah yang membuat "[1]" berdiri di
      // kolomnya sendiri alih-alih menempel ke teks entrinya.
      expect(ieee.bibliography, isNotNull);
      expect(ieee.bibliography!.option('second-field-align'), 'flush');
    });

    test('kelasnya in-text, bukan catatan kaki', () {
      expect(ieee.styleClass, 'in-text');
    });
  });

  group('APA — gaya pengarang-tahun', () {
    late CslStyle apa;
    setUpAll(() => apa = load('apa'));

    test('bukan gaya bernomor', () {
      expect(apa.isNumeric, isFalse);
    });

    test('daftar pustakanya menjorok gantung', () {
      expect(apa.bibliography!.flag('hanging-indent'), isTrue);
    });

    test('daftar pustakanya diurutkan, dan kunci urutnya terbaca', () {
      expect(apa.bibliography!.sort, isNotEmpty);
    });

    test('membedakan sitasi yang kembar dengan huruf setelah tahun', () {
      expect(apa.citation.flag('disambiguate-add-year-suffix'), isTrue);
    });
  });

  test('locale bawaan gaya terbaca kalau ada', () {
    // Sebagian gaya memaksa bahasanya sendiri; yang tidak, mengikuti pilihan
    // penulis.
    for (final entry in catalog().styles.where((s) => !s.isDependent)) {
      expect(load(entry.id).defaultLocale, isA<String>());
    }
  });

  test('gaya tanpa blok citation ditolak', () {
    expect(
      () => CslStyle.parse('''
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info><id>http://example.org/kosong</id><title>Kosong</title></info>
</style>
'''),
      throwsA(isA<FormatException>()),
    );
  });
}
