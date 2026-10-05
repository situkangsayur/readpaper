import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/domain/entities/library_index.dart';
import '../../../settings/domain/entities/repo_profile.dart';
import '../../domain/entities/repo_stats.dart';
import '../controllers/workspace_controller.dart';

/// Pilihan dari [showRepoTransferSheet].
class RepoTransferChoice {
  const RepoTransferChoice({
    required this.target,
    required this.library,
    required this.collectionKey,
    required this.move,
  });

  final RepoProfile target;
  final LibraryIndex library;

  /// Koleksi tujuan; null berarti tanpa koleksi (paper) atau akar (koleksi).
  final String? collectionKey;

  /// true memindah (dihapus dari asal), false menyalin.
  final bool move;
}

/// Memilih repositori dan koleksi tujuan untuk memindah atau menyalin.
///
/// Repositori aktif tidak berpindah selama memilih: library tujuan hanya
/// dibaca dari foldernya. Setiap repositori menyebut ukuran dan isinya,
/// karena memilih tempat menaruh sesuatu tanpa tahu apa yang sudah ada di
/// sana adalah menebak.
Future<RepoTransferChoice?> showRepoTransferSheet(
  BuildContext context, {
  required String what,
  required bool forCollection,
}) => showModalBottomSheet<RepoTransferChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _TransferSheet(what: what, forCollection: forCollection),
);

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({required this.what, required this.forCollection});

  final String what;
  final bool forCollection;

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  RepoProfile? _target;
  LibraryIndex? _library;
  bool _loading = false;
  String? _error;
  String? _collection;
  bool _move = true;

  Future<void> _pick(RepoProfile profile) async {
    setState(() {
      _target = profile;
      _library = null;
      _collection = null;
      _loading = true;
      _error = null;
    });
    final library = await ref.read(workspaceControllerProvider.notifier).otherLibrary(profile);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _library = library;
      if (library == null) {
        _error =
            'Library di "${profile.name}" belum ada di perangkat ini. Buka repositori itu '
            'sekali dan ambil library-nya, lalu ulangi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceControllerProvider);
    final others = state.settings.profiles.where((p) => p.id != state.profile?.id).toList();
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Ke repositori lain', style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(widget.what, style: theme.textTheme.bodySmall, maxLines: 2),
              const SizedBox(height: 12),
              if (others.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Belum ada repositori lain. Tambahkan dulu di pengaturan Repositori.',
                  ),
                )
              else if (_target == null)
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final profile in others)
                        ListTile(
                          leading: const Icon(Icons.storage_outlined),
                          title: Text(profile.name),
                          subtitle: RepoStatsLine(profile: profile),
                          onTap: () => _pick(profile),
                        ),
                    ],
                  ),
                )
              else ...<Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storage),
                  title: Text(_target!.name),
                  subtitle: RepoStatsLine(profile: _target!),
                  trailing: TextButton(
                    onPressed: () => setState(() => _target = null),
                    child: const Text('Ganti'),
                  ),
                ),
                const Divider(height: 1),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(padding: const EdgeInsets.all(16), child: Text(_error!))
                else if (_library != null)
                  Flexible(child: _collectionList(_library!)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.drive_file_move_outline),
                      label: Text('Pindahkan'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.copy_outlined),
                      label: Text('Salin'),
                    ),
                  ],
                  selected: <bool>{_move},
                  onSelectionChanged: (value) => setState(() => _move = value.first),
                ),
                const SizedBox(height: 4),
                Text(
                  _move
                      ? 'Dihapus dari repositori ini setelah salinannya utuh di tujuan.'
                      : 'Yang di sini tetap; tujuan mendapat salinannya.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _library == null
                      ? null
                      : () => Navigator.of(context).pop(
                          RepoTransferChoice(
                            target: _target!,
                            library: _library!,
                            collectionKey: _collection,
                            move: _move,
                          ),
                        ),
                  child: Text(_move ? 'Pindahkan' : 'Salin'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _collectionList(LibraryIndex library) {
    final collections = library.collections.values.toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return RadioGroup<String?>(
      groupValue: _collection,
      onChanged: (value) => setState(() => _collection = value),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          RadioListTile<String?>(
            dense: true,
            value: null,
            title: Text(widget.forCollection ? 'Akar library' : 'Tanpa koleksi'),
            subtitle: Text(library.library.name),
          ),
          for (final c in collections)
            RadioListTile<String?>(
              dense: true,
              value: c.key,
              title: Text(c.name),
              subtitle: c.path == c.name ? null : Text(c.path),
            ),
        ],
      ),
    );
  }
}

/// Ringkasan ukuran sebuah repositori, dihitung sekali di latar.
class RepoStatsLine extends ConsumerStatefulWidget {
  const RepoStatsLine({required this.profile, this.style, super.key});

  final RepoProfile profile;
  final TextStyle? style;

  @override
  ConsumerState<RepoStatsLine> createState() => _RepoStatsLineState();
}

class _RepoStatsLineState extends ConsumerState<RepoStatsLine> {
  late Future<RepoStats> _stats = _load();

  Future<RepoStats> _load() =>
      ref.read(workspaceControllerProvider.notifier).repoStats(widget.profile);

  @override
  void didUpdateWidget(RepoStatsLine old) {
    super.didUpdateWidget(old);
    if (old.profile.localPath != widget.profile.localPath) _stats = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RepoStats>(
    future: _stats,
    builder: (context, snapshot) => Text(
      snapshot.data?.summary ?? 'menghitung ukuran…',
      style: widget.style ?? Theme.of(context).textTheme.bodySmall,
    ),
  );
}
