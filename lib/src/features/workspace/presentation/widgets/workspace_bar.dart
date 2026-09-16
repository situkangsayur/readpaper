import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/domain/entities/library_index.dart';
import '../../../sync/domain/entities/git_entities.dart';
import '../controllers/workspace_controller.dart';
import 'sync_detail_sheet.dart';

/// Full-width bar under the app bar: which repository and library are open,
/// what the sync is doing, and the sync actions.
///
/// It lives here rather than in the app bar because the app bar gives its title
/// a fixed box — a long repository name used to overflow it and paint Flutter's
/// striped overflow marker over the action icons.
class WorkspaceBar extends ConsumerWidget {
  const WorkspaceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    if (!state.hasProfile) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 720;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              children: <Widget>[
                Flexible(child: _RepoPicker(narrow: narrow)),
                if (!narrow) ...<Widget>[
                  const SizedBox(width: 6),
                  Flexible(child: _LibraryPicker()),
                ],
                const Spacer(),
                const _SyncActions(),
              ],
            ),
          ),
          const _ProgressRow(),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

/// Active repository; tapping it switches profile.
class _RepoPicker extends ConsumerWidget {
  const _RepoPicker({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final profiles = state.settings.profiles;
    final active = state.profile;
    if (active == null) return const SizedBox.shrink();

    return _BarButton(
      icon: Icons.folder_copy_outlined,
      label: active.name,
      // Switching repositories mid-sync would leave the running one orphaned.
      enabled: !state.isBusy && profiles.length > 1,
      tooltip: profiles.length > 1
          ? 'Ganti repositori (${profiles.length} tersedia)'
          : active.shortRemote,
      maxWidth: narrow ? 200 : 280,
      onSelected: () async {
        final chosen = await showMenu<String>(
          context: context,
          position: _anchorOf(context),
          items: <PopupMenuEntry<String>>[
            for (final profile in profiles)
              PopupMenuItem<String>(
                value: profile.id,
                child: Row(
                  children: <Widget>[
                    Icon(
                      profile.id == active.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(profile.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
          ],
        );
        if (chosen != null && chosen != active.id) {
          await ref.read(workspaceControllerProvider.notifier).selectProfile(chosen);
        }
      },
    );
  }
}

/// Library inside the repository, shown only when there is more than one.
class _LibraryPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final libraries = state.layout?.libraries ?? const <LibraryRef>[];
    if (libraries.length < 2) return const SizedBox.shrink();
    final active = state.library ?? libraries.first;

    return _BarButton(
      icon: Icons.local_library_outlined,
      label: active.name,
      enabled: !state.isBusy,
      tooltip: 'Ganti library',
      maxWidth: 220,
      onSelected: () async {
        final chosen = await showMenu<String>(
          context: context,
          position: _anchorOf(context),
          items: <PopupMenuEntry<String>>[
            for (final library in libraries)
              PopupMenuItem<String>(
                value: library.directoryName,
                child: Text(library.name, overflow: TextOverflow.ellipsis),
              ),
          ],
        );
        if (chosen != null && chosen != active.directoryName) {
          await ref
              .read(workspaceControllerProvider.notifier)
              .selectLibrary(libraries.firstWhere((l) => l.directoryName == chosen));
        }
      },
    );
  }
}

/// Status chip plus the fetch / pull / push actions.
class _SyncActions extends ConsumerWidget {
  const _SyncActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final controller = ref.read(workspaceControllerProvider.notifier);
    final status = state.gitStatus;
    if (status == null || !status.exists) return const SizedBox.shrink();

    final busy = state.isBusy;
    final narrow = MediaQuery.sizeOf(context).width < 900;

    void guard(VoidCallback action) {
      if (busy) {
        _tellBusy(context, state.phaseLabel);
        return;
      }
      action();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StatusChip(status: status),
        const SizedBox(width: 4),
        if (narrow)
          PopupMenuButton<String>(
            tooltip: 'Sinkronisasi',
            icon: Badge(
              isLabelVisible: !busy && !status.isClean,
              child: Icon(busy ? Icons.sync : Icons.cloud_sync_outlined, size: 20),
            ),
            onSelected: (value) => guard(
              () => switch (value) {
                'fetch' => controller.fetch(),
                'pull' => controller.pull(),
                'push' => _commitAndPush(context, ref),
                _ => showSyncDetailSheet(context),
              },
            ),
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'fetch', child: Text('Periksa perubahan')),
              PopupMenuItem<String>(
                value: 'pull',
                child: Text(
                  status.behind > 0 ? 'Tarik ${status.behind} commit baru' : 'Tarik perubahan',
                ),
              ),
              const PopupMenuItem<String>(value: 'push', child: Text('Kirim perubahan')),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'detail', child: Text('Detail sinkronisasi')),
            ],
          )
        else ...<Widget>[
          IconButton(
            iconSize: 20,
            tooltip: 'Periksa perubahan di remote',
            icon: const Icon(Icons.sync_outlined),
            onPressed: () => guard(controller.fetch),
          ),
          IconButton(
            iconSize: 20,
            tooltip: status.behind > 0 ? 'Tarik ${status.behind} commit baru' : 'Tarik perubahan',
            icon: Badge(
              isLabelVisible: status.behind > 0,
              label: Text('${status.behind}'),
              child: const Icon(Icons.download_outlined),
            ),
            onPressed: () => guard(controller.pull),
          ),
          IconButton(
            iconSize: 20,
            tooltip: 'Kirim perubahan ke GitHub',
            icon: Badge(
              isLabelVisible: status.isDirty || status.ahead > 0,
              label: Text('${status.changes.length + status.ahead}'),
              child: const Icon(Icons.upload_outlined),
            ),
            onPressed: () => guard(() => _commitAndPush(context, ref)),
          ),
          IconButton(
            iconSize: 20,
            tooltip: 'Detail sinkronisasi',
            icon: const Icon(Icons.history_outlined),
            onPressed: () => showSyncDetailSheet(context),
          ),
        ],
      ],
    );
  }

  static void _tellBusy(BuildContext context, String phaseLabel) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            phaseLabel.isEmpty
                ? 'Sinkronisasi sedang berjalan, tunggu sampai selesai.'
                : '$phaseLabel Tunggu sampai selesai.',
          ),
        ),
      );
  }

  Future<void> _commitAndPush(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(workspaceControllerProvider.notifier);
    final status = ref.read(workspaceControllerProvider).gitStatus;

    if (status != null && !status.isDirty && status.ahead > 0) {
      await controller.push();
      return;
    }
    if (status != null && !status.isDirty && status.ahead == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Tidak ada perubahan untuk dikirim.')));
      return;
    }

    final message = await showDialog<String>(
      context: context,
      builder: (_) => const CommitDialog(),
    );
    if (message == null || message.trim().isEmpty) return;
    await controller.commitAll(message: message.trim());
  }
}

/// "Sinkron", "3 perubahan lokal", or what the running step is doing.
class _StatusChip extends ConsumerWidget {
  const _StatusChip({required this.status});

  final GitRepoStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final busy = state.isBusy;

    final label = busy
        ? (state.progress?.isMeasurable ?? false
              ? '${state.phaseLabel.replaceAll('…', '')} ${state.progress!.percent}%'
              : state.phaseLabel)
        : status.summary;
    final color = busy
        ? scheme.primary
        : status.isClean
        ? scheme.tertiary
        : scheme.secondary;

    final lastSync = state.profile?.lastSyncedAt;
    return Tooltip(
      message: <String>[
        'Branch: ${status.branch}',
        if (status.lastCommitSubject.isNotEmpty) 'Commit terakhir: ${status.lastCommitSubject}',
        if (lastSync != null) 'Sinkron terakhir: ${_clock(lastSync)}',
      ].join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
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
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
              ),
            ),
            if (!busy && lastSync != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                _clock(lastSync),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime time) {
    final local = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

/// Determinate progress bar plus the exact step, shown only while syncing.
class _ProgressRow extends ConsumerWidget {
  const _ProgressRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    if (!state.isBusy && !state.loadingLibrary) return const SizedBox.shrink();

    final progress = state.progress;
    final text = state.isBusy
        ? (progress?.label ?? state.phaseLabel)
        : 'Membaca library dari berkas…';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 5,
              // A null value keeps the bar indeterminate instead of pretending
              // to know a percentage git has not reported yet.
              value: progress?.fraction,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Shared shape for the repository / library buttons.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onSelected,
    required this.maxWidth,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final double maxWidth;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip ?? label,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: InkWell(
          onTap: enabled ? onSelected : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (enabled) Icon(Icons.arrow_drop_down, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Places a popup right under the widget that opened it.
RelativeRect _anchorOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) {
    return const RelativeRect.fromLTRB(0, kToolbarHeight, 0, 0);
  }
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  return RelativeRect.fromLTRB(
    topLeft.dx,
    topLeft.dy + box.size.height,
    overlay.size.width - topLeft.dx - box.size.width,
    0,
  );
}

/// Asks for the message of a manual commit.
class CommitDialog extends StatefulWidget {
  const CommitDialog({super.key});

  @override
  State<CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends State<CommitDialog> {
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
    title: const Text('Kirim perubahan'),
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
        child: const Text('Commit & kirim'),
      ),
    ],
  );
}
