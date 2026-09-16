import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/domain/entities/library_index.dart';
import '../controllers/workspace_controller.dart';

/// Repository and library pickers that live in the app bar.
///
/// Switching a repository only flips the active profile: each profile keeps its
/// own clone, so moving back and forth never re-downloads anything.
class RepoSwitcher extends ConsumerWidget {
  const RepoSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final profiles = state.settings.profiles;
    if (profiles.isEmpty) return const SizedBox.shrink();

    final libraries = state.layout?.libraries ?? const <LibraryRef>[];
    final activeId = state.profile?.id ?? profiles.first.id;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Chip(
          icon: Icons.folder_copy_outlined,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: profiles.any((p) => p.id == activeId) ? activeId : profiles.first.id,
              isDense: true,
              borderRadius: BorderRadius.circular(8),
              items: <DropdownMenuItem<String>>[
                for (final profile in profiles)
                  DropdownMenuItem<String>(
                    value: profile.id,
                    child: Text(profile.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: state.isBusy
                  ? null
                  : (value) {
                      if (value != null) {
                        ref.read(workspaceControllerProvider.notifier).selectProfile(value);
                      }
                    },
            ),
          ),
        ),
        if (libraries.length > 1) ...<Widget>[
          const SizedBox(width: 8),
          _Chip(
            icon: Icons.local_library_outlined,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.library?.directoryName ?? libraries.first.directoryName,
                isDense: true,
                borderRadius: BorderRadius.circular(8),
                items: <DropdownMenuItem<String>>[
                  for (final library in libraries)
                    DropdownMenuItem<String>(
                      value: library.directoryName,
                      child: Text(library.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: state.isBusy
                    ? null
                    : (value) {
                        final selected = libraries.firstWhere(
                          (l) => l.directoryName == value,
                          orElse: () => libraries.first,
                        );
                        ref.read(workspaceControllerProvider.notifier).selectLibrary(selected);
                      },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: child),
        ],
      ),
    );
  }
}
