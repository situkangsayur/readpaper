import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/entities/library_index.dart';
import '../../domain/entities/zotero_item.dart';

/// How the item list is ordered.
enum ItemSort {
  title('Judul'),
  year('Tahun'),
  creator('Pengarang'),
  dateAdded('Ditambahkan'),
  annotations('Anotasi');

  const ItemSort(this.label);

  final String label;
}

/// Which collection (or pseudo-collection) is selected in the sidebar.
class SelectionController extends Notifier<LibrarySelection> {
  @override
  LibrarySelection build() => const LibrarySelection.all();

  void select(LibrarySelection selection) => state = selection;
}

final selectionProvider = NotifierProvider<SelectionController, LibrarySelection>(
  SelectionController.new,
);

/// Collection keys whose children are visible in the tree.
class ExpandedCollectionsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String key) {
    final next = <String>{...state};
    if (!next.remove(key)) next.add(key);
    state = next;
  }

  void expandAll(Iterable<String> keys) => state = <String>{...state, ...keys};

  void collapseAll() => state = <String>{};

  bool isExpanded(String key) => state.contains(key);
}

final expandedCollectionsProvider = NotifierProvider<ExpandedCollectionsController, Set<String>>(
  ExpandedCollectionsController.new,
);

/// Free-text filter over the item list.
class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

class ItemSortController extends Notifier<ItemSort> {
  @override
  ItemSort build() => ItemSort.title;

  void set(ItemSort value) => state = value;
}

final itemSortProvider = NotifierProvider<ItemSortController, ItemSort>(ItemSortController.new);

/// Include the items of sub-collections in the list, like Zotero's option.
class IncludeSubcollectionsController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final includeSubcollectionsProvider = NotifierProvider<IncludeSubcollectionsController, bool>(
  IncludeSubcollectionsController.new,
);

/// Key of the item selected in the middle pane.
class SelectedItemController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? key) => state = key;
}

final selectedItemKeyProvider = NotifierProvider<SelectedItemController, String?>(
  SelectedItemController.new,
);

/// The items shown in the middle pane: selection + search + sort applied.
final visibleItemsProvider = Provider<List<ZoteroItem>>((ref) {
  final index = ref.watch(workspaceControllerProvider).index;
  if (index == null) return const <ZoteroItem>[];

  final selection = ref.watch(selectionProvider);
  final includeSub = ref.watch(includeSubcollectionsProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(itemSortProvider);

  var items = switch (selection.kind) {
    SelectionKind.all => index.allItems,
    SelectionKind.unfiled => index.unfiledItems,
    SelectionKind.collection => index.itemsIn(
      selection.collectionKey!,
      includeSubcollections: includeSub,
    ),
  };

  if (query.isNotEmpty) {
    final terms = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    items = items
        .where((item) => terms.every((term) => item.searchHaystack.contains(term)))
        .toList(growable: false);
  }

  final sorted = <ZoteroItem>[...items];
  sorted.sort(
    (a, b) => switch (sort) {
      ItemSort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      ItemSort.year => b.year.compareTo(a.year),
      ItemSort.creator => a.creatorLabel.toLowerCase().compareTo(b.creatorLabel.toLowerCase()),
      ItemSort.dateAdded => (b.dateAdded ?? DateTime(1970)).compareTo(
        a.dateAdded ?? DateTime(1970),
      ),
      ItemSort.annotations => b.annotationCount.compareTo(a.annotationCount),
    },
  );
  return sorted;
});

/// The currently selected item, if it is still part of the visible list.
final selectedItemProvider = Provider<ZoteroItem?>((ref) {
  final key = ref.watch(selectedItemKeyProvider);
  if (key == null) return null;
  return ref.watch(workspaceControllerProvider).index?.items[key];
});
