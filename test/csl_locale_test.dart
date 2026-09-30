import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/citation/domain/csl_locale.dart';

/// Locale sungguhan dari proyek CSL, bukan tiruan.
///
/// Tiruan hanya membuktikan pembacanya sesuai dengan tiruan itu. Yang harus
/// dibuktikan adalah ia sesuai dengan berkas yang benar-benar dipakai Zotero.
CslLocale load(String language) =>
    CslLocale.parse(File('assets/csl/locales/locales-$language.xml').readAsStringSync());

void main() {
  late CslLocale id;
  late CslLocale en;

  setUpAll(() {
    id = load('id-ID');
    en = load('en-US');
  });

  test('bahasanya terbaca dari atribut xml:lang', () {
    expect(id.language, 'id-ID');
    expect(en.language, 'en-US');
  });

  group('istilah', () {
    test('"dkk." dan "et al." datang dari locale, bukan dari gaya', () {
      expect(id.term('et-al'), 'dkk.');
      expect(en.term('et-al'), 'et al.');
    });

    test('"dan" lawan "and"', () {
      expect(id.term('and'), 'dan');
      expect(en.term('and'), 'and');
    });

    test('istilah bertunggal dan berjamak dibedakan', () {
      expect(en.term('page', plural: false), 'page');
      expect(en.term('page', plural: true), 'pages');
    });

    test('bentuk pendek dipakai kalau ada', () {
      expect(id.term('page', form: 'short'), 'hlm.');
      expect(en.term('edition', form: 'short'), 'ed.');
    });

    test('bentuk yang tidak ada mundur ke bentuk panjang, bukan jadi kosong', () {
      // "symbol" untuk halaman tidak ada di locale Indonesia; ia harus mundur
      // ke "short" lalu ke "long", bukan menghasilkan kekosongan.
      expect(id.term('page', form: 'symbol'), isNotNull);
      expect(id.term('page', form: 'symbol'), isNot(''));
    });

    test('istilah yang memang tidak ada tetap null', () {
      expect(en.term('istilah-yang-tidak-pernah-ada'), isNull);
    });
  });

  group('bulan', () {
    test('nama bulan Indonesia', () {
      expect(id.month(1), 'Januari');
      expect(id.month(5), 'Mei');
      expect(id.month(12), 'Desember');
    });

    test('nama bulan Inggris', () {
      expect(en.month(1), 'January');
      expect(en.month(9), 'September');
    });

    test('bentuk pendeknya ada', () {
      expect(en.month(1, form: 'short'), 'Jan.');
    });

    test('di luar 1..12 tidak menghasilkan apa-apa', () {
      expect(en.month(0), isNull);
      expect(en.month(13), isNull);
    });
  });

  group('bentuk tanggal', () {
    test('urutan bagiannya berbeda antar bahasa', () {
      final idText = id.dateFormat('text')!.parts.map((p) => p.name).toList();
      final enText = en.dateFormat('text')!.parts.map((p) => p.name).toList();

      // Indonesia: 13 Mei 2024. Inggris: May 13, 2024.
      expect(idText, <String>['day', 'month', 'year']);
      expect(enText, <String>['month', 'day', 'year']);
    });

    test('bentuk numerik ada dan berakhiran pemisah', () {
      final numeric = id.dateFormat('numeric')!;
      expect(numeric.parts, isNotEmpty);
      expect(numeric.parts.first.suffix, isNotEmpty);
    });
  });

  group('penggabungan', () {
    test('gaya boleh menambal satu istilah tanpa menulis ulang bahasanya', () {
      final patch = CslLocale.parse('''
<locale xmlns="http://purl.org/net/xbiblio/csl" version="1.0">
  <terms><term name="et-al">dan kawan-kawan</term></terms>
</locale>
''');
      final merged = id.mergedWith(patch);

      expect(merged.term('et-al'), 'dan kawan-kawan');
      // Yang tidak ditambal tetap utuh.
      expect(merged.term('and'), 'dan');
      expect(merged.month(5), 'Mei');
      expect(merged.language, 'id-ID');
    });
  });
}
