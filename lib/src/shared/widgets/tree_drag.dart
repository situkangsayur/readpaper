import 'package:meta/meta.dart';

/// Apa yang sedang diseret ke pohon koleksi.
///
/// Sebelumnya yang diseret hanya jalur berkas, jadi muatannya cukup sebuah
/// `String`. Begitu item paper dan catatan yang sudah ada juga bisa diseret,
/// `String` tidak cukup lagi: baris yang menerima perlu tahu **apa** yang
/// mendarat supaya bisa menolak yang tidak pantas — catatan ke akar paper,
/// atau paper ke akar catatan — dengan penjelasan, bukan dengan diam.
@immutable
sealed class TreeDrag {
  const TreeDrag({required this.label});

  /// Nama yang ditampilkan saat diseret dan di dalam pesan.
  final String label;
}

/// Berkas di perangkat, dari panel berkas.
class FileDrag extends TreeDrag {
  const FileDrag({required this.path, required super.label});

  final String path;
}

/// Item Zotero yang sudah ada di library.
class ItemDrag extends TreeDrag {
  const ItemDrag({required this.itemKey, required super.label});

  final String itemKey;
}

/// Catatan yang sudah ada di folder catatan.
class NoteDrag extends TreeDrag {
  const NoteDrag({required this.noteKey, required super.label});

  final String noteKey;
}
