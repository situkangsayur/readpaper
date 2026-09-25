import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/utils/layout_size.dart';
import '../../../../core/utils/zotero_key.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../library/domain/entities/zotero_annotation.dart';
import '../../../library/domain/entities/zotero_item.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/annotation_geometry.dart';
import '../widgets/annotation_editor.dart';
import '../widgets/annotation_overlay_painter.dart';
import '../../domain/page_image_export.dart';
import '../widgets/annotation_sidebar.dart';
import '../widgets/export_image_sheet.dart';
import '../widgets/ink_capture_layer.dart';
import '../widgets/selection_action_bar.dart';

/// Reads one PDF attachment: text selection, coloured markers and comments,
/// each of which is written straight back into the Zotero item file and
/// committed to git.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    required this.itemKey,
    required this.itemFilePath,
    required this.attachmentKey,
    required this.filePath,
    required this.title,
    super.key,
  });

  final String itemKey;
  final String itemFilePath;
  final String attachmentKey;
  final String filePath;
  final String title;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Two fixed configurations, swapped by the marker toggle.
  ///
  /// pdfrx wires drag-to-select as `enableSelectionHandles ? null : onPanStart`,
  /// and that flag defaults to true on touch — which is why a finger only ever
  /// panned the page and marking never started. Turning the handles off hands
  /// the drag to text selection instead.
  late final PdfTextSelectionParams _selectByHandles = PdfTextSelectionParams(
    enabled: true,
    onTextSelectionChange: _onTextSelectionChange,
  );
  late final PdfTextSelectionParams _selectByDrag = PdfTextSelectionParams(
    enabled: true,
    enableSelectionHandles: false,
    onTextSelectionChange: _onTextSelectionChange,
  );

  ItemDetail? _detail;
  List<ZoteroAnnotation> _annotations = const <ZoteroAnnotation>[];
  String? _selectedAnnotationKey;
  String _color = AnnotationPalette.yellow;
  bool _showSidebar = true;
  bool _hasSelection = false;

  /// Armed by the note button: the next tap on a page drops a note there.
  ///
  /// Touch devices need this because long-press belongs to text selection.
  bool _noteMode = false;

  /// While on, dragging marks text instead of panning the page.
  ///
  /// A finger cannot do both at once, so marking has to be a mode on touch.
  bool _markerMode = false;

  /// Guards the auto-marker so one finger lift cannot create two highlights.
  bool _marking = false;

  /// The live selection's text, kept current by [_cacheSelectedText].
  String _selectedText = '';
  int _selectionToken = 0;

  /// While on, dragging draws on the page instead of panning or selecting.
  bool _penMode = false;

  /// Strokes drawn but not yet saved, and the page they belong to.
  ///
  /// Zotero keeps a whole drawing as one `ink` annotation holding many paths,
  /// so strokes are gathered until the pen is put away rather than saved one
  /// by one. Drawing on another page commits what is pending first.
  final List<InkPath> _pendingInk = <InkPath>[];
  int? _inkPage;
  double _inkWidth = 2;

  /// Shown once per opened paper on touch, because nothing else on screen
  /// explains that marking has to be switched on first.
  bool _showCoach = isTouchPlatform;
  bool _loading = true;
  String? _error;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _color = ref.read(workspaceControllerProvider).settings.lastAnnotationColor;
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ref.read(libraryRepositoryProvider).loadItem(widget.itemFilePath);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _annotations = detail.annotationsFor(widget.attachmentKey);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal membaca anotasi: $e';
        _loading = false;
      });
    }
  }

  void _onTextSelectionChange(PdfTextSelection selection) {
    if (!mounted) return;
    if (selection.hasSelectedText != _hasSelection) {
      setState(() => _hasSelection = selection.hasSelectedText);
    }
    _cacheSelectedText(selection);
  }

  /// Keeps the selected text at hand while the selection still exists.
  ///
  /// Reading it back when a button is pressed is too late: by then the
  /// selection can already be gone, and the copy silently produced an empty
  /// clipboard. Fetching it here, while the selection is live, is the only
  /// moment it is reliably available.
  void _cacheSelectedText(PdfTextSelection selection) {
    // Deliberately not cleared when the selection goes away. Tapping a button
    // in the action bar clears the selection first and runs the action second,
    // so wiping the cache here would empty it exactly when it is needed. It is
    // only ever overwritten by the next real selection.
    if (!selection.hasSelectedText) return;
    final token = ++_selectionToken;
    unawaited(
      selection.getSelectedText().then((text) {
        // A newer selection may have landed while this was in flight.
        if (mounted && token == _selectionToken && text.trim().isNotEmpty) {
          _selectedText = text;
        }
      }),
    );
  }

  /// Marking is finished when the finger leaves the glass.
  ///
  /// The action bar sits at the bottom of the window, which on an 11" tablet
  /// is a hand-span away from the text being swept — far enough that the
  /// marker looked broken, because the sweep alone never coloured anything.
  /// In marker mode the lift now applies the active colour straight away and
  /// offers an undo, so choosing a colour and sweeping is the whole gesture.
  Future<void> _onMarkerPointerUp() async {
    if (!_markerMode || _marking) return;
    _marking = true;
    try {
      // The selection settles a frame or two after the pointer is released.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted || !_markerMode) return;
      final delegate = _controller.textSelectionDelegate;
      if (!delegate.hasSelectedText) return;
      await _createFromSelection(delegate, AnnotationType.highlight, undoable: true);
    } finally {
      _marking = false;
    }
  }

  /// Copies the selection to the clipboard and says so.
  ///
  /// Marking is a mode, so the plain selection has to stay good for reading
  /// work too: quoting a sentence into notes elsewhere is the other half of
  /// what a selection is for.
  Future<void> _copySelection() async {
    final delegate = _controller.textSelectionDelegate;
    if (!delegate.isCopyAllowed) {
      _say('Dokumen ini tidak mengizinkan penyalinan');
      return;
    }

    // Prefer what is selected right now; fall back to what was cached while
    // the selection was still live.
    var text = '';
    final ranges = await delegate.getSelectedTextRanges();
    if (ranges.isNotEmpty) text = ranges.map((r) => r.text).join();
    if (text.trim().isEmpty) text = _selectedText;

    if (text.trim().isEmpty) {
      // Reachable in practice: a long-press that lands between two words
      // selects the space, and copying a space looks exactly like a failure.
      _say('Tidak ada teks terpilih — tekan lama tepat di atas sebuah kata');
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    await delegate.clearTextSelection();
    // The character count is not decoration: an empty clipboard used to look
    // exactly like a successful copy.
    _say('${text.characters.length} karakter disalin');
  }

  // ---------------------------------------------------------------- ink

  Future<void> _addStroke(int pageNumber, InkPath stroke) async {
    // A drawing belongs to one page. Wandering onto the next one saves what
    // is there before starting a new drawing.
    if (_inkPage != null && _inkPage != pageNumber && _pendingInk.isNotEmpty) {
      await _saveInk();
    }
    setState(() {
      _inkPage = pageNumber;
      _pendingInk.add(stroke);
    });
  }

  /// Turning the pen off is also what saves the drawing.
  Future<void> _togglePen() async {
    if (_penMode) {
      setState(() => _penMode = false);
      await _saveInk();
      return;
    }
    setState(() {
      _penMode = true;
      _markerMode = false;
      _noteMode = false;
    });
  }

  void _undoStroke() {
    if (_pendingInk.isEmpty) return;
    setState(_pendingInk.removeLast);
  }

  void _discardInk() {
    setState(() {
      _pendingInk.clear();
      _inkPage = null;
    });
  }

  /// Turns the strokes gathered so far into one Zotero `ink` annotation.
  Future<void> _saveInk() async {
    final pageNumber = _inkPage;
    if (pageNumber == null || _pendingInk.isEmpty) return;

    final strokes = List<InkPath>.of(_pendingInk);
    final page = _controller.pages[pageNumber - 1];

    // Ink has no rects in Zotero's format; the sort index still needs to know
    // how far down the page the drawing starts.
    var top = 0.0;
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length; i++) {
        final y = stroke.yAt(i);
        if (y > top) top = y;
      }
    }

    final annotation = ZoteroAnnotation(
      key: ZoteroKey.generate(),
      parentItemKey: widget.attachmentKey,
      type: AnnotationType.ink,
      color: _color,
      pageIndex: pageNumber - 1,
      paths: strokes,
      inkWidth: _inkWidth,
      pageLabel: '$pageNumber',
      sortIndex: ZoteroAnnotation.buildSortIndex(
        pageIndex: pageNumber - 1,
        textOffset: 0,
        topFromPageTop: page.height - top,
      ),
      authorName: '',
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );

    _discardInk();
    await _persist(annotation, isNew: true, undoable: true);
  }

  // ------------------------------------------------------------- ekspor

  /// Saves the page — or every page — as PNG or JPG, markers included.
  Future<void> _exportImages() async {
    final pageCount = _controller.pages.length;
    final choice = await showExportImageSheet(
      context,
      currentPage: _currentPage,
      pageCount: pageCount,
    );
    if (choice == null || !mounted) return;

    final pages = choice.wholeDocument
        ? List<int>.generate(pageCount, (i) => i + 1)
        : <int>[_currentPage];
    final base = _fileStem(widget.title);

    if (choice.format == PageImageFormat.pdf) {
      await _exportPdf(pages: pages, base: base, scale: choice.scale);
      return;
    }

    var saved = 0;
    try {
      for (final pageNumber in pages) {
        final bytes = await exportPageImage(
          page: _controller.pages[pageNumber - 1],
          annotations: _onPage(pageNumber),
          format: choice.format,
          scale: choice.scale,
        );
        if (!mounted) return;

        final suffix = pages.length > 1 ? '-hal${pageNumber.toString().padLeft(3, '0')}' : '';
        final uri = await FilePicker.saveFile(
          fileName: '$base$suffix.${choice.format.extension}',
          bytes: bytes,
          mimeType: choice.format.mimeType,
          dialogTitle: 'Simpan halaman $pageNumber',
        );
        // Cancelling one page cancels the rest; carrying on would mean a save
        // dialog per page with no way out.
        if (uri == null) break;
        saved++;
      }
    } catch (e) {
      _say('Gagal menyimpan gambar: $e');
      return;
    }

    _say(saved == 0 ? 'Tidak ada yang disimpan' : '$saved berkas disimpan');
  }

  /// Writes the chosen pages into one annotated PDF.
  Future<void> _exportPdf({
    required List<int> pages,
    required String base,
    required double scale,
  }) async {
    _say(pages.length == 1 ? 'Menyiapkan PDF…' : 'Menyiapkan PDF ${pages.length} halaman…');
    try {
      final bytes = await exportPagesAsPdf(
        pages: <PdfPage>[for (final n in pages) _controller.pages[n - 1]],
        annotationsFor: _onPage,
        scale: scale,
      );
      if (!mounted) return;
      final uri = await FilePicker.saveFile(
        fileName: '$base-beranotasi.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: 'Simpan salinan beranotasi',
      );
      _say(uri == null ? 'Tidak jadi disimpan' : 'PDF disimpan (${_size(bytes.length)})');
    } catch (e) {
      _say('Gagal membuat PDF: $e');
    }
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} kB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// A file name that survives every platform's rules.
  static String _fileStem(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    if (cleaned.isEmpty) return 'halaman';
    return cleaned.length <= 60 ? cleaned : cleaned.substring(0, 60);
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(duration: const Duration(seconds: 2), content: Text(message)));
  }

  List<ZoteroAnnotation> _onPage(int pageNumber) =>
      _annotations.where((a) => a.pageIndex == pageNumber - 1).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Portrait on a tablet is still ~960dp: wide enough for a docked panel,
    // but the page itself wants that width more, so the panel stays a drawer
    // until the window is genuinely wide.
    final isWide = LayoutSize.of(context) == LayoutSize.expanded;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${_annotations.length} anotasi · halaman $_currentPage',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: <Widget>[
          // Labelled on purpose: a bare icon left people swiping at the page
          // and wondering why nothing was marked.
          if (isTouchPlatform)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _markerMode ? colorFromHex(_color) : null,
                  foregroundColor: _markerMode ? Colors.black87 : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => setState(() {
                  _markerMode = !_markerMode;
                  if (_markerMode) {
                    _noteMode = false;
                    _penMode = false;
                  }
                }),
                icon: Icon(
                  _markerMode ? Icons.border_color : Icons.border_color_outlined,
                  size: 18,
                ),
                label: Text(_markerMode ? 'Menandai' : 'Tandai'),
              ),
            ),
          IconButton(
            tooltip: _noteMode
                ? 'Ketuk halaman untuk menaruh catatan (ketuk lagi untuk batal)'
                : 'Tempel catatan di halaman',
            isSelected: _noteMode,
            selectedIcon: const Icon(Icons.sticky_note_2),
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () => setState(() {
              _noteMode = !_noteMode;
              if (_noteMode) {
                _markerMode = false;
                _penMode = false;
              }
            }),
          ),
          IconButton(
            tooltip: _penMode ? 'Selesai menggambar' : 'Tulis atau gambar di halaman',
            isSelected: _penMode,
            selectedIcon: const Icon(Icons.draw),
            icon: const Icon(Icons.draw_outlined),
            onPressed: _togglePen,
          ),
          _ColorButton(
            color: _color,
            onSelected: (value) {
              setState(() => _color = value);
              ref.read(workspaceControllerProvider.notifier).setLastAnnotationColor(value);
            },
          ),
          IconButton(
            tooltip: 'Simpan salinan beranotasi (PNG, JPG, PDF)',
            icon: const Icon(Icons.image_outlined),
            onPressed: _loading ? null : _exportImages,
          ),
          IconButton(
            tooltip: 'Perkecil',
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _controller.zoomDown(),
          ),
          IconButton(
            tooltip: 'Perbesar',
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _controller.zoomUp(),
          ),
          IconButton(
            tooltip: 'Panel anotasi',
            icon: Badge(
              isLabelVisible: !isWide && _annotations.isNotEmpty,
              label: Text('${_annotations.length}'),
              child: Icon(
                _showSidebar && isWide ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              ),
            ),
            // Wide layouts dock the panel; a phone opens it as a drawer.
            onPressed: isWide
                ? () => setState(() => _showSidebar = !_showSidebar)
                : () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                if (_error != null)
                  Material(
                    color: scheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
                      ),
                    ),
                  ),
                if (_showCoach && !_markerMode && !_noteMode)
                  Material(
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.touch_app_outlined, size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Untuk menandai: tekan "Tandai", pilih warna, lalu sapukan jari '
                              'di atas teks — begitu jari diangkat teks langsung berwarna. '
                              'Untuk menyalin: biarkan "Tandai" mati, tekan lama di teks, '
                              'lalu pilih Salin. Untuk catatan: tekan ikon catatan, lalu '
                              'ketuk halaman.',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                            ),
                          ),
                          IconButton(
                            iconSize: 18,
                            tooltip: 'Mengerti',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _showCoach = false),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_markerMode)
                  Material(
                    color: scheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.border_color, size: 18, color: scheme.onTertiaryContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sapukan jari di atas teks — lepas jari, langsung ditandai '
                              '${AnnotationPalette.names[_color] ?? _color.toLowerCase()}. '
                              'Geser halaman dan salin teks nonaktif; tekan Selesai untuk '
                              'kembali.',
                              style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13),
                            ),
                          ),
                          _ColorButton(
                            color: _color,
                            onSelected: (value) {
                              setState(() => _color = value);
                              ref
                                  .read(workspaceControllerProvider.notifier)
                                  .setLastAnnotationColor(value);
                            },
                          ),
                          TextButton(
                            onPressed: () => setState(() => _markerMode = false),
                            child: const Text('Selesai'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_penMode)
                  Material(
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.draw, size: 18, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _pendingInk.isEmpty
                                  ? 'Gambar bebas di halaman dengan jari atau stylus.'
                                  : '${_pendingInk.length} goresan di halaman $_inkPage — '
                                        'disimpan saat menekan Selesai.',
                              style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13),
                            ),
                          ),
                          _WidthButton(
                            width: _inkWidth,
                            onSelected: (value) => setState(() => _inkWidth = value),
                          ),
                          _ColorButton(
                            color: _color,
                            onSelected: (value) {
                              setState(() => _color = value);
                              ref
                                  .read(workspaceControllerProvider.notifier)
                                  .setLastAnnotationColor(value);
                            },
                          ),
                          IconButton(
                            tooltip: 'Urungkan goresan terakhir',
                            iconSize: 20,
                            icon: const Icon(Icons.undo),
                            onPressed: _pendingInk.isEmpty ? null : _undoStroke,
                          ),
                          IconButton(
                            tooltip: 'Buang semua goresan yang belum disimpan',
                            iconSize: 20,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _pendingInk.isEmpty ? null : _discardInk,
                          ),
                          TextButton(onPressed: _togglePen, child: const Text('Selesai')),
                        ],
                      ),
                    ),
                  ),
                if (_noteMode)
                  Material(
                    color: scheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.touch_app_outlined,
                            size: 18,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ketuk tempat di halaman untuk menaruh catatan.',
                              style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _noteMode = false),
                            child: const Text('Batal'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(child: _buildViewer(scheme)),
                      if (_showSidebar && isWide) ...<Widget>[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 320,
                          child: AnnotationSidebar(
                            annotations: _annotations,
                            selectedKey: _selectedAnnotationKey,
                            onTap: _goToAnnotation,
                            onEdit: _editAnnotation,
                            onDelete: _deleteAnnotation,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
      endDrawer: isWide
          ? null
          : Drawer(
              child: SafeArea(
                child: AnnotationSidebar(
                  annotations: _annotations,
                  selectedKey: _selectedAnnotationKey,
                  onTap: (annotation) {
                    Navigator.of(context).pop();
                    _goToAnnotation(annotation);
                  },
                  onEdit: _editAnnotation,
                  onDelete: _deleteAnnotation,
                ),
              ),
            ),
    );
  }

  Widget _buildViewer(ColorScheme scheme) => Stack(
    children: <Widget>[
      // Listener only watches; it never claims the gesture, so the viewer's
      // own drag-to-select still runs underneath.
      Positioned.fill(
        child: Listener(
          onPointerUp: (_) => _onMarkerPointerUp(),
          onPointerCancel: (_) => _onMarkerPointerUp(),
          child: _buildPdf(scheme),
        ),
      ),
      if (_hasSelection && !_markerMode)
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: SelectionActionBar(
              color: _color,
              onColorChanged: (value) {
                setState(() => _color = value);
                ref.read(workspaceControllerProvider.notifier).setLastAnnotationColor(value);
              },
              onHighlight: () =>
                  _createFromSelection(_controller.textSelectionDelegate, AnnotationType.highlight),
              onUnderline: () =>
                  _createFromSelection(_controller.textSelectionDelegate, AnnotationType.underline),
              onComment: () => _createFromSelection(
                _controller.textSelectionDelegate,
                AnnotationType.highlight,
                withComment: true,
              ),
              onCopy: _controller.textSelectionDelegate.isCopyAllowed ? _copySelection : null,
              onDismiss: () => _controller.textSelectionDelegate.clearTextSelection(),
            ),
          ),
        ),
    ],
  );

  Widget _buildPdf(ColorScheme scheme) => PdfViewer.file(
    widget.filePath,
    controller: _controller,
    params: PdfViewerParams(
      backgroundColor: AppTheme.readerBackground(scheme),
      margin: 10,
      textSelectionParams: _markerMode ? _selectByDrag : _selectByHandles,
      // While marking, the drag belongs to the selection; while drawing, to
      // the pen. Panning would fight either one for the same gesture.
      panEnabled: !_markerMode && !_penMode,
      onPageChanged: (pageNumber) {
        if (pageNumber != null && mounted) setState(() => _currentPage = pageNumber);
      },
      pageOverlaysBuilder: (context, pageRect, page) => <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: AnnotationOverlayPainter(
                annotations: _onPage(page.pageNumber),
                pageWidth: page.width,
                pageHeight: page.height,
                selectedKey: _selectedAnnotationKey,
              ),
            ),
          ),
        ),
        if (_penMode)
          Positioned.fill(
            child: InkCaptureLayer(
              // Rebuilt from scratch when the colour or width changes, so the
              // live stroke never keeps the previous pen's look.
              key: ValueKey<String>('ink-${page.pageNumber}-$_color-$_inkWidth'),
              pageWidth: page.width,
              pageHeight: page.height,
              color: colorFromHex(_color),
              strokeWidth: _inkWidth,
              strokes: _inkPage == page.pageNumber ? _pendingInk : const <InkPath>[],
              onStrokeFinished: (stroke) => _addStroke(page.pageNumber, stroke),
            ),
          ),
      ],
      onGeneralTap: _handleTap,
      buildContextMenu: _buildContextMenu,
    ),
  );

  // ------------------------------------------------------------------ gestures

  bool _handleTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (details.type != PdfViewerGeneralTapType.tap &&
        details.type != PdfViewerGeneralTapType.longPress) {
      return false;
    }

    final hit = controller.getPdfPageHitTestResult(
      details.documentPosition,
      useDocumentLayoutCoordinates: true,
    );
    if (hit == null) return false;

    final onPage = _onPage(hit.page.pageNumber);
    for (final annotation in onPage) {
      if (AnnotationGeometry.hitTest(annotation: annotation, point: hit.offset)) {
        setState(() => _selectedAnnotationKey = annotation.key);
        if (details.type == PdfViewerGeneralTapType.tap) {
          _editAnnotation(annotation);
        }
        return true;
      }
    }

    if (_noteMode && details.type == PdfViewerGeneralTapType.tap) {
      setState(() => _noteMode = false);
      _createNoteAt(page: hit.page, point: hit.offset);
      return true;
    }

    // Long-press is how a finger starts selecting a word, so on touch it is
    // left to the viewer; the note button takes its place there.
    if (details.type == PdfViewerGeneralTapType.longPress && !isTouchPlatform) {
      _createNoteAt(page: hit.page, point: hit.offset);
      return true;
    }

    if (_selectedAnnotationKey != null) {
      setState(() => _selectedAnnotationKey = null);
    }
    return false;
  }

  Widget? _buildContextMenu(BuildContext context, PdfViewerContextMenuBuilderParams params) {
    if (params.contextMenuFor != PdfViewerPart.selectedText) return null;
    final delegate = params.textSelectionDelegate;
    if (!delegate.hasSelectedText) return null;

    final items = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        label: 'Stabilo',
        onPressed: () {
          params.dismissContextMenu();
          _createFromSelection(delegate, AnnotationType.highlight);
        },
      ),
      ContextMenuButtonItem(
        label: 'Stabilo + komentar',
        onPressed: () {
          params.dismissContextMenu();
          _createFromSelection(delegate, AnnotationType.highlight, withComment: true);
        },
      ),
      ContextMenuButtonItem(
        label: 'Garis bawah',
        onPressed: () {
          params.dismissContextMenu();
          _createFromSelection(delegate, AnnotationType.underline);
        },
      ),
      if (delegate.isCopyAllowed)
        ContextMenuButtonItem(
          label: 'Salin',
          onPressed: () {
            params.dismissContextMenu();
            delegate.copyTextSelection();
          },
        ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: TextSelectionToolbarAnchors(
        primaryAnchor: params.anchorA,
        secondaryAnchor: params.anchorB,
      ),
      buttonItems: items,
    );
  }

  // --------------------------------------------------------------- annotations

  /// Turns the current text selection into a Zotero annotation.
  Future<void> _createFromSelection(
    PdfTextSelectionDelegate delegate,
    AnnotationType type, {
    bool withComment = false,
    bool undoable = false,
  }) async {
    final ranges = await delegate.getSelectedTextRanges();
    if (ranges.isEmpty) return;

    // Zotero keeps one annotation per page; use the page the selection starts on.
    final pageNumber = ranges.first.pageNumber;
    final onPage = ranges.where((r) => r.pageNumber == pageNumber).toList();
    final rects = <AnnotationRect>[];
    for (final range in onPage) {
      rects.addAll(AnnotationGeometry.rectsForSelection(range));
    }
    if (rects.isEmpty) return;

    final text = onPage.map((r) => r.text).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    var comment = '';
    var color = _color;
    if (withComment) {
      if (!mounted) return;
      final result = await showAnnotationEditor(
        context,
        initialColor: _color,
        quotedText: text,
        title: 'Stabilo + komentar',
      );
      if (result == null || result.action != AnnotationEditorAction.save) return;
      comment = result.comment;
      color = result.color ?? _color;
    }

    final page = _controller.pages[pageNumber - 1];
    final bounds = AnnotationGeometry.boundsOf(rects);
    final annotation = ZoteroAnnotation(
      key: ZoteroKey.generate(),
      parentItemKey: widget.attachmentKey,
      type: type,
      color: color,
      pageIndex: pageNumber - 1,
      rects: rects,
      text: text,
      comment: comment,
      pageLabel: '$pageNumber',
      sortIndex: ZoteroAnnotation.buildSortIndex(
        pageIndex: pageNumber - 1,
        textOffset: onPage.first.start,
        topFromPageTop: page.height - (bounds?.top ?? 0),
      ),
      authorName: '',
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );

    await delegate.clearTextSelection();
    await _persist(annotation, isNew: true, undoable: undoable);
  }

  /// Long-press on empty space drops a Zotero `text` note on the page.
  Future<void> _createNoteAt({required PdfPage page, required PdfPoint point}) async {
    final result = await showAnnotationEditor(
      context,
      initialColor: _color,
      title: 'Catatan di halaman ${page.pageNumber}',
    );
    if (result == null || result.action != AnnotationEditorAction.save) return;
    if (result.comment.trim().isEmpty) return;

    const noteWidth = 150.0;
    const noteHeight = 16.0;
    final rect = AnnotationRect(point.x, point.y - noteHeight, point.x + noteWidth, point.y);

    final annotation = ZoteroAnnotation(
      key: ZoteroKey.generate(),
      parentItemKey: widget.attachmentKey,
      type: AnnotationType.text,
      color: result.color ?? _color,
      pageIndex: page.pageNumber - 1,
      rects: <AnnotationRect>[rect],
      comment: result.comment,
      pageLabel: '${page.pageNumber}',
      sortIndex: ZoteroAnnotation.buildSortIndex(
        pageIndex: page.pageNumber - 1,
        textOffset: 0,
        topFromPageTop: page.height - rect.top,
      ),
      rawPosition: const <String, dynamic>{'fontSize': 14, 'rotation': 0},
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );
    await _persist(annotation, isNew: true);
  }

  Future<void> _editAnnotation(ZoteroAnnotation annotation) async {
    setState(() => _selectedAnnotationKey = annotation.key);
    final result = await showAnnotationEditor(
      context,
      initialColor: annotation.color,
      initialComment: annotation.comment,
      quotedText: annotation.text,
      title: 'Anotasi halaman ${annotation.pageLabel}',
      allowDelete: true,
    );
    if (result == null) return;

    if (result.action == AnnotationEditorAction.delete) {
      await _deleteAnnotation(annotation);
      return;
    }
    await _persist(
      annotation.copyWith(
        comment: result.comment,
        color: result.color,
        dateModified: DateTime.now(),
      ),
      isNew: false,
    );
  }

  Future<void> _deleteAnnotation(ZoteroAnnotation annotation) async {
    final item = _detail?.item;
    if (item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus anotasi?'),
        content: Text(
          annotation.text.isNotEmpty ? annotation.text : annotation.comment,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await ref
        .read(workspaceControllerProvider.notifier)
        .deleteAnnotation(item: item, annotation: annotation);
    if (!mounted) return;
    if (!removed) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(ref.read(workspaceControllerProvider).error ?? 'Gagal menghapus anotasi'),
          ),
        );
    }
    setState(() => _selectedAnnotationKey = null);
    await _load();
  }

  Future<void> _persist(
    ZoteroAnnotation annotation, {
    required bool isNew,
    bool undoable = false,
  }) async {
    final item = _detail?.item;
    if (item == null) return;
    final saved = await ref
        .read(workspaceControllerProvider.notifier)
        .saveAnnotation(item: item, annotation: annotation, isNew: isNew);
    if (!mounted) return;

    // Saying so beats a marker that appears and then quietly disappears on the
    // reload that follows.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: saved ? (undoable ? 4 : 1) : 5),
          content: Text(
            saved
                ? (isNew ? 'Tersimpan' : 'Perubahan tersimpan')
                : ref.read(workspaceControllerProvider).error ?? 'Gagal menyimpan anotasi',
          ),
          // A sweep that grabbed the wrong line should cost one tap to undo,
          // not a trip through the sidebar.
          action: saved && undoable
              ? SnackBarAction(label: 'Urungkan', onPressed: () => _deleteAnnotation(annotation))
              : null,
        ),
      );

    setState(() => _selectedAnnotationKey = annotation.key);
    await _load();
  }

  Future<void> _goToAnnotation(ZoteroAnnotation annotation) async {
    setState(() => _selectedAnnotationKey = annotation.key);
    final bounds = AnnotationGeometry.boundsOf(annotation.rects);
    if (bounds == null) {
      await _controller.goToPage(pageNumber: annotation.pageNumber);
      return;
    }
    await _controller.goToRectInsidePage(
      pageNumber: annotation.pageNumber,
      rect: AnnotationGeometry.toPdfRect(bounds),
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({required this.color, required this.onSelected});

  final String color;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Warna stabilo: ${AnnotationPalette.names[color] ?? color}',
    onSelected: onSelected,
    itemBuilder: (_) => <PopupMenuEntry<String>>[
      for (final hex in AnnotationPalette.all)
        PopupMenuItem<String>(
          value: hex,
          child: Row(
            children: <Widget>[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: colorFromHex(hex), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(AnnotationPalette.names[hex] ?? hex),
            ],
          ),
        ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: colorFromHex(color),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    ),
  );
}

/// Picks the pen thickness, in PDF points — the same unit Zotero stores.
class _WidthButton extends StatelessWidget {
  const _WidthButton({required this.width, required this.onSelected});

  final double width;
  final ValueChanged<double> onSelected;

  static const List<double> _choices = <double>[1, 2, 4, 8, 16];

  @override
  Widget build(BuildContext context) => PopupMenuButton<double>(
    tooltip: 'Tebal goresan: ${width.toStringAsFixed(0)}',
    onSelected: onSelected,
    itemBuilder: (_) => <PopupMenuEntry<double>>[
      for (final choice in _choices)
        PopupMenuItem<double>(
          value: choice,
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: choice,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(choice),
                ),
              ),
              const SizedBox(width: 12),
              Text(choice.toStringAsFixed(0)),
            ],
          ),
        ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 22,
            height: width.clamp(1, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 16),
        ],
      ),
    ),
  );
}
