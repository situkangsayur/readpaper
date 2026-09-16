import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../../sync/domain/entities/git_entities.dart';
import '../controllers/workspace_controller.dart';

/// Shows pending changes, recent commits and the raw git output.
Future<void> showSyncDetailSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const FractionallySizedBox(heightFactor: 0.85, child: _SyncDetailSheet()),
);

class _SyncDetailSheet extends ConsumerWidget {
  const _SyncDetailSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final status = state.gitStatus;
    final profile = state.profile;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    profile?.name ?? 'Repositori',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (status?.lfsAvailable == false)
                  const Tooltip(
                    message: 'git-lfs tidak terpasang; lampiran besar tetap berupa pointer',
                    child: Icon(Icons.warning_amber_outlined, size: 18),
                  ),
                // Deliberately manual: LFS objects are attachments, and one
                // real library keeps 136 MB of them in a couple of books.
                TextButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => ref.read(workspaceControllerProvider.notifier).lfsPull(),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Unduh semua berkas LFS'),
                ),
              ],
            ),
          ),
          if (profile != null && profile.lazyAttachments && status?.lazyAttachments == false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _RecloneNotice(busy: state.isBusy),
            ),
          if (profile != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  '${profile.shortRemote} · ${profile.transport.label} · '
                  'branch ${status?.branch ?? profile.branch}\n${profile.localPath}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Perubahan'),
              Tab(text: 'Riwayat'),
              Tab(text: 'Log git'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _ChangesTab(status: status),
                const _HistoryTab(),
                _LogTab(lines: state.progressLines),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Offered when the working copy still holds every attachment although the
/// profile asks for the lazy layout — typically a clone made before that
/// option existed.
class _RecloneNotice extends ConsumerWidget {
  const _RecloneNotice({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.storage_outlined, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Salinan lokal ini masih menyimpan semua lampiran. Mengambilnya ulang '
              'hanya mengunduh metadata; PDF menyusul saat papernya dibuka.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: busy ? null : () => _confirm(context, ref),
            child: const Text('Ambil ulang'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ambil ulang salinan lokal?'),
        content: const Text(
          'Folder lokal dihapus lalu diambil lagi tanpa lampiran. '
          'Anotasi yang sudah dikirim ke GitHub tetap aman; yang belum dikirim '
          'akan hilang, jadi ini ditolak kalau masih ada perubahan tertunda.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ambil ulang'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    Navigator.of(context).pop();
    await ref.read(workspaceControllerProvider.notifier).recloneActive();
  }
}

class _ChangesTab extends StatelessWidget {
  const _ChangesTab({required this.status});

  final GitRepoStatus? status;

  @override
  Widget build(BuildContext context) {
    final changes = status?.changes ?? const <GitChange>[];
    if (changes.isEmpty) {
      return const Center(child: Text('Tidak ada perubahan lokal.'));
    }
    return ListView.builder(
      itemCount: changes.length,
      itemBuilder: (context, i) {
        final change = changes[i];
        return ListTile(
          leading: Icon(
            change.isUntracked
                ? Icons.add_circle_outline
                : change.isDeleted
                ? Icons.remove_circle_outline
                : Icons.edit_outlined,
            size: 18,
          ),
          title: Text(change.path, style: Theme.of(context).textTheme.bodySmall),
          trailing: Text(change.label, style: Theme.of(context).textTheme.labelSmall),
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(workspaceControllerProvider).profile;
    if (profile == null) return const SizedBox.shrink();

    return FutureBuilder<List<GitCommitInfo>>(
      future: ref.read(gitBackendProvider).log(repoPath: profile.localPath, limit: 50),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final commits = snapshot.data!;
        if (commits.isEmpty) return const Center(child: Text('Belum ada commit.'));
        return ListView.builder(
          itemCount: commits.length,
          itemBuilder: (context, i) {
            final commit = commits[i];
            return ListTile(
              title: Text(commit.subject, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${commit.shortHash} · ${commit.author} · '
                '${commit.date.toLocal().toString().substring(0, 16)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        );
      },
    );
  }
}

class _LogTab extends StatelessWidget {
  const _LogTab({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const Center(child: Text('Belum ada keluaran git.'));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SelectableText(
          lines.join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    );
  }
}
