import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_paths.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../sync/domain/entities/git_entities.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/entities/repo_profile.dart';

/// Result of the editor: the profile plus the token to store separately.
class ProfileEditorResult {
  const ProfileEditorResult(this.profile, this.token);

  final RepoProfile profile;
  final String? token;
}

/// Creates or edits a repository profile.
Future<void> showProfileEditor(BuildContext context, WidgetRef ref, {RepoProfile? existing}) async {
  final token = existing == null
      ? null
      : await ref.read(settingsRepositoryProvider).tokenFor(existing.id);
  if (!context.mounted) return;

  final result = await showDialog<ProfileEditorResult>(
    context: context,
    builder: (_) => ProfileEditorDialog(existing: existing, existingToken: token),
  );
  if (result == null) return;
  await ref
      .read(workspaceControllerProvider.notifier)
      .saveProfile(result.profile, httpsToken: result.token);
}

class ProfileEditorDialog extends ConsumerStatefulWidget {
  const ProfileEditorDialog({super.key, this.existing, this.existingToken});

  final RepoProfile? existing;
  final String? existingToken;

  @override
  ConsumerState<ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends ConsumerState<ProfileEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _remote;
  late final TextEditingController _branch;
  late final TextEditingController _localPath;
  late final TextEditingController _sshKey;
  late final TextEditingController _httpsUser;
  late final TextEditingController _token;
  late final TextEditingController _authorName;
  late final TextEditingController _authorEmail;

  late GitTransport _transport;
  late bool _autoPush;
  bool _localPathEdited = false;
  bool _nameEdited = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _remote = TextEditingController(text: existing?.remoteUrl ?? '');
    _branch = TextEditingController(text: existing?.branch ?? AppConstants.defaultBranch);
    _localPath = TextEditingController(text: existing?.localPath ?? '');
    _sshKey = TextEditingController(text: existing?.sshKeyPath ?? '');
    _httpsUser = TextEditingController(text: existing?.httpsUsername ?? '');
    _token = TextEditingController(text: widget.existingToken ?? '');
    _authorName = TextEditingController(text: existing?.authorName ?? '');
    _authorEmail = TextEditingController(text: existing?.authorEmail ?? '');
    _transport = existing?.transport ?? GitTransport.ssh;
    _autoPush = existing?.autoPushOnSave ?? false;
    _localPathEdited = existing != null;
    _nameEdited = existing != null;

    _remote.addListener(_syncDerivedFields);
  }

  @override
  void dispose() {
    _remote.removeListener(_syncDerivedFields);
    for (final controller in <TextEditingController>[
      _name,
      _remote,
      _branch,
      _localPath,
      _sshKey,
      _httpsUser,
      _token,
      _authorName,
      _authorEmail,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Keeps name/clone path/transport in step with the typed remote URL.
  void _syncDerivedFields() {
    final url = _remote.text.trim();
    if (url.isEmpty) return;

    final looksSsh = url.startsWith('git@') || url.startsWith('ssh://');
    final detected = looksSsh ? GitTransport.ssh : GitTransport.https;
    final slug = slugFromRemote(url);

    final supported = ref.read(gitBackendProvider).supportedTransports;
    setState(() {
      if (supported.contains(detected) &&
          (url.startsWith('git@') || url.startsWith('ssh://') || url.startsWith('http'))) {
        _transport = detected;
      }
      if (!_localPathEdited) {
        _localPath.text = AppPaths.instance.defaultClonePath(slug);
      }
      // Keep following the URL until the user types their own name; checking
      // for an empty field instead would freeze the name on the first
      // keystroke of the URL.
      if (!_nameEdited) {
        _name.text = slug == 'repo' ? '' : slug;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Android mirrors through the GitHub API, which can only authenticate with
    // a token — SSH is simply not on offer there.
    final supported = ref.watch(gitBackendProvider).supportedTransports;
    if (!supported.contains(_transport)) _transport = supported.first;
    final isSsh = _transport == GitTransport.ssh;

    return AlertDialog(
      title: Text(widget.existing == null ? 'Tambah repositori' : 'Ubah repositori'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _remote,
                  decoration: const InputDecoration(
                    labelText: 'URL repositori',
                    hintText: 'git@github.com:situkangsayur/zotero-hendri.git',
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'URL tidak boleh kosong' : null,
                ),
                const SizedBox(height: 12),
                if (supported.length > 1)
                  SegmentedButton<GitTransport>(
                    segments: const <ButtonSegment<GitTransport>>[
                      ButtonSegment<GitTransport>(
                        value: GitTransport.ssh,
                        label: Text('SSH'),
                        icon: Icon(Icons.vpn_key_outlined, size: 16),
                      ),
                      ButtonSegment<GitTransport>(
                        value: GitTransport.https,
                        label: Text('HTTPS'),
                        icon: Icon(Icons.lock_outline, size: 16),
                      ),
                    ],
                    selected: <GitTransport>{_transport},
                    onSelectionChanged: (values) => setState(() => _transport = values.first),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Perangkat ini menyinkronkan lewat GitHub API, jadi aksesnya '
                      'memakai token HTTPS.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  onChanged: (_) => _nameEdited = true,
                  decoration: const InputDecoration(labelText: 'Nama tampilan'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Nama tidak boleh kosong' : null,
                ),
                const SizedBox(height: 12),
                if (isSsh)
                  _PathField(
                    controller: _sshKey,
                    label: 'Kunci privat SSH (opsional)',
                    hint: '${Platform.environment['HOME']}/.ssh/id_ed25519',
                    helper: 'Kosongkan untuk memakai ssh-agent atau kunci bawaan.',
                    onPick: _pickSshKey,
                  )
                else ...<Widget>[
                  TextFormField(
                    controller: _httpsUser,
                    decoration: const InputDecoration(
                      labelText: 'Username GitHub',
                      hintText: 'situkangsayur',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _token,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Personal access token',
                      helperText: 'Disimpan terpisah di credentials.json (izin 600).',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _branch,
                        decoration: const InputDecoration(labelText: 'Branch'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _PathField(
                        controller: _localPath,
                        label: 'Folder clone lokal',
                        hint: '',
                        onChanged: () => _localPathEdited = true,
                        onPick: _pickDirectory,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Identitas commit', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _authorName,
                        decoration: const InputDecoration(
                          labelText: 'Nama',
                          hintText: 'kosong = pakai konfigurasi git',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _authorEmail,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoPush,
                  title: const Text('Push otomatis setelah menyimpan anotasi'),
                  subtitle: const Text('Setiap highlight/komentar langsung dikirim ke GitHub.'),
                  onChanged: (value) => setState(() => _autoPush = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }

  Future<void> _pickSshKey() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Pilih kunci privat SSH');
    final path = files.isEmpty ? null : files.first.path;
    if (path != null && mounted) setState(() => _sshKey.text = path);
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Pilih folder clone');
    if (path != null && mounted) {
      setState(() {
        _localPath.text = path;
        _localPathEdited = true;
      });
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.existing;
    final remote = _remote.text.trim();
    final localPath = _localPath.text.trim().isEmpty
        ? AppPaths.instance.defaultClonePath(slugFromRemote(remote))
        : _localPath.text.trim();

    final profile = RepoProfile(
      id: existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      remoteUrl: remote,
      localPath: localPath,
      transport: _transport,
      branch: _branch.text.trim().isEmpty ? AppConstants.defaultBranch : _branch.text.trim(),
      sshKeyPath: _transport == GitTransport.ssh && _sshKey.text.trim().isNotEmpty
          ? _sshKey.text.trim()
          : null,
      httpsUsername: _transport == GitTransport.https ? _httpsUser.text.trim() : null,
      authorName: _authorName.text.trim(),
      authorEmail: _authorEmail.text.trim(),
      autoPushOnSave: _autoPush,
      preferredLibraryDir: existing?.preferredLibraryDir,
      lastSyncedAt: existing?.lastSyncedAt,
    );

    Navigator.of(context).pop(
      ProfileEditorResult(
        profile,
        _transport == GitTransport.https ? _token.text.trim() : null,
      ),
    );
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onPick,
    this.helper,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final VoidCallback onPick;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    onChanged: (_) => onChanged?.call(),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      suffixIcon: IconButton(
        tooltip: 'Telusuri',
        icon: const Icon(Icons.folder_open_outlined, size: 18),
        onPressed: onPick,
      ),
    ),
  );
}
