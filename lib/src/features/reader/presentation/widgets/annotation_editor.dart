import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatting.dart';

/// What the editor sheet asks the caller to do.
enum AnnotationEditorAction { save, delete }

class AnnotationEditorResult {
  const AnnotationEditorResult(this.action, {this.comment = '', this.color});

  final AnnotationEditorAction action;
  final String comment;
  final String? color;
}

/// Comment + color editor for one annotation.
///
/// Used both when creating a marker with a comment and when tapping an
/// existing one on the page.
Future<AnnotationEditorResult?> showAnnotationEditor(
  BuildContext context, {
  required String initialColor,
  String initialComment = '',
  String? quotedText,
  String title = 'Komentar',
  String fieldLabel = 'Komentar',
  String fieldHint = 'Catatan untuk bagian ini…',
  bool allowDelete = false,
}) => showDialog<AnnotationEditorResult>(
  context: context,
  builder: (_) => _AnnotationEditorDialog(
    initialColor: initialColor,
    initialComment: initialComment,
    quotedText: quotedText,
    title: title,
    fieldLabel: fieldLabel,
    fieldHint: fieldHint,
    allowDelete: allowDelete,
  ),
);

class _AnnotationEditorDialog extends StatefulWidget {
  const _AnnotationEditorDialog({
    required this.initialColor,
    required this.initialComment,
    required this.title,
    required this.fieldLabel,
    required this.fieldHint,
    required this.allowDelete,
    this.quotedText,
  });

  final String initialColor;
  final String initialComment;
  final String? quotedText;
  final String title;
  final String fieldLabel;
  final String fieldHint;
  final bool allowDelete;

  @override
  State<_AnnotationEditorDialog> createState() => _AnnotationEditorDialogState();
}

class _AnnotationEditorDialogState extends State<_AnnotationEditorDialog> {
  late final TextEditingController _comment = TextEditingController(text: widget.initialComment);
  late String _color = widget.initialColor;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The keyboard eats most of the screen on a tablet held in portrait, and
    // this dialog is used precisely when the keyboard is up. Without
    // scrolling, the buttons end up below the fold and the dialog cannot be
    // completed at all.
    final room = MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom;
    final cramped = room < 520;

    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if ((widget.quotedText ?? '').isNotEmpty) ...<Widget>[
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorFromHex(_color).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(widget.quotedText!, style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
              const SizedBox(height: 14),
            ],
            AnnotationColorPicker(
              selected: _color,
              onSelected: (value) => setState(() => _color = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _comment,
              autofocus: true,
              minLines: cramped ? 1 : 3,
              maxLines: cramped ? 3 : 6,
              decoration: InputDecoration(labelText: widget.fieldLabel, hintText: widget.fieldHint),
            ),
          ],
        ),
      ),
      // One Row rather than three loose actions: AlertDialog lays actions out
      // in an OverflowBar, which does not accept Expanded — a Spacer here
      // threw on every build and left the dialog an empty grey box.
      actions: <Widget>[
        Row(
          children: <Widget>[
            if (widget.allowDelete)
              TextButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pop(const AnnotationEditorResult(AnnotationEditorAction.delete)),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Hapus'),
              ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                AnnotationEditorResult(
                  AnnotationEditorAction.save,
                  comment: _comment.text,
                  color: _color,
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Row of Zotero's highlight colors.
class AnnotationColorPicker extends StatelessWidget {
  const AnnotationColorPicker({
    required this.selected,
    required this.onSelected,
    this.size = 26,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final double size;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: <Widget>[
      for (final hex in AnnotationPalette.all)
        Tooltip(
          message: AnnotationPalette.names[hex] ?? hex,
          child: InkWell(
            onTap: () => onSelected(hex),
            borderRadius: BorderRadius.circular(size),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colorFromHex(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hex == selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: hex == selected
                  ? const Icon(Icons.check, size: 14, color: Colors.black87)
                  : null,
            ),
          ),
        ),
    ],
  );
}
