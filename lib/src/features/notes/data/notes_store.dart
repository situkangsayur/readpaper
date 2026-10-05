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

  /// Mencatat bahwa isi sebuah catatan berubah dari luar store — misalnya
  /// setelah disunting di penyunting Markdown.
  Future<NoteItem?> touch(String itemKey) async {
    final index = await read();
    final item = index.items.where((i) => i.key == itemKey).firstOrNull;
    if (item == null) return null;
    final touched = item.copyWith(dateModified: DateTime.now());
    await _writeItem(touched);
    return touched;
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

  // --------------------------------------------------- ke repositori lain

  /// Menyalin catatan [itemKey] ke folder catatan [target] — biasanya di
  /// repositori lain — sebagai anggota [collectionKeys] di sana.
  ///
  /// Yang disalin adalah seluruh folder berkasnya, bukan hanya berkas
  /// utamanya: buku catatan menyimpan gambar halamannya di sebelahnya, dan
  /// buku yang tiba tanpa gambar itu adalah lembar-lembar kosong. Kunci yang
  /// sudah dipakai di tujuan diganti kunci baru.
  Future<NoteItem> copyItemTo({
    required String itemKey,
    required NotesStore target,
    List<String> collectionKeys = const <String>[],
  }) async {
    final index = await read();
    final item = index.items.where((i) => i.key == itemKey).firstOrNull;
    if (item == null) throw LibraryFailure('Catatan tidak ada', details: itemKey);
    final targetIndex = await target.read();
    for (final key in collectionKeys) {
      if (!targetIndex.collections.any((c) => c.key == key)) {
        throw LibraryFailure('Koleksi catatan tujuan tidak ada', details: key);
      }
    }

    final source = File(p.normalize(p.join(directory, item.file)));
    final holder = source.parent;
    if (!p.isWithin(p.normalize(_filesRoot), p.normalize(holder.path))) {
      throw LibraryFailure('Berkas catatan ada di luar folder catatan', details: item.file);
    }
    if (!source.existsSync()) {
      throw LibraryFailure('Berkas catatan tidak ada di perangkat ini', details: item.file);
    }
    final key = File(target._itemPath(item.key)).existsSync() ? target._freshKey() : item.key;
    final destHolder = Directory(p.join(target._filesRoot, ZoteroKey.bucket(key), key));
    for (final entity in holder.listSync(recursive: true)) {
      if (entity is! File) continue;
      final dest = File(p.join(destHolder.path, p.relative(entity.path, from: holder.path)));
      await dest.parent.create(recursive: true);
      await entity.copy(dest.path);
    }
    final copied = NoteItem(
      key: key,
      title: item.title,
      file: <String>['berkas', ZoteroKey.bucket(key), key, p.basename(item.file)].join('/'),
      collectionKeys: collectionKeys,
      dateAdded: item.dateAdded,
      dateModified: DateTime.now(),
    );
    await target._writeItem(copied);
    return copied;
  }

  /// Menyalin koleksi catatan [collectionKey] beserta sub-koleksi dan
  /// catatannya ke [target], di bawah [targetParentKey] (null = akar).
  ///
  /// Mengembalikan kunci catatan asal yang disalin, dan mana di antaranya
  /// yang juga anggota koleksi lain di asal — saat memindah, yang itu hanya
  /// dilepas dari koleksinya.
  Future<({List<String> items, Set<String> elsewhere})> copyCollectionTo({
    required String collectionKey,
    required NotesStore target,
    String? targetParentKey,
  }) async {
    final index = await read();
    final root = index.collections.where((c) => c.key == collectionKey).firstOrNull;
    if (root == null) throw LibraryFailure('Koleksi catatan tidak ada', details: collectionKey);
    final targetIndex = await target.read();
    if (targetParentKey != null && !targetIndex.collections.any((c) => c.key == targetParentKey)) {
      throw LibraryFailure('Koleksi catatan tujuan tidak ada', details: targetParentKey);
    }
    if (targetIndex.collections.any(
      (c) => c.parentKey == targetParentKey && c.name.toLowerCase() == root.name.toLowerCase(),
    )) {
      throw LibraryFailure(
        'Di tempat tujuan sudah ada koleksi catatan bernama "${root.name}". Ganti namanya dulu.',
      );
    }

    final subtree = <NoteCollection>[root];
    for (var i = 0; i < subtree.length; i++) {
      subtree.addAll(index.collections.where((c) => c.parentKey == subtree[i].key));
    }
    final taken = <String>{for (final c in targetIndex.collections) c.key};
    final keyMap = <String, String>{};
    for (final c in subtree) {
      var key = c.key;
      while (taken.contains(key)) {
        key = target._freshKey();
      }
      taken.add(key);
      keyMap[c.key] = key;
    }

    // Isi diperiksa dulu, sebelum apa pun ditulis di tujuan.
    final moving = keyMap.keys.toSet();
    final members = index.items.where((i) => i.collectionKeys.any(moving.contains)).toList();
    for (final item in members) {
      if (!File(p.join(directory, item.file)).existsSync()) {
        throw LibraryFailure('Berkas catatan "${item.title}" tidak ada di perangkat ini');
      }
    }

    await target._writeCollections(<NoteCollection>[
      ...targetIndex.collections,
      for (final c in subtree)
        NoteCollection(
          key: keyMap[c.key]!,
          name: c.name,
          parentKey: c.key == collectionKey ? targetParentKey : keyMap[c.parentKey],
        ),
    ]);
    final elsewhere = <String>{};
    for (final item in members) {
      final inside = item.collectionKeys.where(moving.contains).toList();
      if (inside.length != item.collectionKeys.length) elsewhere.add(item.key);
      await copyItemTo(
        itemKey: item.key,
        target: target,
        collectionKeys: <String>[for (final k in inside) keyMap[k]!],
      );
    }
    return (items: <String>[for (final i in members) i.key], elsewhere: elsewhere);
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
    await file.writeAsString(_encode(<dynamic>[for (final c in sorted) c.toJson()]), flush: true);
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
