import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workspace/presentation/controllers/workspace_controller.dart';

/// Every author in the library, with how many items each one has.
///
/// Answers "who is in here, and how much of them do I have" — the question
/// the search box cannot answer, because you have to know a name before you
/// can type it.
Future<String?> showCreatorFacetSheet(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => const _CreatorFacetSheet(),
);

class _CreatorFacetSheet extends ConsumerStatefulWidget {
  const _CreatorFacetSheet();

  @override
  ConsumerState<_CreatorFacetSheet> createState() => _CreatorFacetSheetState();
}

class _CreatorFacetSheetState extends ConsumerState<_CreatorFacetSheet> {
  final TextEditingController _filter = TextEditingController();
  bool _byCount = true;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(workspaceControllerProvider).index;
    final all = index?.creatorFacets() ?? const <MapEntry<String, int>>[];

    final needle = _filter.text.trim().toLowerCase();
    final entries = <MapEntry<String, int>>[
      for (final e in all)
        if (needle.isEmpty || e.key.toLowerCase().contains(needle)) e,
    ];
    if (_byCount) {
      entries.sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    }

    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text('Pengarang (${all.length})', style: text.titleMedium)),
                  TextButton.icon(
                    onPressed: () => setState(() => _byCount = !_byCount),
                    icon: Icon(_byCount ? Icons.sort : Icons.sort_by_alpha, size: 18),
                    label: Text(_byCount ? 'Terbanyak' : 'A–Z'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _filter,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Saring nama',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        all.isEmpty
                            ? 'Belum ada library yang terbaca.'
                            : 'Tidak ada nama yang cocok.',
                        style: text.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        return ListTile(
                          dense: true,
                          title: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text('${entry.value}', style: text.labelMedium),
                          // Quoted, so a name with a space stays one term.
                          onTap: () => Navigator.of(context).pop('pengarang:"${entry.key}"'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
