import 'package:flutter/material.dart';

import '../../domain/page_image_export.dart';

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

  static const List<({double scale, String label})> _scales = <({double scale, String label})>[
    (scale: 1, label: 'Layar (72 dpi)'),
    (scale: 2, label: 'Baik (144 dpi)'),
    (scale: 4, label: 'Cetak (288 dpi)'),
  ];

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
            Text('Simpan halaman sebagai gambar', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('Stabilo, garis bawah, dan coretan ikut tergambar.', style: text.bodySmall),
            const SizedBox(height: 16),

            Text('Format', style: text.labelLarge),
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

            Text('Kerapatan', style: text.labelLarge),
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
              title: const Text('Seluruh dokumen'),
              subtitle: Text(
                _whole
                    ? '${widget.pageCount} berkas, satu per halaman'
                    : 'Hanya halaman ${widget.currentPage}',
              ),
            ),

            if (_whole && widget.pageCount > 40)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${widget.pageCount} halaman pada kerapatan ini akan makan waktu dan '
                  'ruang penyimpanan yang tidak sedikit.',
                  style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(ExportImageChoice(format: _format, scale: _scale, wholeDocument: _whole)),
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
