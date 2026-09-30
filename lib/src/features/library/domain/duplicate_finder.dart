import 'entities/zotero_item.dart';

/// Kenapa dua item dianggap salinan yang sama.
///
/// Urutannya adalah urutan kepercayaan, dan itu yang ditampilkan ke orang:
/// "DOI-nya sama" adalah pernyataan yang hampir tidak bisa salah, sedangkan
/// "judul, tahun, dan pengarangnya sama" adalah dugaan yang pantas diperiksa
/// dulu. Menyamakan keduanya berarti meminta orang memercayai tebakan sekuat
/// mereka memercayai fakta.
enum DuplicateReason {
  doi('DOI-nya sama'),
  isbn('ISBN-nya sama'),
  titleYearAuthor('Judul, tahun, dan pengarangnya sama');

  const DuplicateReason(this.label);

  final String label;
}

/// Sekelompok item yang tampaknya salinan dari karya yang sama.
class DuplicateGroup {
  const DuplicateGroup({required this.items, required this.reasons});

  /// Terurut: yang paling lengkap lebih dulu — itu calon yang dipertahankan.
  final List<ZoteroItem> items;

  /// Semua alasan yang membuat kelompok ini terbentuk.
  final Set<DuplicateReason> reasons;

  /// Alasan terkuat, untuk ditampilkan sebagai ringkasan.
  DuplicateReason get strongest => DuplicateReason.values.firstWhere(
    reasons.contains,
    orElse: () => DuplicateReason.titleYearAuthor,
  );

  /// Jumlah anotasi di seluruh salinan.
  ///
  /// Angka ini yang membuat penggabungan terasa berisiko atau tidak: dua
  /// salinan yang sama-sama punya coretan tidak boleh digabung sembarangan.
  int get totalAnnotations =>
      items.fold(0, (sum, item) => sum + item.annotationCount);

  bool get annotationsOnMoreThanOne =>
      items.where((item) => item.annotationCount > 0).length > 1;
}

/// Menemukan item yang sebenarnya karya yang sama, masuk dua kali.
///
/// Library yang tumbuh dari beberapa sumber — diimpor dari BibTeX, ditarik
/// lewat penambah peramban, lalu disalin dari rekan penulis — hampir pasti
/// punya ganda. Yang mahal bukan ruangnya, melainkan anotasi yang tersebar:
/// stabilo di satu salinan dan catatan di salinan lain, dan tidak ada satu
/// pun yang lengkap.
///
/// Pencocokannya bertingkat, dari yang pasti ke yang menduga: DOI, lalu ISBN,
/// lalu judul + tahun + nama belakang pengarang pertama. Yang tidak pernah
/// dilakukan di sini adalah **menghapus apa pun**; kelas ini hanya menjawab
/// "yang mana yang mencurigakan", dan keputusannya milik orang.
class DuplicateFinder {
  const DuplicateFinder._();

  /// Jenis item yang tidak pernah ikut dibandingkan.
  static const Set<String> _ignoredTypes = <String>{
    'attachment',
    'note',
    'annotation',
  };

  static List<DuplicateGroup> find(List<ZoteroItem> items) {
    final candidates = <ZoteroItem>[
      for (final item in items)
        if (!_ignoredTypes.contains(item.itemType)) item,
    ];
    if (candidates.length < 2) return const <DuplicateGroup>[];

    final union = _Union(candidates.length);
    final reasons = <int, Set<DuplicateReason>>{};

    void link(int a, int b, DuplicateReason reason) {
      union.join(a, b);
      (reasons[union.find(a)] ??= <DuplicateReason>{}).add(reason);
    }

    void bucket(String Function(ZoteroItem) keyOf, DuplicateReason reason) {
      final seen = <String, int>{};
      for (var i = 0; i < candidates.length; i++) {
        final key = keyOf(candidates[i]);
        if (key.isEmpty) continue;
        final first = seen[key];
        if (first == null) {
          seen[key] = i;
        } else {
          link(first, i, reason);
        }
      }
    }

    bucket(doiKeyOf, DuplicateReason.doi);
    bucket(isbnKeyOf, DuplicateReason.isbn);
    bucket(titleKeyOf, DuplicateReason.titleYearAuthor);

    // Alasan dikumpulkan di bawah wakil kelompok yang berlaku **saat** ia
    // dicatat, dan wakil itu bisa berganti setelah penggabungan berikutnya.
    // Jadi dikumpulkan ulang di akhir, bukan diandalkan apa adanya.
    final merged = <int, Set<DuplicateReason>>{};
    for (final entry in reasons.entries) {
      (merged[union.find(entry.key)] ??= <DuplicateReason>{}).addAll(
        entry.value,
      );
    }

    final members = <int, List<ZoteroItem>>{};
    for (var i = 0; i < candidates.length; i++) {
      (members[union.find(i)] ??= <ZoteroItem>[]).add(candidates[i]);
    }

    final groups = <DuplicateGroup>[
      for (final entry in members.entries)
        if (entry.value.length > 1)
          DuplicateGroup(
            items: <ZoteroItem>[...entry.value]..sort(_mostCompleteFirst),
            reasons:
                merged[entry.key] ??
                <DuplicateReason>{DuplicateReason.titleYearAuthor},
          ),
    ];

    // Yang paling meyakinkan lebih dulu, lalu yang paling banyak salinannya.
    groups.sort((a, b) {
      final byReason = a.strongest.index.compareTo(b.strongest.index);
      if (byReason != 0) return byReason;
      final byCount = b.items.length.compareTo(a.items.length);
      if (byCount != 0) return byCount;
      return a.items.first.title.toLowerCase().compareTo(
        b.items.first.title.toLowerCase(),
      );
    });
    return groups;
  }

  /// Salinan mana yang pantas dipertahankan kalau nanti digabung.
  ///
  /// Yang punya anotasi didahulukan — itu pekerjaan orang, dan paling mahal
  /// kalau hilang. Setelah itu yang punya berkas, lalu yang metadatanya
  /// paling lengkap.
  static int _mostCompleteFirst(ZoteroItem a, ZoteroItem b) {
    final byAnnotations = b.annotationCount.compareTo(a.annotationCount);
    if (byAnnotations != 0) return byAnnotations;
    final byFile = (b.hasReadableFile ? 1 : 0).compareTo(
      a.hasReadableFile ? 1 : 0,
    );
    if (byFile != 0) return byFile;
    final byFields = _richness(b).compareTo(_richness(a));
    if (byFields != 0) return byFields;
    return a.key.compareTo(b.key);
  }

  static int _richness(ZoteroItem item) =>
      (item.doi.isNotEmpty ? 1 : 0) +
      (item.abstractNote.isNotEmpty ? 1 : 0) +
      (item.publication.isNotEmpty ? 1 : 0) +
      (item.publisher.isNotEmpty ? 1 : 0) +
      (item.url.isNotEmpty ? 1 : 0) +
      (item.date.isNotEmpty ? 1 : 0) +
      item.creatorDetails.length +
      item.extraFields.length;

  /// DOI yang dinormalkan, atau kosong kalau tidak ada.
  static String doiKeyOf(ZoteroItem item) {
    var value = item.doi.trim().toLowerCase();
    for (final prefix in const <String>[
      'https://doi.org/',
      'http://doi.org/',
      'https://dx.doi.org/',
      'http://dx.doi.org/',
      'doi:',
    ]) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length);
        break;
      }
    }
    // Titik di ujung datang dari DOI yang disalin dari kalimat.
    value = value.replaceAll(RegExp(r'[.,;)\]]+$'), '').trim();
    return value.startsWith('10.') ? value : '';
  }

  /// ISBN yang dinormalkan ke bentuk 13 angka.
  ///
  /// Satu buku yang sama sering tercatat dengan ISBN-10 di satu salinan dan
  /// ISBN-13 di salinan lain; membandingkannya apa adanya membuat keduanya
  /// tampak berbeda padahal buku yang sama.
  static String isbnKeyOf(ZoteroItem item) {
    final raw = item.extraFields['ISBN'];
    if (raw is! String) return '';
    // Satu medan bisa memuat beberapa ISBN; yang pertama sudah cukup.
    final cleaned = raw.toUpperCase().replaceAll(RegExp('[^0-9X]'), '');
    if (cleaned.length >= 13) return cleaned.substring(0, 13);
    if (cleaned.length == 10) return _isbn13(cleaned);
    return '';
  }

  static String _isbn13(String isbn10) {
    final body = '978${isbn10.substring(0, 9)}';
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(body[i]) * (i.isEven ? 1 : 3);
    }
    return '$body${(10 - sum % 10) % 10}';
  }

  /// Judul + tahun + nama belakang pengarang pertama, dinormalkan.
  ///
  /// Ketiganya harus ada. Judul saja terlalu longgar — "Introduction" ada di
  /// sepuluh buku — dan judul tanpa tahun membuat edisi kedua tampak sama
  /// dengan edisi pertama.
  static String titleKeyOf(ZoteroItem item) {
    final title = normalizeTitle(item.title);
    if (title.length < 4) return '';
    final year = yearOf(item);
    if (year.isEmpty) return '';
    final author = firstAuthorKeyOf(item);
    if (author.isEmpty) return '';
    return '$title|$year|$author';
  }

  /// Judul tanpa tanda baca, tanpa kata sandang di depan, huruf kecil semua.
  static String normalizeTitle(String title) {
    var value = title
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), ' ')
        .trim();
    for (final article in const <String>['the ', 'a ', 'an ']) {
      if (value.startsWith(article)) {
        value = value.substring(article.length);
        break;
      }
    }
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String yearOf(ZoteroItem item) {
    if (item.year.length == 4 && int.tryParse(item.year) != null) {
      return item.year;
    }
    final found = RegExp(r'(1\d{3}|2\d{3})').firstMatch(item.date);
    return found?.group(0) ?? '';
  }

  /// Nama belakang pengarang pertama, dinormalkan.
  static String firstAuthorKeyOf(ZoteroItem item) {
    for (final creator in item.creatorDetails) {
      if (creator.creatorType != 'author') continue;
      final family = creator.lastName.trim().isNotEmpty
          ? creator.lastName
          : creator.name.split(',').first;
      final key = family.toLowerCase().replaceAll(RegExp('[^a-z]+'), '');
      if (key.isNotEmpty) return key;
    }
    for (final raw in item.creators) {
      final key = raw
          .split(',')
          .first
          .toLowerCase()
          .replaceAll(RegExp('[^a-z]+'), '');
      if (key.isNotEmpty) return key;
    }
    return '';
  }
}

/// Union-find sederhana: dua item yang cocok lewat jalan mana pun berakhir di
/// kelompok yang sama, walau tidak pernah dibandingkan langsung.
class _Union {
  _Union(int size) : _parent = List<int>.generate(size, (i) => i);

  final List<int> _parent;

  int find(int x) {
    var root = x;
    while (_parent[root] != root) {
      root = _parent[root];
    }
    var current = x;
    while (_parent[current] != root) {
      final next = _parent[current];
      _parent[current] = root;
      current = next;
    }
    return root;
  }

  void join(int a, int b) {
    final rootA = find(a);
    final rootB = find(b);
    if (rootA != rootB) _parent[rootB] = rootA;
  }
}
