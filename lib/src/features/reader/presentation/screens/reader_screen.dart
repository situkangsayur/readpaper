import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/utils/layout_size.dart';
import '../../../../core/utils/zotero_key.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../library/domain/entities/zotero_annotation.dart';
import '../../../library/domain/entities/zotero_item.dart';
import '../../../settings/domain/entities/repo_profile.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/annotation_geometry.dart';
import '../../data/pdf_page_editor.dart';
import '../../domain/annotation_move.dart';
import '../widgets/annotation_editor.dart';
import '../widgets/annotation_move_layer.dart';
import '../widgets/annotation_overlay_painter.dart';
import '../../domain/page_image_export.dart';
import '../widgets/annotation_sidebar.dart';
import '../widgets/export_image_sheet.dart';
import '../widgets/ink_capture_layer.dart';
import '../widgets/navigation_sheet.dart';
import '../widgets/page_tint.dart';
import '../widgets/signature_pad.dart';
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
    this.subtitle = '',
    super.key,
  });

  final String itemKey;
  final String itemFilePath;
  final String attachmentKey;
  final String filePath;
  final String title;

  /// Author and year, kept only so the history list can show them.
  final String subtitle;

  /// Opened as a loose file rather than from the library.
  ///
  /// There is no Zotero item to write into, so markers, ink and notes live in
  /// memory until the file is saved as a new PDF. Everything else about the
  /// reader is the same.
  bool get isStandalone => itemFilePath.isEmpty;

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

  /// Debounces history writes while pages are being flicked through.
  Timer? _recordTimer;

  /// Held so the final history write still works from [dispose].
  late final WorkspaceController _workspace;

  /// The library this paper belongs to, captured once it is known.
  String? _profileId;

  /// True when a standalone file has changes not yet written to disk.
  bool _unsaved = false;

  /// A signature drawn on the pad, waiting for a tap to say where it goes.
  List<InkPath>? _pendingSignature;

  /// Armed by the text button: the next tap opens a box to type into.
  bool _textMode = false;

  /// Hides everything but the page.
  bool _readingMode = false;

  /// Layar dibiarkan menyala selama pembaca ini terbuka.
  ///
  /// Membaca paper berarti menatap satu halaman berpuluh detik tanpa
  /// menyentuh apa pun, dan layar yang mati di tengah kalimat memutus
  /// bacaan. Tetapi ia juga memakan baterai, jadi ini pilihan yang dinyalakan
  /// sendiri — bukan keputusan aplikasi untuk semua orang.
  bool _keepScreenOn = false;

  Future<void> _applyKeepScreenOn(bool value) async {
    setState(() => _keepScreenOn = value);
    try {
      await WakelockPlus.toggle(enable: value);
    } on Object {
      // Perangkat yang menolak permintaan ini bukan alasan untuk menutup
      // pembacanya; yang hilang hanya kenyamanan.
    }
  }

  /// Mode menyajikan: satu halaman penuh layar, maju-mundur dengan ketukan.
  ///
  /// Berbeda dari mode baca. Mode baca menyembunyikan bilah supaya yang
  /// tersisa adalah halamannya; mode menyajikan mengubah cara berpindah —
  /// yang menyajikan berdiri di depan orang, tidak sedang menggulir dengan
  /// hati-hati, dan satu ketukan di tepi layar harus berarti satu halaman.
  bool _presentMode = false;

  /// Tint applied over the page while reading.
  PageTint _tint = PageTint.none;

  /// The document's own table of contents, empty when it has none.
  List<PdfOutlineNode> _outline = const <PdfOutlineNode>[];

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
  void dispose() {
    // Leaving within the debounce window would otherwise throw away the very
    // page the reader stopped on, which is the one worth keeping. The
    // notifier is held from initState because it outlives this widget, so a
    // last write can still go through from here.
    if (_recordTimer?.isActive ?? false) {
      _recordTimer!.cancel();
      final profileId = _profileId;
      if (profileId != null) _recordVisit(profileId);
    }
    _recordTimer = null;
    // The bars must come back even if the reader is closed from inside
    // reading mode, or the rest of the app loses its status bar.
    if (_readingMode) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Dilepas saat pembacanya ditutup, apa pun yang terjadi sebelumnya:
    // layar yang terus menyala di layar daftar paper tidak ada gunanya.
    if (_keepScreenOn) WakelockPlus.disable();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _workspace = ref.read(workspaceControllerProvider.notifier);
    final settings = ref.read(workspaceControllerProvider).settings;
    _color = settings.lastAnnotationColor;
    if (settings.keepScreenOn) _applyKeepScreenOn(true);
    _load();
  }

  Future<void> _load() async {
    if (widget.isStandalone) {
      // Nothing to read: a loose PDF carries no Zotero annotations, and the
      // ones made here are held in memory.
      if (mounted) setState(() => _loading = false);
      return;
    }
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

  // ------------------------------------------------------- mode baca

  /// Masuk atau keluar dari mode menyajikan.
  void _togglePresent() {
    setState(() {
      _presentMode = !_presentMode;
      if (_presentMode) {
        _readingMode = false;
        _markerMode = false;
        _noteMode = false;
        _textMode = false;
        _showSidebar = false;
        _pendingSignature = null;
      }
    });
    SystemChrome.setEnabledSystemUIMode(
      _presentMode ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
    );
    if (_presentMode) {
      // Satu putaran bingkai supaya tata letaknya sudah tanpa bilah saat
      // ukurannya dihitung; kalau tidak, halamannya pas ke layar yang lama.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCurrentPage());
    }
  }

  /// Memasang halaman yang sedang dilihat pas di layar.
  ///
  /// `PdfPageAnchor.all` memaksa seluruh halaman masuk — bukan lebarnya saja.
  /// Menyajikan berarti orang melihat dari jauh; halaman yang terpotong di
  /// bawah adalah kalimat yang hilang.
  Future<void> _fitCurrentPage() async {
    if (!_controller.isReady) return;
    await _controller.goToPage(pageNumber: _currentPage, anchor: PdfPageAnchor.all);
  }

  /// Pindah [delta] halaman, berhenti di ujungnya.
  Future<void> _stepPage(int delta) async {
    if (!_controller.isReady) return;
    final target = _currentPage + delta;
    if (target < 1 || target > _controller.pages.length) return;
    await _controller.goToPage(pageNumber: target, anchor: _presentMode ? PdfPageAnchor.all : null);
  }

  /// Hides every bar and panel, leaving the page.
  void _toggleReadingMode() {
    setState(() {
      _readingMode = !_readingMode;
      if (_readingMode) {
        // A mode that draws on the page while hiding the tools to undo it
        // would be a trap.
        _markerMode = false;
        _noteMode = false;
        _penMode = false;
      }
    });
    SystemChrome.setEnabledSystemUIMode(
      _readingMode ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
    );
  }

  void _cycleTint() {
    final next = PageTint.values[(_tint.index + 1) % PageTint.values.length];
    setState(() => _tint = next);
    _say(
      next == PageTint.invert
          ? 'Warna halaman: ${next.label} — warna penanda ikut terbalik'
          : 'Warna halaman: ${next.label}',
    );
  }

  // ----------------------------------------------------------- riwayat

  /// Goes back to where this paper was left, and records the visit.
  ///
  /// Papers are put down mid-way far more often than they are finished, so
  /// reopening one at page 1 throws away the only thing the reader knew.
  Future<void> _resumeAndRemember() async {
    final workspace = ref.read(workspaceControllerProvider);
    final profileId = workspace.settings.activeProfile?.id;
    if (profileId == null) return;
    _profileId = profileId;

    final previous = workspace.settings.recentFor(profileId: profileId, filePath: widget.filePath);
    if (previous != null &&
        previous.lastPage > 1 &&
        previous.lastPage <= _controller.pages.length) {
      await _controller.goToPage(pageNumber: previous.lastPage);
      if (mounted) _say('Dilanjutkan di halaman ${previous.lastPage}');
    }

    _recordVisit(profileId);
  }

  /// Saves the page after the scrolling stops, not during it.
  ///
  /// Flicking through twenty pages should write the history once, not twenty
  /// times: it lands in `config.json`, which is the same file the profiles
  /// live in.
  void _scheduleRecordVisit() {
    _recordTimer?.cancel();
    _recordTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final profileId = _profileId;
      if (profileId != null) _recordVisit(profileId);
    });
  }

  void _recordVisit(String profileId) {
    unawaited(
      _workspace.rememberRecent(
        RecentPaper(
          profileId: profileId,
          itemKey: widget.itemKey,
          itemFilePath: widget.itemFilePath,
          attachmentKey: widget.attachmentKey,
          filePath: widget.filePath,
          title: widget.title,
          subtitle: widget.subtitle,
          lastPage: _currentPage,
          openedAt: DateTime.now(),
        ),
      ),
    );
  }

  /// Opens the jump-to-page and table-of-contents sheet.
  Future<void> _navigate() async {
    final target = await showNavigationSheet(
      context,
      currentPage: _currentPage,
      pageCount: _controller.pages.length,
      outline: _outline,
    );
    if (target == null || !mounted) return;
    if (target.dest != null) {
      await _controller.goToDest(target.dest);
      return;
    }
    await _controller.goToPage(pageNumber: target.pageNumber!);
  }

  // -------------------------------------------------- tanda tangan & simpan

  /// Opens the pad, then waits for a tap to say where the signature goes.
  Future<void> _drawSignature() async {
    final strokes = await showSignaturePad(context);
    if (strokes == null || !mounted) return;
    setState(() {
      _pendingSignature = strokes;
      _markerMode = false;
      _noteMode = false;
      _penMode = false;
      _textMode = false;
    });
    _say('Ketuk halaman di tempat tanda tangannya ditaruh');
  }

  Future<void> _placeSignatureAt({
    required PdfPage page,
    required PdfPoint point,
    required List<InkPath> signature,
  }) async {
    // A signature about a third of the page wide reads right on A4 and still
    // fits in the space a form leaves for one.
    final width = page.width * 0.32;
    final placed = placeSignature(signature, x: point.x, y: point.y, width: width);

    var top = 0.0;
    for (final stroke in placed) {
      for (var i = 0; i < stroke.length; i++) {
        if (stroke.yAt(i) > top) top = stroke.yAt(i);
      }
    }

    final annotation = ZoteroAnnotation(
      key: ZoteroKey.generate(),
      parentItemKey: widget.attachmentKey,
      type: AnnotationType.ink,
      color: AnnotationPalette.ink,
      pageIndex: page.pageNumber - 1,
      paths: placed,
      inkWidth: 1.4,
      pageLabel: '${page.pageNumber}',
      sortIndex: ZoteroAnnotation.buildSortIndex(
        pageIndex: page.pageNumber - 1,
        textOffset: 0,
        topFromPageTop: page.height - top,
      ),
      authorName: '',
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );
    await _persist(annotation, isNew: true, undoable: true);
  }

  /// Berkas yang sedang ditampilkan.
  ///
  /// Biasanya sama dengan yang dibuka. Berbeda begitu halaman kosong
  /// ditambahkan: yang tampil sejak itu adalah salinan kerja yang memuat
  /// halaman tambahan, sementara berkas aslinya tidak disentuh sampai
  /// pengguna menyimpannya sendiri.
  String? _workingPath;

  String get _path => _workingPath ?? widget.filePath;

  /// Langkah-langkah yang masih bisa diurungkan, yang terbaru di belakang.
  ///
  /// Sebelumnya urungkan hanya ada selama beberapa detik di dalam snackbar —
  /// dan tidak ada sama sekali pada PDF yang dibuka lepas, yang justru tempat
  /// tanda tangan dan isian formulir dipakai. Sekali salah taruh, satu-satunya
  /// jalan adalah mencarinya di daftar dan menghapusnya.
  final List<_UndoStep> _undoSteps = <_UndoStep>[];

  void _pushUndo(String label, Future<void> Function() action) {
    setState(() {
      _undoSteps.add(_UndoStep(label, action));
      // Dua puluh langkah sudah lebih dari yang diingat siapa pun.
      if (_undoSteps.length > 20) _undoSteps.removeAt(0);
    });
  }

  Future<void> _undoLast() async {
    if (_undoSteps.isEmpty) return;
    final step = _undoSteps.removeLast();
    setState(() {});
    await step.action();
    if (mounted) _say('Diurungkan: ${step.label}');
  }

  /// True when writing back over [widget.filePath] would achieve nothing.
  ///
  /// Android's file picker hands the app a **copy in its own cache**, not the
  /// file the person chose. Overwriting that copy looks like it worked and
  /// changes nothing they can see, so on Android saving always goes through
  /// the system's save dialog instead.
  bool get _canWriteInPlace {
    if (Platform.isAndroid || Platform.isIOS) return false;
    final path = widget.filePath;
    return !path.contains('/cache/') && !path.contains('/file_picker/');
  }

  /// Saves the annotated PDF wherever the platform allows.
  Future<void> _savePdf() => _canWriteInPlace ? _saveOverOriginal() : _savePdfThroughDialog();

  /// Writes the PDF through the system save dialog.
  Future<void> _savePdfThroughDialog() async {
    _say('Menyiapkan PDF…');
    try {
      final bytes = await _annotatedPdf();
      if (!mounted) return;
      final uri = await FilePicker.saveFile(
        fileName: '${_fileStem(widget.title)}-terisi.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: 'Simpan PDF',
      );
      if (uri == null) {
        _say('Tidak jadi disimpan');
        return;
      }
      setState(() => _unsaved = false);
      _say('PDF disimpan (${_size(bytes.length)})');
    } catch (e) {
      _say('Gagal menyimpan: $e');
    }
  }

  /// Memasukkan PDF yang sedang dibuka ke library, ke koleksi pilihan.
  ///
  /// Hanya untuk berkas lepas: paper yang memang berasal dari library sudah
  /// ada di sana. Yang disalin adalah berkas yang sedang ditampilkan — kalau
  /// halaman kosong sudah ditambahkan, itulah yang ikut masuk.
  Future<void> _addToCollection() async {
    final index = ref.read(workspaceControllerProvider).index;
    if (index == null) {
      _say('Belum ada library yang terbuka di aplikasi ini.');
      return;
    }

    if (_unsaved) {
      _say('Anotasi yang belum disimpan tidak ikut. Simpan PDF dulu bila perlu.');
    }

    final chosen = await showModalBottomSheet<_CollectionChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shrinkWrap: true,
            children: <Widget>[
              Text('Tambahkan ke koleksi', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Berkasnya disalin ke dalam library, dibuatkan item Zotero, '
                'lalu di-commit — jadi ikut tersinkron ke GitHub.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Tanpa koleksi'),
                subtitle: const Text('masuk library, tidak masuk koleksi mana pun'),
                onTap: () => Navigator.of(context).pop(const _CollectionChoice(null)),
              ),
              const Divider(),
              for (final collection in index.collections.values)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(collection.name),
                  subtitle: collection.path == collection.name ? null : Text(collection.path),
                  onTap: () => Navigator.of(context).pop(_CollectionChoice(collection.key)),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;

    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: widget.title);
        return AlertDialog(
          title: const Text('Judul dokumen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Tambahkan'),
            ),
          ],
        );
      },
    );
    if (title == null || title.trim().isEmpty || !mounted) return;

    _say('Menambahkan ke library…');
    final created = await _workspace.addPdfToLibrary(
      pdfPath: _path,
      title: title.trim(),
      collectionKey: chosen.key,
    );
    if (!mounted) return;
    _say(
      created == null
          ? (ref.read(workspaceControllerProvider).error ?? 'Gagal menambahkan')
          : 'Masuk library sebagai ${created.itemKey}',
    );
  }

  /// Mencetak dokumen yang sedang dibuka.
  ///
  /// Dialog cetak Android juga memuat "Simpan sebagai PDF", jadi yang tidak
  /// punya pencetak tetap mendapat sesuatu yang berguna — itu sebabnya ini
  /// satu tombol, bukan dua.
  ///
  /// Yang dicetak adalah berkas apa adanya, termasuk halaman kosong yang
  /// ditambahkan. Anotasi yang belum disimpan belum menyatu dengan
  /// halamannya, jadi itu dikatakan dulu daripada mengejutkan di kertas.
  Future<void> _print() async {
    if (_unsaved) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cetak tanpa anotasi terbaru?'),
          content: const Text(
            'Ada anotasi yang belum menyatu dengan halaman, jadi belum akan '
            'ikut tercetak. Simpan PDF dulu kalau anotasinya perlu ikut.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cetak apa adanya'),
            ),
          ],
        ),
      );
      if (lanjut != true || !mounted) return;
    }

    try {
      final bytes = await File(_path).readAsBytes();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: p.basenameWithoutExtension(_path),
      );
    } on Object catch (e) {
      if (mounted) _say('Gagal mencetak: $e');
    }
  }

  /// Menambahkan halaman kosong untuk dicoreti, seperti papan tulis yang
  /// menempel pada dokumennya.
  ///
  /// Halamannya disalin sebagai objek PDF, bukan digambar ulang jadi gambar:
  /// teks paper aslinya tetap bisa dicari dan disalin. Ditambahkan di akhir
  /// supaya nomor halaman anotasi yang sudah ada tidak bergeser.
  Future<void> _addBlankPages() async {
    final count = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tambah halaman kosong'),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Ditambahkan di akhir dokumen, seukuran halaman pertamanya. '
              'Berkas aslinya tidak disentuh — yang berubah adalah salinan '
              'kerja, sampai Anda menyimpannya.',
            ),
          ),
          for (final n in <int>[1, 2, 5])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(n),
              child: Text('$n halaman'),
            ),
        ],
      ),
    );
    if (count == null || !mounted) return;

    try {
      final dir = await Directory(
        p.join((await getTemporaryDirectory()).path, 'papan'),
      ).create(recursive: true);
      final stem = p.basenameWithoutExtension(_path);
      final target = p.join(dir.path, '$stem-papan-${DateTime.now().millisecondsSinceEpoch}.pdf');

      await PdfPageEditor.addBlankPages(source: _path, target: target, count: count);

      final before = _controller.pages.length;
      if (!mounted) return;
      setState(() {
        _workingPath = target;
        _unsaved = true;
      });
      _say('$count halaman kosong ditambahkan — simpan lewat menu bagikan');
      // Langsung ke halaman kosong pertamanya: yang menambahkannya hendak
      // menulis di sana sekarang, bukan mencarinya dulu.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (_controller.isReady && before + 1 <= _controller.pages.length) {
        await _controller.goToPage(pageNumber: before + 1);
      }
    } on Object catch (e) {
      if (mounted) _say('Gagal menambah halaman: $e');
    }
  }

  /// Writes the annotated document back over the file that was opened.
  ///
  /// The original is copied to `<nama>.asli.pdf` first. Flattening is not
  /// reversible, so the untouched version has to survive somewhere.
  Future<void> _saveOverOriginal() async {
    final source = File(_path);
    final backup = File('${widget.filePath.replaceAll(RegExp(r'\.pdf$'), '')}.asli.pdf');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simpan ke berkas ini?'),
        content: Text(
          'Anotasi akan digambar menjadi bagian halaman, jadi tidak bisa '
          'disunting lagi setelah ini.\n\n'
          'Versi aslinya disimpan sebagai ${p.basename(backup.path)}.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final bytes = await _annotatedPdf();
      if (!backup.existsSync()) await source.copy(backup.path);
      await source.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _unsaved = false);
      _say('Tersimpan (asli: ${p.basename(backup.path)})');
    } catch (e) {
      _say('Gagal menyimpan: $e');
    }
  }

  /// Renders every page with its annotations into one PDF.
  Future<Uint8List> _annotatedPdf() =>
      exportPagesAsPdf(pages: _controller.pages, annotationsFor: _onPage, scale: 2);

  Future<void> _shareAnnotated() async {
    _say('Menyiapkan berkas…');
    try {
      final bytes = await _annotatedPdf();
      // Shared from a temporary copy so the original is never handed out by
      // accident, and so an unsaved document can still be sent.
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, '${_fileStem(widget.title)}.pdf'));
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
          subject: widget.title,
          text: widget.title,
        ),
      );
    } catch (e) {
      _say('Gagal membagikan: $e');
    }
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
      appBar: (_readingMode || _presentMode)
          ? null
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  // Tappable: the page number is exactly where you look when you
                  // want to be on a different page.
                  InkWell(
                    onTap: _loading ? null : _navigate,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${_unsaved ? '• ' : ''}'
                            '${_annotations.length} anotasi · halaman $_currentPage'
                            '${_controller.isReady ? ' dari ${_controller.pages.length}' : ''}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.unfold_more,
                            size: 12,
                            color: Theme.of(context).textTheme.labelSmall?.color,
                          ),
                        ],
                      ),
                    ),
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
                  tooltip: _textMode
                      ? 'Ketuk halaman untuk menaruh teks (ketuk lagi untuk batal)'
                      : 'Isi teks di halaman — untuk mengisi formulir',
                  isSelected: _textMode,
                  selectedIcon: const Icon(Icons.text_fields),
                  icon: const Icon(Icons.text_fields_outlined),
                  onPressed: () => setState(() {
                    _textMode = !_textMode;
                    if (_textMode) {
                      _markerMode = false;
                      _noteMode = false;
                      _penMode = false;
                      _pendingSignature = null;
                    }
                  }),
                ),
                IconButton(
                  tooltip: _keepScreenOn
                      ? 'Layar tetap menyala — tekan untuk mematikan'
                      : 'Biarkan layar menyala selama membaca',
                  isSelected: _keepScreenOn,
                  selectedIcon: const Icon(Icons.lightbulb),
                  icon: const Icon(Icons.lightbulb_outline),
                  onPressed: () async {
                    final value = !_keepScreenOn;
                    await _applyKeepScreenOn(value);
                    // Diingat untuk pembacaan berikutnya: yang menyalakannya
                    // sekali biasanya menginginkannya selalu.
                    await _workspace.setKeepScreenOn(value);
                    if (mounted) {
                      _say(
                        value
                            ? 'Layar akan tetap menyala selama membaca'
                            : 'Layar kembali mati sendiri',
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Sajikan — satu halaman penuh layar',
                  icon: const Icon(Icons.slideshow_outlined),
                  onPressed: _togglePresent,
                ),
                IconButton(
                  tooltip: _undoSteps.isEmpty
                      ? 'Belum ada yang bisa diurungkan'
                      : 'Urungkan: ${_undoSteps.last.label}',
                  icon: const Icon(Icons.undo),
                  onPressed: _undoSteps.isEmpty ? null : _undoLast,
                ),
                IconButton(
                  tooltip: 'Tanda tangan',
                  isSelected: _pendingSignature != null,
                  selectedIcon: const Icon(Icons.draw),
                  icon: const Icon(Icons.gesture),
                  onPressed: _loading ? null : _drawSignature,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Simpan dan bagikan',
                  icon: const Icon(Icons.ios_share),
                  onSelected: (choice) => switch (choice) {
                    'simpan' => _savePdf(),
                    'simpan-sebagai' => _exportImages(),
                    'halaman-kosong' => _addBlankPages(),
                    'cetak' => _print(),
                    'ke-koleksi' => _addToCollection(),
                    _ => _shareAnnotated(),
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    if (widget.isStandalone)
                      const PopupMenuItem<String>(
                        value: 'ke-koleksi',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.library_add_outlined),
                          title: Text('Tambahkan ke koleksi…'),
                          subtitle: Text('masuk library dan ikut tersinkron'),
                        ),
                      ),
                    const PopupMenuItem<String>(
                      value: 'cetak',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.print_outlined),
                        title: Text('Cetak…'),
                        subtitle: Text('ke pencetak, atau simpan sebagai PDF'),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'halaman-kosong',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.note_add_outlined),
                        title: Text('Tambah halaman kosong'),
                        subtitle: Text('papan tulis di akhir dokumen'),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'simpan',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.save_outlined),
                        title: Text(_canWriteInPlace ? 'Simpan ke berkas ini' : 'Simpan PDF'),
                        subtitle: Text(
                          _canWriteInPlace ? 'yang asli disalin dulu' : 'pilih tempatnya sendiri',
                        ),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'simpan-sebagai',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.save_as_outlined),
                        title: Text('Simpan sebagai…'),
                        subtitle: Text('PDF, PNG, atau JPG'),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'bagikan',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.share_outlined),
                        title: Text('Bagikan'),
                        subtitle: Text('chat, surel, atau aplikasi lain'),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Warna halaman: ${_tint.label}',
                  icon: Icon(_tint.icon),
                  onPressed: _cycleTint,
                ),
                IconButton(
                  tooltip: 'Mode baca — sembunyikan semua bilah',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _loading ? null : _toggleReadingMode,
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
                if (_showCoach && !_markerMode && !_noteMode && !_readingMode && !_presentMode)
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
                      if (_showSidebar && isWide && !_readingMode && !_presentMode) ...<Widget>[
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
          child: _tint.filter == null
              ? _buildPdf(scheme)
              : ColorFiltered(colorFilter: _tint.filter!, child: _buildPdf(scheme)),
        ),
      ),
      // Menyajikan: separuh kiri mundur, separuh kanan maju. Hanya saat pena
      // tidak aktif — kalau tidak, satu coretan berubah jadi ganti halaman.
      if (_presentMode && !_penMode) ...<Widget>[
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 96,
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _stepPage(-1)),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 96,
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _stepPage(1)),
        ),
      ],
      if (_presentMode)
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: Row(
              children: <Widget>[
                _ReadingChip(
                  icon: _penMode ? Icons.draw : Icons.draw_outlined,
                  tooltip: _penMode ? 'Selesai menggambar' : 'Coret-coret di halaman',
                  onTap: _togglePen,
                ),
                const SizedBox(width: 8),
                _ReadingChip(
                  icon: Icons.chevron_left,
                  tooltip: 'Halaman sebelumnya',
                  onTap: () => _stepPage(-1),
                ),
                const SizedBox(width: 8),
                _ReadingChip(
                  icon: Icons.chevron_right,
                  tooltip: 'Halaman berikutnya',
                  onTap: () => _stepPage(1),
                ),
                const SizedBox(width: 8),
                _ReadingChip(
                  icon: Icons.close_fullscreen,
                  tooltip: 'Keluar dari mode menyajikan',
                  onTap: _togglePresent,
                ),
              ],
            ),
          ),
        ),
      // In reading mode the bar is gone, so the way back has to be on the
      // page itself — and small enough not to become part of the page.
      if (_readingMode)
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: Row(
              children: <Widget>[
                _ReadingChip(
                  icon: _tint.icon,
                  tooltip: 'Warna halaman: ${_tint.label}',
                  onTap: _cycleTint,
                ),
                const SizedBox(width: 8),
                _ReadingChip(
                  icon: Icons.unfold_more,
                  tooltip: 'Halaman $_currentPage',
                  onTap: _navigate,
                ),
                const SizedBox(width: 8),
                _ReadingChip(
                  icon: Icons.fullscreen_exit,
                  tooltip: 'Keluar dari mode baca',
                  onTap: _toggleReadingMode,
                ),
              ],
            ),
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
    _path,
    // Berkasnya berganti saat halaman kosong ditambahkan, dan penampilnya
    // harus benar-benar memuat ulang, bukan memakai halaman yang sudah ada.
    key: ValueKey<String>(_path),
    controller: _controller,
    params: PdfViewerParams(
      backgroundColor: _tint.background ?? AppTheme.readerBackground(scheme),
      margin: 10,
      textSelectionParams: _markerMode ? _selectByDrag : _selectByHandles,
      // While marking, the drag belongs to the selection; while drawing, to
      // the pen. Panning would fight either one for the same gesture.
      panEnabled: !_markerMode && !_penMode,
      onPageChanged: (pageNumber) {
        if (pageNumber == null || !mounted) return;
        setState(() => _currentPage = pageNumber);
        _scheduleRecordVisit();
      },
      onViewerReady: (document, controller) async {
        // Outlines are cheap to read but only exist once the document is
        // open, so this cannot be part of the annotation load.
        final outline = await document.loadOutline();
        if (mounted) setState(() => _outline = outline);
        await _resumeAndRemember();
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
        // Anotasi yang sedang dipilih bisa digeser, selama tidak ada alat
        // lain yang aktif — dua hal yang menerima seretan di tempat yang sama
        // akan saling merebut.
        if (!_penMode && !_markerMode) ..._moveLayersFor(page: page, pageRect: pageRect),
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
      // Bilah gulir yang bisa diseret: paper 40 halaman tidak pantas
      // dijelajahi dengan sapuan jari satu layar demi satu layar.
      viewerOverlayBuilder: (context, size, handleLinkTap) => <Widget>[
        PdfViewerScrollThumb(
          controller: _controller,
          thumbSize: const Size(46, 38),
          thumbBuilder: (context, thumbSize, pageNumber, controller) => Material(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(6),
            child: Center(
              child: Text(
                '${pageNumber ?? 1}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSecondary, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
      onGeneralTap: _handleTap,
      buildContextMenu: _buildContextMenu,
    ),
  );

  /// Kotak geser untuk anotasi terpilih yang ada di halaman ini.
  List<Widget> _moveLayersFor({required PdfPage page, required Rect pageRect}) {
    final key = _selectedAnnotationKey;
    if (key == null) return const <Widget>[];

    final annotation = _onPage(page.pageNumber).where((a) => a.key == key).firstOrNull;
    if (annotation == null) return const <Widget>[];

    final rects = AnnotationMove.rectsOf(annotation);
    if (rects.isEmpty) return const <Widget>[];

    final scaleX = pageRect.width / page.width;
    final scaleY = pageRect.height / page.height;

    var bounds = Rect.zero;
    for (final rect in rects) {
      final canvas = Rect.fromLTRB(
        rect.left * scaleX,
        (page.height - rect.top) * scaleY,
        rect.right * scaleX,
        (page.height - rect.bottom) * scaleY,
      );
      bounds = bounds == Rect.zero ? canvas : bounds.expandToInclude(canvas);
    }

    return <Widget>[
      AnnotationMoveLayer(
        key: ValueKey<String>('geser-$key-${annotation.dateModified}'),
        bounds: bounds,
        onDelete: () => _deleteAnnotation(annotation),
        onMoved: (delta) =>
            _moveAnnotation(annotation, page: page, dx: delta.dx / scaleX, dy: -delta.dy / scaleY),
      ),
    ];
  }

  /// Memindahkan anotasi, dan mencatatnya sebagai langkah yang bisa
  /// diurungkan.
  Future<void> _moveAnnotation(
    ZoteroAnnotation annotation, {
    required PdfPage page,
    required double dx,
    required double dy,
  }) async {
    final moved = AnnotationMove.shift(
      annotation,
      dx: dx,
      dy: dy,
      pageWidth: page.width,
      pageHeight: page.height,
    );
    if (identical(moved, annotation)) return;

    _pushUndo('memindahkan anotasi', () async {
      await _persist(annotation, isNew: false, recordUndo: false);
    });
    await _persist(moved, isNew: false, recordUndo: false);
  }

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

    final signature = _pendingSignature;
    if (signature != null && details.type == PdfViewerGeneralTapType.tap) {
      setState(() => _pendingSignature = null);
      _placeSignatureAt(page: hit.page, point: hit.offset, signature: signature);
      return true;
    }

    if (_textMode && details.type == PdfViewerGeneralTapType.tap) {
      setState(() => _textMode = false);
      _createNoteAt(page: hit.page, point: hit.offset, asText: true);
      return true;
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
  /// Puts a text box on the page.
  ///
  /// [asText] is the form-filling case: the words are drawn onto the page
  /// rather than shown as a sticky note, which is what makes it possible to
  /// fill in a PDF that has no form fields of its own.
  Future<void> _createNoteAt({
    required PdfPage page,
    required PdfPoint point,
    bool asText = false,
  }) async {
    final result = await showAnnotationEditor(
      context,
      initialColor: asText ? AnnotationPalette.ink : _color,
      title: asText
          ? 'Isi teks di halaman ${page.pageNumber}'
          : 'Catatan di halaman ${page.pageNumber}',
      fieldLabel: asText ? 'Teks' : 'Komentar',
      fieldHint: asText ? 'Yang ditulis di halaman…' : 'Catatan untuk bagian ini…',
    );
    if (result == null || result.action != AnnotationEditorAction.save) return;
    if (result.comment.trim().isEmpty) return;

    // The box has to fit what was typed, or a long answer would be clipped
    // at the edge of a fixed rectangle and look like it was lost.
    const fontSize = 12.0;
    final lines = result.comment.split('\n');
    final longest = lines.fold<int>(0, (m, l) => l.length > m ? l.length : m);
    final noteWidth = asText ? (longest * fontSize * 0.52).clamp(40.0, page.width) : 150.0;
    final noteHeight = asText ? lines.length * fontSize * 1.18 : 16.0;
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
      rawPosition: const <String, dynamic>{'fontSize': fontSize, 'rotation': 0},
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
    // Menyunting komentar atau warna juga bisa diurungkan: yang sudah
    // ditulis sebelumnya tidak boleh hilang hanya karena salah tekan.
    _pushUndo('mengubah anotasi', () => _persist(annotation, isNew: false, recordUndo: false));
    await _persist(
      annotation.copyWith(
        comment: result.comment,
        color: result.color,
        dateModified: DateTime.now(),
      ),
      isNew: false,
      recordUndo: false,
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

    // `recordUndo: false`: mengembalikannya bukan langkah baru yang perlu
    // diurungkan lagi.
    _pushUndo('menghapus anotasi', () => _persist(annotation, isNew: true, recordUndo: false));
    await _removeAnnotation(annotation);
  }

  /// Menghapus tanpa bertanya. Dipakai penghapusan yang sudah disetujui dan
  /// oleh urungkan.
  Future<void> _removeAnnotation(ZoteroAnnotation annotation) async {
    final item = _detail?.item;

    if (widget.isStandalone) {
      setState(() {
        _annotations = _annotations.where((a) => a.key != annotation.key).toList();
        _unsaved = true;
        _selectedAnnotationKey = null;
      });
      return;
    }
    if (item == null) return;

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
    bool recordUndo = true,
  }) async {
    if (isNew && recordUndo) {
      _pushUndo('menambah ${annotation.type.wire}', () => _removeAnnotation(annotation));
    }
    if (widget.isStandalone) {
      setState(() {
        _annotations = <ZoteroAnnotation>[
          for (final a in _annotations)
            if (a.key != annotation.key) a,
          annotation,
        ];
        _unsaved = true;
        _selectedAnnotationKey = annotation.key;
      });
      _say(undoable ? 'Ditambahkan — belum disimpan ke berkas' : 'Ditambahkan');
      return;
    }

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
              // Lewat tumpukan yang sama dengan tombol Urungkan, supaya
              // keduanya tidak pernah berbeda pendapat.
              ? SnackBarAction(label: 'Urungkan', onPressed: _undoLast)
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

/// A small round button that floats over the page in reading mode.
class _ReadingChip extends StatelessWidget {
  const _ReadingChip({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.82),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Satu langkah yang bisa diurungkan.
class _UndoStep {
  const _UndoStep(this.label, this.action);

  /// Disebut apa saat diurungkan, supaya yang menekan tahu apa yang kembali.
  final String label;
  final Future<void> Function() action;
}

/// Koleksi yang dipilih saat memasukkan berkas ke library; null berarti
/// tidak masuk koleksi mana pun.
class _CollectionChoice {
  const _CollectionChoice(this.key);

  final String? key;
}
