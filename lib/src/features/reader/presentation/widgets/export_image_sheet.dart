import 'package:flutter/material.dart';

import '../../domain/page_image_export.dart';
import '../../../../core/l10n.dart';

/// What the user chose in the export sheet.
class ExportImageChoice {
  const ExportImageChoice({required this.format, required this.scale, required this.wholeDocument});

  final PageImageFormat format;
  final double scale;

  /// False exports the page on screen, true every page of the document.
  final bool wholeDocument;
}

/// Asks what to save the page as, before doing any rendering.
///
/// Rendering a 400-page paper at 288 dpi is a minute of work and a few hundred
/// megabytes, so the choice is made first rather than guessed.
Future<ExportImageChoice?> showExportImageSheet(
  BuildContext context, {
  required int currentPage,
  required int pageCount,
}) => showModalBottomSheet<ExportImageChoice>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => _ExportSheet(currentPage: currentPage, pageCount: pageCount),
);

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.currentPage, required this.pageCount});

  final int currentPage;
  final int pageCount;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  PageImageFormat _format = PageImageFormat.png;
  double _scale = 2;
  bool _whole = false;

  List<({double scale, String label})> get _scales => <({double scale, String label})>[
    (scale: 1, label: context.l10n.readerDpiScreen),
    (scale: 2, label: context.l10n.readerDpiGood),
    (scale: 4, label: context.l10n.readerDpiPrint),
  ];

  String get _subtitle {
    if (!_whole) return context.l10n.readerOnlyPage(widget.currentPage);
    return _format == PageImageFormat.pdf
        ? context.l10n.readerOnePdfPages(widget.pageCount)
        : context.l10n.readerFilesOnePerPage(widget.pageCount);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.l10n.readerSaveAnnotatedCopy, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(context.l10n.readerExportExplain, style: text.bodySmall),
            const SizedBox(height: 16),

            Text(context.l10n.readerFormat, style: text.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<PageImageFormat>(
              segments: <ButtonSegment<PageImageFormat>>[
                for (final f in PageImageFormat.values)
                  ButtonSegment<PageImageFormat>(value: f, label: Text(f.label)),
              ],
              selected: <PageImageFormat>{_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 16),

            Text(context.l10n.readerDensity, style: text.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<double>(
              segments: <ButtonSegment<double>>[
                for (final entry in _scales)
                  ButtonSegment<double>(value: entry.scale, label: Text(entry.label)),
              ],
              selected: <double>{_scale},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _scale = s.first),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _whole,
              onChanged: widget.pageCount > 1 ? (v) => setState(() => _whole = v) : null,
              title: Text(context.l10n.readerWholeDocument),
              subtitle: Text(_subtitle),
            ),

            if (_format == PageImageFormat.pdf)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(context.l10n.readerExportPdfImages, style: text.bodySmall),
              ),

            if (_whole && widget.pageCount > 40)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context.l10n.readerExportLarge(widget.pageCount),
                  style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.readerCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(ExportImageChoice(format: _format, scale: _scale, wholeDocument: _whole)),
                  child: Text(context.l10n.readerSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
