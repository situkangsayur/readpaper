import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/citation_server_controller.dart';
import '../../../../core/l10n.dart';
import '../../data/js_engine.dart';

/// Kartu "Sitasi di Word & OnlyOffice" di layar pengaturan.
///
/// Tempat satu-satunya orang melihat token yang harus ditempel ke add-in,
/// jadi alamat dan token selalu bisa disalin dari sini.
class CitationServerCard extends ConsumerStatefulWidget {
  const CitationServerCard({super.key});

  @override
  ConsumerState<CitationServerCard> createState() => _CitationServerCardState();
}

class _CitationServerCardState extends ConsumerState<CitationServerCard> {
  /// Token disamarkan sampai diminta: layar pengaturan sering terlihat di
  /// tangkapan layar dan rapat daring, dan token ini membuka seluruh library.
  bool _showToken = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(citationServerProvider);
    if (!status.available) return const SizedBox.shrink();
    final controller = ref.read(citationServerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.outline);

    final (IconData icon, Color color, String line) = switch (status) {
      CitationServerStatus(running: true) => (
        Icons.check_circle_outline,
        scheme.primary,
        context.l10n.citationRunningAt(status.address),
      ),
      CitationServerStatus(error: final String error) => (Icons.error_outline, scheme.error, error),
      CitationServerStatus(enabled: false) => (
        Icons.pause_circle_outline,
        scheme.outline,
        context.l10n.citationOff,
      ),
      _ => (Icons.hourglass_empty, scheme.outline, context.l10n.citationStarting),
    };

    final token = status.token;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.format_quote_outlined),
              title: Text(context.l10n.citationTitle),
              subtitle: Text(context.l10n.citationSubtitle),
              value: status.enabled,
              onChanged: controller.setEnabled,
            ),
            Row(
              children: <Widget>[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(line, style: theme.textTheme.bodySmall?.copyWith(color: color)),
                ),
                if (status.enabled && !status.running && status.error != null)
                  TextButton(onPressed: controller.retry, child: Text(context.l10n.citationRetry)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                SizedBox(width: 64, child: Text(context.l10n.citationAddress)),
                Expanded(child: SelectableText(status.address)),
                IconButton(
                  tooltip: context.l10n.citationCopyAddress,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy(status.address, context.l10n.citationAddressCopied),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const SizedBox(width: 64, child: Text('Token')),
                Expanded(
                  child: token == null
                      ? Text(context.l10n.citationNoToken, style: small)
                      : _showToken
                      ? SelectableText(token, style: const TextStyle(fontFamily: 'monospace'))
                      : Text('•' * 16, style: const TextStyle(fontFamily: 'monospace')),
                ),
                IconButton(
                  tooltip: _showToken
                      ? context.l10n.citationHideToken
                      : context.l10n.citationShowToken,
                  icon: Icon(
                    _showToken ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                  ),
                  onPressed: token == null ? null : () => setState(() => _showToken = !_showToken),
                ),
                IconButton(
                  tooltip: context.l10n.citationCopyToken,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: token == null
                      ? null
                      : () => _copy(token, context.l10n.citationTokenCopied),
                ),
                IconButton(
                  tooltip: context.l10n.citationNewToken,
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: token == null ? null : () => _confirmRegenerate(controller),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(context.l10n.citationPasteHint, style: small),
            const SizedBox(height: 4),
            Text(
              JsEngine.availableName == null
                  ? context.l10n.citationLibreOfficeMissing
                  : context.l10n.citationLibreOfficeReady(JsEngine.availableName!),
              style: small,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ditanya dulu karena tidak bisa dibatalkan: setiap add-in yang sudah
  /// tersambung harus diberi token baru satu per satu.
  Future<void> _confirmRegenerate(CitationServerController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.citationNewTokenTitle),
        content: Text(context.l10n.citationNewTokenBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.filesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.citationCreateNew),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.regenerateToken();
  }
}
