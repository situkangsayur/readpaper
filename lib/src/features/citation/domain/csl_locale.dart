import 'package:xml/xml.dart';

/// Satu istilah CSL beserta bentuk tunggal dan jamaknya.
///
/// Sebagian istilah punya dua bentuk — `halaman` dan `halaman-halaman`,
/// `page` dan `pages` — dan gaya sitasi memilih salah satunya menurut berapa
/// banyak yang dirujuk. Sebagian lain hanya satu kata untuk keduanya.
class CslTerm {
  const CslTerm({required this.single, required this.multiple});

  const CslTerm.same(String value) : single = value, multiple = value;

  final String single;
  final String multiple;

  /// Bentuk yang dipakai kalau yang dirujuk lebih dari satu.
  String forCount(bool plural) => plural ? multiple : single;
}

/// Bentuk tanggal bawaan sebuah bahasa: urutan bagiannya beserta pemisahnya.
///
/// Gaya sitasi boleh menyebut `<date form="text" />` tanpa merinci apa pun,
/// dan yang menentukan hasilnya adalah locale: bahasa Indonesia menulis
/// `13 Mei 2024`, bahasa Inggris `May 13, 2024`. Urutan itu ada di sini.
class CslDateFormat {
  const CslDateFormat(this.parts);

  /// Tiap bagian: nama (`day`/`month`/`year`), bentuk, awalan, akhiran.
  final List<CslDatePart> parts;
}

class CslDatePart {
  const CslDatePart({required this.name, this.form = '', this.prefix = '', this.suffix = ''});

  final String name;
  final String form;
  final String prefix;
  final String suffix;
}

/// Istilah, nama bulan, dan bentuk tanggal untuk satu bahasa.
///
/// Inilah yang membuat daftar pustaka berbahasa Indonesia berbunyi "dkk."
/// dan "dalam" alih-alih "et al." dan "in", tanpa satu pun gaya CSL perlu
/// diubah. Gaya menyebut nama istilahnya; locale yang menyediakan katanya.
class CslLocale {
  CslLocale({
    required this.language,
    required Map<String, CslTerm> terms,
    required Map<String, CslDateFormat> dates,
    this.punctuationInQuote = false,
    this.limitDayOrdinalsToDay1 = false,
  }) : _terms = terms,
       _dates = dates;

  final String language;
  final Map<String, CslTerm> _terms;
  final Map<String, CslDateFormat> _dates;
  final bool punctuationInQuote;
  final bool limitDayOrdinalsToDay1;

  static const String _ns = 'http://purl.org/net/xbiblio/csl';

  /// Kunci penyimpanan istilah: nama beserta bentuknya.
  static String keyOf(String name, String form) => form.isEmpty ? name : '$name/$form';

  /// Istilah [name] dalam [form], dengan aturan mundur milik CSL.
  ///
  /// Spesifikasinya tegas soal ini: bentuk yang tidak ada **tidak** berarti
  /// istilahnya tidak ada. `verb-short` mundur ke `verb`, lalu ke `long`;
  /// `symbol` mundur ke `short`, lalu ke `long`. Tanpa aturan itu sebuah gaya
  /// yang meminta `symbol` untuk "halaman" akan menghasilkan kekosongan,
  /// padahal locale-nya menyediakan "hlm.".
  String? term(String name, {String form = 'long', bool plural = false}) {
    for (final candidate in _formChain(form)) {
      final found = _terms[keyOf(name, candidate)];
      if (found != null) {
        final value = plural ? found.multiple : found.single;
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static List<String> _formChain(String form) => switch (form) {
    'verb-short' => const <String>['verb-short', 'verb', '', 'long'],
    'verb' => const <String>['verb', '', 'long'],
    'symbol' => const <String>['symbol', 'short', '', 'long'],
    'short' => const <String>['short', '', 'long'],
    _ => const <String>['', 'long'],
  };

  /// Nama bulan ke-[month] (1–12), atau null kalau di luar jangkauan.
  String? month(int month, {String form = 'long'}) {
    if (month < 1 || month > 12) return null;
    final name = 'month-${month.toString().padLeft(2, '0')}';
    return term(name, form: form);
  }

  /// Bentuk tanggal bawaan: `text` atau `numeric`.
  CslDateFormat? dateFormat(String form) => _dates[form];

  /// Membaca berkas locale CSL (`locales-id-ID.xml`).
  factory CslLocale.parse(String xml) {
    final doc = XmlDocument.parse(xml);
    final root = doc.rootElement;
    final language =
        root.getAttribute('lang', namespaceUri: 'http://www.w3.org/XML/1998/namespace') ??
        root.getAttribute('xml:lang') ??
        '';

    final terms = <String, CslTerm>{};
    for (final element in root.findAllElements('term', namespaceUri: _ns)) {
      final name = element.getAttribute('name');
      if (name == null) continue;
      final form = element.getAttribute('form') ?? '';
      final single = element.getElement('single', namespaceUri: _ns)?.innerText;
      final multiple = element.getElement('multiple', namespaceUri: _ns)?.innerText;
      final term = single == null && multiple == null
          ? CslTerm.same(element.innerText.trim())
          : CslTerm(
              single: (single ?? multiple ?? '').trim(),
              multiple: (multiple ?? single ?? '').trim(),
            );
      // Istilah yang muncul dua kali — berkas locale memang mengulang
      // sebagiannya — dimenangkan oleh yang pertama, sama seperti citeproc.
      terms.putIfAbsent(keyOf(name, form), () => term);
    }

    final dates = <String, CslDateFormat>{};
    for (final element in root.findElements('date', namespaceUri: _ns)) {
      final form = element.getAttribute('form');
      if (form == null) continue;
      dates[form] = CslDateFormat(<CslDatePart>[
        for (final part in element.findElements('date-part', namespaceUri: _ns))
          CslDatePart(
            name: part.getAttribute('name') ?? '',
            form: part.getAttribute('form') ?? '',
            prefix: part.getAttribute('prefix') ?? '',
            suffix: part.getAttribute('suffix') ?? '',
          ),
      ]);
    }

    final options = root.getElement('style-options', namespaceUri: _ns);
    return CslLocale(
      language: language,
      terms: terms,
      dates: dates,
      punctuationInQuote: options?.getAttribute('punctuation-in-quote') == 'true',
      limitDayOrdinalsToDay1: options?.getAttribute('limit-day-ordinals-to-day-1') == 'true',
    );
  }

  /// Locale gabungan: [over] menimpa istilah dan tanggal milik dasar ini.
  ///
  /// Gaya CSL boleh membawa blok `<locale>` sendiri untuk menambal satu dua
  /// istilah — sebuah jurnal yang menulis "edisi ke-" alih-alih "edisi",
  /// misalnya — tanpa menuntut seluruh berkas bahasa ditulis ulang.
  CslLocale mergedWith(CslLocale over) => CslLocale(
    language: over.language.isEmpty ? language : over.language,
    terms: <String, CslTerm>{..._terms, ...over._terms},
    dates: <String, CslDateFormat>{..._dates, ...over._dates},
    punctuationInQuote: over.punctuationInQuote || punctuationInQuote,
    limitDayOrdinalsToDay1: over.limitDayOrdinalsToDay1 || limitDayOrdinalsToDay1,
  );
}
