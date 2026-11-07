import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../domain/install_kind.dart';
import 'update_controller.dart';

/// Kunci navigator aplikasi, supaya kartu pembaruan (yang duduk di atas
/// Navigator) bisa membuka dialog.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Kartu kecil di pojok layar: ada versi baru, sedang mengunduh, siap dibuka
/// ulang, atau gagal. Dipasang sekali di atas seluruh aplikasi.
class UpdateOverlay extends ConsumerWidget {
  const UpdateOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateControllerProvider);
    if (!s.showsCard) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _UpdateCard(state: s),
          ),
        ),
      ),
    );
  }
}

class _UpdateCard extends ConsumerWidget {
  const _UpdateCard({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(updateControllerProvider.notifier);
    final theme = Theme.of(context);
    final version = state.release?.version ?? '';
    final (title, body) = switch (state.phase) {
      UpdatePhase.downloading => (
        l.updateAvailableTitle(version),
        l.updateDownloading('${(state.progress * 100).round()}'),
      ),
      UpdatePhase.installing => (l.updateAvailableTitle(version), l.updateInstalling),
      UpdatePhase.handedOff => (l.updateAvailableTitle(version), l.updateAndroidConfirm),
      UpdatePhase.ready => (l.updateReadyTitle(version), l.updateRestartHint),
      UpdatePhase.failed => (l.updateAvailableTitle(version), failureText(context, state)),
      _ => (
        l.updateAvailableTitle(version),
        state.kind.canInstall ? l.updateCurrent(state.current) : l.updateManualHint,
      ),
    };
    final busy = state.phase == UpdatePhase.downloading || state.phase == UpdatePhase.installing;
    final command = state.phase == UpdatePhase.failed ? state.error?.command : null;
    return Material(
      key: const ValueKey('kartu-pembaruan'),
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.system_update_alt, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                if (!busy && state.phase != UpdatePhase.ready)
                  IconButton(
                    tooltip: l.updateLater,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: c.dismiss,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(body, style: theme.textTheme.bodySmall),
            ),
            if (busy) ...<Widget>[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LinearProgressIndicator(
                  value: state.phase == UpdatePhase.downloading ? state.progress : null,
                ),
              ),
            ],
            if (command != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(l.updateRunYourself, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              SelectableText(
                command,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ],
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: <Widget>[
                  if (state.phase == UpdatePhase.available ||
                      state.phase == UpdatePhase.failed) ...[
                    if ((state.release?.notes ?? '').isNotEmpty)
                      TextButton(onPressed: () => _showNotes(state), child: Text(l.updateNotes)),
                    if (state.phase == UpdatePhase.available)
                      TextButton(onPressed: c.skip, child: Text(l.updateSkip)),
                    if (command != null)
                      TextButton(
                        onPressed: () => Clipboard.setData(ClipboardData(text: command)),
                        child: Text(l.updateCopyCommand),
                      ),
                    FilledButton(
                      onPressed: () => startUpdate(ref),
                      child: Text(
                        !state.kind.canInstall
                            ? l.updateOpenPage
                            : state.phase == UpdatePhase.failed
                            ? l.updateRetry
                            : l.updateNow,
                      ),
                    ),
                  ],
                  if (state.phase == UpdatePhase.handedOff)
                    TextButton(onPressed: () => startUpdate(ref), child: Text(l.updateRetry)),
                  if (state.phase == UpdatePhase.ready) ...<Widget>[
                    TextButton(onPressed: c.dismiss, child: Text(l.updateLater)),
                    FilledButton(onPressed: c.restart, child: Text(l.updateRestart)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotes(UpdateState s) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.updateAvailableTitle(s.release?.version ?? '')),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: SelectableText(s.release?.notes ?? '')),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// Pesan kegagalan yang bisa dibaca orang.
String failureText(BuildContext context, UpdateState s) {
  final l = context.l10n;
  final e = s.error;
  return switch (e?.message) {
    null => '',
    'izin' => l.updateAndroidPermission,
    'batal' => l.updateCancelled,
    'tanpa-root' => l.updateNoRoot,
    'tanpa-berkas' => l.updateNoAsset,
    _ => l.updateFailed(e!.message),
  };
}

/// "Perbarui": Windows ditanya dulu, karena ReadPaper harus ditutup.
Future<void> startUpdate(WidgetRef ref) async {
  final s = ref.read(updateControllerProvider);
  final c = ref.read(updateControllerProvider.notifier);
  if (s.kind == InstallKind.windowsSetup) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.updateWindowsConfirmTitle),
        content: Text(context.l10n.updateWindowsConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.updateLater),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.updateCloseAndUpdate),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  await c.update();
}

String installKindLabel(BuildContext context, InstallKind kind) {
  final l = context.l10n;
  return switch (kind) {
    InstallKind.androidApk => l.updateKindApk,
    InstallKind.windowsSetup => l.updateKindSetup,
    InstallKind.linuxTarball => l.updateKindTarball,
    InstallKind.linuxDeb => l.updateKindDeb,
    InstallKind.linuxArch => l.updateKindArch,
    InstallKind.manual => l.updateKindManual,
  };
}

/// Di Pengaturan, di bawah nomor versi: periksa sekarang, status, dan
/// sakelar pemberitahuan otomatis.
class UpdateSettingsRow extends ConsumerWidget {
  const UpdateSettingsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateControllerProvider);
    final c = ref.read(updateControllerProvider.notifier);
    final l = context.l10n;
    final theme = Theme.of(context);
    final small = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline);
    final status = switch (s.phase) {
      UpdatePhase.checking => l.updateChecking,
      UpdatePhase.upToDate => l.updateUpToDate(s.current),
      UpdatePhase.available => l.updateAvailableTitle(s.release!.version),
      UpdatePhase.ready => l.updateReadyTitle(s.release!.version),
      UpdatePhase.downloading => l.updateDownloading('${(s.progress * 100).round()}'),
      UpdatePhase.installing => l.updateInstalling,
      UpdatePhase.handedOff => l.updateAndroidConfirm,
      UpdatePhase.failed => failureText(context, s),
      UpdatePhase.idle => l.updateVia(installKindLabel(context, s.kind)),
    };
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: <Widget>[
        TextButton.icon(
          key: const ValueKey('periksa-pembaruan'),
          onPressed: s.phase == UpdatePhase.checking
              ? null
              : () async {
                  if (s.phase == UpdatePhase.available) {
                    await startUpdate(ref);
                  } else {
                    await c.check();
                  }
                },
          icon: const Icon(Icons.system_update_alt, size: 16),
          label: Text(s.phase == UpdatePhase.available ? l.updateNow : l.updateCheck),
        ),
        Text(status, style: small),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Checkbox(
              value: s.autoCheck,
              visualDensity: VisualDensity.compact,
              onChanged: (v) => c.setAutoCheck(v ?? true),
            ),
            Text(l.updateAuto, style: small),
          ],
        ),
      ],
    );
  }
}
