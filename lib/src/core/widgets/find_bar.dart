import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';

/// Bilah "cari di dokumen" yang sama untuk PDF, EPUB, Word/PowerPoint, dan
/// tabel: kolom kata, jumlah hasil, sebelumnya/berikutnya, tutup.
///
/// Enter ke hasil berikutnya, Shift+Enter ke sebelumnya, Esc menutup —
/// seperti pencarian di peramban dan pembaca PDF lain, yang sudah dihafal
/// tangan.
class FindBar extends StatefulWidget {
  const FindBar({
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    this.current,
    this.total,
    this.searching = false,
    this.initialQuery = '',
    super.key,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  /// Hasil yang sedang disorot, mulai 1; null bila belum ada.
  final int? current;

  /// Jumlah hasil; null bila belum ada pencarian.
  final int? total;
  final bool searching;
  final String initialQuery;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  late final TextEditingController _text = TextEditingController(text: widget.initialQuery);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.selection = TextSelection(baseOffset: 0, extentOffset: _text.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        widget.onPrevious();
      } else {
        widget.onNext();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.total;
    final hasQuery = _text.text.trim().isNotEmpty;
    final String status;
    if (!hasQuery) {
      status = '';
    } else if (widget.searching && (total ?? 0) == 0) {
      status = context.l10n.findSearching;
    } else if (total == null) {
      status = '';
    } else if (total == 0) {
      status = context.l10n.findNoResults;
    } else {
      status = context.l10n.findCount(widget.current ?? 0, total);
    }
    final canStep = (total ?? 0) > 0;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: <Widget>[
            Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  key: const ValueKey<String>('find-field'),
                  controller: _text,
                  focusNode: _focus,
                  decoration: InputDecoration(
                    hintText: context.l10n.findHint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() {});
                    widget.onChanged(value);
                  },
                ),
              ),
            ),
            if (widget.searching)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: total == 0 && !widget.searching ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            IconButton(
              tooltip: context.l10n.findPrevious,
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: canStep ? widget.onPrevious : null,
            ),
            IconButton(
              tooltip: context.l10n.findNext,
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: canStep ? widget.onNext : null,
            ),
            IconButton(
              tooltip: context.l10n.findClose,
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}
