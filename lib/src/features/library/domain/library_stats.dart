import 'entities/zotero_item.dart';

/// Satu baris hitungan: label beserta berapa banyaknya.
typedef StatTally = ({String label, int count});

/// Ringkasan angka sebuah library.
///
/// Pertanyaan yang dijawabnya bukan "apa isinya" — itu tugas daftar item —
/// melainkan "seperti apa bentuknya": tahun-tahun mana yang menumpuk, jenis
/// apa yang paling banyak, siapa yang paling sering muncul, dan berapa banyak
/// yang PDF-nya belum ada. Yang terakhir itu yang paling sering berguna:
/// sebuah library dengan seribu item yang setengahnya tanpa berkas adalah
/// daftar bacaan, bukan perpustakaan.
class LibraryStats {
  const LibraryStats({
    required this.itemCount,
    required this.withFile,
    required this.withAnnotations,
    required this.annotationTotal,
    required this.untitledCount,
    required this.withoutYear,
    required this.byYear,
    required this.byType,
    required this.topCreators,
    required this.topTags,
    this.earliestYear,
    this.latestYear,
  });

  final int itemCount;

  /// Item yang berkasnya benar-benar ada di disk.
  final int withFile;
  final int withAnnotations;
  final int annotationTotal;

  /// Item tanpa judul yang berarti — biasanya impor yang gagal.
  final int untitledCount;
  final int withoutYear;

  /// Per tahun, dari yang terbaru. Tahun tanpa item tidak ikut.
  final List<StatTally> byYear;

  /// Per jenis item, dari yang terbanyak.
  final List<StatTally> byType;

  /// Pengarang yang paling sering muncul, dari yang terbanyak.
  final List<StatTally> topCreators;

  final List<StatTally> topTags;

  final int? earliestYear;
  final int? latestYear;

  bool get isEmpty => itemCount == 0;

  /// Berapa persen item yang berkasnya ada, dibulatkan.
  int get filePercent =>
      itemCount == 0 ? 0 : (withFile * 100 / itemCount).round();

  /// Jenis item Zotero → nama yang enak dibaca.
  ///
  /// Ditulis di sini, bukan di layar, karena nama jenis juga dipakai saat
  /// hasilnya disalin atau diekspor.
  static const Map<String, String> typeLabels = <String, String>{
    'journalArticle': 'Artikel jurnal',
    'conferencePaper': 'Makalah konferensi',
    'book': 'Buku',
    'bookSection': 'Bab buku',
    'thesis': 'Tesis / disertasi',
    'report': 'Laporan',
    'preprint': 'Pracetak',
    'webpage': 'Halaman web',
    'manuscript': 'Naskah',
    'document': 'Dokumen',
    'presentation': 'Presentasi',
    'dataset': 'Data',
    'standard': 'Standar',
    'patent': 'Paten',
    'magazineArticle': 'Artikel majalah',
    'newspaperArticle': 'Artikel koran',
    'encyclopediaArticle': 'Artikel ensiklopedia',
    'blogPost': 'Tulisan blog',
    'computerProgram': 'Perangkat lunak',
    'attachment': 'Lampiran',
    'note': 'Catatan',
  };

  static String labelForType(String itemType) =>
      typeLabels[itemType] ?? itemType;

  /// Menghitung ringkasan dari daftar item.
  ///
  /// [topCount] membatasi daftar pengarang dan tag; sebuah library dengan
  /// 1.700 item punya ribuan pengarang, dan menampilkan semuanya bukan
  /// ringkasan lagi.
  static LibraryStats of(List<ZoteroItem> items, {int topCount = 15}) {
    if (items.isEmpty) {
      return const LibraryStats(
        itemCount: 0,
        withFile: 0,
        withAnnotations: 0,
        annotationTotal: 0,
        untitledCount: 0,
        withoutYear: 0,
        byYear: <StatTally>[],
        byType: <StatTally>[],
        topCreators: <StatTally>[],
        topTags: <StatTally>[],
      );
    }

    var withFile = 0;
    var withAnnotations = 0;
    var annotationTotal = 0;
    var untitled = 0;
    var withoutYear = 0;
    final years = <int, int>{};
    final types = <String, int>{};
    final creators = <String, int>{};
    final tags = <String, int>{};

    for (final item in items) {
      if (item.hasReadableFile) withFile++;
      if (item.annotationCount > 0) withAnnotations++;
      annotationTotal += item.annotationCount;
      if (item.title.trim().isEmpty || item.title == '(tanpa judul)') {
        untitled++;
      }

      final year = _yearOf(item);
      if (year == null) {
        withoutYear++;
      } else {
        years[year] = (years[year] ?? 0) + 1;
      }

      types[item.itemType] = (types[item.itemType] ?? 0) + 1;

      // Satu nama dihitung sekali per item walau ia muncul dua kali sebagai
      // pengarang dan penyunting; yang ditanya adalah "di berapa karya ia
      // muncul", bukan "berapa baris namanya tertulis".
      for (final name in _creatorNamesOf(item)) {
        creators[name] = (creators[name] ?? 0) + 1;
      }
      for (final tag in item.tags.toSet()) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) tags[trimmed] = (tags[trimmed] ?? 0) + 1;
      }
    }

    final yearKeys = years.keys.toList()..sort((a, b) => b.compareTo(a));

    return LibraryStats(
      itemCount: items.length,
      withFile: withFile,
      withAnnotations: withAnnotations,
      annotationTotal: annotationTotal,
      untitledCount: untitled,
      withoutYear: withoutYear,
      byYear: <StatTally>[
        for (final year in yearKeys) (label: '$year', count: years[year]!),
      ],
      byType: _ranked(types, types.length),
      topCreators: _ranked(creators, topCount),
      topTags: _ranked(tags, topCount),
      earliestYear: yearKeys.isEmpty ? null : yearKeys.last,
      latestYear: yearKeys.isEmpty ? null : yearKeys.first,
    );
  }

  /// Terbanyak lebih dulu; yang sama banyaknya diurutkan menurut abjad, supaya
  /// daftarnya tidak berganti urutan sendiri antar pemanggilan.
  static List<StatTally> _ranked(Map<String, int> counts, int limit) {
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    return <StatTally>[
      for (final entry in entries.take(limit))
        (label: entry.key, count: entry.value),
    ];
  }

  static int? _yearOf(ZoteroItem item) {
    final direct = int.tryParse(item.year);
    if (direct != null && direct > 1000 && direct < 2200) return direct;
    final found = RegExp(r'(1\d{3}|2\d{3})').firstMatch(item.date);
    return found == null ? null : int.parse(found.group(0)!);
  }

  static Set<String> _creatorNamesOf(ZoteroItem item) {
    final out = <String>{};
    for (final creator in item.creatorDetails) {
      final name = creator.lastName.trim().isNotEmpty
          ? creator.lastName.trim()
          : creator.name.trim();
      if (name.isNotEmpty) out.add(name);
    }
    if (out.isEmpty) {
      for (final raw in item.creators) {
        final name = raw.split(',').first.trim();
        if (name.isNotEmpty) out.add(name);
      }
    }
    return out;
  }
}
