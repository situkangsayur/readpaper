import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/entities/repo_profile.dart';
import '../widgets/profile_editor_dialog.dart';

/// Manage the repositories ReadPaper knows about and pick the active one.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final controller = ref.read(workspaceControllerProvider.notifier);
    final profiles = state.settings.profiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repositori'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Tema',
            icon: const Icon(Icons.brightness_6_outlined),
            initialValue: state.settings.themeMode,
            onSelected: controller.setThemeMode,
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'system', child: Text('Ikut sistem')),
              PopupMenuItem<String>(value: 'light', child: Text('Terang')),
              PopupMenuItem<String>(value: 'dark', child: Text('Gelap')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showProfileEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah repositori'),
      ),
      bottomNavigationBar: const SafeArea(child: _VersionFooter()),
      body: profiles.isEmpty
          ? const Center(child: Text('Belum ada repositori.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final profile = profiles[i];
                final isActive = state.profile?.id == profile.id;
                return _ProfileCard(
                  profile: profile,
                  isActive: isActive,
                  onActivate: () => controller.selectProfile(profile.id),
                  onEdit: () => showProfileEditor(context, ref, existing: profile),
                  onDelete: () => _confirmDelete(context, controller, profile),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WorkspaceController controller,
    RepoProfile profile,
  ) async {
    var deleteClone = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Hapus "${profile.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Profil akan dihapus dari ReadPaper.'),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: deleteClone,
                title: const Text('Hapus juga folder clone lokal'),
                subtitle: Text(profile.localPath, style: Theme.of(context).textTheme.labelSmall),
                onChanged: (value) => setState(() => deleteClone = value ?? false),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
    if (confirmed ?? false) {
      await controller.deleteProfile(profile.id, deleteClone: deleteClone);
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
  });

  final RepoProfile profile;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: isActive ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isActive ? scheme.primary : scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 18,
                  color: isActive ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(profile.name, style: Theme.of(context).textTheme.titleSmall)),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(profile.transport.label),
                  padding: EdgeInsets.zero,
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(profile.remoteUrl, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              profile.localPath,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
            ),
            if (!profile.remoteMatchesTransport)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.warning_amber_outlined, size: 14, color: scheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'URL tidak cocok dengan mode ${profile.transport.label}.',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isActive)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onActivate,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Jadikan aktif'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows which build is actually installed.
///
/// Two devices running different APKs looked like a broken feature once: a
/// tablet still on an older build had no marker button at all, and there was
/// no way to tell from inside the app.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (context, snapshot) {
      final info = snapshot.data;
      final text = info == null
          ? 'ReadPaper'
          : 'ReadPaper ${info.version} (build ${info.buildNumber})';
      final outline = Theme.of(context).colorScheme.outline;
      final small = Theme.of(context).textTheme.labelSmall?.copyWith(color: outline);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.info_outline, size: 14, color: outline),
                const SizedBox(width: 6),
                SelectableText(text, style: small),
              ],
            ),
            const SizedBox(height: 4),
            // AGPL asks that an interactive program keeps showing where its
            // source is; this line is that notice, not decoration.
            SelectableText(
              'Perangkat lunak bebas, lisensi AGPL-3.0-or-later.\n'
              'Kode sumber: github.com/situkangsayur/readpaper',
              textAlign: TextAlign.center,
              style: small,
            ),
          ],
        ),
      );
    },
  );
}
