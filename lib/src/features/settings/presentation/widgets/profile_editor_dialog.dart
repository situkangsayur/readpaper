import 'dart:io';

import '../../../../core/utils/file_pick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'github_login_dialog.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_paths.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../sync/domain/entities/git_entities.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/entities/repo_profile.dart';
import '../../../../core/l10n.dart';

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
  late bool _lazyAttachments;
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
    _lazyAttachments = existing?.lazyAttachments ?? true;
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

  /// Mengisi profil dari login GitHub: alamat HTTPS repositorinya, nama
  /// pengguna dan token, branch bawaan, serta nama dan surel penulis commit.
  Future<void> _signInWithGitHub() async {
    final result = await showGitHubLoginDialog(context);
    if (result == null || !mounted) return;
    setState(() {
      _remote.text = result.repo.cloneUrl;
      _transport = GitTransport.https;
      _httpsUser.text = result.account.login;
      _token.text = result.token;
      _branch.text = result.repo.defaultBranch;
      if (!_nameEdited) _name.text = result.repo.name;
      if (_authorName.text.trim().isEmpty) _authorName.text = result.account.name;
      if (_authorEmail.text.trim().isEmpty) _authorEmail.text = result.account.email;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l10n.githubLoginDone(result.account.login, result.repo.fullName)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Android mirrors through the GitHub API, which can only authenticate with
    // a token — SSH is simply not on offer there.
    final supported = ref.watch(gitBackendProvider).supportedTransports;
    if (!supported.contains(_transport)) _transport = supported.first;
    final isSsh = _transport == GitTransport.ssh;
    // On a phone the mirror lives in the app's private storage; letting the
    // user pick a folder there would only offer paths dart:io cannot write to.
    final canChooseFolder = !Platform.isAndroid && !Platform.isIOS;

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? context.l10n.settingsAddRepository
            : context.l10n.settingsEditRepository,
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Jalan termudah: masuk lewat browser, pilih atau buat
                // repositorinya — tanpa tahu apa itu token akses.
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.login),
                  label: Text(context.l10n.githubLoginButton),
                  onPressed: _signInWithGitHub,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.githubLoginButtonHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _remote,
                  decoration: InputDecoration(
                    labelText: context.l10n.settingsRepoUrl,
                    hintText: 'git@github.com:situkangsayur/zotero-hendri.git',
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? context.l10n.settingsUrlRequired : null,
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
                      context.l10n.settingsApiTokenNote,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  onChanged: (_) => _nameEdited = true,
                  decoration: InputDecoration(labelText: context.l10n.settingsDisplayName),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? context.l10n.settingsNameRequired : null,
                ),
                const SizedBox(height: 12),
                if (isSsh)
                  _PathField(
                    controller: _sshKey,
                    label: context.l10n.settingsSshKeyOptional,
                    hint: '${Platform.environment['HOME']}/.ssh/id_ed25519',
                    helper: context.l10n.settingsSshKeyHelper,
                    onPick: _pickSshKey,
                  )
                else ...<Widget>[
                  TextFormField(
                    controller: _httpsUser,
                    decoration: InputDecoration(
                      labelText: context.l10n.settingsGithubUsername,
                      hintText: 'situkangsayur',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _token,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.settingsAccessToken,
                      helperText: context.l10n.settingsTokenHelper,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (canChooseFolder)
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
                          label: context.l10n.settingsLocalCloneFolder,
                          hint: '',
                          onChanged: () => _localPathEdited = true,
                          onPick: _pickDirectory,
                        ),
                      ),
                    ],
                  )
                else
                  TextFormField(
                    controller: _branch,
                    decoration: InputDecoration(
                      labelText: 'Branch',
                      helperText: context.l10n.settingsPrivateStorage,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.settingsCommitIdentity,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _authorName,
                        decoration: InputDecoration(
                          labelText: context.l10n.settingsNameLabel,
                          hintText: context.l10n.settingsAuthorHint,
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
                  value: _lazyAttachments,
                  title: Text(context.l10n.settingsLazyPdfTitle),
                  subtitle: Text(context.l10n.settingsLazyPdfSubtitle),
                  // Di Android juga: mirror-nya mengunduh semua PDF sesudah
                  // ambil dan pull bila pilihan ini dimatikan.
                  onChanged: (value) => setState(() => _lazyAttachments = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoPush,
                  title: Text(context.l10n.settingsAutoPushTitle),
                  subtitle: Text(context.l10n.settingsAutoPushSubtitle),
                  onChanged: (value) => setState(() => _autoPush = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.filesCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.filesSave)),
      ],
    );
  }

  Future<void> _pickSshKey() async {
    final files = await pickFilesOrTell(
      context,
      title: context.l10n.settingsPickSshKey,
      multiple: false,
    );
    final path = files.firstOrNull;
    if (path != null && mounted) setState(() => _sshKey.text = path);
  }

  Future<void> _pickDirectory() async {
    final path = await pickDirectoryOrTell(context, title: context.l10n.settingsPickCloneFolder);
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
      lazyAttachments: _lazyAttachments,
      preferredLibraryDir: existing?.preferredLibraryDir,
      lastSyncedAt: existing?.lastSyncedAt,
    );

    Navigator.of(context).pop(
      ProfileEditorResult(profile, _transport == GitTransport.https ? _token.text.trim() : null),
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
