import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Sebuah koleksi catatan.
///
/// Sengaja terpisah dari koleksi Zotero. Item Zotero membawa properti
/// bibliografi — penulis, tahun, DOI, kunci sitasi — yang tidak berarti apa
/// pun untuk catatan rapat atau papan tulis, dan formatnya dijaga
/// byte-for-byte oleh plugin `zotero-github-sync`. Menumpangkan catatan di
/// sana berarti menulis item yang tidak sah bagi Zotero.
@immutable
class NoteCollection {
  const NoteCollection({required this.key, required this.name, this.parentKey});

  factory NoteCollection.fromJson(Map<String, dynamic> json) => NoteCollection(
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    parentKey: json['parentKey'] as String?,
  );

  final String key;
  final String name;
  final String? parentKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'name': name,
    'parentKey': parentKey,
  };
}

/// Sebuah catatan: satu berkas beserta keterangannya.
@immutable
class NoteItem {
  const NoteItem({
    required this.key,
    required this.title,
    required this.file,
    this.collectionKeys = const <String>[],
    required this.dateAdded,
    required this.dateModified,
  });

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
    key: json['key'] as String? ?? '',
    title: json['title'] as String? ?? '',
    file: json['file'] as String? ?? '',
    collectionKeys: <String>[
      for (final entry in (json['collections'] as List?) ?? const <dynamic>[])
        if (entry is String) entry,
    ],
    dateAdded: DateTime.tryParse(json['dateAdded'] as String? ?? '') ?? DateTime(1970),
    dateModified: DateTime.tryParse(json['dateModified'] as String? ?? '') ?? DateTime(1970),
  );

  final String key;
  final String title;

  /// Jalur berkasnya relatif terhadap folder catatan, selalu dengan garis
  /// miring maju — berkas ini dibaca juga di Windows.
  final String file;

  final List<String> collectionKeys;
  final DateTime dateAdded;
  final DateTime dateModified;

  String get extension => p.extension(file).toLowerCase();

  bool get isPdf => extension == '.pdf';
  bool get isMarkdown => extension == '.md';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'collections': collectionKeys,
    'dateAdded': _stamp(dateAdded),
    'dateModified': _stamp(dateModified),
    'file': file,
    'key': key,
    'title': title,
  };

  NoteItem copyWith({
    String? title,
    List<String>? collectionKeys,
    DateTime? dateModified,
  }) => NoteItem(
    key: key,
    title: title ?? this.title,
    file: file,
    collectionKeys: collectionKeys ?? this.collectionKeys,
    dateAdded: dateAdded,
    dateModified: dateModified ?? DateTime.now(),
  );

  static String _stamp(DateTime when) => '${when.toUtc().toIso8601String().split('.').first}Z';
}

/// Seluruh isi folder catatan, sudah dibaca.
@immutable
class NotesIndex {
  const NotesIndex({required this.collections, required this.items, required this.directory});

  static const NotesIndex empty = NotesIndex(
    collections: <NoteCollection>[],
    items: <NoteItem>[],
    directory: '',
  );

  final List<NoteCollection> collections;
  final List<NoteItem> items;

  /// Folder catatan di dalam repositori.
  final String directory;

  bool get isEmpty => collections.isEmpty && items.isEmpty;

  /// Anak langsung sebuah koleksi; null untuk yang di akar.
  List<NoteCollection> childrenOf(String? parentKey) => <NoteCollection>[
    for (final collection in collections)
      if (collection.parentKey == parentKey) collection,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<NoteItem> inCollection(String key) => <NoteItem>[
    for (final item in items)
      if (item.collectionKeys.contains(key)) item,
  ]..sort((a, b) => b.dateModified.compareTo(a.dateModified));

  List<NoteItem> get unfiled => <NoteItem>[
    for (final item in items)
      if (item.collectionKeys.isEmpty) item,
  ]..sort((a, b) => b.dateModified.compareTo(a.dateModified));

  /// Berapa catatan di dalam koleksi ini beserta seluruh keturunannya.
  int countIn(String key) {
    final keys = <String>{key, ..._descendants(key)};
    return items.where((item) => item.collectionKeys.any(keys.contains)).length;
  }

  Set<String> _descendants(String key) {
    final out = <String>{};
    void walk(String parent) {
      for (final child in childrenOf(parent)) {
        if (out.add(child.key)) walk(child.key);
      }
    }

    walk(key);
    return out;
  }
}
