import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/utils/layout_size.dart';

/// Floating bar shown while text is selected in the reader.
///
/// The PDF viewer's own context menu only appears on right-click (and is
/// suppressed for documents that forbid copying), so the marker actions live
/// here where they are always reachable.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    required this.color,
    required this.onColorChanged,
    required this.onHighlight,
    required this.onUnderline,
    required this.onComment,
    required this.onDismiss,
    super.key,
  });

  final String color;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onHighlight;
  final VoidCallback onUnderline;
  final VoidCallback onComment;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A 22dp circle is an easy click and a hard tap.
    final swatch = isTouchPlatform ? 32.0 : 22.0;

    // Twelve swatches beside three labelled buttons overflow a phone, so the
    // colours scroll sideways and the actions drop their labels when space
    // runs short.
    final available = MediaQuery.sizeOf(context).width - 24;
    final compact = available < 620;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      color: scheme.surfaceContainerHighest,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: available),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final hex in AnnotationPalette.all)
                        _Swatch(
                          hex: hex,
                          size: swatch,
                          selected: hex == color,
                          onTap: () => onColorChanged(hex),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(height: swatch + 4, child: const VerticalDivider(width: 1)),
              const SizedBox(width: 6),
              _Action(
                icon: Icons.format_color_fill,
                label: 'Stabilo',
                compact: compact,
                onPressed: onHighlight,
              ),
              _Action(
                icon: Icons.format_underlined,
                label: 'Garis bawah',
                compact: compact,
                onPressed: onUnderline,
              ),
              _Action(
                icon: Icons.add_comment_outlined,
                label: 'Komentar',
                compact: compact,
                onPressed: onComment,
              ),
              IconButton(
                iconSize: 18,
                tooltip: 'Batalkan pilihan',
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.hex,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = AnnotationPalette.names[hex] ?? hex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        // Zotero only knows its own eight; the rest still round-trip, but it
        // shows them as a custom colour rather than one of its buttons.
        message: AnnotationPalette.isZoteroPreset(hex) ? name : '$name (di luar palet Zotero)',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colorFromHex(hex),
              shape: BoxShape.circle,
              border: Border.all(color: selected ? scheme.onSurface : Colors.transparent, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Drop the label and keep the icon when the bar has to fit a phone.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(tooltip: label, iconSize: 20, icon: Icon(icon), onPressed: onPressed);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
