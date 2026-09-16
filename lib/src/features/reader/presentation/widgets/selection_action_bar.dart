import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatting.dart';

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

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final hex in AnnotationPalette.all)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Tooltip(
                  message: AnnotationPalette.names[hex] ?? hex,
                  child: InkWell(
                    onTap: () => onColorChanged(hex),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: colorFromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hex == color ? scheme.onSurface : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const SizedBox(height: 26, child: VerticalDivider(width: 1)),
            const SizedBox(width: 6),
            _Action(
              icon: Icons.format_color_fill,
              label: 'Stabilo',
              onPressed: onHighlight,
            ),
            _Action(
              icon: Icons.format_underlined,
              label: 'Garis bawah',
              onPressed: onUnderline,
            ),
            _Action(
              icon: Icons.add_comment_outlined,
              label: 'Komentar',
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
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
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
