import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

/// Where the reader should jump to.
@immutable
class NavigationTarget {
  const NavigationTarget.page(int this.pageNumber) : dest = null;
  const NavigationTarget.dest(PdfDest this.dest) : pageNumber = null;

  final int? pageNumber;

  /// A destination from the document's own outline, which carries a position
  /// on the page as well as the page itself.
  final PdfDest? dest;
}

/// Jump to a page, or to a heading in the document's table of contents.
///
/// Papers are read out of order — a result sends you to a method section
/// forty pages back and then to the figure you were looking at. Scrolling
/// there is the slow way.
Future<NavigationTarget?> showNavigationSheet(
  BuildContext context, {
  required int currentPage,
  required int pageCount,
  required List<PdfOutlineNode> outline,
}) => showModalBottomSheet<NavigationTarget>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) =>
      _NavigationSheet(currentPage: currentPage, pageCount: pageCount, outline: outline),
);

class _NavigationSheet extends StatefulWidget {
  const _NavigationSheet({
    required this.currentPage,
    required this.pageCount,
    required this.outline,
  });

  final int currentPage;
  final int pageCount;
  final List<PdfOutlineNode> outline;

  @override
  State<_NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends State<_NavigationSheet> {
  late final TextEditingController _field = TextEditingController(text: '${widget.currentPage}');
  late double _slider = widget.currentPage.toDouble();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _goToTyped() {
    final n = int.tryParse(_field.text.trim());
    if (n == null || n < 1 || n > widget.pageCount) {
      // Saying which range is valid beats clearing the field silently.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Halaman harus antara 1 dan ${widget.pageCount}')));
      return;
    }
    Navigator.of(context).pop(NavigationTarget.page(n));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Lompat ke halaman', style: text.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _field,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.go,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            labelText: 'Halaman',
                          ),
                          onSubmitted: (_) => _goToTyped(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('dari ${widget.pageCount}', style: text.bodyMedium),
                      const Spacer(),
                      FilledButton(onPressed: _goToTyped, child: const Text('Pergi')),
                    ],
                  ),
                  if (widget.pageCount > 1)
                    Slider(
                      value: _slider.clamp(1, widget.pageCount.toDouble()),
                      min: 1,
                      max: widget.pageCount.toDouble(),
                      divisions: widget.pageCount > 1 ? widget.pageCount - 1 : null,
                      label: '${_slider.round()}',
                      onChanged: (v) => setState(() {
                        _slider = v;
                        _field.text = '${v.round()}';
                      }),
                      onChangeEnd: (v) =>
                          Navigator.of(context).pop(NavigationTarget.page(v.round())),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('Daftar isi', style: text.titleMedium),
            ),
            Flexible(
              child: widget.outline.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Text('Berkas ini tidak membawa daftar isi.', style: text.bodySmall),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: <Widget>[
                        for (final node in widget.outline) _OutlineTile(node: node, depth: 0),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineTile extends StatelessWidget {
  const _OutlineTile({required this.node, required this.depth});

  final PdfOutlineNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      node.title.trim().isEmpty ? '(tanpa judul)' : node.title.trim(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    // Indent by depth rather than nesting widgets, so a deep outline does not
    // squeeze the title into a column two words wide.
    final padding = EdgeInsets.only(left: 20.0 + depth * 14, right: 12);

    if (node.children.isEmpty) {
      return ListTile(
        dense: true,
        contentPadding: padding,
        title: title,
        trailing: node.dest == null
            ? null
            : Text('${node.dest!.pageNumber}', style: Theme.of(context).textTheme.labelSmall),
        onTap: node.dest == null
            ? null
            : () => Navigator.of(context).pop(NavigationTarget.dest(node.dest!)),
      );
    }

    return ExpansionTile(
      dense: true,
      initiallyExpanded: depth == 0,
      tilePadding: padding,
      childrenPadding: EdgeInsets.zero,
      title: title,
      // The heading itself is a destination too; tapping the row expands it,
      // so its own page gets a button of its own.
      trailing: node.dest == null
          ? null
          : IconButton(
              iconSize: 18,
              tooltip: 'Buka halaman ${node.dest!.pageNumber}',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => Navigator.of(context).pop(NavigationTarget.dest(node.dest!)),
            ),
      children: <Widget>[
        for (final child in node.children) _OutlineTile(node: child, depth: depth + 1),
      ],
    );
  }
}
