import 'package:flutter/material.dart';

import '../../../../core/utils/formatting.dart';
import '../../../library/domain/entities/zotero_annotation.dart';

/// The list of markers and comments next to the page view.
class AnnotationSidebar extends StatelessWidget {
  const AnnotationSidebar({
    required this.annotations,
    required this.selectedKey,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<ZoteroAnnotation> annotations;
  final String? selectedKey;
  final ValueChanged<ZoteroAnnotation> onTap;
  final ValueChanged<ZoteroAnnotation> onEdit;
  final ValueChanged<ZoteroAnnotation> onDelete;

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Belum ada anotasi.\n\nPilih teks pada halaman, lalu pilih Stabilo '
            'atau Stabilo + komentar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: annotations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final annotation = annotations[i];
        return _AnnotationCard(
          annotation: annotation,
          selected: annotation.key == selectedKey,
          onTap: () => onTap(annotation),
          onEdit: () => onEdit(annotation),
          onDelete: () => onDelete(annotation),
        );
      },
    );
  }
}

class _AnnotationCard extends StatelessWidget {
  const _AnnotationCard({
    required this.annotation,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ZoteroAnnotation annotation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = colorFromHex(annotation.color);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(_iconFor(annotation.type), size: 12, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'hal. ${annotation.pageLabel.isEmpty ? annotation.pageNumber : annotation.pageLabel}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  if (annotation.text.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      annotation.text.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
                    ),
                  ],
                  if (annotation.hasComment) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        annotation.comment.trim(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: <Widget>[
                IconButton(
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Ubah komentar / warna',
                  icon: const Icon(Icons.edit_note),
                  onPressed: onEdit,
                ),
                IconButton(
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AnnotationType type) => switch (type) {
    AnnotationType.highlight => Icons.format_color_fill,
    AnnotationType.underline => Icons.format_underlined,
    AnnotationType.note || AnnotationType.text => Icons.sticky_note_2_outlined,
    AnnotationType.image => Icons.image_outlined,
    AnnotationType.ink => Icons.draw_outlined,
  };
}
