import 'package:meta/meta.dart';

import 'zotero_collection.dart';
import 'zotero_item.dart';

/// One library directory inside a synced repository (`my-library`, `group-…`).
@immutable
class LibraryRef {
  const LibraryRef({
    required this.name,
    required this.directoryName,
    required this.directoryPath,
    this.itemCount = 0,
    this.collectionCount = 0,
    this.type = 'user',
  });

  final String name;
  final String directoryName;

  /// Absolute path of the library directory.
  final String directoryPath;
  final int itemCount;
  final int collectionCount;
  final String type;
}

/// Where the Zotero export lives inside a cloned repository.
@immutable
class RepoLayout {
  const RepoLayout({
    required this.repoRoot,
    required this.zoteroRoot,
    required this.libraries,
  });

  final String repoRoot;

  /// Directory that holds `.zotero-sync/` and the library directories.
  final String zoteroRoot;
  final List<LibraryRef> libraries;

  bool get isEmpty => libraries.isEmpty;
}

/// Fully parsed, in-memory view of one library.
class LibraryIndex {
  LibraryIndex({
    required this.library,
    required this.collections,
    required this.roots,
    required this.items,
    required this.itemsByCollection,
    required this.unfiledItemKeys,
    required this.builtAt,
  });

  final LibraryRef library;

  /// Every collection, keyed by its Zotero key.
  final Map<String, ZoteroCollection> collections;

  /// Top-level collection nodes (children already attached).
  final List<CollectionNode> roots;

  /// Every top-level item, keyed by its Zotero key.
  final Map<String, ZoteroItem> items;

  /// Item keys per collection key (direct membership only).
  final Map<String, List<String>> itemsByCollection;

  final List<String> unfiledItemKeys;
  final DateTime builtAt;

  int get itemCount => items.length;
  int get collectionCount => collections.length;

  List<ZoteroItem> get allItems => items.values.toList(growable: false);

  /// Items in [collectionKey]; when [includeSubcollections] the whole subtree.
  List<ZoteroItem> itemsIn(String collectionKey, {bool includeSubcollections = true}) {
    final node = _nodeFor(collectionKey);
    final keys = <String>{};
    if (node == null) {
      keys.addAll(itemsByCollection[collectionKey] ?? const <String>[]);
    } else {
      final scope = includeSubcollections ? node.subtreeKeys : <String>[collectionKey];
      for (final k in scope) {
        keys.addAll(itemsByCollection[k] ?? const <String>[]);
      }
    }
    return keys.map((k) => items[k]).whereType<ZoteroItem>().toList(growable: false);
  }

  List<ZoteroItem> get unfiledItems =>
      unfiledItemKeys.map((k) => items[k]).whereType<ZoteroItem>().toList(growable: false);

  CollectionNode? _nodeFor(String key) {
    for (final root in roots) {
      if (root.key == key) return root;
      for (final node in root.descendants) {
        if (node.key == key) return node;
      }
    }
    return null;
  }

  /// All distinct creators in the library, sorted, with their item counts.
  List<MapEntry<String, int>> creatorFacets() {
    final counts = <String, int>{};
    for (final item in items.values) {
      for (final creator in item.creators) {
        if (creator.trim().isEmpty) continue;
        counts.update(creator, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return entries;
  }
}

/// The selection driving the item list.
@immutable
class LibrarySelection {
  const LibrarySelection.all() : collectionKey = null, kind = SelectionKind.all;
  const LibrarySelection.unfiled() : collectionKey = null, kind = SelectionKind.unfiled;
  const LibrarySelection.collection(String key) : collectionKey = key, kind = SelectionKind.collection;

  final String? collectionKey;
  final SelectionKind kind;

  @override
  bool operator ==(Object other) =>
      other is LibrarySelection && other.kind == kind && other.collectionKey == collectionKey;

  @override
  int get hashCode => Object.hash(kind, collectionKey);
}

enum SelectionKind { all, unfiled, collection }
