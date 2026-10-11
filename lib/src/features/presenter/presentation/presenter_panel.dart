import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/l10n.dart';
import '../../library/domain/entities/zotero_annotation.dart';
import '../../reader/presentation/widgets/annotation_overlay_painter.dart';

/// Sisi presenter selama layar audiens tersambung: slide berikutnya,
/// catatan presenter untuk slide ini, dan waktu yang sudah berjalan.
///
/// Slide yang sedang tampil tetap di penampil utama di sebelahnya — di sana
/// pula semua alat coret bekerja — jadi panel ini hanya berisi yang tidak
/// boleh terlihat audiens.
class PresenterPanel extends StatefulWidget {
  const PresenterPanel({
    required this.document,
    required this.currentPage,
    required this.nextAnnotations,
    required this.pictures,
    required this.notes,
    required this.onNotesChanged,
    required this.blank,
    required this.onToggleBlank,
    required this.onHide,
    required this.onCloseAudience,
    required this.onNext,
    super.key,
  });

  final PdfDocument? document;
  final int currentPage;

  /// Anotasi slide berikutnya, supaya pratinjaunya sama dengan yang akan
  /// tampil.
  final List<ZoteroAnnotation> nextAnnotations;
  final Map<String, ui.Image> pictures;

  /// Catatan presenter untuk [currentPage].
  final String notes;
  final ValueChanged<String> onNotesChanged;

  final bool blank;
  final VoidCallback onToggleBlank;

  /// Menyembunyikan panel ini: slide sekarang memenuhi layar presenter.
  final VoidCallback onHide;
  final VoidCallback onCloseAudience;
  final VoidCallback onNext;

  @override
  State<PresenterPanel> createState() => _PresenterPanelState();
}

class _PresenterPanelState extends State<PresenterPanel> {
  late final TextEditingController _notes = TextEditingController(text: widget.notes);
  final Stopwatch _clock = Stopwatch()..start();
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });

  @override
  void didUpdateWidget(PresenterPanel old) {
    super.didUpdateWidget(old);
    // Berganti slide, atau catatannya baru selesai dibaca dari berkas. Yang
    // sedang diketik sudah sama dengan [PresenterPanel.notes], jadi tidak
    // ikut tertimpa.
    if (_notes.text != widget.notes) _notes.text = widget.notes;
  }

  @override
  void dispose() {
    _tick.cancel();
    _notes.dispose();
    super.dispose();
  }

  String get _elapsed {
    final d = _clock.elapsed;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0
        ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final document = widget.document;
    final pageCount = document?.pages.length ?? 0;
    final next = widget.currentPage + 1;
    final hasNext = document != null && next <= pageCount;

    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.connected_tv, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.presenterSlideOf(widget.currentPage, pageCount),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Tooltip(
                    message: l10n.presenterResetTimer,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _clock.reset()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          _elapsed,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(l10n.presenterNextSlide, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              AspectRatio(
                aspectRatio: 16 / 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: !hasNext
                      ? Center(
                          child: Text(
                            l10n.presenterLastSlide,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        )
                      : InkWell(
                          onTap: widget.onNext,
                          child: PdfPageView(
                            key: ValueKey<int>(next),
                            document: document,
                            pageNumber: next,
                            backgroundColor: Colors.black,
                            decorationBuilder: (context, pageSize, page, image) =>
                                SizedBox.fromSize(
                                  size: pageSize,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: <Widget>[
                                      if (image != null)
                                        image
                                      else
                                        const ColoredBox(color: Colors.white),
                                      CustomPaint(
                                        painter: AnnotationOverlayPainter(
                                          annotations: widget.nextAnnotations,
                                          pictures: widget.pictures,
                                          pageWidth: page.width,
                                          pageHeight: page.height,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.presenterNotes, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Expanded(
                child: TextField(
                  controller: _notes,
                  onChanged: widget.onNotesChanged,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 16, height: 1.35),
                  decoration: InputDecoration(
                    hintText: l10n.presenterNotesHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  FilterChip(
                    avatar: const Icon(Icons.tv_off_outlined, size: 18),
                    label: Text(l10n.presenterBlank),
                    selected: widget.blank,
                    onSelected: (_) => widget.onToggleBlank(),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.fullscreen, size: 18),
                    label: Text(l10n.presenterFullSlide),
                    onPressed: widget.onHide,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.close, size: 18),
                    label: Text(l10n.presenterStopAudience),
                    onPressed: widget.onCloseAudience,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
