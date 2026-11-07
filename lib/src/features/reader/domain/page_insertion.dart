import '../../library/domain/entities/zotero_annotation.dart';

/// Apa yang harus ikut bergeser ketika halaman disisipkan ke tengah dokumen.
///
/// Anotasi menyimpan nomor halamannya sendiri. Begitu halaman kosong
/// disisipkan setelah halaman 3, slide yang tadinya halaman 4 menjadi
/// halaman 5 — tetapi coretannya masih menyebut halaman 4, jadi tergambar di
/// halaman kosong yang baru, dan coretan slide 5 tergambar di slide 4. Saat
/// disimpan, semuanya ikut terlebur di slide yang salah.
class PageInsertion {
  const PageInsertion._();

  /// Anotasi di [annotations] yang terdampak penyisipan [count] halaman di
  /// indeks [at] (0 = di depan), dalam keadaan sesudah digeser. Yang tidak
  /// terdampak tidak dikembalikan, supaya pemanggil cukup menyimpan yang
  /// berubah.
  static List<ZoteroAnnotation> shifted(
    Iterable<ZoteroAnnotation> annotations, {
    required int at,
    required int count,
  }) => <ZoteroAnnotation>[
    for (final a in annotations)
      if (a.pageIndex >= at) shift(a, by: count),
  ];

  /// Seluruh [annotations] dengan yang terdampak sudah digeser.
  static List<ZoteroAnnotation> apply(
    Iterable<ZoteroAnnotation> annotations, {
    required int at,
    required int count,
  }) => <ZoteroAnnotation>[
    for (final a in annotations) a.pageIndex >= at ? shift(a, by: count) : a,
  ];

  /// [annotation] dipindah [by] halaman ke belakang, letaknya di halaman
  /// tetap sama.
  static ZoteroAnnotation shift(ZoteroAnnotation annotation, {required int by}) {
    final page = annotation.pageIndex + by;
    // Label yang dibuat ReadPaper adalah nomor halamannya. Label lain (mis.
    // "iv" dari PDF) tidak bisa ditebak, jadi dibiarkan.
    final label = annotation.pageLabel == '${annotation.pageIndex + 1}'
        ? '${page + 1}'
        : annotation.pageLabel;
    return annotation.copyWith(
      pageIndex: page,
      pageLabel: label,
      // dateModified ikut baru (bawaan copyWith): perubahannya harus menang
      // saat disinkronkan dengan Zotero.
      sortIndex: _sortIndex(annotation.sortIndex, page),
    );
  }

  /// Indeks urut Zotero diawali nomor halamannya (`00003|…`); bila tidak ikut
  /// diganti, panel anotasi mengurutkannya di halaman lamanya.
  static String _sortIndex(String sortIndex, int pageIndex) {
    final bar = sortIndex.indexOf('|');
    if (bar != 5 || int.tryParse(sortIndex.substring(0, 5)) == null) return sortIndex;
    return '${pageIndex.clamp(0, 99999).toString().padLeft(5, '0')}${sortIndex.substring(5)}';
  }

  /// Catatan presenter per nomor halaman (mulai 1), digeser seperti anotasi:
  /// halaman sesudah halaman nomor [at] mundur [count].
  static Map<int, String> notes(Map<int, String> notes, {required int at, required int count}) =>
      <int, String>{for (final e in notes.entries) e.key > at ? e.key + count : e.key: e.value};
}
