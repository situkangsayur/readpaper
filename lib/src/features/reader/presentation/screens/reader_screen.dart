import 'package:flutter/material.dart';
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
import '../widgets/annotation_sidebar.dart';
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

  /// Text selection must stay identical between builds: pdfrx reloads the
  /// document when this object changes.
  late final PdfTextSelectionParams _textSelectionParams = PdfTextSelectionParams(
    enabled: true,
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
          IconButton(
            tooltip: _noteMode
                ? 'Ketuk halaman untuk menaruh catatan (ketuk lagi untuk batal)'
                : 'Tempel catatan di halaman',
            isSelected: _noteMode,
            selectedIcon: const Icon(Icons.sticky_note_2),
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () => setState(() => _noteMode = !_noteMode),
          ),
          _ColorButton(
            color: _color,
            onSelected: (value) {
              setState(() => _color = value);
              ref.read(workspaceControllerProvider.notifier).setLastAnnotationColor(value);
            },
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
      Positioned.fill(child: _buildPdf(scheme)),
      if (_hasSelection)
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
      textSelectionParams: _textSelectionParams,
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
    await _persist(annotation, isNew: true);
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

    await ref
        .read(workspaceControllerProvider.notifier)
        .deleteAnnotation(item: item, annotation: annotation);
    if (!mounted) return;
    setState(() => _selectedAnnotationKey = null);
    await _load();
  }

  Future<void> _persist(ZoteroAnnotation annotation, {required bool isNew}) async {
    final item = _detail?.item;
    if (item == null) return;
    await ref
        .read(workspaceControllerProvider.notifier)
        .saveAnnotation(item: item, annotation: annotation, isNew: isNew);
    if (!mounted) return;
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
