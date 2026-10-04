import '../../library/domain/entities/zotero_item.dart';

/// Mengubah satu item Zotero menjadi CSL-JSON.
///
/// CSL-JSON adalah bentuk yang dimengerti setiap mesin sitasi — citeproc-js,
/// pandoc, dan penyunting mana pun — dan ia **bukan** bentuk Zotero. Nama
/// jenisnya berbeda (`journalArticle` lawan `article-journal`), nama medannya
/// berbeda (`publicationTitle` lawan `container-title`), dan tanggalnya
/// berbentuk angka, bukan kalimat. Seluruh penerjemahan itu ada di berkas ini,
/// satu tempat, supaya penyambung ke Word, LibreOffice, OnlyOffice, dan Google
/// Docs tidak masing-masing menebak sendiri.
///
/// Peta jenis dan peran penulisnya mengikuti peta milik Zotero sendiri. Itu
/// disengaja: daftar pustaka yang dibuat ReadPaper harus sama persis dengan
/// yang dibuat Zotero dari item yang sama, karena keduanya membaca library
/// yang sama dan orang yang sama akan membandingkannya.
class CslJson {
  const CslJson._();

  /// Jenis item Zotero → jenis CSL.
  ///
  /// Yang tidak ada di sini jatuh ke `document`, jenis umum CSL 1.0.2 yang
  /// masih menghasilkan entri masuk akal alih-alih entri kosong.
  static const Map<String, String> itemTypes = <String, String>{
    'journalArticle': 'article-journal',
    'magazineArticle': 'article-magazine',
    'newspaperArticle': 'article-newspaper',
    'preprint': 'article',
    'book': 'book',
    'bookSection': 'chapter',
    'conferencePaper': 'paper-conference',
    'thesis': 'thesis',
    'report': 'report',
    'manuscript': 'manuscript',
    'webpage': 'webpage',
    'blogPost': 'post-weblog',
    'forumPost': 'post',
    'letter': 'personal_communication',
    'email': 'personal_communication',
    'instantMessage': 'personal_communication',
    'interview': 'interview',
    'film': 'motion_picture',
    'videoRecording': 'motion_picture',
    'audioRecording': 'song',
    'podcast': 'broadcast',
    'radioBroadcast': 'broadcast',
    'tvBroadcast': 'broadcast',
    'artwork': 'graphic',
    'map': 'map',
    'presentation': 'speech',
    'computerProgram': 'software',
    'dataset': 'dataset',
    'standard': 'standard',
    'patent': 'patent',
    'case': 'legal_case',
    'statute': 'legislation',
    'bill': 'bill',
    'hearing': 'hearing',
    'encyclopediaArticle': 'entry-encyclopedia',
    'dictionaryEntry': 'entry-dictionary',
    'document': 'document',
    'note': 'document',
    'attachment': 'document',
  };

  /// Peran penulis Zotero → peran CSL.
  ///
  /// Peran yang tidak dikenal dijadikan `author`: sebuah nama yang muncul
  /// dengan peran yang salah masih jauh lebih berguna daripada nama yang
  /// hilang sama sekali dari daftar pustaka.
  static const Map<String, String> creatorTypes = <String, String>{
    'author': 'author',
    'editor': 'editor',
    'seriesEditor': 'collection-editor',
    'bookAuthor': 'container-author',
    'translator': 'translator',
    'contributor': 'contributor',
    'reviewedAuthor': 'reviewed-author',
    'interviewer': 'interviewer',
    'interviewee': 'author',
    'director': 'director',
    'producer': 'producer',
    'scriptwriter': 'script-writer',
    'composer': 'composer',
    'recipient': 'recipient',
    'inventor': 'author',
    'programmer': 'author',
    'presenter': 'author',
    'podcaster': 'author',
    'guest': 'guest',
    'cartographer': 'author',
    'artist': 'author',
    'performer': 'performer',
    'sponsor': 'authority',
    'counsel': 'author',
    'attorneyAgent': 'author',
    'castMember': 'performer',
    'commenter': 'contributor',
    'wordsBy': 'author',
  };

  /// Medan Zotero yang jadi `container-title`, menurut urutan kepercayaan.
  ///
  /// Satu item hanya punya salah satunya, tetapi jenis yang berbeda memakai
  /// nama yang berbeda untuk gagasan yang sama: "tempat karya ini terbit".
  static const List<String> _containerFields = <String>[
    'publicationTitle',
    'bookTitle',
    'proceedingsTitle',
    'encyclopediaTitle',
    'dictionaryTitle',
    'blogTitle',
    'websiteTitle',
    'forumTitle',
    'programTitle',
    'publicationType',
    'reporter',
    'code',
  ];

  /// Medan Zotero yang jadi penerbit, menurut urutan kepercayaan.
  ///
  /// Skripsi menyebutnya `university`, laporan `institution`, perangkat lunak
  /// `company`. Ketiganya penerbit.
  static const List<String> _publisherFields = <String>[
    'publisher',
    'university',
    'institution',
    'company',
    'label',
    'distributor',
    'networkg',
    'network',
  ];

  /// Medan Zotero yang jadi `number`.
  static const List<String> _numberFields = <String>[
    'reportNumber',
    'documentNumber',
    'patentNumber',
    'billNumber',
    'docketNumber',
    'codeNumber',
    'publicLawNumber',
    'applicationNumber',
    'issue',
  ];

  /// Medan Zotero yang jadi `genre` — "jenis karya" yang ditulis apa adanya.
  static const List<String> _genreFields = <String>[
    'thesisType',
    'reportType',
    'letterType',
    'manuscriptType',
    'mapType',
    'presentationType',
    'postType',
    'websiteType',
    'audioRecordingFormat',
    'videoRecordingFormat',
    'genre',
    'type',
  ];

  /// Pemetaan satu-lawan-satu yang tidak perlu penjelasan.
  static const Map<String, String> _plainFields = <String, String>{
    'volume': 'volume',
    'numberOfVolumes': 'number-of-volumes',
    'issue': 'issue',
    'pages': 'page',
    'numPages': 'number-of-pages',
    'edition': 'edition',
    'place': 'publisher-place',
    'series': 'collection-title',
    'seriesTitle': 'collection-title',
    'seriesNumber': 'collection-number',
    'section': 'section',
    'medium': 'medium',
    'scale': 'scale',
    'version': 'version',
    'ISBN': 'ISBN',
    'ISSN': 'ISSN',
    'callNumber': 'call-number',
    'archive': 'archive',
    'archiveLocation': 'archive_location',
    'libraryCatalog': 'source',
    'rights': 'rights',
    'language': 'language',
    'shortTitle': 'title-short',
    'journalAbbreviation': 'container-title-short',
    'conferenceName': 'event-title',
    'meetingName': 'event-title',
    'court': 'authority',
    'legislativeBody': 'authority',
    'issuingAuthority': 'authority',
    'assignee': 'authority',
    'system': 'medium',
  };

  /// CSL-JSON untuk satu item.
  ///
  /// [id] biasanya kunci Zotero-nya; itu yang disimpan di dalam dokumen Word
  /// atau LibreOffice sebagai identitas sitasi, jadi ia harus tahan lama dan
  /// bukan nomor urut yang berubah tiap kali library dimuat ulang.
  static Map<String, dynamic> of(ZoteroItem item) {
    final out = <String, dynamic>{'id': item.key, 'type': itemTypes[item.itemType] ?? 'document'};

    void put(String field, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      out[field] = value is String ? value.trim() : value;
    }

    put('title', item.title);
    put('abstract', item.abstractNote);
    put('DOI', _bareDoi(item.doi));
    put('URL', item.url);
    put('publisher', item.publisher);

    final extra = item.extraFields;

    for (final entry in _plainFields.entries) {
      put(entry.value, extra[entry.key]);
    }
    for (final field in _containerFields) {
      if (out.containsKey('container-title')) break;
      put('container-title', extra[field]);
    }
    if (!out.containsKey('container-title')) {
      put('container-title', item.publication);
    }

    for (final field in _publisherFields) {
      if (out.containsKey('publisher')) break;
      put('publisher', extra[field]);
    }
    for (final field in _genreFields) {
      if (out.containsKey('genre')) break;
      put('genre', extra[field]);
    }
    for (final field in _numberFields) {
      if (out.containsKey('number')) break;
      put('number', extra[field]);
    }

    // `extra` Zotero adalah tempat orang menaruh apa pun yang tidak punya
    // medan sendiri; CSL menyebutnya `note`, dan citeproc membacanya untuk
    // medan tambahan bergaya `original-date: 1867`.
    put('note', extra['extra']);

    final creators = _creatorsOf(item);
    out.addAll(creators);

    final issued = parseDate(item.date);
    if (issued != null) out['issued'] = issued;
    final accessed = parseDate(extra['accessDate'] as String? ?? '');
    if (accessed != null) out['accessed'] = accessed;
    final filed = parseDate(extra['filingDate'] as String? ?? '');
    if (filed != null) out['submitted'] = filed;

    return out;
  }

  /// CSL-JSON untuk banyak item sekaligus, urutannya dipertahankan.
  static List<Map<String, dynamic>> ofAll(Iterable<ZoteroItem> items) => <Map<String, dynamic>>[
    for (final item in items) of(item),
  ];

  /// Nama-nama dikelompokkan menurut perannya di CSL.
  static Map<String, List<Map<String, String>>> _creatorsOf(ZoteroItem item) {
    final out = <String, List<Map<String, String>>>{};
    for (final creator in item.creatorDetails) {
      final role = creatorTypes[creator.creatorType] ?? 'author';
      final name = _nameOf(creator);
      if (name.isEmpty) continue;
      (out[role] ??= <Map<String, String>>[]).add(name);
    }

    // Item lama kadang hanya menyimpan nama sebagai teks, tanpa rinciannya.
    // Menjatuhkannya berarti daftar pustaka tanpa pengarang, jadi ia dibaca
    // apa adanya sebagai satu nama utuh.
    if (out.isEmpty && item.creators.isNotEmpty) {
      out['author'] = <Map<String, String>>[
        for (final raw in item.creators)
          if (raw.trim().isNotEmpty) <String, String>{'literal': raw.trim()},
      ];
    }
    return out;
  }

  /// Satu nama dalam bentuk CSL.
  ///
  /// CSL membedakan nama yang punya bagian depan dan belakang dari nama yang
  /// utuh — lembaga, misalnya, atau nama Indonesia yang memang satu kata.
  /// `literal` adalah cara CSL mengatakan "jangan dibalik, jangan disingkat".
  static Map<String, String> _nameOf(ZoteroCreator creator) {
    final family = creator.lastName.trim();
    final given = creator.firstName.trim();
    if (family.isEmpty && given.isEmpty) {
      final whole = creator.name.trim();
      return whole.isEmpty ? const <String, String>{} : <String, String>{'literal': whole};
    }
    if (family.isEmpty) return <String, String>{'literal': given};
    if (given.isEmpty) {
      // Nama satu kata: kalau ditaruh sebagai `family` saja, sebagian gaya
      // tetap mencoba menyingkat nama depan yang tidak ada dan menghasilkan
      // koma yang menggantung.
      return <String, String>{'literal': family};
    }
    return <String, String>{'family': family, 'given': given};
  }

  /// DOI tanpa awalan alamat web.
  ///
  /// Sebagian item menyimpannya sebagai `https://doi.org/10.1000/xyz`, dan
  /// gaya sitasi yang menambahkan awalannya sendiri akan menuliskannya dua
  /// kali.
  static String _bareDoi(String doi) {
    var value = doi.trim();
    for (final prefix in const <String>[
      'https://doi.org/',
      'http://doi.org/',
      'https://dx.doi.org/',
      'http://dx.doi.org/',
      'doi:',
      'DOI:',
    ]) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length);
        break;
      }
    }
    return value.trim();
  }

  static final RegExp _ymd = RegExp(r'^(\d{4})-(\d{1,2})(?:-(\d{1,2}))?');
  static final RegExp _year = RegExp(r'(1\d{3}|2\d{3})');

  /// Nama bulan yang ditulis orang, Indonesia dan Inggris.
  static const Map<String, int> _months = <String, int>{
    'jan': 1,
    'januari': 1,
    'january': 1,
    'feb': 2,
    'februari': 2,
    'february': 2,
    'peb': 2,
    'mar': 3,
    'maret': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'mei': 5,
    'may': 5,
    'jun': 6,
    'juni': 6,
    'june': 6,
    'jul': 7,
    'juli': 7,
    'july': 7,
    'agu': 8,
    'agustus': 8,
    'aug': 8,
    'august': 8,
    'ags': 8,
    'sep': 9,
    'september': 9,
    'sept': 9,
    'okt': 10,
    'oktober': 10,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'des': 12,
    'desember': 12,
    'dec': 12,
    'december': 12,
  };

  /// Tanggal Zotero → tanggal CSL.
  ///
  /// Zotero menyimpan tanggal sebagai teks yang ditulis manusia: `2024`,
  /// `2024-05`, `2024-05-13`, `Mei 2024`, `13 Mei 2024`, kadang `n.d.`. CSL
  /// menuntut angka. Yang tidak terbaca tetap dibawa sebagai `raw` supaya
  /// tidak hilang — sebuah gaya masih bisa mencetaknya apa adanya, dan itu
  /// lebih baik daripada entri tanpa tahun sama sekali.
  static Map<String, dynamic>? parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final iso = _ymd.firstMatch(text);
    if (iso != null) {
      final parts = <int>[int.parse(iso.group(1)!), int.parse(iso.group(2)!)];
      if (iso.group(3) != null) parts.add(int.parse(iso.group(3)!));
      if (parts[1] >= 1 && parts[1] <= 12) {
        return <String, dynamic>{
          'date-parts': <List<int>>[parts],
          'raw': text,
        };
      }
    }

    final year = _year.firstMatch(text);
    if (year == null) return <String, dynamic>{'raw': text};

    final parts = <int>[int.parse(year.group(0)!)];
    final lowered = text.toLowerCase();
    for (final entry in _months.entries) {
      if (!RegExp('\\b${entry.key}\\b').hasMatch(lowered)) continue;
      parts.add(entry.value);
      // Hari hanya dipercaya kalau bulannya juga terbaca; angka kecil yang
      // berdiri sendiri sering nomor terbitan, bukan tanggal.
      final day = RegExp(
        r'\b([1-9]|[12]\d|3[01])\b',
      ).firstMatch(lowered.replaceAll(year.group(0)!, ''));
      if (day != null) parts.add(int.parse(day.group(1)!));
      break;
    }

    return <String, dynamic>{
      'date-parts': <List<int>>[parts],
      'raw': text,
    };
  }
}
