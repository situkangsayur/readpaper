import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/formatting.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../../sync/domain/entities/git_entities.dart';
import '../controllers/workspace_controller.dart';
import '../../../../core/l10n.dart';

/// Shows pending changes, recent commits and the raw git output.
///
/// Berkas yang ditolak GitHub punya tabnya sendiri, paling depan, jadi
/// lembar ini langsung terbuka di sana selama masih ada yang menunggu.
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
    final rejectedFiles = status?.rejected ?? const <GitRejectedFile>[];
    final excluded = status?.excluded ?? const <String>[];
    final hasRejectedTab = rejectedFiles.isNotEmpty || excluded.isNotEmpty;

    return DefaultTabController(
      // Tab "Ditolak" muncul dan hilang mengikuti isinya.
      key: ValueKey<bool>(hasRejectedTab),
      length: hasRejectedTab ? 4 : 3,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    profile?.name ?? context.l10n.workspaceRepository,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (status?.lfsAvailable == false)
                  Tooltip(
                    message: context.l10n.syncLfsMissing,
                    child: const Icon(Icons.warning_amber_outlined, size: 18),
                  ),
                // Deliberately manual: LFS objects are attachments, and one
                // real library keeps 136 MB of them in a couple of books.
                TextButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => ref.read(workspaceControllerProvider.notifier).lfsPull(),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text(context.l10n.syncLfsPullAll),
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
                  '${context.l10n.syncBranchLine(status?.branch ?? profile.branch)}\n${profile.localPath}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          TabBar(
            tabs: <Widget>[
              if (hasRejectedTab)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (rejectedFiles.isNotEmpty) ...<Widget>[
                        Icon(Icons.block, size: 16, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        rejectedFiles.isEmpty
                            ? context.l10n.syncTabExcluded
                            : context.l10n.syncTabRejected(rejectedFiles.length),
                      ),
                    ],
                  ),
                ),
              Tab(text: context.l10n.syncTabChanges),
              Tab(text: context.l10n.syncTabHistory),
              Tab(text: context.l10n.syncTabLog),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                if (hasRejectedTab) _RejectedTab(rejected: rejectedFiles, excluded: excluded),
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
              context.l10n.syncRecloneNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: busy ? null : () => _confirm(context, ref),
            child: Text(context.l10n.syncReclone),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.syncRecloneTitle),
        content: Text(context.l10n.syncRecloneBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.workspaceCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.syncReclone),
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

/// Berkas yang ditolak GitHub, dan keputusan untuk masing-masing.
///
/// Sebelumnya hanya ada pesan galat dengan tiga nama berkas, dan berkas itu
/// tetap di antrean selamanya: setiap Kirim berakhir merah lagi, tanpa cara
/// untuk berkata "yang ini tidak usah dikirim".
class _RejectedTab extends ConsumerStatefulWidget {
  const _RejectedTab({required this.rejected, required this.excluded});

  final List<GitRejectedFile> rejected;
  final List<String> excluded;

  @override
  ConsumerState<_RejectedTab> createState() => _RejectedTabState();
}

class _RejectedTabState extends ConsumerState<_RejectedTab> {
  /// Yang dicentang; semuanya, sampai ada yang dilepas.
  Set<String>? _picked;

  Set<String> get _selection => (_picked ?? widget.rejected.map((f) => f.path).toSet())
      .where((path) => widget.rejected.any((f) => f.path == path))
      .toSet();

  Future<void> _decide(List<String> paths, FileDecision decision) async {
    if (paths.isEmpty) return;
    if (decision == FileDecision.remove && !await _confirmRemove(paths)) return;
    await ref.read(workspaceControllerProvider.notifier).decideFiles(paths, decision);
    if (mounted) setState(() => _picked = null);
  }

  Future<bool> _confirmRemove(List<String> paths) async {
    final onRemote = widget.rejected.where((f) => paths.contains(f.path) && f.onRemote).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.syncRemoveFilesTitle(paths.length)),
        content: Text(
          <String>[
            context.l10n.syncRemoveFilesBody,
            if (onRemote > 0) context.l10n.syncRemoveFilesOnRemote(onRemote),
          ].join('\n\n'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.workspaceCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.syncRemoveFile),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(workspaceControllerProvider.select((s) => s.isBusy));
    final selection = _selection;
    final picked = selection.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      children: <Widget>[
        if (widget.rejected.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(context.l10n.syncRejectedIntro, style: text.bodySmall),
          ),
          const SizedBox(height: 8),
          for (final file in widget.rejected)
            CheckboxListTile(
              value: selection.contains(file.path),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.only(left: 4),
              onChanged: (on) => setState(() {
                final next = Set<String>.of(selection);
                on == true ? next.add(file.path) : next.remove(file.path);
                _picked = next;
              }),
              title: Text(p.basename(file.path), maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                <String>[
                  file.path,
                  <String>[
                    file.size == null ? context.l10n.syncFileGone : humanFileSize(file.size!),
                    if (file.onRemote) context.l10n.syncFileOnRemote,
                  ].join(' · '),
                  file.reason,
                ].join('\n'),
                style: text.labelSmall,
              ),
              isThreeLine: true,
              secondary: PopupMenuButton<FileDecision>(
                tooltip: context.l10n.syncFileDecision,
                enabled: !busy,
                onSelected: (decision) => _decide(<String>[file.path], decision),
                itemBuilder: (_) => _decisionItems(context),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: busy || picked.isEmpty
                      ? null
                      : () => _decide(picked, FileDecision.exclude),
                  icon: const Icon(Icons.do_not_disturb_on_outlined, size: 18),
                  label: Text(context.l10n.syncExcludeSelected(picked.length)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: busy || picked.isEmpty
                      ? null
                      : () => _decide(picked, FileDecision.remove),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(context.l10n.syncRemoveSelected(picked.length)),
                ),
                TextButton.icon(
                  onPressed: busy || picked.isEmpty
                      ? null
                      : () => _decide(picked, FileDecision.retry),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(context.l10n.syncRetrySelected(picked.length)),
                ),
              ],
            ),
          ),
        ],
        if (widget.excluded.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(context.l10n.syncExcludedTitle, style: text.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Text(context.l10n.syncExcludedIntro, style: text.bodySmall),
          ),
          for (final path in widget.excluded)
            ListTile(
              dense: true,
              leading: const Icon(Icons.do_not_disturb_on_outlined, size: 18),
              title: Text(p.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(path, style: text.labelSmall),
              trailing: TextButton(
                onPressed: busy ? null : () => _decide(<String>[path], FileDecision.include),
                child: Text(context.l10n.syncIncludeAgain),
              ),
            ),
        ],
      ],
    );
  }

  List<PopupMenuEntry<FileDecision>> _decisionItems(BuildContext context) =>
      <PopupMenuEntry<FileDecision>>[
        for (final (decision, icon, label) in <(FileDecision, IconData, String)>[
          (FileDecision.exclude, Icons.do_not_disturb_on_outlined, context.l10n.syncExcludeFile),
          (FileDecision.remove, Icons.delete_outline, context.l10n.syncRemoveFile),
          (FileDecision.retry, Icons.refresh, context.l10n.syncRetryFile),
        ])
          PopupMenuItem<FileDecision>(
            value: decision,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, size: 18),
              title: Text(label),
            ),
          ),
      ];
}

class _ChangesTab extends StatelessWidget {
  const _ChangesTab({required this.status});

  final GitRepoStatus? status;

  @override
  Widget build(BuildContext context) {
    final changes = status?.changes ?? const <GitChange>[];
    if (changes.isEmpty) {
      return Center(child: Text(context.l10n.syncNoLocalChanges));
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
        if (commits.isEmpty) return Center(child: Text(context.l10n.syncNoCommits));
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
    if (lines.isEmpty) return Center(child: Text(context.l10n.syncNoGitOutput));
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
