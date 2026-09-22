import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/providers/app_providers.dart';
import '../../../settings/presentation/widgets/profile_editor_dialog.dart';
import '../controllers/workspace_controller.dart';

/// Shown before any repository has been configured.
class NoProfileView extends ConsumerWidget {
  const NoProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(gitBackendProvider);
    final akses = backend.supportedTransports.length > 1
        ? 'lewat SSH atau HTTPS'
        : 'lewat token GitHub';

    return _CenteredCard(
      icon: Icons.library_books_outlined,
      title: 'Belum ada repositori',
      body: Text(
        'ReadPaper membaca library Zotero yang disinkronkan ke GitHub oleh plugin '
        'zotero-github-sync. Tambahkan repositori ($akses) untuk mulai '
        'membaca, menandai dan memberi komentar pada paper.',
      ),
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () => showProfileEditor(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Tambah repositori'),
        ),
      ],
    );
  }
}

/// The profile exists but the clone directory is not there yet.
class NotClonedView extends ConsumerWidget {
  const NotClonedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final controller = ref.read(workspaceControllerProvider.notifier);
    final profile = state.profile;
    if (profile == null) return const NoProfileView();

    // Both the Android mirror and a partial clone fetch only metadata first.
    final lazy = profile.lazyAttachments;
    // An interrupted download leaves its bookkeeping behind; the same button
    // then continues instead of starting over.
    final partial = File(p.join(profile.localPath, '.readpaper', 'sync-state.json')).existsSync();

    return _CenteredCard(
      icon: Icons.cloud_download_outlined,
      title: lazy ? 'Ambil library "${profile.name}"' : 'Clone "${profile.name}"',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText('${profile.remoteUrl}  (${profile.transport.label})'),
          const SizedBox(height: 4),
          Text(
            partial
                ? 'Unduhan sebelumnya terputus. Melanjutkan hanya mengambil berkas '
                      'yang belum sempat tersimpan.'
                : lazy
                ? 'Metadata library diunduh sekarang; berkas PDF menyusul saat '
                      'papernya dibuka.'
                : 'Akan disimpan di ${profile.localPath}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.progressLines.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              height: 160,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  state.progressLines.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: state.isBusy ? null : controller.checkConnection,
          icon: const Icon(Icons.wifi_tethering, size: 18),
          label: const Text('Periksa koneksi'),
        ),
        TextButton.icon(
          onPressed: () => showProfileEditor(context, ref, existing: profile),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Ubah profil'),
        ),
        FilledButton.icon(
          onPressed: state.isBusy ? null : controller.clone,
          icon: state.isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(
            state.isBusy
                ? (lazy ? 'Mengunduh…' : 'Meng-clone…')
                : (partial ? 'Lanjutkan' : (lazy ? 'Ambil sekarang' : 'Clone sekarang')),
          ),
        ),
      ],
    );
  }
}

/// Cloned, but no Zotero export was found inside.
class NoLibraryView extends ConsumerWidget {
  const NoLibraryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workspaceControllerProvider.notifier);
    return _CenteredCard(
      icon: Icons.folder_off_outlined,
      title: 'Library tidak terbaca',
      body: const Text(
        'Repositori sudah ada di lokal tetapi tidak ditemukan struktur Zotero '
        '(collections.json dan folder items/). Pastikan repositori memang hasil '
        'ekspor plugin Zotero GitHub Sync, lalu tarik perubahan terbaru.',
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: controller.reloadLibrary,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Baca ulang'),
        ),
        FilledButton.icon(
          onPressed: controller.pull,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Pull'),
        ),
      ],
    );
  }
}

class _CenteredCard extends StatelessWidget {
  const _CenteredCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 12),
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
                  child: body,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    for (final action in actions) ...<Widget>[action, const SizedBox(width: 8)],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
