import 'dart:math' as math;

import 'package:pdfrx/pdfrx.dart';

/// Satu baris teks yang sudah diangkat dari halaman PDF.
class PdfTextLine {
  const PdfTextLine({
    required this.page,
    required this.text,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final int page;
  final String text;

  /// Koordinat PDF: `top` lebih besar dari `bottom`, karena y menghitung dari
  /// bawah halaman.
  final double top;
  final double bottom;
  final double left;
  final double right;

  double get height => (top - bottom).abs();
  double get width => (right - left).abs();
}

/// Mengubah PDF jadi Markdown.
///
/// Yang dikerjakan di sini adalah pekerjaan yang jujur: PDF tidak menyimpan
/// paragraf, tajuk, atau daftar — ia hanya menyimpan potongan teks beserta
/// tempatnya. Jadi strukturnya ditebak dari geometri, dan tebakan itu
/// dikerjakan dengan aturan yang bisa dijelaskan:
///
/// * baris yang hurufnya lebih besar dari kebanyakan → tajuk;
/// * baris yang berulang di banyak halaman, atau hanya berisi angka →
///   kepala/kaki halaman, dibuang;
/// * baris yang berdekatan digabung jadi paragraf, dan tanda hubung di ujung
///   baris disambung tanpa spasi;
/// * baris yang dimulai dengan butir atau angka → daftar.
///
/// Yang tidak dikerjakan: menebak gambar, rumus, atau tabel. Itu bukan
/// kekurangan yang disembunyikan — kolom tabel akan keluar sebagai teks biasa,
/// dan itu lebih baik daripada tabel Markdown yang isinya salah tempat.
class PdfToMarkdown {
  const PdfToMarkdown._();

  /// Membaca berkas PDF dan mengubahnya jadi Markdown.
  ///
  /// [title] dipakai sebagai tajuk pertama kalau dokumennya tidak punya satu
  /// pun baris berhuruf besar.
  static Future<String> fromFile(String path, {String? title, int? maxPages}) async {
    final document = await PdfDocument.openFile(path);
    try {
      final lines = <PdfTextLine>[];
      final pages = maxPages == null
          ? document.pages.length
          : math.min(maxPages, document.pages.length);
      for (var i = 0; i < pages; i++) {
        final text = await document.pages[i].loadStructuredText();
        lines.addAll(linesOf(text, i + 1));
      }
      return fromLines(lines, title: title);
    } finally {
      await document.dispose();
    }
  }

  /// Menyusun potongan teks satu halaman jadi baris-baris.
  ///
  /// Potongan yang titik tengahnya berdekatan dianggap satu baris, lalu
  /// diurutkan dari kiri ke kanan — urutan di dalam berkas tidak dijamin
  /// mengikuti urutan baca.
  static List<PdfTextLine> linesOf(PdfPageText text, int page) {
    final fragments = <PdfPageTextFragment>[
      for (final fragment in text.fragments)
        if (fragment.text.trim().isNotEmpty) fragment,
    ];
    if (fragments.isEmpty) return const <PdfTextLine>[];

    final rows = <List<PdfPageTextFragment>>[];
    final sorted = <PdfPageTextFragment>[...fragments]
      ..sort((a, b) => b.bounds.top.compareTo(a.bounds.top));

    for (final fragment in sorted) {
      final centre = (fragment.bounds.top + fragment.bounds.bottom) / 2;
      final tolerance = math.max(2.0, (fragment.bounds.top - fragment.bounds.bottom).abs() * 0.5);
      final row = rows.firstWhere(
        (candidate) {
          final first = candidate.first.bounds;
          return ((first.top + first.bottom) / 2 - centre).abs() <= tolerance;
        },
        orElse: () {
          final created = <PdfPageTextFragment>[];
          rows.add(created);
          return created;
        },
      );
      row.add(fragment);
    }

    return <PdfTextLine>[
      for (final row in rows)
        if (row.isNotEmpty)
          () {
            final ordered = <PdfPageTextFragment>[...row]
              ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
            final buffer = StringBuffer();
            for (var i = 0; i < ordered.length; i++) {
              if (i > 0) {
                // Jarak melintang yang lebar berarti spasi yang hilang saat
                // potongannya dipisah.
                final gap = ordered[i].bounds.left - ordered[i - 1].bounds.right;
                final size = (ordered[i].bounds.top - ordered[i].bounds.bottom).abs();
                if (gap > size * 0.2 && !buffer.toString().endsWith(' ')) buffer.write(' ');
              }
              buffer.write(ordered[i].text.replaceAll('\n', ' '));
            }
            return PdfTextLine(
              page: page,
              text: buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim(),
              top: ordered.map((f) => f.bounds.top).reduce(math.max),
              bottom: ordered.map((f) => f.bounds.bottom).reduce(math.min),
              left: ordered.first.bounds.left,
              right: ordered.map((f) => f.bounds.right).reduce(math.max),
            );
          }(),
    ]..removeWhere((line) => line.text.isEmpty);
  }

  /// Mengubah baris-baris jadi Markdown. Ini bagian yang bisa diuji tanpa
  /// pdfium sama sekali.
  static String fromLines(List<PdfTextLine> lines, {String? title}) {
    final kept = <PdfTextLine>[
      for (final line in lines)
        if (!_isFurniture(line, lines)) line,
    ];
    if (kept.isEmpty) {
      return title == null ? '' : '# $title\n';
    }

    final body = _bodyHeight(kept);

    final out = StringBuffer();
    var titled = false;
    String? pendingParagraph;
    double? previousBottom;
    int? previousPage;
    var inList = false;

    void closeParagraph() {
      if (pendingParagraph == null) return;
      out.writeln(pendingParagraph);
      out.writeln();
      pendingParagraph = null;
    }

    void closeList() {
      if (!inList) return;
      out.writeln();
      inList = false;
    }

    for (final line in kept) {
      final text = line.text;
      final headingLevel = _headingLevel(line, body);
      final bullet = _bulletOf(text);

      // Jarak menegak antar baris, untuk memutuskan paragraf baru.
      final gap = (previousBottom == null || previousPage != line.page)
          ? null
          : previousBottom - line.top;
      previousBottom = line.bottom;
      previousPage = line.page;

      if (headingLevel != null) {
        closeParagraph();
        closeList();
        final level = titled && headingLevel == 1 ? 2 : headingLevel;
        out.writeln('${'#' * level} $text');
        out.writeln();
        if (level == 1) titled = true;
        continue;
      }

      if (bullet != null) {
        closeParagraph();
        if (!inList) inList = true;
        out.writeln(bullet);
        continue;
      }
      closeList();

      if (pendingParagraph == null) {
        pendingParagraph = text;
        continue;
      }

      // Paragraf baru kalau barisnya berjauhan, atau kalau baris sebelumnya
      // jelas berakhir: kalimat selesai dan barisnya tidak sampai ke tepi.
      final farApart = gap != null && gap > body * 1.6;
      if (farApart) {
        closeParagraph();
        pendingParagraph = text;
        continue;
      }

      final previous = pendingParagraph!;
      if (previous.endsWith('-')) {
        // Kata yang dipotong di ujung baris disambung tanpa spasi.
        pendingParagraph = previous.substring(0, previous.length - 1) + text;
      } else {
        pendingParagraph = '$previous $text';
      }
    }
    closeParagraph();
    closeList();

    var markdown = out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trimLeft();
    if (!titled && title != null && title.trim().isNotEmpty) {
      markdown = '# ${title.trim()}\n\n$markdown';
    }
    return markdown.endsWith('\n') ? markdown : '$markdown\n';
  }

  /// Tinggi huruf badan teks, jadi patokan untuk menilai mana yang tajuk.
  ///
  /// Dihitung dari tinggi yang membawa **paling banyak huruf**, bukan dari
  /// rata-rata dan bukan dari nilai tengah: satu tajuk raksasa menggeser
  /// rata-rata, dan dokumen yang tajuknya banyak menggeser nilai tengah.
  /// Yang tidak pernah bergeser adalah kenyataan bahwa badan teks memuat
  /// hampir seluruh huruf di dokumen.
  static double _bodyHeight(List<PdfTextLine> lines) {
    final weight = <double, int>{};
    for (final line in lines) {
      // Dibulatkan ke setengah titik: tinggi baris yang sama bisa berbeda
      // beberapa perseratus karena huruf yang menjulur ke atas atau ke bawah.
      final bucket = (line.height * 2).round() / 2;
      weight.update(bucket, (v) => v + line.text.length, ifAbsent: () => line.text.length);
    }
    var best = lines.first.height;
    var most = -1;
    for (final entry in weight.entries) {
      // Seri dimenangkan tinggi yang lebih kecil: salah menebak badan teks
      // terlalu besar berarti seluruh dokumen jadi tajuk.
      if (entry.value > most || (entry.value == most && entry.key < best)) {
        best = entry.key;
        most = entry.value;
      }
    }
    return best <= 0 ? 1 : best;
  }

  /// Tajuk kalau hurufnya jelas lebih besar dari badan teks dan barisnya
  /// pendek — tajuk yang panjangnya satu paragraf bukan tajuk.
  static int? _headingLevel(PdfTextLine line, double body) {
    if (line.text.length > 90) return null;
    final ratio = line.height / body;
    if (ratio >= 1.75) return 1;
    if (ratio >= 1.4) return 2;
    if (ratio >= 1.18) return 3;
    return null;
  }

  static String? _bulletOf(String text) {
    final unordered = RegExp(r'^\s*[•◦▪‣·–—*]\s+(.*)$').firstMatch(text);
    if (unordered != null) return '- ${unordered.group(1)!.trim()}';
    final dash = RegExp(r'^\s*-\s+(.*)$').firstMatch(text);
    if (dash != null) return '- ${dash.group(1)!.trim()}';
    final ordered = RegExp(r'^\s*(\d{1,2})[.)]\s+(.*)$').firstMatch(text);
    if (ordered != null) return '${ordered.group(1)}. ${ordered.group(2)!.trim()}';
    return null;
  }

  /// Kepala dan kaki halaman: nomor halaman, atau baris yang sama muncul di
  /// banyak halaman di tempat yang sama.
  static bool _isFurniture(PdfTextLine line, List<PdfTextLine> all) {
    final text = line.text.trim();
    if (text.isEmpty) return true;

    // Nomor halaman berdiri sendiri — "7", "- 7 -", "vii".
    if (RegExp(r'^[-–—\s]*\d{1,4}[-–—\s]*$').hasMatch(text)) return true;
    if (RegExp(r'^[ivxlcdm]{1,7}$', caseSensitive: false).hasMatch(text) && text.length <= 5) {
      return true;
    }

    final pages = all.map((l) => l.page).toSet().length;
    if (pages < 3) return false;

    // Hanya baris paling atas atau paling bawah di halamannya yang boleh
    // dicurigai sebagai kepala/kaki — dan hanya kalau ia **terpisah jauh**
    // dari baris tetangganya. Itulah yang sebenarnya membedakan kepala
    // halaman dari baris pertama sebuah paragraf: bukan isinya, melainkan
    // ruang kosong di antaranya. Tanpa pagar ini, badan teks yang kebetulan
    // berpola — "Isi halaman 3." — ikut terbuang, dan yang hilang adalah
    // isinya sendiri.
    final samePage = <PdfTextLine>[
      for (final l in all)
        if (l.page == line.page) l,
    ]..sort((a, b) => b.top.compareTo(a.top));
    if (samePage.length < 2) return false;
    final at = samePage.indexOf(line);
    final double gap;
    if (at == 0) {
      gap = line.bottom - samePage[1].top;
    } else if (at == samePage.length - 1) {
      gap = samePage[at - 1].bottom - line.top;
    } else {
      return false;
    }
    if (gap < math.max(12, line.height * 1.8)) return false;

    // Baris yang isinya sama — setelah angkanya dibuang, supaya "Bab 2 · 14"
    // dan "Bab 2 · 15" terhitung sama — dan muncul di separuh halaman.
    final normalised = text.replaceAll(RegExp(r'\d+'), '#').toLowerCase();
    if (normalised.length < 3) return false;
    final appearances = all
        .where((l) => l.text.replaceAll(RegExp(r'\d+'), '#').toLowerCase() == normalised)
        .map((l) => l.page)
        .toSet()
        .length;
    return appearances >= math.max(3, (pages / 2).ceil());
  }
}
