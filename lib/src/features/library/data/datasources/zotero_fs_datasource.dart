import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../../core/errors/failure.dart';
import '../../domain/entities/library_index.dart';
import '../../domain/entities/zotero_annotation.dart';
import '../../domain/entities/zotero_collection.dart';
import '../../domain/entities/zotero_item.dart';
import 'zotero_json.dart';

/// Reads a Zotero export from disk.
///
/// A library holds ~2k JSON files, so the whole scan runs in a background
/// isolate and the UI only ever sees the finished [LibraryIndex].
class ZoteroFsDataSource {
  const ZoteroFsDataSource();

  Future<LibraryIndex> loadLibrary(LibraryRef library) {
    final path = library.directoryPath;
    final name = library.name;
    final dirName = library.directoryName;
    final type = library.type;
    return Isolate.run(() => parseLibrarySync(path, name, dirName, type));
  }

  /// Reads a single item file including its annotation children.
  Future<ItemDetail> loadItemDetail(String itemFilePath) async {
    final file = File(itemFilePath);
    if (!file.existsSync()) {
      throw LibraryFailure('Berkas item tidak ditemukan', details: itemFilePath);
    }
    final json = ZoteroJson.decodeObject(await file.readAsString());
    return buildItemDetail(json, itemFilePath);
  }
}

/// Parses one library directory. Runs inside a background isolate.
LibraryIndex parseLibrarySync(
  String directoryPath,
  String name,
  String directoryName,
  String type,
) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) {
    throw LibraryFailure('Direktori library tidak ada', details: directoryPath);
  }

  final collections = <String, ZoteroCollection>{};
  final collectionsFile = File(p.join(directoryPath, 'collections.json'));
  if (collectionsFile.existsSync()) {
    for (final entry in ZoteroJson.decodeArray(collectionsFile.readAsStringSync())) {
      if (entry is! Map) continue;
      final collection = ZoteroCollection.fromJson(entry.cast<String, dynamic>());
      if (collection.key.isEmpty) continue;
      collections[collection.key] = collection;
    }
  }

  final items = <String, ZoteroItem>{};
  final itemsByCollection = <String, List<String>>{};
  final unfiled = <String>[];

  final itemsDir = Directory(p.join(directoryPath, 'items'));
  if (itemsDir.existsSync()) {
    for (final entity in itemsDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json = ZoteroJson.decodeObject(entity.readAsStringSync());
        final item = buildItem(json, entity.path);
        if (item == null) continue;
        items[item.key] = item;
        if (item.collectionKeys.isEmpty) {
          unfiled.add(item.key);
        } else {
          for (final key in item.collectionKeys) {
            itemsByCollection.putIfAbsent(key, () => <String>[]).add(item.key);
          }
        }
      } catch (_) {
        // A single unreadable item must not take the whole library down.
        continue;
      }
    }
  }

  final roots = buildCollectionTree(collections, itemsByCollection);

  return LibraryIndex(
    library: LibraryRef(
      name: name,
      directoryName: directoryName,
      directoryPath: directoryPath,
      itemCount: items.length,
      collectionCount: collections.length,
      type: type,
    ),
    collections: collections,
    roots: roots,
    items: items,
    itemsByCollection: itemsByCollection,
    unfiledItemKeys: unfiled,
    builtAt: DateTime.now(),
  );
}

/// Builds the parent/child tree, sorted the way Zotero sorts collections.
List<CollectionNode> buildCollectionTree(
  Map<String, ZoteroCollection> collections,
  Map<String, List<String>> itemsByCollection,
) {
  final nodes = <String, CollectionNode>{
    for (final entry in collections.entries) entry.key: CollectionNode(collection: entry.value),
  };

  final roots = <CollectionNode>[];
  for (final node in nodes.values) {
    node.directItemCount = itemsByCollection[node.key]?.length ?? 0;
    final parentKey = node.collection.parentKey;
    final parent = parentKey == null ? null : nodes[parentKey];
    if (parent == null) {
      roots.add(node);
    } else {
      parent.children = <CollectionNode>[...parent.children, node];
    }
  }

  void sortNode(CollectionNode node) {
    node.children.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final child in node.children) {
      sortNode(child);
    }
  }

  roots.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final root in roots) {
    sortNode(root);
  }
  return roots;
}

/// Converts one `items/<XX>/<KEY>.json` document into a [ZoteroItem].
ZoteroItem? buildItem(Map<String, dynamic> json, String filePath) {
  final zotero = (json['zotero'] as Map?)?.cast<String, dynamic>();
  final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  if (zotero == null) return null;

  final key = zotero['key'] as String? ?? p.basenameWithoutExtension(filePath);
  final children = (json['children'] as List?) ?? const <dynamic>[];

  final attachments = <ZoteroAttachment>[];
  for (final entry in (meta['attachments'] as List?) ?? const <dynamic>[]) {
    if (entry is! Map) continue;
    attachments.add(ZoteroAttachment.fromMeta(entry.cast<String, dynamic>(), key));
  }

  final notes = <ZoteroNote>[];
  var annotationCount = 0;
  for (final entry in children) {
    if (entry is! Map) continue;
    final child = entry.cast<String, dynamic>();
    switch (child['itemType']) {
      case 'note':
        notes.add(
          ZoteroNote(
            key: child['key'] as String? ?? '',
            html: child['note'] as String? ?? '',
            dateModified: DateTime.tryParse(child['dateModified'] as String? ?? ''),
          ),
        );
      case 'annotation':
        annotationCount++;
    }
  }

  final creatorDetails = <ZoteroCreator>[];
  for (final entry in (zotero['creators'] as List?) ?? const <dynamic>[]) {
    if (entry is! Map) continue;
    creatorDetails.add(ZoteroCreator.fromJson(entry.cast<String, dynamic>()));
  }

  final creators = <String>[
    for (final entry in (meta['creators'] as List?) ?? const <dynamic>[])
      if (entry is String && entry.trim().isNotEmpty) entry,
  ];
  if (creators.isEmpty) {
    creators.addAll(creatorDetails.map((c) => c.display).where((c) => c.isNotEmpty));
  }

  final tags = <String>[
    for (final entry in (zotero['tags'] as List?) ?? const <dynamic>[])
      if (entry is Map && entry['tag'] is String) entry['tag'] as String,
  ];

  final reservedFields = <String>{
    'key',
    'itemType',
    'title',
    'creators',
    'collections',
    'tags',
    'relations',
    'dateAdded',
    'dateModified',
    'abstractNote',
    'DOI',
    'url',
    'date',
  };
  final extras = <String, dynamic>{
    for (final entry in zotero.entries)
      if (!reservedFields.contains(entry.key) && entry.value != null && entry.value != '')
        entry.key: entry.value,
  };

  return ZoteroItem(
    key: key,
    title: (meta['title'] as String?)?.trim().isNotEmpty == true
        ? meta['title'] as String
        : (zotero['title'] as String? ?? '(tanpa judul)'),
    itemType: zotero['itemType'] as String? ?? meta['itemType'] as String? ?? 'document',
    filePath: filePath,
    creators: creators,
    creatorDetails: creatorDetails,
    year: meta['year'] as String? ?? _yearOf(zotero['date'] as String?),
    date: zotero['date'] as String? ?? '',
    collectionKeys: <String>[
      for (final entry in (zotero['collections'] as List?) ?? const <dynamic>[])
        if (entry is String) entry,
    ],
    collectionPaths: <String>[
      for (final entry in (meta['collections'] as List?) ?? const <dynamic>[])
        if (entry is String) entry,
    ],
    attachments: attachments,
    notes: notes,
    annotationCount: annotationCount,
    tags: tags,
    publication:
        zotero['publicationTitle'] as String? ??
        zotero['bookTitle'] as String? ??
        zotero['proceedingsTitle'] as String? ??
        '',
    doi: zotero['DOI'] as String? ?? '',
    url: zotero['url'] as String? ?? '',
    abstractNote: zotero['abstractNote'] as String? ?? '',
    publisher: zotero['publisher'] as String? ?? '',
    dateAdded: DateTime.tryParse(zotero['dateAdded'] as String? ?? ''),
    dateModified: DateTime.tryParse(zotero['dateModified'] as String? ?? ''),
    extraFields: extras,
  );
}

/// Parses an item document into the detail view used by the reader.
ItemDetail buildItemDetail(Map<String, dynamic> json, String filePath) {
  final item = buildItem(json, filePath);
  if (item == null) {
    throw LibraryFailure('Berkas item tidak valid', details: filePath);
  }
  final annotations = <ZoteroAnnotation>[];
  for (final entry in (json['children'] as List?) ?? const <dynamic>[]) {
    if (entry is! Map) continue;
    final child = entry.cast<String, dynamic>();
    if (child['itemType'] != 'annotation') continue;
    annotations.add(ZoteroAnnotation.fromJson(child));
  }
  annotations.sort(compareAnnotations);
  return ItemDetail(item: item, annotations: annotations, rawJson: json);
}

int compareAnnotations(ZoteroAnnotation a, ZoteroAnnotation b) {
  if (a.sortIndex.isNotEmpty && b.sortIndex.isNotEmpty && a.sortIndex != b.sortIndex) {
    return a.sortIndex.compareTo(b.sortIndex);
  }
  if (a.pageIndex != b.pageIndex) return a.pageIndex.compareTo(b.pageIndex);
  final aTop = a.rects.isEmpty ? 0.0 : a.rects.first.top;
  final bTop = b.rects.isEmpty ? 0.0 : b.rects.first.top;
  return bTop.compareTo(aTop);
}

String _yearOf(String? date) {
  if (date == null || date.isEmpty) return '';
  final match = RegExp(r'(\d{4})').firstMatch(date);
  return match?.group(1) ?? '';
}
