import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/zotero_key.dart';
import 'zotero_json.dart';
import 'zotero_writer.dart';

/// Hasil menyalin item atau koleksi ke library lain.
class TransferResult {
  const TransferResult({
    required this.itemFiles,
    required this.touched,
    this.collectionKeys = const <String, String>{},
    this.alsoElsewhere = const <String>{},
  });

  /// Berkas item **di library asal** yang disalin.
  final List<String> itemFiles;

  /// Semua berkas yang ditulis di library tujuan.
  final List<String> touched;

  /// Kunci koleksi asal → kunci di tujuan (sama, kecuali bentrok).
  final Map<String, String> collectionKeys;

  /// Item asal yang juga anggota koleksi lain, di luar yang disalin. Saat
  /// memindah, item ini hanya dilepas dari koleksinya, bukan dihapus.
  final Set<String> alsoElsewhere;
}

/// Lampiran yang tidak bisa ikut disalin karena isinya belum ada di sini.
class MissingAttachments implements Exception {
  const MissingAttachments(this.files);

  /// Jalur lampiran, relatif terhadap library asal.
  final List<String> files;

  @override
  String toString() =>
      '${files.length} lampiran belum ada di perangkat ini (belum diunduh, atau '
      'masih penunjuk Git LFS): ${files.map(p.basename).join(', ')}';
}

/// Menyalin item dan koleksi Zotero dari satu library ke library lain.
///
/// Library di sini adalah folder ekspor plugin di dalam sebuah repositori —
/// biasanya dua repositori yang berbeda. Yang disalin adalah semua yang
/// membentuk satu item: berkas item beserta anotasinya, folder lampirannya
/// (`attachments/` maupun `attachments-lfs/`), dan catatan Markdown buatan
/// plugin. Identitas library di dalam item — `libraryID`, `libraryName`,
/// `zoteroURI` — diganti mengikuti `library.json` tujuan, karena item itu kini
/// milik library tersebut.
///
/// Memindah adalah menyalin lalu menghapus dari asal, dan itu dikerjakan
/// pemanggilnya: kelas ini tidak pernah menyentuh library asal.
class LibraryTransfer {
  const LibraryTransfer();

  static const List<String> _attachmentDirs = <String>['attachments', 'attachments-lfs'];

  /// Menyalin satu item ke [targetDir], sebagai anggota [collectionKeys].
  Future<TransferResult> copyItem({
    required String sourceDir,
    required String targetDir,
    required String itemFilePath,
    required List<String> collectionKeys,
    required List<String> collectionPaths,
  }) async {
    final json = ZoteroJson.decodeObject(await File(itemFilePath).readAsString());
    final zotero = (json['zotero'] as Map?)?.cast<String, dynamic>();
    final key = zotero?['key'] as String?;
    if (zotero == null || key == null || key.isEmpty) {
      throw LibraryFailure('Berkas item tidak punya kunci Zotero', details: itemFilePath);
    }
    final target = File(p.join(targetDir, 'items', ZoteroKey.bucket(key), '$key.json'));
    if (target.existsSync()) {
      throw LibraryFailure(
        'Item ini sudah ada di repositori tujuan (kunci $key). Tidak disalin dua kali.',
      );
    }

    // Lampiran diperiksa dulu, sebelum apa pun ditulis: item yang tiba tanpa
    // PDF-nya — lalu dihapus dari asal saat memindah — adalah PDF yang hilang.
    final copies = <(Directory, Directory)>[];
    final missing = <String>[];
    for (final attachment in _attachmentKeys(json)) {
      var found = false;
      for (final root in _attachmentDirs) {
        final from = Directory(p.join(sourceDir, root, ZoteroKey.bucket(attachment), attachment));
        if (!p.isWithin(p.join(sourceDir, root), p.normalize(from.path))) continue;
        if (!from.existsSync()) continue;
        found = true;
        for (final file in from.listSync(recursive: true).whereType<File>()) {
          if (_isLfsPointer(file)) missing.add(p.relative(file.path, from: sourceDir));
        }
        copies.add((
          from,
          Directory(p.join(targetDir, root, ZoteroKey.bucket(attachment), attachment)),
        ));
      }
      if (!found && _expectsFile(json, attachment)) {
        missing.add('attachments/${ZoteroKey.bucket(attachment)}/$attachment');
      }
    }
    if (missing.isNotEmpty) throw MissingAttachments(missing);

    final touched = <String>[];
    for (final (from, to) in copies) {
      touched.addAll(await _copyDir(from, to));
    }

    final note = await const ZoteroWriter().findNoteFile(sourceDir, key);
    if (note != null) {
      final to = File(p.join(targetDir, p.relative(note, from: sourceDir)));
      await to.parent.create(recursive: true);
      await File(note).copy(to.path);
      touched.add(to.path);
    }

    zotero['collections'] = <dynamic>[...collectionKeys];
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>();
    if (meta != null) {
      meta['collections'] = <dynamic>[...collectionPaths];
      final library = await _libraryInfo(targetDir);
      meta['libraryID'] = library.id;
      meta['libraryName'] = library.name;
      meta['zoteroURI'] = library.type == 'group'
          ? 'zotero://select/groups/${library.id}/items/$key'
          : 'zotero://select/library/items/$key';
    }
    await target.parent.create(recursive: true);
    await target.writeAsString(ZoteroJson.encodeFile(json), flush: true);
    touched.add(target.path);
    return TransferResult(itemFiles: <String>[itemFilePath], touched: touched);
  }

  /// Menyalin koleksi [collectionKey] beserta sub-koleksi dan itemnya ke
  /// [targetDir], di bawah [targetParentKey] (null = akar).
  Future<TransferResult> copyCollection({
    required String sourceDir,
    required String targetDir,
    required String collectionKey,
    required String? targetParentKey,
  }) async {
    final source = await _collections(sourceDir);
    final target = await _collections(targetDir);
    final root = source.where((c) => c['key'] == collectionKey).firstOrNull;
    if (root == null) throw LibraryFailure('Koleksi tidak ada lagi', details: collectionKey);
    if (targetParentKey != null && !target.any((c) => c['key'] == targetParentKey)) {
      throw LibraryFailure('Koleksi tujuan tidak ada', details: targetParentKey);
    }
    final twin = target.any(
      (c) =>
          (c['parentKey'] as String?) == targetParentKey &&
          ((c['name'] as String?) ?? '').toLowerCase() ==
              ((root['name'] as String?) ?? '').toLowerCase(),
    );
    if (twin) {
      throw LibraryFailure(
        'Di tempat tujuan sudah ada koleksi bernama "${root['name']}". Ganti namanya dulu.',
      );
    }

    // Pohon yang disalin, induk lebih dulu.
    final subtree = <Map<String, dynamic>>[root];
    for (var i = 0; i < subtree.length; i++) {
      subtree.addAll(source.where((c) => c['parentKey'] == subtree[i]['key']));
    }
    // Kunci koleksi dipakai ulang; hanya yang sudah terpakai di tujuan yang
    // diberi kunci baru, dan keanggotaan itemnya ikut dipetakan.
    final taken = <String>{for (final c in target) c['key'] as String};
    final keyMap = <String, String>{};
    for (final c in subtree) {
      var key = c['key'] as String;
      while (taken.contains(key)) {
        key = ZoteroKey.generate();
      }
      taken.add(key);
      keyMap[c['key'] as String] = key;
    }
    final parentPath = targetParentKey == null
        ? null
        : target.firstWhere((c) => c['key'] == targetParentKey)['path'] as String?;
    final paths = <String, String>{};
    final added = <Map<String, dynamic>>[];
    for (final c in subtree) {
      final oldKey = c['key'] as String;
      final isRoot = oldKey == collectionKey;
      final parent = isRoot ? targetParentKey : keyMap[c['parentKey']];
      final base = isRoot ? parentPath : paths[c['parentKey']];
      final name = (c['name'] as String?) ?? '';
      paths[oldKey] = base == null || base.isEmpty ? name : '$base/$name';
      added.add(<String, dynamic>{
        ...c,
        'key': keyMap[oldKey],
        'parentKey': parent,
        'path': paths[oldKey],
      });
    }
    // Semua item yang akan ikut diperiksa lebih dulu — lampiran yang belum
    // ada dan kunci yang sudah dipakai di tujuan — sebelum satu berkas pun
    // ditulis. Gagal di tengah jalan meninggalkan tujuan setengah jadi.
    final moving = keyMap.keys.toSet();
    final plan = <(String, List<String>)>[];
    final missing = <String>[];
    final elsewhere = <String>{};
    final items = Directory(p.join(sourceDir, 'items'));
    final candidates = items.existsSync()
        ? items.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json'))
        : const <File>[];
    for (final file in candidates) {
      final text = await file.readAsString();
      if (!text.contains('"collections"')) continue;
      final json = ZoteroJson.decodeObject(text);
      final memberships =
          ((json['zotero'] as Map?)?['collections'] as List?)?.whereType<String>().toList() ??
          const <String>[];
      final inside = memberships.where(moving.contains).toList();
      if (inside.isEmpty) continue;
      if (inside.length != memberships.length) elsewhere.add(file.path);
      final itemKey = (json['zotero'] as Map)['key'] as String? ?? '';
      if (File(
        p.join(targetDir, 'items', ZoteroKey.bucket(itemKey), '$itemKey.json'),
      ).existsSync()) {
        throw LibraryFailure(
          'Item ${(json['meta'] as Map?)?['title'] ?? itemKey} sudah ada di repositori tujuan.',
        );
      }
      missing.addAll(await missingAttachments(sourceDir, file.path));
      plan.add((file.path, inside));
    }
    if (missing.isNotEmpty) {
      throw MissingAttachments(<String>[for (final m in missing) p.relative(m, from: sourceDir)]);
    }

    final collectionsFile = File(p.join(targetDir, 'collections.json'));
    await collectionsFile.writeAsString(
      '${const JsonEncoder.withIndent('\t').convert(ZoteroJson.sortKeys(<Object?>[...target, ...added]))}\n',
      flush: true,
    );
    final itemFiles = <String>[];
    final touched = <String>[collectionsFile.path];
    for (final (path, inside) in plan) {
      final copied = await copyItem(
        sourceDir: sourceDir,
        targetDir: targetDir,
        itemFilePath: path,
        collectionKeys: <String>[for (final k in inside) keyMap[k]!],
        collectionPaths: <String>[for (final k in inside) paths[k]!],
      );
      itemFiles.add(path);
      touched.addAll(copied.touched);
    }
    return TransferResult(
      itemFiles: itemFiles,
      touched: touched,
      collectionKeys: keyMap,
      alsoElsewhere: elsewhere,
    );
  }

  /// Berkas item yang akan ikut bila koleksi [collectionKey] disalin — untuk
  /// memeriksa lampirannya lebih dulu, sebelum apa pun ditulis.
  Future<List<String>> itemsInCollection(String sourceDir, String collectionKey) async {
    final source = await _collections(sourceDir);
    final subtree = <String>{collectionKey};
    var grew = true;
    while (grew) {
      grew = false;
      for (final c in source) {
        if (subtree.contains(c['parentKey']) && subtree.add(c['key'] as String)) grew = true;
      }
    }
    final out = <String>[];
    final items = Directory(p.join(sourceDir, 'items'));
    if (!items.existsSync()) return out;
    for (final file in items.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final text = await file.readAsString();
      if (!text.contains('"collections"')) continue;
      final keys = ((ZoteroJson.decodeObject(text)['zotero'] as Map?)?['collections'] as List?)
          ?.whereType<String>();
      if (keys != null && keys.any(subtree.contains)) out.add(file.path);
    }
    return out;
  }

  /// Lampiran yang belum ada isinya di sini, untuk item [itemFilePath].
  Future<List<String>> missingAttachments(String sourceDir, String itemFilePath) async {
    final json = ZoteroJson.decodeObject(await File(itemFilePath).readAsString());
    final out = <String>[];
    for (final attachment in _attachmentKeys(json)) {
      var found = false;
      for (final root in _attachmentDirs) {
        final dir = Directory(p.join(sourceDir, root, ZoteroKey.bucket(attachment), attachment));
        if (!dir.existsSync()) continue;
        found = true;
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (_isLfsPointer(file)) out.add(file.path);
        }
      }
      if (!found && _expectsFile(json, attachment)) {
        out.add(p.join(sourceDir, 'attachments', ZoteroKey.bucket(attachment), attachment));
      }
    }
    return out;
  }

  static Iterable<String> _attachmentKeys(Map<String, dynamic> json) sync* {
    for (final child in (json['children'] as List?) ?? const <dynamic>[]) {
      if (child is Map && child['itemType'] == 'attachment' && child['key'] is String) {
        yield child['key'] as String;
      }
    }
  }

  /// Lampiran tautan (URL, berkas di luar Zotero) tidak punya isi untuk
  /// disalin; yang diharapkan ada hanya yang disimpan di repositori.
  static bool _expectsFile(Map<String, dynamic> json, String attachmentKey) {
    for (final entry in ((json['meta'] as Map?)?['attachments'] as List?) ?? const <dynamic>[]) {
      if (entry is Map && entry['key'] == attachmentKey) {
        final files = entry['files'];
        return files is List && files.isNotEmpty;
      }
    }
    return false;
  }

  static bool _isLfsPointer(File file) {
    if (file.lengthSync() > 512) return false;
    try {
      return file.readAsStringSync().startsWith('version https://git-lfs');
    } on FormatException {
      return false;
    }
  }

  static Future<List<String>> _copyDir(Directory from, Directory to) async {
    final out = <String>[];
    for (final entity in from.listSync(recursive: true)) {
      if (entity is! File) continue;
      final dest = File(p.join(to.path, p.relative(entity.path, from: from.path)));
      await dest.parent.create(recursive: true);
      await entity.copy(dest.path);
      out.add(dest.path);
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> _collections(String libraryDir) async {
    final file = File(p.join(libraryDir, 'collections.json'));
    if (!file.existsSync()) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw LibraryFailure('collections.json tidak berisi daftar koleksi', details: file.path);
    }
    return <Map<String, dynamic>>[for (final e in decoded) (e as Map).cast<String, dynamic>()];
  }

  static Future<({int id, String name, String type})> _libraryInfo(String libraryDir) async {
    final file = File(p.join(libraryDir, 'library.json'));
    if (!file.existsSync()) return (id: 1, name: 'My Library', type: 'user');
    final json = ZoteroJson.decodeObject(await file.readAsString());
    return (
      id: (json['id'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? 'My Library',
      type: json['type'] as String? ?? 'user',
    );
  }
}
