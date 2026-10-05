/// BibTeX dari CSL-JSON — untuk naskah LaTeX.
///
/// Dibangun dari CSL-JSON yang sama dengan yang dipakai sitasi di Word dan
/// OnlyOffice ([CslJson.of]), jadi satu paper punya satu tafsiran data di semua
/// jalur: judul, pengarang, dan tahun yang muncul di daftar pustaka Word sama
/// dengan yang masuk ke `.bib`.
///
/// Kunci sitasi adalah satu-satunya hal yang dipegang naskah LaTeX — `\cite{…}`
/// menunjuk ke sana — jadi ia harus **stabil**: mengekspor ulang koleksi yang
/// sama tidak boleh mengganti kunci dan mematahkan naskah. Aturannya:
/// - `Citation Key: …` di kolom Extra Zotero (konvensi Better BibTeX) dipakai
///   apa adanya, sehingga kuncinya sama dengan yang di Zotero;
/// - selain itu `pengarang` + `tahun` + `kata judul pertama`, huruf kecil ASCII,
///   mis. `mcclean2018barren`;
/// - yang bentrok diberi akhiran `a`, `b`, … menurut urutan kunci Zotero-nya,
///   bukan urutan tampil, supaya hasilnya sama setiap kali.
class BibTex {
  const BibTex._();

  /// Seluruh isi berkas `.bib` untuk [items] (CSL-JSON), diurutkan menurut
  /// kunci sitasinya.
  static String export(List<Map<String, dynamic>> items) {
    final keys = citationKeys(items);
    final entries = <(String, String)>[
      for (final item in items) (keys[item['id']]!, entry(item, keys[item['id']]!)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return entries.map((e) => e.$2).join('\n');
  }

  /// Kunci sitasi untuk setiap item, per `id` (kunci Zotero).
  static Map<String, String> citationKeys(List<Map<String, dynamic>> items) {
    final byBase = <String, List<Map<String, dynamic>>>{};
    final fixed = <String, String>{};
    for (final item in items) {
      final explicit = explicitKey(item);
      if (explicit != null) {
        fixed[item['id'] as String] = explicit;
      } else {
        byBase.putIfAbsent(baseKey(item), () => <Map<String, dynamic>>[]).add(item);
      }
    }
    final out = <String, String>{...fixed};
    final taken = fixed.values.toSet();
    for (final entry in byBase.entries) {
      final group = entry.value..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      for (var i = 0; i < group.length; i++) {
        var key = group.length == 1 ? entry.key : '${entry.key}${_suffix(i)}';
        while (taken.contains(key)) {
          key = '${key}x';
        }
        taken.add(key);
        out[group[i]['id'] as String] = key;
      }
    }
    return out;
  }

  static String _suffix(int i) {
    var n = i;
    var out = '';
    do {
      out = String.fromCharCode(97 + n % 26) + out;
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return out;
  }

  static final RegExp _citationKeyLine = RegExp(
    r'^\s*Citation Key:\s*(\S+)\s*$',
    multiLine: true,
    caseSensitive: false,
  );

  /// `Citation Key: …` di kolom Extra, kalau ada.
  static String? explicitKey(Map<String, dynamic> item) {
    final note = item['note'];
    if (note is! String) return null;
    return _citationKeyLine.firstMatch(note)?.group(1);
  }

  /// Kunci dasar sebelum dibedakan dari yang kembar.
  static String baseKey(Map<String, dynamic> item) {
    final people = (item['author'] ?? item['editor']) as List?;
    var who = '';
    if (people != null && people.isNotEmpty) {
      final first = people.first as Map;
      who = (first['family'] ?? first['literal'] ?? '') as String;
    }
    final year = _year(item) ?? 'nd';
    final word = _titleWords(item['title'] as String? ?? '').firstOrNull ?? '';
    final key = '${_ascii(who).split(' ').first}$year$word';
    return key.isEmpty ? (item['id'] as String).toLowerCase() : key;
  }

  static const Set<String> _stopwords = <String>{
    'a',
    'an',
    'the',
    'of',
    'on',
    'in',
    'and',
    'for',
    'to',
    'with',
    'at',
    'by',
    'from',
    'yang',
    'dan',
    'di',
    'ke',
    'dari',
    'untuk',
    'dengan',
    'pada',
    'dalam',
    'sebuah',
    'suatu',
  };

  static Iterable<String> _titleWords(String title) =>
      _ascii(title).split(' ').where((w) => w.isNotEmpty && !_stopwords.contains(w));

  /// Huruf kecil, tanpa diakritik, hanya a–z, 0–9, dan spasi.
  static String _ascii(String input) {
    const from = 'àáâãäåāăąçćčďèéêëēėęěğìíîïīįıľłñńňòóôõöøōőŕřśšşťùúûüūůűųýÿžźż';
    const to = 'aaaaaaaaacccdeeeeeeeegiiiiiiillnnnoooooooorrsssstuuuuuuuuyyzzz';
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      final mapped = i >= 0 ? to[i] : ch;
      if (RegExp(r'[a-z0-9]').hasMatch(mapped)) {
        buffer.write(mapped);
      } else if (mapped == 'ß') {
        buffer.write('ss');
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _year(Map<String, dynamic> item) {
    final parts = (item['issued'] as Map?)?['date-parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    final first = parts.first as List;
    return first.isEmpty ? null : '${first.first}';
  }

  /// CSL → jenis entri BibTeX.
  static String typeOf(Map<String, dynamic> item) {
    final genre = (item['genre'] as String? ?? '').toLowerCase();
    return switch (item['type']) {
      'article-journal' || 'article-magazine' || 'article-newspaper' => 'article',
      'book' => 'book',
      'chapter' || 'entry-encyclopedia' || 'entry-dictionary' => 'incollection',
      'paper-conference' => 'inproceedings',
      'thesis' =>
        genre.contains('master') || genre.contains('tesis') ? 'mastersthesis' : 'phdthesis',
      'report' => 'techreport',
      'manuscript' => 'unpublished',
      _ => 'misc',
    };
  }

  /// Satu entri `@jenis{kunci, …}`.
  static String entry(Map<String, dynamic> item, String key) {
    final type = typeOf(item);
    final fields = <(String, String)>[];
    void put(String name, Object? value, {bool raw = false}) {
      if (value == null) return;
      final text = '$value'.trim();
      if (text.isEmpty) return;
      fields.add((name, raw ? text : escape(text)));
    }

    put('author', _names(item['author']), raw: true);
    put('editor', _names(item['editor']), raw: true);
    put('title', item['title']);
    final container = item['container-title'];
    switch (type) {
      case 'article':
        put('journal', container);
      case 'incollection' || 'inproceedings':
        put('booktitle', container);
      case 'misc':
        put('howpublished', container);
    }
    put('year', _year(item));
    final month = _month(item);
    if (month != null) fields.add(('month', month));
    put('volume', item['volume']);
    put('number', item['issue'] ?? (type == 'techreport' ? item['number'] : null));
    final page = item['page'];
    if (page is String) put('pages', page.replaceAll(RegExp(r'\s*[-–—]+\s*'), '--'));
    switch (type) {
      case 'phdthesis' || 'mastersthesis':
        put('school', item['publisher']);
      case 'techreport':
        put('institution', item['publisher']);
      default:
        put('publisher', item['publisher']);
    }
    put('address', item['publisher-place']);
    put('edition', item['edition']);
    put('isbn', item['ISBN']);
    put('issn', item['ISSN']);
    put('doi', item['DOI'], raw: true);
    put('url', item['URL'], raw: true);
    put('abstract', item['abstract']);

    final width = fields.fold(0, (w, f) => f.$1.length > w ? f.$1.length : w);
    final body = fields.map((f) => '  ${f.$1.padRight(width)} = {${f.$2}}').join(',\n');
    return '@$type{$key,\n$body\n}\n';
  }

  static String? _names(Object? people) {
    if (people is! List || people.isEmpty) return null;
    return people
        .map((p) {
          final person = p as Map;
          final literal = person['literal'] as String?;
          // Nama lembaga dibungkus kurung kurawal: tanpa itu BibTeX membacanya
          // sebagai "Organization, World Health".
          if (literal != null && literal.isNotEmpty) return '{${escape(literal)}}';
          final family = escape(person['family'] as String? ?? '');
          final given = escape(person['given'] as String? ?? '');
          return given.isEmpty ? family : '$family, $given';
        })
        .where((n) => n.isNotEmpty)
        .join(' and ');
  }

  static const List<String> _months = <String>[
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  /// Bulan sebagai makro BibTeX (`jan`, `feb`, …), tanpa kurung kurawal.
  static String? _month(Map<String, dynamic> item) {
    final parts = (item['issued'] as Map?)?['date-parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    final first = parts.first as List;
    if (first.length < 2) return null;
    final m = first[1];
    return m is int && m >= 1 && m <= 12 ? _months[m - 1] : null;
  }

  /// Karakter yang punya arti di LaTeX diloloskan, supaya judul berisi `&`
  /// atau `%` tidak menggagalkan kompilasi — `%` bahkan memotong sisa baris
  /// tanpa pesan apa pun.
  static String escape(String input) {
    final out = StringBuffer();
    for (final ch in input.split('')) {
      out.write(switch (ch) {
        r'\' => r'\textbackslash{}',
        '&' => r'\&',
        '%' => r'\%',
        r'$' => r'\$',
        '#' => r'\#',
        '_' => r'\_',
        '{' => r'\{',
        '}' => r'\}',
        '~' => r'\textasciitilde{}',
        '^' => r'\textasciicircum{}',
        _ => ch,
      });
    }
    return out.toString();
  }
}
