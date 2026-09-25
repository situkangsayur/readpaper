import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatting.dart';
import '../../../settings/domain/entities/repo_profile.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';

/// The papers opened before, newest first.
///
/// Reading is picked up again far more often than it is started: the list you
/// want on opening the app is usually the three papers you had open
/// yesterday, not the whole library.
class RecentPapersCard extends ConsumerWidget {
  const RecentPapersCard({required this.onOpen, this.maxVisible = 5, super.key});

  /// Called with a history entry the reader should open.
  final void Function(RecentPaper entry) onOpen;

  final int maxVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceControllerProvider);
    final profileId = workspace.settings.activeProfile?.id;
    if (profileId == null) return const SizedBox.shrink();

    // History from other libraries is deliberately hidden: those clones may
    // not even be on disk, and offering a paper that cannot open is worse
    // than not offering it.
    final entries = workspace.settings.recents
        .where((r) => r.profileId == profileId)
        .take(maxVisible)
        .toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: <Widget>[
                Icon(Icons.history, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Terakhir dibaca', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.read(workspaceControllerProvider.notifier).forgetRecent(),
                  child: const Text('Bersihkan'),
                ),
              ],
            ),
          ),
          for (final entry in entries)
            ListTile(
              dense: true,
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                <String>[
                  if (entry.subtitle.isNotEmpty) entry.subtitle,
                  if (entry.lastPage > 1) 'halaman ${entry.lastPage}',
                  relativeTime(entry.openedAt),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                iconSize: 18,
                tooltip: 'Hapus dari riwayat',
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(workspaceControllerProvider.notifier).forgetRecent(entry: entry),
              ),
              onTap: () => onOpen(entry),
            ),
        ],
      ),
    );
  }
}
