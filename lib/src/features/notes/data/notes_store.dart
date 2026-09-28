import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/failure.dart';
import '../../../core/utils/zotero_key.dart';
import '../domain/note_entities.dart';

/// Baca dan tulis folder catatan di dalam repositori.
///
/// Folder ini **di luar** struktur Zotero, dan itu keputusan yang sengaja:
/// berkas di dalam `zotero/` ditulis byte-for-byte oleh plugin
/// `zotero-github-sync`, dan item Zotero membawa properti rujukan yang tidak
/// berlaku untuk catatan. Menumpangkan catatan di sana berarti menulis item
/// yang tidak sah bagi Zotero — jadi catatan mendapat folder sendiri:
///
/// ```
/// <repo>/catatan/
///   koleksi.json                  daftar koleksi catatan
///   item/<XX>/<KEY>.json          satu berkas per catatan
///   berkas/<XX>/<KEY>/<nama>      isinya
/// ```
///
/// Bentuknya meniru ekspor Zotero — ember dua huruf, kunci delapan karakter,
/// JSON beridentasi tab dengan kunci terurut — supaya diff git tetap kecil dan
/// siapa pun yang sudah membaca repositori ini langsung mengenalinya.
class NotesStore {
  const NotesStore(this.directory);

  /// Nama foldernya di akar repositori.
  static const String dirName = 'catatan';

  static String directoryFor(String repoRoot) => p.join(repoRoot, dirName);

  /// Jalur absolut folder catatan.
  final String directory;

  File get _collectionsFile => File(p.join(directory, 'koleksi.json'));

  String get _itemsRoot => p.join(directory, 'item');

  String get _filesRoot => p.join(directory, 'berkas');

  // ------------------------------------------------------------------- membaca

  /// Membaca seluruh isi folder catatan. Folder yang belum ada berarti kosong,
  /// bukan galat: sebuah repositori paper yang belum pernah dipakai untuk
  /// catatan tetap sah.
  Future<NotesIndex> read() async {
    final collections = <NoteCollection>[];
    final file = _collectionsFile;
    if (file.existsSync()) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is! Map) continue;
          final collection = NoteCollection.fromJson(entry.cast<String, dynamic>());
          if (collection.key.isNotEmpty) collections.add(collection);
        }
      }
    }

    final items = <NoteItem>[];
    final itemsDir = Directory(_itemsRoot);
    if (itemsDir.existsSync()) {
      for (final entity in itemsDir.listSync(recursive: true)) {
        if (entity is! File || p.extension(entity.path) != '.json') continue;
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is! Map) continue;
          final item = NoteItem.fromJson(json.cast<String, dynamic>());
          if (item.key.isNotEmpty) items.add(item);
        } on FormatException {
          // Satu berkas rusak tidak boleh menyembunyikan catatan lainnya.
          continue;
        }
      }
    }

    // Koleksi yang menunjuk ke induk yang sudah tidak ada akan hilang dari
    // pohon tanpa jejak, jadi rujukannya dikembalikan ke akar.
    final known = <String>{for (final c in collections) c.key};
    final repaired = <NoteCollection>[
      for (final c in collections)
        if (c.parentKey == null || known.contains(c.parentKey))
          c
        else
          NoteCollection(key: c.key, name: c.name),
    ];

    return NotesIndex(collections: repaired, items: items, directory: directory);
  }

  /// Jalur absolut berkas sebuah catatan.
  String absolutePathOf(NoteItem item) => p.join(directory, item.file);

  // ------------------------------------------------------------------ koleksi

  Future<NoteCollection> createCollection({required String name, String? parentKey}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const LibraryFailure('Nama koleksi catatan tidak boleh kosong');
    }
    final index = await read();
    if (parentKey != null && !index.collections.any((c) => c.key == parentKey)) {
      throw LibraryFailure('Koleksi induk tidak ada', details: parentKey);
    }
    final created = NoteCollection(key: _freshKey(), name: trimmed, parentKey: parentKey);
    await _writeCollections(<NoteCollection>[...index.collections, created]);
    return created;
  }

  Future<void> renameCollection({required String key, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const LibraryFailure('Nama koleksi catatan tidak boleh kosong');
    }
    final index = await read();
    if (!index.collections.any((c) => c.key == key)) {
      throw LibraryFailure('Koleksi catatan tidak ada', details: key);
    }
    await _writeCollections(<NoteCollection>[
      for (final c in index.collections)
        if (c.key == key) NoteCollection(key: c.key, name: trimmed, parentKey: c.parentKey) else c,
    ]);
  }

  /// Membuang sebuah koleksi catatan beserta keturunannya.
  ///
  /// Catatannya sendiri **tidak** dihapus: yang dibuang hanya penataannya, dan
  /// isinya pindah ke "tanpa koleksi". Menghapus folder yang berarti menghapus
  /// tulisan orang adalah kejutan yang tidak pantas datang dari satu ketukan.
  Future<void> deleteCollection(String key) async {
    final index = await read();
    if (!index.collections.any((c) => c.key == key)) return;

    final gone = <String>{key};
    var grew = true;
    while (grew) {
      grew = false;
      for (final c in index.collections) {
        if (c.parentKey != null && gone.contains(c.parentKey) && gone.add(c.key)) grew = true;
      }
    }

    await _writeCollections(<NoteCollection>[
      for (final c in index.collections)
        if (!gone.contains(c.key)) c,
    ]);

    for (final item in index.items) {
      if (!item.collectionKeys.any(gone.contains)) continue;
      await _writeItem(
        item.copyWith(
          collectionKeys: <String>[
            for (final k in item.collectionKeys)
              if (!gone.contains(k)) k,
          ],
        ),
      );
    }
  }

  // -------------------------------------------------------------------- item

  /// Menyalin sebuah berkas ke folder catatan dan mencatatnya.
  ///
  /// Disalin, tidak dirujuk: berkas di `/cache` atau di folder unduhan bisa
  /// hilang kapan saja, dan catatan yang isinya hilang lebih buruk daripada
  /// catatan yang tidak pernah dibuat.
  Future<NoteItem> addFile({
    required String sourcePath,
    required String title,
    String? collectionKey,
    DateTime? now,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw LibraryFailure('Berkas catatan tidak ditemukan', details: sourcePath);
    }
    if (collectionKey != null) {
      final index = await read();
      if (!index.collections.any((c) => c.key == collectionKey)) {
        throw LibraryFailure('Koleksi catatan tidak ada', details: collectionKey);
      }
    }

    final key = _freshKey();
    final filename = _safeName(p.basename(sourcePath));
    final relative = <String>['berkas', ZoteroKey.bucket(key), key, filename].join('/');
    final target = File(p.join(directory, relative));
    await target.parent.create(recursive: true);
    await source.copy(target.path);

    final moment = now ?? DateTime.now();
    final item = NoteItem(
      key: key,
      title: title.trim().isEmpty ? p.basenameWithoutExtension(filename) : title.trim(),
      file: relative,
      collectionKeys: collectionKey == null ? const <String>[] : <String>[collectionKey],
      dateAdded: moment,
      dateModified: moment,
    );
    await _writeItem(item);
    return item;
  }

  /// Memindahkan sebuah catatan ke koleksi lain; null berarti keluar dari
  /// semua koleksi.
  Future<NoteItem> fileInto({required String itemKey, String? collectionKey}) async {
    final index = await read();
    final item = index.items.where((i) => i.key == itemKey).firstOrNull;
    if (item == null) throw LibraryFailure('Catatan tidak ada', details: itemKey);
    if (collectionKey != null && !index.collections.any((c) => c.key == collectionKey)) {
      throw LibraryFailure('Koleksi catatan tidak ada', details: collectionKey);
    }
    final moved = item.copyWith(
      collectionKeys: collectionKey == null ? const <String>[] : <String>[collectionKey],
    );
    await _writeItem(moved);
    return moved;
  }

  Future<NoteItem> rename({required String itemKey, required String title}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw const LibraryFailure('Judul catatan tidak boleh kosong');
    final index = await read();
    final item = index.items.where((i) => i.key == itemKey).firstOrNull;
    if (item == null) throw LibraryFailure('Catatan tidak ada', details: itemKey);
    final renamed = item.copyWith(title: trimmed);
    await _writeItem(renamed);
    return renamed;
  }

  /// Membuang sebuah catatan beserta berkasnya.
  Future<void> deleteItem(String itemKey) async {
    final index = await read();
    final item = index.items.where((i) => i.key == itemKey).firstOrNull;
    if (item == null) return;

    // Pagar yang sama galaknya dengan yang di sisi Zotero: yang dihapus di
    // sini berkas di dalam repositori orang, jadi jalurnya diperiksa dulu.
    final file = File(p.normalize(p.join(directory, item.file)));
    if (p.isWithin(p.normalize(_filesRoot), file.path)) {
      if (file.existsSync()) await file.delete();
      final holder = file.parent;
      if (p.isWithin(p.normalize(_filesRoot), p.normalize(holder.path)) &&
          holder.existsSync() &&
          holder.listSync().isEmpty) {
        await holder.delete();
      }
    }

    final json = File(_itemPath(item.key));
    if (json.existsSync()) await json.delete();
    final bucket = json.parent;
    if (p.isWithin(p.normalize(_itemsRoot), p.normalize(bucket.path)) &&
        bucket.existsSync() &&
        bucket.listSync().isEmpty) {
      await bucket.delete();
    }
  }

  // ---------------------------------------------------------------- internals

  String _itemPath(String key) => p.join(_itemsRoot, ZoteroKey.bucket(key), '$key.json');

  Future<void> _writeItem(NoteItem item) async {
    final file = File(_itemPath(item.key));
    await file.parent.create(recursive: true);
    await file.writeAsString(_encode(item.toJson()), flush: true);
  }

  Future<void> _writeCollections(List<NoteCollection> collections) async {
    final sorted = <NoteCollection>[...collections]..sort((a, b) => a.key.compareTo(b.key));
    final file = _collectionsFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      _encode(<dynamic>[for (final c in sorted) c.toJson()]),
      flush: true,
    );
  }

  /// Kunci yang belum dipakai berkas item mana pun.
  String _freshKey() {
    for (var attempt = 0; attempt < 32; attempt++) {
      final key = ZoteroKey.generate();
      if (!File(_itemPath(key)).existsSync()) return key;
    }
    throw const LibraryFailure('Gagal membuat kunci catatan baru');
  }

  /// Nama berkas yang aman: tanpa garis miring, tanpa `..`.
  static String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/]'), '-').replaceAll('..', '.').trim();
    return cleaned.isEmpty ? 'catatan' : cleaned;
  }

  static final JsonEncoder _pretty = JsonEncoder.withIndent('\t');

  /// Identasi tab dan kunci terurut, sama seperti yang ditulis plugin Zotero
  /// di sebelah — dua format yang berbeda di satu repositori hanya membuat
  /// diff sulit dibaca.
  static String _encode(Object? value) => '${_pretty.convert(_sortKeys(value))}\n';

  static Object? _sortKeys(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted[entry.key.toString()] = _sortKeys(entry.value);
      }
      return sorted;
    }
    if (value is List) return value.map(_sortKeys).toList();
    return value;
  }
}
