import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/citation_server_controller.dart';

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
        'Berjalan di ${status.address}',
      ),
      CitationServerStatus(error: final String error) => (Icons.error_outline, scheme.error, error),
      CitationServerStatus(enabled: false) => (
        Icons.pause_circle_outline,
        scheme.outline,
        'Mati. Add-in Word dan OnlyOffice tidak bisa tersambung.',
      ),
      _ => (Icons.hourglass_empty, scheme.outline, 'Menyalakan…'),
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
              title: const Text('Sitasi di Word & OnlyOffice'),
              subtitle: const Text('Server lokal yang dipakai add-in untuk mencari dan menyitasi.'),
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
                  TextButton(onPressed: controller.retry, child: const Text('Coba lagi')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const SizedBox(width: 64, child: Text('Alamat')),
                Expanded(child: SelectableText(status.address)),
                IconButton(
                  tooltip: 'Salin alamat',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy(status.address, 'Alamat disalin.'),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const SizedBox(width: 64, child: Text('Token')),
                Expanded(
                  child: token == null
                      ? Text('Belum ada', style: small)
                      : _showToken
                      ? SelectableText(token, style: const TextStyle(fontFamily: 'monospace'))
                      : Text('•' * 16, style: const TextStyle(fontFamily: 'monospace')),
                ),
                IconButton(
                  tooltip: _showToken ? 'Sembunyikan token' : 'Tampilkan token',
                  icon: Icon(
                    _showToken ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                  ),
                  onPressed: token == null ? null : () => setState(() => _showToken = !_showToken),
                ),
                IconButton(
                  tooltip: 'Salin token',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: token == null ? null : () => _copy(token, 'Token disalin.'),
                ),
                IconButton(
                  tooltip: 'Buat token baru',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: token == null ? null : () => _confirmRegenerate(controller),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tempel alamat dan token ini di add-in. Panduannya: docs/api-sitasi.md '
              'di repositori ReadPaper.',
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
        title: const Text('Buat token baru?'),
        content: const Text(
          'Token lama langsung tidak berlaku. Add-in Word dan OnlyOffice yang '
          'sudah tersambung harus diberi token baru.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Buat baru'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.regenerateToken();
  }
}
