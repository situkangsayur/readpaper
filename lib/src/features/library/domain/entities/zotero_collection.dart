import 'package:meta/meta.dart';

/// A Zotero collection as stored in `<library>/collections.json`.
@immutable
class ZoteroCollection {
  const ZoteroCollection({
    required this.key,
    required this.name,
    required this.path,
    this.parentKey,
    this.relations = const <String, dynamic>{},
  });

  factory ZoteroCollection.fromJson(Map<String, dynamic> json) => ZoteroCollection(
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? '(untitled)',
    path: json['path'] as String? ?? (json['name'] as String? ?? ''),
    parentKey: json['parentKey'] as String?,
    relations: (json['relations'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
  );

  final String key;
  final String name;

  /// Full slash-separated path, e.g. `Astri Reference Mendeley/DKD`.
  final String path;
  final String? parentKey;
  final Map<String, dynamic> relations;

  int get depth => path.split('/').length - 1;
}

/// A node of the collection tree shown in the sidebar.
class CollectionNode {
  CollectionNode({required this.collection, List<CollectionNode>? children})
    : children = children ?? <CollectionNode>[];

  final ZoteroCollection collection;
  List<CollectionNode> children;

  String get key => collection.key;
  String get name => collection.name;
  String get path => collection.path;

  /// Number of items directly assigned to this collection.
  int directItemCount = 0;

  /// Items in this collection and every descendant.
  int get totalItemCount =>
      directItemCount + children.fold(0, (sum, child) => sum + child.totalItemCount);

  Iterable<CollectionNode> get descendants sync* {
    for (final child in children) {
      yield child;
      yield* child.descendants;
    }
  }

  List<String> get subtreeKeys => <String>[key, ...descendants.map((n) => n.key)];
}
