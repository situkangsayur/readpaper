import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/domain/entities/git_entities.dart';
import '../controllers/workspace_controller.dart';
import 'sync_detail_sheet.dart';

/// Pull / commit+push controls plus the working-copy state, in the app bar.
class SyncBar extends ConsumerWidget {
  const SyncBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final controller = ref.read(workspaceControllerProvider.notifier);
    final status = state.gitStatus;
    if (!state.hasProfile || status == null || !status.exists) return const SizedBox.shrink();

    final busy = state.isBusy;
    // A phone has no room for four buttons plus the status chip.
    final compact = MediaQuery.sizeOf(context).width < 720;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          PopupMenuButton<String>(
            tooltip: status.summary,
            icon: Badge(
              isLabelVisible: !status.isClean,
              child: Icon(status.isClean ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined),
            ),
            enabled: !busy,
            onSelected: (value) => switch (value) {
              'fetch' => controller.fetch(),
              'pull' => controller.pull(),
              'push' => _commitAndPush(context, ref),
              _ => showSyncDetailSheet(context),
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Text(status.summary, style: Theme.of(context).textTheme.labelSmall),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'fetch', child: Text('Periksa perubahan')),
              PopupMenuItem<String>(
                value: 'pull',
                child: Text(status.behind > 0 ? 'Tarik ${status.behind} commit baru' : 'Tarik perubahan'),
              ),
              const PopupMenuItem<String>(value: 'push', child: Text('Kirim perubahan')),
              const PopupMenuItem<String>(value: 'detail', child: Text('Detail sinkronisasi')),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StatusChip(status: status, phaseLabel: state.phaseLabel, busy: busy),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Periksa perubahan di remote (fetch)',
          icon: const Icon(Icons.sync_outlined),
          onPressed: busy ? null : controller.fetch,
        ),
        IconButton(
          tooltip: status.behind > 0 ? 'Tarik ${status.behind} commit baru' : 'Pull',
          icon: Badge(
            isLabelVisible: status.behind > 0,
            label: Text('${status.behind}'),
            child: const Icon(Icons.download_outlined),
          ),
          onPressed: busy ? null : controller.pull,
        ),
        IconButton(
          tooltip: 'Commit & push perubahan lokal',
          icon: Badge(
            isLabelVisible: status.isDirty || status.ahead > 0,
            label: Text('${status.changes.length + status.ahead}'),
            child: const Icon(Icons.upload_outlined),
          ),
          onPressed: busy ? null : () => _commitAndPush(context, ref),
        ),
        IconButton(
          tooltip: 'Detail sinkronisasi',
          icon: const Icon(Icons.history_outlined),
          onPressed: () => showSyncDetailSheet(context),
        ),
      ],
    );
  }

  Future<void> _commitAndPush(BuildContext context, WidgetRef ref) async {
    final state = ref.read(workspaceControllerProvider);
    final status = state.gitStatus;
    final controller = ref.read(workspaceControllerProvider.notifier);

    if (status != null && !status.isDirty && status.ahead > 0) {
      await controller.push();
      return;
    }

    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _CommitDialog(),
    );
    if (message == null || message.trim().isEmpty) return;
    await controller.commitAll(message: message.trim());
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.phaseLabel, required this.busy});

  final GitRepoStatus status;
  final String phaseLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = busy && phaseLabel.isNotEmpty ? phaseLabel : status.summary;
    final color = busy
        ? scheme.primary
        : status.isClean
        ? scheme.tertiary
        : scheme.secondary;

    return Tooltip(
      message: <String>[
        'Branch: ${status.branch}',
        if (status.remoteUrl.isNotEmpty) 'Remote: ${status.remoteUrl}',
        if (status.lastCommitSubject.isNotEmpty) 'Terakhir: ${status.lastCommitSubject}',
      ].join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (busy)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(
                status.isClean ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined,
                size: 14,
                color: color,
              ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommitDialog extends StatefulWidget {
  const _CommitDialog();

  @override
  State<_CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends State<_CommitDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: 'Perbarui anotasi dari ReadPaper',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Commit & push'),
    content: SizedBox(
      width: 420,
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Pesan commit'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
    ),
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Commit & push'),
      ),
    ],
  );
}
