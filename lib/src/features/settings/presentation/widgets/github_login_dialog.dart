import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n.dart';
import '../../../sync/data/datasources/github_device_flow.dart';
import '../../data/datasources/settings_local_datasource.dart';

/// Hasil masuk ke GitHub: token, akun, dan repositori yang dipilih atau baru
/// dibuat.
class GitHubLoginResult {
  const GitHubLoginResult({required this.token, required this.account, required this.repo});

  final String token;
  final GitHubAccount account;
  final GitHubRepoInfo repo;
}

/// Pembuat layanan login; diganti oleh uji supaya tidak menghubungi GitHub.
GitHubDeviceFlow Function() createGitHubDeviceFlow = GitHubDeviceFlow.new;

/// Masuk ke GitHub dengan kode perangkat, lalu memilih atau membuat
/// repositori library — tanpa harus tahu apa itu token akses.
Future<GitHubLoginResult?> showGitHubLoginDialog(BuildContext context, {GitHubDeviceFlow? flow}) =>
    showDialog<GitHubLoginResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GitHubLoginDialog(flow: flow ?? createGitHubDeviceFlow()),
    );

class GitHubLoginDialog extends StatefulWidget {
  const GitHubLoginDialog({required this.flow, super.key});

  final GitHubDeviceFlow flow;

  @override
  State<GitHubLoginDialog> createState() => _GitHubLoginDialogState();
}

class _GitHubLoginDialogState extends State<GitHubLoginDialog> {
  DeviceCode? _code;
  String? _token;
  GitHubAccount? _account;
  List<GitHubRepoInfo>? _repos;
  String? _error;
  bool _busy = false;
  bool _closed = false;
  String _filter = '';
  final TextEditingController _newName = TextEditingController(text: 'zotero-library');
  bool _private = true;

  /// Akun yang pernah dipakai masuk (login → token). Null selagi dibaca;
  /// kosong berarti langsung ke kode perangkat.
  Map<String, String>? _known;
  bool _choosingAccount = false;
  static const SettingsLocalDataSource _store = SettingsLocalDataSource();

  @override
  void initState() {
    super.initState();
    _loadKnown();
  }

  Future<void> _loadKnown() async {
    final known = await _store.githubAccounts();
    if (!mounted) return;
    setState(() {
      _known = known;
      _choosingAccount = known.isNotEmpty;
    });
    if (known.isEmpty) await _begin();
  }

  /// Memakai akun yang sudah pernah masuk: tidak perlu kode lagi, langsung ke
  /// daftar repositori. Token yang sudah dicabut di GitHub dilupakan, lalu
  /// masuk ulang.
  Future<void> _useKnown(String login) async {
    final token = _known![login]!;
    setState(() {
      _choosingAccount = false;
      _error = null;
    });
    try {
      final account = await widget.flow.account(token);
      final repos = await widget.flow.repositories(token);
      if (!mounted) return;
      setState(() {
        _token = token;
        _account = account;
        _repos = repos;
      });
    } on Object {
      await _store.saveGitHubAccount(login: login, token: null);
      if (!mounted) return;
      await _begin();
    }
  }

  Future<void> _forget(String login) async {
    await _store.saveGitHubAccount(login: login, token: null);
    final known = await _store.githubAccounts();
    if (!mounted) return;
    setState(() {
      _known = known;
      _choosingAccount = known.isNotEmpty;
    });
    if (known.isEmpty) await _begin();
  }

  @override
  void dispose() {
    _closed = true;
    _newName.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() {
      _choosingAccount = false;
      _error = null;
      _code = null;
    });
    try {
      final code = await widget.flow.start();
      if (!mounted) return;
      setState(() => _code = code);
      // Kodenya sudah di papan klip: di halaman GitHub tinggal ditempel.
      await Clipboard.setData(ClipboardData(text: code.userCode));
      final token = await widget.flow.waitForToken(code, cancelled: () => _closed);
      final account = await widget.flow.account(token);
      // Diingat untuk profil berikutnya: repo lain di akun yang sama.
      await _store.saveGitHubAccount(login: account.login, token: token);
      final repos = await widget.flow.repositories(token);
      if (!mounted) return;
      setState(() {
        _token = token;
        _account = account;
        _repos = repos;
      });
    } on GitHubLoginCancelled {
      return;
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _openGitHub() async {
    final uri = Uri.parse(_code?.verificationUri ?? 'https://github.com/login/device');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _choose(GitHubRepoInfo repo) =>
      Navigator.of(context).pop(GitHubLoginResult(token: _token!, account: _account!, repo: repo));

  Future<void> _create() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = await widget.flow.createRepository(_token!, name: name, private: _private);
      if (!mounted) return;
      _choose(repo);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return AlertDialog(
      title: Text(t.githubLoginTitle),
      content: SizedBox(width: 480, child: _content(context)),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            _closed = true;
            Navigator.of(context).pop();
          },
          child: Text(t.githubLoginCancel),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final error = _error;
    if (_repos != null) return _pickRepo(context);
    if (_known == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_choosingAccount) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(t.githubLoginChooseAccount),
          const SizedBox(height: 8),
          for (final login in _known!.keys)
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(t.githubLoginUseAccount(login)),
              trailing: IconButton(
                tooltip: t.githubLoginForgetAccount,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _forget(login),
              ),
              onTap: () => _useKnown(login),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: Text(t.githubLoginOtherAccount),
              onPressed: _begin,
            ),
          ),
        ],
      );
    }
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(onPressed: _begin, child: Text(t.githubLoginRetry)),
          ),
        ],
      );
    }
    final code = _code;
    if (code == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(t.githubLoginStep1),
        const SizedBox(height: 12),
        Center(
          child: SelectableText(
            code.userCode,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: Text(t.githubLoginCopyCode),
            onPressed: () => Clipboard.setData(ClipboardData(text: code.userCode)),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_browser),
          label: Text(t.githubLoginOpen),
          onPressed: _openGitHub,
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(t.githubLoginWaiting, style: theme.textTheme.bodySmall)),
          ],
        ),
      ],
    );
  }

  Widget _pickRepo(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final repos = _repos!
        .where((r) => r.fullName.toLowerCase().contains(_filter.toLowerCase()))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(t.githubLoginSignedIn(_account!.login), style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Text(t.githubLoginChooseRepo),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: t.githubLoginSearchRepo,
            isDense: true,
          ),
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: repos.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(t.githubLoginNoRepos, style: theme.textTheme.bodySmall),
                )
              : ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final repo in repos)
                      ListTile(
                        dense: true,
                        leading: Icon(repo.private ? Icons.lock_outline : Icons.public, size: 18),
                        title: Text(repo.fullName),
                        onTap: _busy ? null : () => _choose(repo),
                      ),
                  ],
                ),
        ),
        const Divider(height: 24),
        Text(t.githubLoginCreateTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(t.githubLoginCreateHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        TextField(
          controller: _newName,
          decoration: InputDecoration(labelText: t.githubLoginRepoName, isDense: true),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.githubLoginPrivate),
          value: _private,
          onChanged: (value) => setState(() => _private = value),
        ),
        if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(t.githubLoginCreate),
            onPressed: _busy ? null : _create,
          ),
        ),
      ],
    );
  }
}
