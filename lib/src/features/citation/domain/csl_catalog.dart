import 'dart:convert';

import 'package:meta/meta.dart';

/// Satu gaya sitasi yang ikut di dalam aplikasi.
@immutable
class CslStyleEntry {
  const CslStyleEntry({
    required this.id,
    required this.file,
    required this.title,
    required this.kind,
    this.format = '',
    this.parent,
  });

  factory CslStyleEntry.fromJson(Map<String, dynamic> json) => CslStyleEntry(
    id: json['id'] as String,
    file: json['file'] as String,
    title: json['title'] as String? ?? json['id'] as String,
    kind: json['kind'] as String? ?? 'independent',
    format: json['format'] as String? ?? '',
    parent: json['parent'] as String?,
  );

  /// Nama pendeknya, mis. `vancouver-nlm`. Inilah yang disimpan di dalam
  /// dokumen Word atau OnlyOffice sebagai "gaya yang dipakai dokumen ini".
  final String id;

  /// Jalur berkasnya relatif terhadap `assets/csl/`.
  final String file;

  /// Judul yang ditulis pembuat gayanya, mis. "Vancouver - NLM
  /// (citation-sequence)". Ditampilkan apa adanya: mengarangkan judul sendiri
  /// berarti dua nama untuk satu gaya yang sama.
  final String title;

  /// `independent` atau `dependent`.
  final String kind;

  /// `numeric`, `author-date`, `author`, `note`, atau kosong.
  final String format;

  /// Untuk gaya dependen: id gaya induknya.
  final String? parent;

  bool get isDependent => kind == 'dependent';
}

/// Daftar gaya dan locale yang ikut di dalam aplikasi.
///
/// Dibaca dari `assets/csl/styles.json`, yang ditulis oleh
/// `scripts/csl-style.py` dan tidak pernah disunting tangan.
///
/// Yang paling perlu dimengerti di sini adalah **gaya dependen**. Gaya CSL
/// tidak selalu berisi aturannya sendiri: sebagian hanya nama beserta
/// penunjuk ke induknya. "Vancouver" adalah contoh yang paling menjebak —
/// yang ada di repositori resmi bukan satu gaya bernama Vancouver, melainkan
/// dua gaya dependen: `vancouver-ama` yang menunjuk AMA, dan `vancouver-nlm`
/// yang menunjuk NLM citation-sequence. Keduanya harus muncul di daftar
/// pilihan dengan namanya sendiri, tetapi yang dipakai merender adalah
/// aturan induknya.
@immutable
class CslCatalog {
  const CslCatalog({required this.styles, required this.locales});

  factory CslCatalog.parse(String json) {
    final root = jsonDecode(json) as Map<String, dynamic>;
    return CslCatalog(
      styles: <CslStyleEntry>[
        for (final entry in (root['styles'] as List? ?? const <dynamic>[]))
          CslStyleEntry.fromJson((entry as Map).cast<String, dynamic>()),
      ],
      locales: <String>[
        for (final entry in (root['locales'] as List? ?? const <dynamic>[]))
          if (entry is String) entry,
      ],
    );
  }

  final List<CslStyleEntry> styles;
  final List<String> locales;

  CslStyleEntry? byId(String id) {
    for (final style in styles) {
      if (style.id == id) return style;
    }
    return null;
  }

  /// Gaya yang benar-benar berisi aturannya, mengikuti rantai induk.
  ///
  /// Mengembalikan null kalau gayanya tidak ada, atau kalau rantainya putus —
  /// gaya dependen yang induknya tidak ikut tidak bisa merender apa pun, dan
  /// itu harus ketahuan sebagai null di sini, bukan sebagai daftar pustaka
  /// kosong di tengah dokumen orang.
  CslStyleEntry? resolve(String id) {
    var current = byId(id);
    // Rantai induk yang berputar hanya mungkin kalau berkasnya salah, tetapi
    // berputar selamanya bukan cara yang pantas untuk mengatakannya.
    for (var step = 0; step < 8 && current != null; step++) {
      if (!current.isDependent) return current;
      final parent = current.parent;
      if (parent == null) return null;
      current = byId(parent);
    }
    return null;
  }

  /// Gaya yang pantas ditawarkan kepada penulis, terurut menurut judulnya.
  ///
  /// Termasuk yang dependen: "Vancouver - NLM" adalah nama yang dicari orang,
  /// sementara "NLM/Vancouver: Citing Medicine" adalah nama yang tidak pernah
  /// diketik siapa pun di kotak pencarian.
  List<CslStyleEntry> get choices {
    final out = <CslStyleEntry>[...styles]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return out;
  }
}
