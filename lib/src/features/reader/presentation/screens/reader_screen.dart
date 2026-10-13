import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui show Image;
import 'dart:ui' show AppExitResponse;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/utils/layout_size.dart';
import '../../../../core/utils/share_file.dart';
import '../../../../core/utils/work_folder.dart';
import '../../../notebook/data/note_document_store.dart';
import '../../../notebook/data/pdf_to_notebook.dart';
import '../../../notebook/presentation/screens/notebook_screen.dart';
import '../../../../core/utils/zotero_key.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../library/domain/entities/zotero_annotation.dart';
import '../../../markdown/data/pdf_to_markdown.dart';
import '../../../markdown/presentation/screens/markdown_editor_screen.dart';
import '../../../library/domain/entities/zotero_item.dart';
import '../../../settings/domain/entities/repo_profile.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/annotation_geometry.dart';
import '../../data/page_picture.dart';
import '../../data/pdf_page_editor.dart';
import '../../../../core/utils/clipboard_image.dart';
import '../../../../core/utils/file_pick.dart';
import '../../domain/annotation_move.dart';
import '../../domain/ink_eraser.dart';
import '../widgets/annotation_editor.dart';
import '../widgets/annotation_move_layer.dart';
import '../widgets/annotation_overlay_painter.dart';
import '../../domain/page_image_export.dart';
import '../widgets/annotation_sidebar.dart';
import '../widgets/save_as_dialog.dart';
import '../widgets/export_image_sheet.dart';
import '../widgets/ink_capture_layer.dart';
import '../widgets/navigation_sheet.dart';
import '../widgets/page_tint.dart';
import '../widgets/signature_pad.dart';
import '../widgets/selection_action_bar.dart';
import '../../../../core/l10n.dart';
import '../../../../core/widgets/find_bar.dart';
import '../../../presenter/data/audience_link.dart';
import '../../../presenter/data/presenter_notes_store.dart';
import '../../../presenter/domain/audience_state.dart';
import '../../../presenter/presentation/laser_pointer.dart';
import '../../../presenter/presentation/presenter_keys.dart';
import '../../../presenter/presentation/presenter_panel.dart';

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
    this.annotationsFile,
    this.onAnnotationsChanged,
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

  /// Berkas tempat anotasi PDF lepas disimpan seketika — untuk PDF di
  /// Catatan. Tanpa ini stabilo dan catatan di PDF catatan hanya hidup di
  /// memori, menuntut "Simpan sebagai", dan hilang saat dibuka lagi.
  final String? annotationsFile;

  /// Dipanggil setelah [annotationsFile] ditulis, dengan ringkasan
  /// perubahannya (mis. untuk dicatat sebagai perubahan yang menunggu Kirim).
  final Future<void> Function(String message)? onAnnotationsChanged;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PdfViewerController _controller = PdfViewerController();

  /// Cari kata di dokumen: pdfrx membaca teks tiap halaman di latar, hasilnya
  /// disorot di halaman lewat [_paintMatches]. Dibuat saat penampil siap —
  /// ia langsung membaca dokumen dari controller — dan dibuat ulang setiap
  /// kali PDF-nya dimuat ulang (halaman kosong ditambahkan, disimpan).
  PdfTextSearcher? _searcher;
  late final List<PdfViewerPagePaintCallback> _paintMatches = <PdfViewerPagePaintCallback>[
    (canvas, pageRect, page) => _searcher?.pageTextMatchPaintCallback(canvas, pageRect, page),
  ];
  bool _finding = false;
  String _findQuery = '';
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

  /// Selama pena aktif seleksi teks dimatikan sama sekali. Stylus yang
  /// berhenti sebentar di atas kata terbaca sebagai tekan lama: teks terblok,
  /// bilah stabilo muncul, dan goresannya terputus — persis di tengah
  /// menulis di depan kelas.
  static const PdfTextSelectionParams _selectOff = PdfTextSelectionParams(enabled: false);

  late final PdfTextSelectionParams _selectByDrag = PdfTextSelectionParams(
    enabled: true,
    enableSelectionHandles: false,
    onTextSelectionChange: _onTextSelectionChange,
  );

  ItemDetail? _detail;
  List<ZoteroAnnotation> _annotations = const <ZoteroAnnotation>[];
  String? _selectedAnnotationKey;

  /// Catatan gaya Zotero yang balonnya sedang terbuka. Mengetuk ikonnya
  /// membuka dan menutupnya, seperti di Zotero.
  final Set<String> _openNotes = <String>{};
  DateTime _lastNoteToggle = DateTime(0);

  /// Membuka atau menutup balon catatan [key]. Satu ketukan bisa sampai dua
  /// kali — di bingkai pilihan dan di penampil PDF di bawahnya — dan tanpa
  /// penahan ini balonnya terbuka lalu langsung tertutup lagi.
  void _toggleNote(String key) {
    final now = DateTime.now();
    if (now.difference(_lastNoteToggle) < const Duration(milliseconds: 350)) return;
    _lastNoteToggle = now;
    setState(() {
      _selectedAnnotationKey = key;
      if (!_openNotes.remove(key)) _openNotes.add(key);
    });
  }

  /// Isi gambar tempelan per nama berkas: yang tersandi (untuk disimpan dan
  /// dilebur ke PDF) dan yang sudah dibaca (untuk digambar).
  final Map<String, Uint8List> _pictureBytes = <String, Uint8List>{};
  final Map<String, ui.Image> _pictureImages = <String, ui.Image>{};

  /// Anotasi yang terakhir disalin atau dipotong. Statis, jadi tetap ada
  /// setelah pembaca ditutup: yang disalin dari satu paper bisa ditempel di
  /// paper lain.
  static ZoteroAnnotation? _clipboard;

  /// Isi gambar yang disalin, ikut di papan klip: pembaca lain tidak punya
  /// berkas gambarnya.
  static Uint8List? _clipboardPicture;

  /// Seretan anotasi yang sedang berlangsung. Diurus di sini, di atas
  /// penampil, karena lapisan geser terkurung di halamannya sendiri.
  _AnnotationDrag? _annotationDrag;
  Timer? _dragScroll;
  double _dragScrollSpeed = 0;
  final GlobalKey _viewerKey = GlobalKey();
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

  /// Layar audiens yang tersambung — jendela di monitor kedua, atau layar
  /// eksternal tablet. Selama ada, semua yang terjadi di slide sekarang
  /// dikirim ke sana.
  AudienceLink? _audience;
  StreamSubscription<void>? _audienceClosed;
  StreamSubscription<PresenterKey>? _audienceKeys;

  /// Layar audiens dihitamkan sementara (tombol B / titik pada clicker).
  bool _audienceBlank = false;

  /// Panel presenter (slide berikutnya, catatan) terlihat. Disembunyikan,
  /// slide sekarang memenuhi layar presenter.
  bool _presenterPanel = true;

  /// Isi `scene` terakhir yang dikirim; yang sama tidak dikirim ulang.
  String? _lastScene;
  final Set<String> _sentPictures = <String>{};

  /// Goresan yang sedang ditarik dikirim paling sering 30 kali sedetik.
  Timer? _liveTimer;
  ({int page, List<double> points})? _liveQueued;
  DateTime _liveSentAt = DateTime(0);

  /// Catatan presenter per slide, dan tempat menyimpannya.
  PresenterNotesStore? _notesStore;
  Map<int, String> _presenterNotes = <int, String>{};
  Timer? _notesSave;
  bool _notesChangeRecorded = false;

  /// Penunjuk menyala: mouse, jari, atau stylus menunjuk tanpa mencoret.
  bool _pointerMode = false;
  late final LaserPointer _pointer;

  /// Stylus sedang menggores; selama itu halaman tidak boleh ikut bergeser.
  bool _stylusDrawing = false;

  /// Kotak tiap halaman di layar, diperbarui saat lapisannya dibangun.
  final Map<int, Rect> _pageRects = <int, Rect>{};

  /// Ukuran tiap halaman dalam titik PDF, pasangan dari [_pageRects].
  final Map<int, Size> _pageSizes = <int, Size>{};

  /// Goresan stylus yang sedang ditarik, dalam koordinat kanvas halaman.
  final List<Offset> _stylusLive = <Offset>[];

  /// Ditambah setiap kali [_stylusLive] bertambah titik, supaya hanya kanvas
  /// tintanya yang dicat ulang — bukan seluruh layar pembaca.
  final ValueNotifier<int> _stylusTick = ValueNotifier<int>(0);

  /// Halaman tempat goresan itu mendarat.
  int? _stylusPage;

  /// Pointer milik stylus yang sedang menggores.
  ///
  /// Wajib diingat, dan ini bukan kerapian: telapak tangan yang bertumpu di
  /// layar — persis keadaan yang hendak dilayani mode "Stylus saja" — mengirim
  /// pointer-nya sendiri, turun dan naik berkali-kali selama tangan bergerak.
  /// Tanpa membedakan pointer, **setiap telapak yang terangkat mengakhiri
  /// goresan yang sedang ditarik**; yang baru satu dua titik dibuang begitu
  /// saja, dan geseran halaman menyala lagi di tengah tulisan. Itulah sebabnya
  /// stylusnya terasa kadang jalan kadang tidak.
  int? _stylusPointer;

  /// Hanya stylus yang menggambar. Tangan yang bertumpu di layar tidak
  /// meninggalkan garis — itu penolak telapak tangan yang sebenarnya.
  ///
  /// Nilainya diambil dari setelan dan disimpan balik: ini sifat perangkatnya,
  /// bukan pilihan sesaat, dan memilihnya ulang setiap kali membuka dokumen
  /// adalah cara tercepat membuat orang berhenti memakainya.
  late bool _stylusOnly = ref.read(workspaceControllerProvider).settings.stylusOnly;

  /// Sentuhan tangan yang dianggap telapak, bukan jari yang hendak menggeser.
  ///
  /// "Stylus saja" menyerahkan jari ke halaman supaya dokumen tetap bisa
  /// digeser sambil menulis. Harganya: telapak yang mendarat sebelum ujung
  /// pena menyentuh layar ikut terhitung jari, dan halamannya bergeser di
  /// bawah tangan — persis saat orang hendak mulai menulis. Sentuhan yang
  /// datang ketika stylus sedang dekat layar (melayang), sedang menulis, atau
  /// baru saja diangkat, atau yang bidang sentuhnya selebar telapak, dicatat
  /// di sini, dan selama ada satu saja halaman tidak menerima geser maupun
  /// cubit.
  final Set<int> _palmPointers = <int>{};

  /// Stylus terlihat — melayang atau menyentuh — belum lama ini.
  bool _stylusNear = false;
  Timer? _stylusNearTimer;

  /// Selama ini sejak stylus terakhir terlihat, tangan masih dianggap tangan
  /// yang sedang menulis.
  static const Duration _stylusGrace = Duration(milliseconds: 800);

  /// Jari-jari bidang sentuh, dalam titik logis, yang sudah pasti bukan ujung
  /// jari. Perangkat yang tidak melaporkannya mengirim nol, dan aturan
  /// melayang di atas tetap bekerja.
  static const double _palmRadius = 16;

  bool get _handLocked =>
      _penMode && _stylusOnly && (_stylusDrawing || _stylusNear || _palmPointers.isNotEmpty);

  bool _isStylus(PointerEvent event) =>
      event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus;

  void _noteStylusNear() {
    _stylusNearTimer?.cancel();
    _stylusNearTimer = Timer(_stylusGrace, () {
      if (mounted && _stylusNear) setState(() => _stylusNear = false);
    });
    if (!_stylusNear) setState(() => _stylusNear = true);
  }

  void _handDown(PointerDownEvent event) {
    if (!_penMode || !_stylusOnly) return;
    if (_isStylus(event)) {
      _noteStylusNear();
      return;
    }
    if (event.kind != PointerDeviceKind.touch) return;
    final palm =
        _stylusNear ||
        _stylusDrawing ||
        _palmPointers.isNotEmpty ||
        event.radiusMajor > _palmRadius;
    if (palm) setState(() => _palmPointers.add(event.pointer));
  }

  void _handUp(PointerEvent event) {
    if (_isStylus(event) && _penMode) _noteStylusNear();
    if (_palmPointers.contains(event.pointer)) {
      setState(() => _palmPointers.remove(event.pointer));
    }
  }

  void _setStylusOnly(bool value) {
    setState(() => _stylusOnly = value);
    ref.read(workspaceControllerProvider.notifier).setStylusOnly(value);
    _say(value ? context.l10n.readerStylusOnlyOn : context.l10n.readerStylusOnlyOff);
  }

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
    final audience = _audience;
    if (audience != null) unawaited(audience.close());
    _audienceClosed?.cancel();
    _audienceKeys?.cancel();
    _liveTimer?.cancel();
    if (_notesSave?.isActive ?? false) {
      _notesSave!.cancel();
      unawaited(_writePresenterNotes());
    }
    HardwareKeyboard.instance.removeHandler(_onPresentKey);
    _pointer.dispose();
    _searcher?.removeListener(_onSearchChanged);
    _searcher?.dispose();
    _exitListener.dispose();
    _stylusNearTimer?.cancel();
    _dragScroll?.cancel();
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
    _exitListener;
    _workspace = ref.read(workspaceControllerProvider.notifier);
    final settings = ref.read(workspaceControllerProvider).settings;
    _color = settings.lastAnnotationColor;
    _pointer = LaserPointer(trail: Duration(milliseconds: settings.pointerTrailMs));
    if (settings.keepScreenOn) _applyKeepScreenOn(true);
    _load();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _openFind() {
    if (_loading) return;
    setState(() => _finding = true);
  }

  void _find(String query) {
    _findQuery = query;
    final searcher = _searcher;
    if (searcher == null) return;
    if (query.trim().isEmpty) {
      searcher.resetTextSearch();
    } else {
      searcher.startTextSearch(query.trim(), caseInsensitive: true, goToFirstMatch: true);
    }
  }

  void _closeFind() {
    _searcher?.resetTextSearch();
    setState(() => _finding = false);
  }

  /// Ke hasil berikutnya ([delta] 1) atau sebelumnya (-1), memutar di ujung
  /// seperti pencarian di peramban. pdfrx sendiri berhenti di ujung dan tidak
  /// memberi tahu pendengarnya saat berpindah, jadi angkanya diperbarui di sini.
  Future<void> _stepMatch(int delta) async {
    final searcher = _searcher;
    if (searcher == null || searcher.matches.isEmpty) return;
    final count = searcher.matches.length;
    final current = searcher.currentIndex ?? (delta > 0 ? -1 : 0);
    await searcher.goToMatchOfIndex((current + delta) % count);
    if (mounted) setState(() {});
  }

  /// Penampil siap dengan dokumen (baru): pencari dibuat untuknya, dan
  /// pencarian yang sedang terbuka diulang di dokumen itu.
  void _attachSearcher() {
    _searcher?.removeListener(_onSearchChanged);
    _searcher?.dispose();
    _searcher = PdfTextSearcher(_controller)..addListener(_onSearchChanged);
    if (_finding && _findQuery.trim().isNotEmpty) {
      _searcher!.startTextSearch(_findQuery.trim(), caseInsensitive: true, goToFirstMatch: false);
    }
  }

  /// Nomor pemuatan terakhir. Dua pemuatan bisa berjalan bersamaan (simpan
  /// yang berurutan cepat), dan yang selesai belakangan tidak boleh menimpa
  /// daftar dengan isi berkas yang lebih tua — itu membuat anotasi yang baru
  /// disimpan hilang dari panel dan dari urungkan.
  int _loadGeneration = 0;

  /// PDF lepas yang anotasinya tersimpan seketika ke berkas pendamping.
  bool get _autoSaves => widget.isStandalone && widget.annotationsFile != null;

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (widget.isStandalone) {
      // A loose PDF carries no Zotero annotations; a note PDF keeps its own
      // beside it, the rest are held in memory.
      final saved = _autoSaves ? await _readAnnotationsFile() : null;
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        if (saved != null) _annotations = saved;
        _loading = false;
      });
      return;
    }
    try {
      final detail = await ref.read(libraryRepositoryProvider).loadItem(widget.itemFilePath);
      final store = _workspace.pagePictures(widget.attachmentKey);
      final pictures = store == null ? const <ZoteroAnnotation>[] : await store.load();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _detail = detail;
        _annotations = <ZoteroAnnotation>[
          ...detail.annotationsFor(widget.attachmentKey),
          ...pictures,
        ];
        _loading = false;
      });
      await _loadPictures();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.readerLoadAnnotationsFailed('$e');
        _loading = false;
      });
    }
  }

  Future<List<ZoteroAnnotation>> _readAnnotationsFile() async {
    final file = File(widget.annotationsFile!);
    if (!file.existsSync()) return <ZoteroAnnotation>[];
    try {
      final json = jsonDecode(await file.readAsString());
      final list = json is Map ? json['annotations'] : null;
      if (list is! List) return <ZoteroAnnotation>[];
      return <ZoteroAnnotation>[
        for (final entry in list)
          if (entry is Map) ZoteroAnnotation.fromJson(entry.cast<String, dynamic>()),
      ];
    } on Object catch (e) {
      _say(l10n.readerNoteAnnotationsUnreadable('$e'));
      return <ZoteroAnnotation>[];
    }
  }

  /// Menulis semua anotasi (kecuali gambar tempelan, yang isinya hanya ada
  /// di memori) ke berkas pendamping, lalu memberi tahu pemanggil.
  Future<void> _writeAnnotationsFile(String message) async {
    final file = File(widget.annotationsFile!);
    final kept = _annotations.where((a) => !PagePicture.isPicture(a)).toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('\t').convert(<String, dynamic>{
        'schema': 1,
        'annotations': <dynamic>[for (final a in kept) a.toJson()],
      })}\n',
      flush: true,
    );
    await widget.onAnnotationsChanged?.call(message);
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
      _say(context.l10n.readerCopyNotAllowed);
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
      _say(l10n.readerNothingSelected);
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    await delegate.clearTextSelection();
    // The character count is not decoration: an empty clipboard used to look
    // exactly like a successful copy.
    _say(l10n.readerCharactersCopied(text.characters.length));
  }

  // ---------------------------------------------------------------- ink

  Future<void> _addStroke(int pageNumber, InkPath stroke, {bool erase = false}) async {
    if (_erasing || erase) {
      await _eraseAlong(pageNumber, stroke);
      return;
    }
    // A drawing belongs to one page. Wandering onto the next one saves what
    // is there before starting a new drawing.
    if (_inkPage != null && _inkPage != pageNumber && _pendingInk.isNotEmpty) {
      await _saveInk();
    }
    setState(() {
      _inkPage = pageNumber;
      _pendingInk.add(stroke);
      _redoStrokes.clear();
    });
  }

  /// Turning the pen off is also what saves the drawing.
  Future<void> _togglePen() async {
    if (_penMode) {
      // Penghapus ikut mati: membuka pena lagi lalu mendapati coretan pertama
      // malah menghapus adalah kejutan yang buruk.
      setState(() {
        _penMode = false;
        _erasing = false;
      });
      await _saveInk();
      return;
    }
    // Blok teks atau anotasi terpilih yang tertinggal membuat bilahnya tetap
    // tampil di atas halaman yang sedang ditulisi.
    if (_hasSelection) _controller.textSelectionDelegate.clearTextSelection();
    setState(() {
      _penMode = true;
      _pointerMode = false;
      _markerMode = false;
      _noteMode = false;
      _hasSelection = false;
      _selectedAnnotationKey = null;
    });
  }

  /// Penghapus pena: goresan yang disapu dibuang, bukan ditimpa.
  ///
  /// Tinta putih bisa menutupi kesalahan, tetapi tetap ada di berkas — di
  /// Zotero, di PDF yang dibagikan, dan di atas halaman yang tidak putih.
  /// Penghapus membuang goresannya sendiri.
  bool _erasing = false;

  /// Goresan yang sedang ditarik berasal dari ujung penghapus stylus.
  bool _stylusErase = false;

  void _toggleEraser() {
    setState(() => _erasing = !_erasing);
    _say(_erasing ? context.l10n.readerEraserOn : context.l10n.readerBackToWriting);
  }

  /// Berlabel, bukan ikon saja: tidak ada ikon penghapus yang dikenal di
  /// set ikon aplikasi ini, dan tongkat ajaib yang dulu dipakai tidak terbaca
  /// sebagai penghapus — di tablet, saat menyajikan, ia dicari dan tidak
  /// ditemukan padahal ada.
  Widget _eraserButton() => Tooltip(
    message: _erasing ? context.l10n.readerBackToWriting : context.l10n.readerEraserTooltip,
    child: _erasing
        ? FilledButton.tonalIcon(
            onPressed: _toggleEraser,
            icon: const Icon(Icons.auto_fix_off, size: 18),
            label: Text(context.l10n.readerEraser),
          )
        : TextButton.icon(
            onPressed: _toggleEraser,
            icon: const Icon(Icons.auto_fix_normal, size: 18),
            label: Text(context.l10n.readerEraser),
          ),
  );

  /// Warna sebelum tinta putih dipilih lewat tombol cepatnya.
  String? _colorBeforeWhite;

  /// Tombol cepat tinta putih, di luar menu warna.
  ///
  /// Tinta putih dipakai untuk menutup kesalahan di tengah menulis — saat itu
  /// membuka menu empat belas warna dan menggulir ke bawah terlalu lama, dan
  /// warna yang tersembunyi di dalam menu dianggap tidak ada. Ketuk lagi untuk
  /// kembali ke warna sebelumnya.
  Widget _whiteInkButton() {
    final on = _color == AnnotationPalette.white;
    return IconButton(
      tooltip: on ? context.l10n.readerBackToPreviousColor : context.l10n.readerWhiteInk,
      isSelected: on,
      onPressed: () {
        if (on) {
          _switchPen(color: _colorBeforeWhite ?? AnnotationPalette.ink);
        } else {
          _colorBeforeWhite = _color;
          _switchPen(color: AnnotationPalette.white);
        }
      },
      icon: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: on
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: on ? 2.5 : 1.2,
          ),
        ),
      ),
    );
  }

  /// Membuang setiap goresan di [pageNumber] yang dilewati [eraser]: yang
  /// belum disimpan, dan yang sudah jadi anotasi tinta.
  ///
  /// Satu goresan dibuang utuh, seperti penghapus goresan di papan tulis:
  /// memotong goresan di tengah menghasilkan potongan-potongan yang tidak
  /// dimaksud siapa pun. Coretan yang semua goresannya terhapus ikut dihapus
  /// sebagai anotasi. Semuanya bisa diurungkan.
  Future<void> _eraseAlong(int pageNumber, InkPath eraser) async {
    final reach = math.max(6.0, _inkWidth * 1.5);
    var removed = 0;

    if (_inkPage == pageNumber && _pendingInk.isNotEmpty) {
      final kept = InkEraser.keep(_pendingInk, eraser, reach);
      removed += _pendingInk.length - kept.length;
      if (kept.length != _pendingInk.length) {
        setState(
          () => _pendingInk
            ..clear()
            ..addAll(kept),
        );
      }
    }

    for (final annotation in _onPage(pageNumber)) {
      if (annotation.type != AnnotationType.ink) continue;
      final kept = InkEraser.keep(annotation.paths, eraser, reach);
      if (kept.length == annotation.paths.length) continue;
      removed += annotation.paths.length - kept.length;
      if (kept.isEmpty) {
        _recordChange(context.l10n.readerUndoEraseInk, before: annotation, after: null);
        await _removeAnnotation(annotation);
      } else {
        final trimmed = annotation.copyWith(paths: kept, dateModified: DateTime.now());
        _recordChange(context.l10n.readerUndoEraseStroke, before: annotation, after: trimmed);
        await _persist(trimmed, isNew: false, recordUndo: false);
      }
    }
    if (removed == 0) _say(l10n.readerEraserMissed);
  }

  /// Goresan tertunda yang baru diurungkan, untuk diulangi.
  final List<InkPath> _redoStrokes = <InkPath>[];

  void _undoStroke() {
    if (_pendingInk.isEmpty) return;
    setState(() => _redoStrokes.add(_pendingInk.removeLast()));
  }

  void _redoStroke() {
    if (_redoStrokes.isEmpty) return;
    setState(() => _pendingInk.add(_redoStrokes.removeLast()));
  }

  /// Ulangi yang berlaku sekarang: goresan tertunda lebih dulu, karena itu
  /// yang baru saja diurungkan selagi menulis.
  VoidCallback? get _redoAction =>
      _redoStrokes.isNotEmpty ? _redoStroke : (_redoSteps.isEmpty ? null : _redoLast);

  String get _redoTooltip => _redoStrokes.isNotEmpty
      ? context.l10n.readerRedoStroke
      : (_redoSteps.isEmpty
            ? context.l10n.readerNothingToRedo
            : context.l10n.readerRedoStep(_redoSteps.last.label));

  void _discardInk() {
    setState(() {
      _pendingInk.clear();
      _redoStrokes.clear();
      _inkPage = null;
    });
  }

  /// Mengganti pena di tengah menggambar: warna, tebal, atau keduanya.
  ///
  /// Goresan yang sudah ada **disimpan lebih dulu** sebagai gambar tersendiri.
  /// Zotero menyimpan satu gambar tinta sebagai **satu** anotasi dengan satu
  /// warna dan satu ketebalan, jadi tanpa ini mengganti warna di tengah jalan
  /// mengubah warna seluruh coretan yang belum selesai — termasuk yang sudah
  /// digambar dengan warna sebelumnya. Yang diharapkan orang sebaliknya:
  /// coretan lama tetap seperti semula, yang baru memakai warna yang baru.
  Future<void> _switchPen({String? color, double? width}) async {
    if (_pendingInk.isNotEmpty) await _saveInk();
    if (!mounted) return;
    setState(() {
      if (color != null) _color = color;
      if (width != null) _inkWidth = width;
    });
    if (color != null) {
      await ref.read(workspaceControllerProvider.notifier).setLastAnnotationColor(color);
    }
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
        // Gagang geser dan bilah aksi anotasi terpilih tidak pantas tampil
        // di depan audiens.
        _selectedAnnotationKey = null;
      }
    });
    SystemChrome.setEnabledSystemUIMode(
      _presentMode ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
    );
    if (_presentMode) {
      HardwareKeyboard.instance.addHandler(_onPresentKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_onPresentKey);
      _pointerMode = false;
      _pointer.hide();
      unawaited(_closeAudience());
    }
    if (_presentMode) _refitSoon();
  }

  /// Memaskan slide sekarang ke layar beberapa kali, makin jarang.
  ///
  /// Tata letak baru (masuk mode menyajikan, panel presenter muncul atau
  /// hilang) baru berlaku setelah penampilnya disusun ulang, dan susunan ulang
  /// itu tidak mengabarkan kapan selesainya — pemasangan yang terlalu awal
  /// memakai ukuran lama, dan halamannya mendarat terlalu besar dan terlalu
  /// ke bawah. Terbukti di tablet: menekan "pas ke layar" sekali langsung
  /// membetulkannya, jadi yang salah memang waktunya.
  ///
  /// Berhenti begitu presenter berpindah slide: pemasangan yang tertinggal
  /// memaskan slide lama dan menarik layar kembali ke sana — clicker yang
  /// ditekan tepat setelah layar audiens dibuka seolah tidak berbuat apa-apa.
  void _refitSoon() {
    final step = _stepCount;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final jeda in const <int>[0, 200, 500, 900]) {
        if (!mounted || !_presentMode || step != _stepCount) return;
        if (jeda > 0) await Future<void>.delayed(Duration(milliseconds: jeda));
        if (!mounted || !_presentMode || step != _stepCount) return;
        await _fitCurrentPage();
      }
    });
  }

  /// Bertambah setiap kali [_stepPage] berpindah slide.
  int _stepCount = 0;

  // ------------------------------------------------------ layar audiens

  /// Membuka layar audiens, dan masuk mode menyajikan bila belum.
  Future<void> _openAudience() async {
    if (_audience != null) return;
    final link = AudienceLink.forPlatform();
    if (link == null) return;
    final l10n = context.l10n;
    final opened = await link.open();
    if (!mounted) {
      if (opened) unawaited(link.close());
      return;
    }
    if (!opened) {
      _say(l10n.presenterNoExternalDisplay);
      return;
    }
    _audienceClosed = link.closed.listen((_) {
      if (!mounted) return;
      _dropAudience();
      _say(context.l10n.presenterAudienceClosed);
    });
    _audienceKeys = link.keys.listen(_onPresenterKey);
    setState(() {
      _audience = link;
      _audienceBlank = false;
      _presenterPanel = true;
      _lastScene = null;
      _sentPictures.clear();
    });
    if (!_presentMode) {
      _togglePresent();
    } else {
      _refitSoon();
    }
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      _say(l10n.presenterAudienceOpened);
    }
    await _loadPresenterNotes();
    _syncAudience();
  }

  Future<void> _closeAudience() async {
    final link = _audience;
    if (link == null) return;
    _dropAudience();
    await link.close();
  }

  void _dropAudience() {
    _audienceClosed?.cancel();
    _audienceKeys?.cancel();
    _audienceClosed = null;
    _audienceKeys = null;
    _liveTimer?.cancel();
    _liveQueued = null;
    if (mounted) {
      setState(() => _audience = null);
      _refitSoon();
    } else {
      _audience = null;
    }
  }

  /// Tombol clicker atau keyboard saat menyajikan — dari jendela ini atau
  /// dari jendela audiens yang sedang fokus.
  void _onPresenterKey(PresenterKey key) {
    if (!mounted || !_presentMode) return;
    switch (key) {
      case PresenterKey.next:
        _stepPage(1);
      case PresenterKey.previous:
        _stepPage(-1);
      case PresenterKey.blank:
        if (_audience != null) setState(() => _audienceBlank = !_audienceBlank);
      case PresenterKey.exit:
        if (_pointerMode) {
          _togglePointer();
        } else if (!_penMode) {
          _togglePresent();
        }
    }
  }

  /// Tombol clicker dan papan ketik selama menyajikan, kecuali saat sedang
  /// mengetik — spasi di catatan presenter bukan "slide berikutnya".
  ///
  /// Dipasang di [HardwareKeyboard], bukan di pohon fokus. Terbukti di
  /// tablet: setelah tombol di layar diketuk, tidak ada widget yang memegang
  /// fokus, dan Page Down dari clicker Bluetooth hilang begitu saja. Penangan
  /// global juga mendahului penampil PDF, yang tanpa ini memakai panah dan
  /// Page Down untuk menggulir setengah halaman.
  bool _onPresentKey(KeyEvent event) {
    if (!mounted || !_presentMode || event is KeyUpEvent) return false;
    // Hanya saat pembaca ini yang terlihat, bukan dialog di atasnya.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null && focus.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
      return false;
    }
    final key = presenterKeyFor(event.logicalKey);
    if (key == null) return false;
    if (event is KeyDownEvent) _onPresenterKey(key);
    return true;
  }

  /// Mengirim isi slide sekarang ke layar audiens bila ada yang berubah.
  ///
  /// Dipanggil setelah setiap susun ulang: semua yang tampil di slide — ganti
  /// halaman, anotasi baru, goresan, warna halaman — selalu berakhir dengan
  /// setState, jadi tidak ada perubahan yang terlewat, dan yang tidak
  /// berubah tidak dikirim.
  void _syncAudience() {
    final link = _audience;
    if (link == null || !mounted) return;
    final annotations = _onPage(_currentPage);
    final missing = <String, Uint8List>{};
    for (final a in annotations) {
      final file = PagePicture.fileOf(a);
      if (file == null || _sentPictures.contains(file)) continue;
      final bytes = _pictureBytes[file];
      if (bytes != null) missing[file] = bytes;
    }
    if (missing.isNotEmpty) {
      _sentPictures.addAll(missing.keys);
      unawaited(link.send(AudienceMessage.pictures(missing)));
    }
    final scene = AudienceMessage.scene(
      AudienceState(
        path: _path,
        page: _currentPage,
        annotations: annotations,
        pending: _inkPage == _currentPage ? List<InkPath>.of(_pendingInk) : const <InkPath>[],
        pendingColor: _color,
        pendingWidth: _inkWidth,
        tint: _tint.name,
        blank: _audienceBlank,
      ),
    );
    final encoded = jsonEncode(scene);
    if (encoded == _lastScene) return;
    _lastScene = encoded;
    unawaited(link.send(scene));
  }

  /// Goresan yang sedang ditarik di [page], titik PDF bergantian x, y.
  void _sendLive(int page, List<double> points) {
    if (_audience == null || page != _currentPage) return;
    _liveQueued = (page: page, points: points);
    const gap = Duration(milliseconds: 33);
    final wait = gap - DateTime.now().difference(_liveSentAt);
    if (points.isEmpty || wait <= Duration.zero) {
      _flushLive();
    } else {
      _liveTimer ??= Timer(wait, _flushLive);
    }
  }

  void _flushLive() {
    _liveTimer?.cancel();
    _liveTimer = null;
    final queued = _liveQueued;
    final link = _audience;
    if (queued == null || link == null) return;
    _liveQueued = null;
    _liveSentAt = DateTime.now();
    final erasing = _erasing || _stylusErase;
    unawaited(
      link.send(
        AudienceMessage.live(
          points: queued.points,
          color: erasing ? '#80808066' : _color,
          width: erasing ? math.max(12, _inkWidth * 3) : _inkWidth,
        ),
      ),
    );
  }

  /// Goresan stylus yang ditangkap di atas penampil, untuk layar audiens.
  void _sendStylusLive() {
    final page = _stylusPage;
    if (_audience == null || page == null) return;
    final rect = _pageRects[page];
    final size = _pageSizes[page];
    if (rect == null || size == null || rect.isEmpty || size.isEmpty) return;
    final sx = rect.width / size.width;
    final sy = rect.height / size.height;
    _sendLive(page, <double>[
      for (final o in _stylusLive) ...<double>[o.dx / sx, size.height - o.dy / sy],
    ]);
  }

  void _togglePointer() {
    if (_penMode) unawaited(_togglePen());
    // Tanpa SnackBar: ia menutupi bilah menyajikan di bawah selama
    // beberapa detik, padahal tombol penunjuknya sendiri sudah menyala.
    // Anotasi terpilih dilepas: gagang geser dan bilah aksinya menutupi
    // slide yang sedang ditunjuk.
    setState(() {
      _pointerMode = !_pointerMode;
      if (_pointerMode) _selectedAnnotationKey = null;
    });
    if (!_pointerMode) _hidePointer();
  }

  /// Penunjuk pindah ke titik [local] di penampil.
  void _movePointer(Offset local) {
    final pages = _controller.isReady
        ? <int>[_currentPage, for (var i = 1; i <= _controller.pages.length; i++) i]
        : _pageRects.keys.toList();
    for (final page in pages) {
      final rect = _pageRectNow(page);
      if (rect == null || rect.isEmpty || !rect.contains(local)) continue;
      _pointer.moveTo(
        page,
        Offset((local.dx - rect.left) / rect.width, (local.dy - rect.top) / rect.height),
      );
      _sendPointer();
      return;
    }
    _hidePointer();
  }

  void _hidePointer() {
    if (_pointer.head == null) return;
    _pointer.hide();
    _sendPointer();
  }

  void _sendPointer() {
    final link = _audience;
    if (link != null) unawaited(link.send(_pointer.toMessage()));
  }

  Future<void> _setPointerTrail(int milliseconds) async {
    _pointer.trail = Duration(milliseconds: milliseconds);
    _sendPointer();
    await ref.read(workspaceControllerProvider.notifier).setPointerTrail(milliseconds);
  }

  /// Tempat catatan presenter dokumen ini: di repositori untuk paper
  /// library dan PDF catatan (ikut tersinkron), di perangkat untuk PDF lepas.
  PresenterNotesStore _presenterNotesStore() {
    if (!widget.isStandalone) {
      final root = ref.read(workspaceControllerProvider).settings.activeProfile?.localPath;
      if (root != null && root.isNotEmpty && widget.attachmentKey.isNotEmpty) {
        return PresenterNotesStore.forLibrary(repoRoot: root, attachmentKey: widget.attachmentKey);
      }
    }
    final annotationsFile = widget.annotationsFile;
    if (annotationsFile != null) return PresenterNotesStore.forNote(annotationsFile);
    return PresenterNotesStore.forLooseFile(widget.filePath);
  }

  Future<void> _loadPresenterNotes() async {
    final store = _notesStore ??= _presenterNotesStore();
    final notes = await store.load();
    if (mounted) setState(() => _presenterNotes = notes);
  }

  void _setPresenterNote(String text) {
    _presenterNotes[_currentPage] = text;
    _notesSave?.cancel();
    _notesSave = Timer(const Duration(milliseconds: 800), _writePresenterNotes);
  }

  Future<void> _writePresenterNotes() async {
    final store = _notesStore;
    if (store == null) return;
    final message = l10n.presenterNotesChanged(widget.title);
    try {
      await store.save(_presenterNotes);
    } on Object catch (e) {
      if (mounted) _say(l10n.presenterNotesSaveFailed('$e'));
      return;
    }
    // Satu catatan perubahan per pembukaan, bukan satu per ketikan.
    if (!store.synced || _notesChangeRecorded) return;
    _notesChangeRecorded = true;
    if (!widget.isStandalone) {
      await _workspace.commitChange(message);
    } else {
      await widget.onAnnotationsChanged?.call(message);
    }
  }

  /// Tata letak mode menyajikan: satu halaman per layar.
  static PdfPageLayout _presentLayout(List<PdfPage> pages, PdfViewerParams params) {
    final width = pages.fold(0.0, (w, page) => math.max(w, page.width));
    final gap = pages.fold(0.0, (h, page) => math.max(h, page.height));

    final layouts = <Rect>[];
    var y = gap / 2;
    for (final page in pages) {
      layouts.add(Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height));
      y += page.height + gap;
    }
    // Lebarnya **tidak** dilebihkan. Dokumen yang lebih lebar dari halamannya
    // membuat pemasangan awal memilih zum yang mengecilkan halaman — halaman
    // pertama mendarat kecil dengan ruang gelap di sekelilingnya, dan itu
    // keluhan yang sudah terbukti.
    return PdfPageLayout(pageLayouts: layouts, documentSize: Size(width, y + gap / 2));
  }

  /// Memasang halaman yang sedang dilihat pas di layar.
  ///
  /// `PdfPageAnchor.all` memaksa seluruh halaman masuk — bukan lebarnya saja.
  /// Menyajikan berarti orang melihat dari jauh; halaman yang terpotong di
  /// bawah adalah kalimat yang hilang.
  Future<void> _fitCurrentPage([int? pageNumber]) async {
    if (!_controller.isReady) return;
    final page = pageNumber ?? _currentPage;

    // Lewat `goToArea`, bukan `goToPage`: `goToPage` membatasi zumnya pada zum
    // yang sedang berlaku (`zoomMax: _currentZoom` di dalam pdfrx), jadi
    // halaman yang sedang kecil tidak pernah bisa membesar untuk memenuhi
    // layar. Yang diminta "pas satu halaman ke layar" memang harus boleh
    // memperbesar.
    try {
      final rect = _controller.layout.pageLayouts[page - 1];
      await _controller.goToArea(rect: rect.inflate(6), anchor: PdfPageAnchor.all);
    } on Object {
      await _controller.goToPage(pageNumber: page, anchor: PdfPageAnchor.all);
    }
  }

  /// Pindah [delta] halaman, berhenti di ujungnya.
  Future<void> _stepPage(int delta) async {
    if (!_controller.isReady) return;
    final target = _currentPage + delta;
    if (target < 1 || target > _controller.pages.length) return;
    _stepCount++;
    await _controller.goToPage(pageNumber: target, anchor: _presentMode ? PdfPageAnchor.all : null);
    // Sekali lagi setelah halamannya berganti: halaman yang ukurannya berbeda
    // dari halaman sebelumnya — lembar kosong mendatar di antara halaman tegak,
    // misalnya — harus ikut dipaskan penuh layar, bukan mewarisi zum lama.
    //
    // Ke halaman tujuan, bukan ke [_currentPage]: penampil baru mengabarkan
    // halaman barunya sesudah ini, dan memaskan halaman lama membuat
    // "mundur" melompat kembali ke slide semula.
    if (_presentMode) await _fitCurrentPage(target);
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
          ? context.l10n.readerPageColorInverted(next.label)
          : context.l10n.readerPageColor(next.label),
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
      if (mounted) _say(context.l10n.readerResumedAtPage(previous.lastPage));
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
    _say(context.l10n.readerTapToPlaceSignature);
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

  /// Dinaikkan untuk memuat ulang penampil setelah berkas yang sama ditimpa.
  int _reloadToken = 0;

  /// Langkah-langkah yang masih bisa diurungkan, yang terbaru di belakang.
  ///
  /// Sebelumnya urungkan hanya ada selama beberapa detik di dalam snackbar —
  /// dan tidak ada sama sekali pada PDF yang dibuka lepas, yang justru tempat
  /// tanda tangan dan isian formulir dipakai. Sekali salah taruh, satu-satunya
  /// jalan adalah mencarinya di daftar dan menghapusnya.
  final List<_UndoStep> _undoSteps = <_UndoStep>[];

  /// Langkah yang baru diurungkan, untuk diulangi lagi.
  ///
  /// Setiap langkah mencatat keadaan anotasinya sebelum dan sesudah — bukan
  /// hanya cara membatalkannya — jadi mengulangi sama mudahnya dengan
  /// mengurungkan. Perubahan baru mengosongkannya, seperti di aplikasi lain:
  /// mengulangi sesuatu di atas keadaan yang sudah berbeda hanya membingungkan.
  final List<_UndoStep> _redoSteps = <_UndoStep>[];

  void _recordChange(
    String label, {
    required ZoteroAnnotation? before,
    required ZoteroAnnotation? after,
  }) {
    setState(() {
      _undoSteps.add(_UndoStep(label, before: before, after: after));
      // Dua puluh langkah sudah lebih dari yang diingat siapa pun.
      if (_undoSteps.length > 20) _undoSteps.removeAt(0);
      _redoSteps.clear();
    });
  }

  Future<void> _undoLast() async {
    if (_undoSteps.isEmpty) return;
    final step = _undoSteps.removeLast();
    setState(() => _redoSteps.add(step));
    await _applyState(step.key, step.before);
    if (mounted) _say(context.l10n.readerUndone(step.label));
  }

  Future<void> _redoLast() async {
    if (_redoSteps.isEmpty) return;
    final step = _redoSteps.removeLast();
    setState(() => _undoSteps.add(step));
    await _applyState(step.key, step.after);
    if (mounted) _say(context.l10n.readerRedone(step.label));
  }

  /// Membuat anotasi [key] menjadi [target]: dihapus bila null, ditambahkan
  /// bila belum ada, diganti bila sudah.
  Future<void> _applyState(String key, ZoteroAnnotation? target) async {
    final current = _annotations.where((a) => a.key == key).firstOrNull;
    if (target == null) {
      if (current != null) await _removeAnnotation(current);
      return;
    }
    await _persist(target, isNew: current == null, recordUndo: false);
  }

  /// True when writing back over [widget.filePath] would achieve nothing.
  ///
  /// Android's file picker hands the app a **copy in its own cache**, not the
  /// file the person chose. Overwriting that copy looks like it worked and
  /// changes nothing they can see, so on Android saving always goes through
  /// the system's save dialog instead.
  bool get _canWriteInPlace {
    if (Platform.isAndroid || Platform.isIOS) return false;
    // Lampiran paper dari library tidak pernah ditimpa. Menimpanya berarti
    // anotasinya dileburkan ke halaman — di Zotero muncul dua kali, sekali
    // sebagai gambar di halaman dan sekali sebagai anotasi — dan salinan
    // `.asli.pdf` yang ditaruh di sebelahnya adalah berkas asing di dalam
    // struktur yang dijaga plugin sinkronisasi. Paper library disimpan sebagai
    // PDF baru, di folder kerja.
    if (!widget.isStandalone) return false;
    final path = widget.filePath;
    return !path.contains('/cache/') && !path.contains('/file_picker/');
  }

  /// Berkas tempat "Simpan" menulis, setelah sekali disimpan-sebagai.
  ///
  /// Simpan yang pertama selalu menanyakan nama dan tempat: berkas yang dibuka
  /// tidak pernah ditimpa diam-diam, karena melebur coretan ke halaman tidak
  /// bisa dibalik. Sesudahnya Simpan langsung menimpa berkas hasil itu —
  /// dibangun ulang dari berkas asli ditambah semua anotasi, jadi coretan
  /// tidak pernah tergambar dua kali.
  String? _savedAs;

  /// Menyimpan PDF beranotasi: ke [_savedAs] bila sudah ada, selain itu lewat
  /// Simpan sebagai. Mengembalikan true bila benar-benar tersimpan.
  Future<bool> _savePdf() async {
    // Goresan yang belum jadi anotasi ikut disimpan lebih dulu. Tanpa ini,
    // menyimpan sambil pena masih aktif menghasilkan berkas tanpa coretan yang
    // baru saja dibuat — dan yang menyimpannya tidak akan tahu sampai
    // membukanya lagi.
    if (_pendingInk.isNotEmpty) await _saveInk();
    if (!mounted) return false;
    final target = _savedAs;
    if (target != null && File(target).parent.existsSync()) return _writePdfTo(target);
    return _savePdfAs();
  }

  /// Menanyakan nama dan tempat, lalu menyimpan ke sana.
  Future<bool> _savePdfAs() async {
    if (_pendingInk.isNotEmpty) await _saveInk();
    final work = await WorkFolder.choices();
    if (!mounted) return false;

    final desktop = !(Platform.isAndroid || Platform.isIOS);
    final folders = <SaveFolder>[
      if (_canWriteInPlace)
        SaveFolder(
          label: context.l10n.readerOriginalFolder(p.basename(p.dirname(widget.filePath))),
          path: p.dirname(widget.filePath),
        ),
      for (final folder in work) SaveFolder(label: WorkFolder.label(folder), path: folder.path),
    ];
    final savedAs = _savedAs;
    final choice = await showSaveAsDialog(
      context,
      initialName: savedAs != null
          ? p.basenameWithoutExtension(savedAs)
          : '${_fileStem(widget.title)}-terisi',
      folders: folders,
      initialFolder: savedAs != null ? p.dirname(savedAs) : folders.firstOrNull?.path,
      originalPath: widget.isStandalone ? widget.filePath : null,
      allowPickFolder: desktop,
    );
    if (choice == null || !mounted) return false;
    final path = choice.path;
    if (path == null) return _savePdfThroughDialog(choice.systemName!);
    return _writePdfTo(path);
  }

  /// Menulis PDF beranotasi ke [path] dan menjadikannya tujuan Simpan.
  Future<bool> _writePdfTo(String path) async {
    final overSource =
        SaveAsNames.samePath(path, widget.filePath) || SaveAsNames.samePath(path, _path);
    // Lampiran library tidak pernah ditimpa: anotasinya akan muncul dua kali
    // di Zotero, sekali di halaman dan sekali sebagai anotasi.
    if (overSource && !widget.isStandalone) {
      _say(context.l10n.readerCannotOverwriteAttachment);
      return false;
    }
    _say(context.l10n.readerPreparingPdf);
    try {
      final bytes = await _annotatedPdf();
      await File(path).writeAsBytes(bytes, flush: true);
      if (!mounted) return true;
      setState(() {
        _savedAs = path;
        _unsaved = false;
        if (overSource) {
          // Coretannya sekarang bagian halaman. Dibiarkan sebagai anotasi,
          // simpan berikutnya akan menggambarnya sekali lagi.
          _annotations = const <ZoteroAnnotation>[];
          _undoSteps.clear();
          _redoSteps.clear();
          _workingPath = null;
          _reloadToken++;
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(context.l10n.readerSavedFile(p.basename(path), _size(bytes.length))),
          ),
        );
      return true;
    } on Object catch (e) {
      _say(context.l10n.readerSaveFailed('$e'));
      return false;
    }
  }

  /// Lewat dialog simpan bawaan sistem — untuk tempat di luar jangkauan
  /// aplikasi. Jalurnya tidak bisa ditulis ulang nanti (di Android hanya
  /// berupa URI), jadi Simpan berikutnya menanyakan lagi.
  Future<bool> _savePdfThroughDialog(String fileName) async {
    _say(context.l10n.readerPreparingPdf);
    try {
      final bytes = await _annotatedPdf();
      if (!mounted) return false;
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: context.l10n.readerSavePdf,
      );
      if (uri == null) {
        _say(l10n.readerNotSaved);
        return false;
      }
      setState(() => _unsaved = false);
      _say(l10n.readerPdfSaved(_size(bytes.length)));
      return true;
    } catch (e) {
      _say(l10n.readerSaveFailed('$e'));
      return false;
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
      _say(context.l10n.readerNoLibraryOpen);
      return;
    }

    if (_unsaved) {
      _say(context.l10n.readerUnsavedNotIncluded);
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
              Text(
                context.l10n.readerAddToCollectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.readerAddToCollectionExplain,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: Text(context.l10n.readerNoCollection),
                subtitle: Text(context.l10n.readerNoCollectionHint),
                onTap: () => Navigator.of(context).pop(const _CollectionChoice(null)),
              ),
              // Koleksi yang dicari sering belum ada — dokumen kuliah hari ini
              // misalnya — dan menyuruh keluar ke pohon koleksi dulu berarti
              // kehilangan apa yang sedang dikerjakan.
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text(context.l10n.readerNewCollectionEllipsis),
                subtitle: Text(context.l10n.readerNewCollectionHint),
                onTap: () => Navigator.of(context).pop(const _CollectionChoice.create(null)),
              ),
              const Divider(),
              for (final collection in index.collections.values)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(collection.name),
                  subtitle: collection.path == collection.name ? null : Text(collection.path),
                  trailing: IconButton(
                    tooltip: context.l10n.readerNewSubcollectionIn(collection.name),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    onPressed: () =>
                        Navigator.of(context).pop(_CollectionChoice.create(collection.key)),
                  ),
                  onTap: () => Navigator.of(context).pop(_CollectionChoice(collection.key)),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;

    var collectionKey = chosen.key;
    if (chosen.create) {
      final parent = chosen.key == null ? null : index.collections[chosen.key];
      final name = await _askCollectionName(parent?.name);
      if (name == null || name.trim().isEmpty || !mounted) return;
      // Lewat jalur yang sama dengan pohon koleksi: satu-satunya penulis
      // collections.json, jadi koleksinya tetap terbaca oleh Zotero.
      collectionKey = await _workspace.createCollection(name: name.trim(), parentKey: chosen.key);
      if (!mounted) return;
      if (collectionKey == null) {
        _say(
          ref.read(workspaceControllerProvider).error ?? context.l10n.readerCreateCollectionFailed,
        );
        return;
      }
    }

    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: widget.title);
        return AlertDialog(
          title: Text(context.l10n.readerDocumentTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.readerCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(context.l10n.readerAdd),
            ),
          ],
        );
      },
    );
    if (title == null || title.trim().isEmpty || !mounted) return;

    _say(context.l10n.readerAddingToLibrary);
    final created = await _workspace.addPdfToLibrary(
      pdfPath: _path,
      title: title.trim(),
      collectionKey: collectionKey,
    );
    if (!mounted) return;
    if (created == null) {
      _say(ref.read(workspaceControllerProvider).error ?? context.l10n.readerAddFailed);
      return;
    }

    // Anotasinya ikut, dalam format Zotero di item barunya: catatan (PDF di
    // Catatan) bukan item Zotero, dan inilah jalan anotasinya terbaca di
    // Zotero. Gambar tempelan tidak ikut — isinya hanya ada di memori.
    final carried = _annotations.where((a) => !PagePicture.isPicture(a)).toList();
    var copied = 0;
    if (carried.isNotEmpty) {
      try {
        final detail = await ref.read(libraryRepositoryProvider).loadItem(created.itemFilePath);
        for (final annotation in carried) {
          final ok = await _workspace.saveAnnotation(
            item: detail.item,
            annotation: annotation.copyWith(parentItemKey: created.attachmentKey),
            isNew: true,
          );
          if (ok) copied++;
        }
      } on Object catch (e) {
        if (mounted) _say(context.l10n.readerAddedButAnnotationsFailed('$e'));
        return;
      }
    }
    if (!mounted) return;
    _say(
      carried.isEmpty
          ? context.l10n.readerAddedAs(created.itemKey)
          : context.l10n.readerAddedWithAnnotations(created.itemKey, copied),
    );
  }

  /// Menjadikan PDF ini buku catatan di folder kerja, lalu membukanya.
  ///
  /// Menunya sudah ada sejak buku catatan bisa dibuat dari PDF, tetapi tidak
  /// pernah disambungkan: pilihannya jatuh ke cabang bawaan dan malah
  /// membagikan PDF-nya. Berkas aslinya tidak disentuh.
  Future<void> _convertToNotebook() async {
    if (_unsaved) {
      _say(context.l10n.readerUnsavedNotIncluded);
    }
    _say(context.l10n.readerPreparingNotebook(widget.title));
    try {
      final folder = await WorkFolder.dir();
      final notePath = await PdfToNotebook.convert(
        pdfPath: _path,
        targetDir: folder.path,
        title: widget.title,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<String>(
          builder: (_) => NotebookScreen(path: notePath, title: NoteDocumentStore.stemOf(notePath)),
        ),
      );
    } on Object catch (e) {
      if (mounted) _say(context.l10n.readerNotebookFailed('$e'));
    }
  }

  Future<String?> _askCollectionName(String? parentName) => showDialog<String>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      return AlertDialog(
        title: Text(
          parentName == null
              ? context.l10n.readerNewCollection
              : context.l10n.readerSubcollectionIn(parentName),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: context.l10n.readerCollectionName,
            helperText: context.l10n.readerCollectionNameHelper,
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.readerCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.readerCreate),
          ),
        ],
      );
    },
  );

  /// Mencetak dokumen yang sedang dibuka.
  ///
  /// Dialog cetak Android juga memuat "Simpan sebagai PDF", jadi yang tidak
  /// punya pencetak tetap mendapat sesuatu yang berguna — itu sebabnya ini
  /// satu tombol, bukan dua.
  ///
  /// Yang dicetak adalah berkas apa adanya, termasuk halaman kosong yang
  /// ditambahkan. Anotasi yang belum disimpan belum menyatu dengan
  /// halamannya, jadi itu dikatakan dulu daripada mengejutkan di kertas.
  /// Mengubah teks PDF ini jadi dokumen Markdown yang bisa disunting.
  ///
  /// Hasilnya **tidak** ditulis di sebelah berkas aslinya: paper hidup di
  /// dalam ekspor Zotero, dan berkas asing di sana mengacaukan struktur yang
  /// dijaga plugin sinkronisasi. Markdown-nya karena itu mendarat di folder
  /// kerja aplikasi — tempat yang sama dengan papan tulis dan berkas lain
  /// yang dibuat sendiri.
  Future<void> _convertToMarkdown() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.readerReadingPageText)));
    try {
      final markdown = await PdfToMarkdown.fromFile(widget.filePath, title: widget.title);
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'readpaper'));
      await dir.create(recursive: true);

      final stem = p.basenameWithoutExtension(widget.filePath);
      var file = File(p.join(dir.path, '$stem.md'));
      for (var n = 2; file.existsSync() && n < 100; n++) {
        file = File(p.join(dir.path, '$stem-$n.md'));
      }
      await file.writeAsString(markdown, flush: true);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      final empty = markdown.trim().isEmpty || markdown.trim().split('\n').length <= 1;
      if (empty) {
        // PDF hasil pindaian tidak punya lapisan teks sama sekali. Mengatakan
        // "berhasil" untuk berkas yang isinya kosong hanya menunda kecewanya.
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.readerNoTextLayer), duration: Duration(seconds: 6)),
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute<String>(
          builder: (_) => MarkdownEditorScreen(path: file.path, title: widget.title),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.readerMarkdownFailed('$e'))));
    }
  }

  Future<void> _print() async {
    if (_unsaved) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.readerPrintWithoutLatest),
          content: Text(context.l10n.readerPrintExplain),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.readerCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.readerPrintAsIs),
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
      if (mounted) _say(context.l10n.readerPrintFailed('$e'));
    }
  }

  /// Menambahkan halaman kosong untuk dicoreti, seperti papan tulis yang
  /// menempel pada dokumennya.
  ///
  /// Halamannya disalin sebagai objek PDF, bukan digambar ulang jadi gambar:
  /// teks paper aslinya tetap bisa dicari dan disalin. Ditambahkan di akhir
  /// supaya nomor halaman anotasi yang sudah ada tidak bergeser.
  Future<void> _addBlankPages() async {
    // Dua pertanyaan, bukan satu: berapa, lalu di mana. Menambahkan di akhir
    // saja memaksa yang sedang menjelaskan melompat ke belakang dokumen, dan
    // catatan yang ditulis di sana kehilangan tempatnya dalam cerita.
    final pilihan = await showDialog<({int count, bool here})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.readerAddBlankPages),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(context.l10n.readerBlankPagesExplain),
          ),
          for (final n in <int>[1, 2, 5])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop((count: n, here: true)),
              child: Text(context.l10n.readerPagesAfter(n, _currentPage)),
            ),
          const Divider(height: 8),
          for (final n in <int>[1, 5])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop((count: n, here: false)),
              child: Text(context.l10n.readerPagesAtEnd(n)),
            ),
        ],
      ),
    );
    if (pilihan == null || !mounted) return;
    final count = pilihan.count;
    final at = pilihan.here ? _currentPage : null;

    try {
      final dir = await Directory(
        p.join((await getTemporaryDirectory()).path, 'papan'),
      ).create(recursive: true);
      final stem = p.basenameWithoutExtension(_path);
      final target = p.join(dir.path, '$stem-papan-${DateTime.now().millisecondsSinceEpoch}.pdf');

      await PdfPageEditor.addBlankPages(source: _path, target: target, count: count, at: at);

      final before = _controller.pages.length;
      if (!mounted) return;
      setState(() {
        _workingPath = target;
        _unsaved = true;
      });
      _say(
        at == null
            ? context.l10n.readerBlankPagesAdded(count)
            : context.l10n.readerBlankPagesInserted(count, at),
      );
      // Langsung ke halaman kosong pertamanya: yang menambahkannya hendak
      // menulis di sana sekarang, bukan mencarinya dulu.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final target1 = (at ?? before) + 1;
      if (_controller.isReady && target1 <= _controller.pages.length) {
        await _controller.goToPage(
          pageNumber: target1,
          anchor: _presentMode ? PdfPageAnchor.all : null,
        );
      }
    } on Object catch (e) {
      if (mounted) _say(context.l10n.readerAddPagesFailed('$e'));
    }
  }

  /// Renders every page with its annotations into one PDF.
  /// PDF berisi halaman aslinya dengan anotasi di atasnya.
  ///
  /// Halaman aslinya tidak dirender jadi gambar: teks tetap bisa dicari dan
  /// disalin, tabel tetap tabel, dan hanya coretan yang jadi gambar — sebagai
  /// vektor. Merender jadi gambar hanya jalan terakhir, untuk PDF yang tidak
  /// bisa dibuka pdfium untuk ditulisi (misalnya yang dienkripsi).
  Future<Uint8List> _annotatedPdf() async {
    try {
      await _loadPictures();
      return PdfPageEditor.withAnnotations(
        source: _path,
        annotationsFor: _onPage,
        pictures: _pictureBytes,
      );
    } on Object {
      _say(l10n.readerPdfSavedAsImages);
      return exportPagesAsPdf(
        pages: _controller.pages,
        annotationsFor: _onPage,
        scale: 2,
        pictures: _pictureImages,
      );
    }
  }

  Future<void> _shareAnnotated() async {
    _say(context.l10n.readerPreparingFile);
    try {
      final bytes = await _annotatedPdf();
      if (!mounted) return;
      // Shared from a temporary copy so the original is never handed out by
      // accident, and so an unsaved document can still be sent. Lewat fungsi
      // bersama supaya lembar bagikannya punya titik asal — wajib di iPad.
      final failure = await shareBytes(
        context,
        bytes,
        '${_fileStem(widget.title)}.pdf',
        title: widget.title,
      );
      if (failure != null) _say(failure);
    } catch (e) {
      _say(l10n.readerShareFailed('$e'));
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
          pictures: _pictureImages,
        );
        if (!mounted) return;

        final suffix = pages.length > 1 ? '-hal${pageNumber.toString().padLeft(3, '0')}' : '';
        final uri = await FilePicker.saveFile(
          fileName: '$base$suffix.${choice.format.extension}',
          bytes: bytes,
          mimeType: choice.format.mimeType,
          dialogTitle: context.l10n.readerSavePage(pageNumber),
        );
        // Cancelling one page cancels the rest; carrying on would mean a save
        // dialog per page with no way out.
        if (uri == null) break;
        saved++;
      }
    } catch (e) {
      _say(l10n.readerSaveImageError('$e'));
      return;
    }

    _say(saved == 0 ? l10n.readerNothingSaved : l10n.readerFilesSaved(saved));
  }

  /// Writes the chosen pages into one annotated PDF.
  Future<void> _exportPdf({
    required List<int> pages,
    required String base,
    required double scale,
  }) async {
    _say(
      pages.length == 1
          ? context.l10n.readerPreparingPdf
          : context.l10n.readerPreparingPdfPages(pages.length),
    );
    try {
      final bytes = await exportPagesAsPdf(
        pages: <PdfPage>[for (final n in pages) _controller.pages[n - 1]],
        annotationsFor: _onPage,
        scale: scale,
        pictures: _pictureImages,
      );
      if (!mounted) return;
      final uri = await FilePicker.saveFile(
        fileName: '$base-beranotasi.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: context.l10n.readerSaveAnnotatedCopy,
      );
      _say(uri == null ? l10n.readerNotSaved : l10n.readerPdfSaved(_size(bytes.length)));
    } catch (e) {
      _say(l10n.readerPdfFailed('$e'));
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

  /// Sudah dijawab "keluar" — PopScope tidak boleh menahan lagi.
  bool _leaving = false;

  late final AppLifecycleListener _exitListener = AppLifecycleListener(
    // Menutup jendela di desktop juga keluar, dan sama hilangnya.
    onExitRequested: () async =>
        await _confirmLeave() ? AppExitResponse.exit : AppExitResponse.cancel,
  );

  /// Ada yang hilang bila keluar sekarang: goresan yang belum jadi anotasi,
  /// atau — untuk PDF lepas — anotasi yang hanya hidup di memori. Anotasi
  /// paper library sudah tersimpan ke library begitu dibuat.
  bool get _hasUnsavedWork => _pendingInk.isNotEmpty || (widget.isStandalone && _unsaved);

  /// Menanyakan apa yang dilakukan dengan perubahan sebelum keluar. True
  /// berarti boleh keluar.
  Future<bool> _confirmLeave() async {
    if (_leaving || !_hasUnsavedWork || !mounted) return true;
    final standalone = widget.isStandalone && (_unsaved || (!_autoSaves && _pendingInk.isNotEmpty));
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.save_outlined),
        title: Text(context.l10n.readerSaveChangesFirst),
        content: Text(
          standalone
              ? context.l10n.readerUnsavedStandalone(widget.title)
              : context.l10n.readerUnsavedStrokes,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.readerCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('buang'),
            child: Text(context.l10n.readerLeaveWithoutSaving),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('simpan'),
            child: Text(
              standalone && _savedAs == null
                  ? context.l10n.readerSaveEllipsis
                  : context.l10n.readerSave,
            ),
          ),
        ],
      ),
    );
    if (choice == 'buang') return true;
    if (choice != 'simpan' || !mounted) return false;
    if (!standalone) {
      await _saveInk();
      return true;
    }
    return _savePdf();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_audience != null) WidgetsBinding.instance.addPostFrameCallback((_) => _syncAudience());
    // Portrait on a tablet is still ~960dp: wide enough for a docked panel,
    // but the page itself wants that width more, so the panel stays a drawer
    // until the window is genuinely wide.
    final isWide = LayoutSize.of(context) == LayoutSize.expanded;

    final tools = <Widget>[
      IconButton(
        tooltip: context.l10n.findTooltip,
        isSelected: _finding,
        icon: const Icon(Icons.search),
        onPressed: _loading ? null : (_finding ? _closeFind : _openFind),
      ),
      // Labelled on purpose: a bare icon left people swiping at the page
      // and wondering why nothing was marked. Di desktop juga: memblok teks
      // lalu mencari bilah stabilo tidak pernah ditemukan di Windows, jadi
      // "Tandai" — seret mouse di atas teks, langsung berwarna — ada di semua
      // platform.
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
          icon: Icon(_markerMode ? Icons.border_color : Icons.border_color_outlined, size: 18),
          label: Text(_markerMode ? context.l10n.readerMarking : context.l10n.readerMark),
        ),
      ),
      IconButton(
        tooltip: _noteMode ? context.l10n.readerTapToPlaceNote : context.l10n.readerPlaceNote,
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
        tooltip: _penMode ? context.l10n.readerDoneDrawing : context.l10n.readerDrawOnPage,
        isSelected: _penMode,
        selectedIcon: const Icon(Icons.draw),
        icon: const Icon(Icons.draw_outlined),
        onPressed: _togglePen,
      ),
      _ColorButton(
        color: _color,
        onSelected: (value) => _switchPen(color: value),
      ),
      IconButton(
        tooltip: _textMode ? context.l10n.readerTapToPlaceText : context.l10n.readerFillText,
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
            ? context.l10n.readerKeepScreenOnActive
            : context.l10n.readerKeepScreenOn,
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
            _say(value ? l10n.readerKeepScreenOnEnabled : l10n.readerKeepScreenOnDisabled);
          }
        },
      ),
      IconButton(
        tooltip: context.l10n.readerPresent,
        icon: const Icon(Icons.slideshow_outlined),
        onPressed: _togglePresent,
      ),
      IconButton(
        tooltip: _undoSteps.isEmpty
            ? context.l10n.readerNothingToUndo
            : context.l10n.readerUndoStep(_undoSteps.last.label),
        icon: const Icon(Icons.undo),
        onPressed: _undoSteps.isEmpty ? null : _undoLast,
      ),
      IconButton(
        tooltip: _redoSteps.isEmpty
            ? context.l10n.readerNothingToRedoYet
            : context.l10n.readerRedoStep(_redoSteps.last.label),
        icon: const Icon(Icons.redo),
        onPressed: _redoSteps.isEmpty ? null : _redoLast,
      ),
      _pictureButton(),
      IconButton(
        tooltip: context.l10n.readerSignature,
        isSelected: _pendingSignature != null,
        selectedIcon: const Icon(Icons.draw),
        icon: const Icon(Icons.gesture),
        onPressed: _loading ? null : _drawSignature,
      ),
      PopupMenuButton<String>(
        tooltip: context.l10n.readerSaveAndShare,
        icon: const Icon(Icons.ios_share),
        onSelected: (choice) => switch (choice) {
          'simpan' => _savePdf(),
          'simpan-sebagai' => _savePdfAs(),
          'ekspor' => _exportImages(),
          'halaman-kosong' => _addBlankPages(),
          'cetak' => _print(),
          'ke-markdown' => _convertToMarkdown(),
          'ke-koleksi' => _addToCollection(),
          'ke-catatan' => _convertToNotebook(),
          _ => _shareAnnotated(),
        },
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          if (widget.isStandalone)
            PopupMenuItem<String>(
              value: 'ke-koleksi',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.library_add_outlined),
                title: Text(context.l10n.readerAddToCollectionMenu),
                subtitle: Text(context.l10n.readerAddToCollectionMenuHint),
              ),
            ),
          PopupMenuItem<String>(
            value: 'cetak',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.print_outlined),
              title: Text(context.l10n.readerPrintMenu),
              subtitle: Text(context.l10n.readerPrintMenuHint),
            ),
          ),
          PopupMenuItem<String>(
            value: 'ke-markdown',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.notes_outlined),
              title: Text(context.l10n.readerToMarkdown),
              subtitle: Text(context.l10n.readerToMarkdownHint),
            ),
          ),
          PopupMenuItem<String>(
            value: 'ke-catatan',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.auto_stories_outlined),
              title: Text(context.l10n.readerToNotebook),
              subtitle: Text(context.l10n.readerToNotebookHint),
            ),
          ),
          PopupMenuItem<String>(
            value: 'halaman-kosong',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.note_add_outlined),
              title: Text(context.l10n.readerAddBlankPages),
              subtitle: Text(context.l10n.readerBlankPagesMenuHint),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'simpan',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.save_outlined),
              title: Text(
                _savedAs == null ? context.l10n.readerSaveEllipsis : context.l10n.readerSave,
              ),
              subtitle: Text(
                _savedAs == null
                    ? context.l10n.readerSaveMenuHintNew
                    : context.l10n.readerSaveMenuHintTo(p.basename(_savedAs!)),
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'simpan-sebagai',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.save_as_outlined),
              title: Text(context.l10n.readerSaveAsMenu),
              subtitle: Text(context.l10n.readerSaveAsMenuHint),
            ),
          ),
          PopupMenuItem<String>(
            value: 'ekspor',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.image_outlined),
              title: Text(context.l10n.readerExportPagesMenu),
              subtitle: Text(context.l10n.readerExportPagesMenuHint),
            ),
          ),
          PopupMenuItem<String>(
            value: 'bagikan',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.share_outlined),
              title: Text(context.l10n.readerShare),
              subtitle: Text(context.l10n.readerShareHint),
            ),
          ),
        ],
      ),
      IconButton(
        // Penolak telapak tangan. Tangan yang bertumpu di layar sambil menulis
        // dengan stylus dulu meninggalkan garisnya sendiri, dan itu cukup untuk
        // membuat orang berhenti memakai penanya.
        tooltip: _stylusOnly
            ? context.l10n.readerStylusOnlyTooltip
            : context.l10n.readerFingerAndStylusTooltip,
        isSelected: _stylusOnly,
        selectedIcon: const Icon(Icons.do_not_touch_outlined),
        icon: const Icon(Icons.touch_app_outlined),
        onPressed: () => _setStylusOnly(!_stylusOnly),
      ),
      IconButton(
        // Dulu hanya ada di dalam menu simpan, dan di situ tidak ada yang
        // mencarinya: yang mau menambah lembar catatan tidak sedang berpikir
        // tentang menyimpan.
        tooltip: context.l10n.readerAddBlankSheet,
        icon: const Icon(Icons.note_add_outlined),
        onPressed: _loading ? null : _addBlankPages,
      ),
      IconButton(
        tooltip: context.l10n.readerPageColor(_tint.label),
        icon: Icon(_tint.icon),
        onPressed: _cycleTint,
      ),
      IconButton(
        tooltip: context.l10n.readerReadMode,
        icon: const Icon(Icons.fullscreen),
        onPressed: _loading ? null : _toggleReadingMode,
      ),
      IconButton(
        tooltip: context.l10n.readerSaveAnnotatedCopyFormats,
        icon: const Icon(Icons.image_outlined),
        onPressed: _loading ? null : _exportImages,
      ),
      IconButton(
        tooltip: context.l10n.readerZoomOut,
        icon: const Icon(Icons.zoom_out),
        onPressed: () => _controller.zoomDown(),
      ),
      IconButton(
        tooltip: context.l10n.readerZoomIn,
        icon: const Icon(Icons.zoom_in),
        onPressed: () => _controller.zoomUp(),
      ),
      IconButton(
        tooltip: context.l10n.readerAnnotationPanel,
        icon: Badge(
          isLabelVisible: !isWide && _annotations.isNotEmpty,
          label: Text('${_annotations.length}'),
          child: Icon(_showSidebar && isWide ? Icons.view_sidebar : Icons.view_sidebar_outlined),
        ),
        // Wide layouts dock the panel; a phone opens it as a drawer.
        onPressed: isWide
            ? () => setState(() => _showSidebar = !_showSidebar)
            : () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      const SizedBox(width: 4),
    ];

    // Ctrl+Z dan Ctrl+Shift+Z / Ctrl+Y di desktop — ⌘ di Mac. Di layar sentuh
    // tombolnya yang dipakai, tetapi di papan ketik tangan sudah mencari
    // pintasan ini sebelum mencari ikonnya.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undoAny,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undoAny,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () =>
            _redoAction?.call(),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): () =>
            _redoAction?.call(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () => _redoAction?.call(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _savePdf,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _savePdf,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openFind,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openFind,
        const SingleActivator(LogicalKeyboardKey.f3): () => _finding ? _stepMatch(1) : _openFind(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): _savePdfAs,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true): _savePdfAs,
        // Salin, potong, tempel anotasi. Tanpa anotasi terpilih, Ctrl+C tetap
        // menyalin teks yang diblok, seperti biasa.
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copyShortcut,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): _copyShortcut,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true): _cutAnnotation,
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true): _cutAnnotation,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _pasteAny,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _pasteAny,
        const SingleActivator(LogicalKeyboardKey.delete): () {
          final selected = _selectedAnnotation;
          if (selected != null) _deleteAnnotation(selected);
        },
      },
      child: PopScope(
        // Keluar dengan coretan yang belum disimpan dulu berarti semuanya
        // hilang tanpa sepatah kata pun.
        canPop: _leaving || !_hasUnsavedWork,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (!await _confirmLeave() || !mounted) return;
          setState(() => _leaving = true);
          Navigator.of(this.context).pop();
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
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
                                  '${_controller.isReady ? context.l10n.readerStatusOf(_annotations.length, _currentPage, _controller.pages.length) : context.l10n.readerStatus(_annotations.length, _currentPage)}',
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
                    // Di layar sempit tombolnya pindah ke baris sendiri di bawah judul.
                    // Sebelumnya semuanya berdesakan di kanan judul, dan AppBar
                    // memberi judul kotak tetap: keterangan dokumen — jumlah anotasi
                    // dan nomor halaman — tertutup tombol-tombol di atasnya.
                    actions: isWide ? tools : const <Widget>[],
                    bottom: isWide
                        ? null
                        : PreferredSize(
                            preferredSize: const Size.fromHeight(50),
                            child: SizedBox(
                              height: 50,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(children: tools),
                              ),
                            ),
                          ),
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
                      if (_finding)
                        FindBar(
                          initialQuery: _findQuery,
                          current: _searcher?.currentIndex == null
                              ? null
                              : _searcher!.currentIndex! + 1,
                          total: _findQuery.trim().isEmpty
                              ? null
                              : (_searcher?.matches.length ?? 0),
                          searching: _searcher?.isSearching ?? false,
                          onChanged: _find,
                          onNext: () => _stepMatch(1),
                          onPrevious: () => _stepMatch(-1),
                          onClose: _closeFind,
                        ),
                      if (_showCoach &&
                          !_markerMode &&
                          !_noteMode &&
                          !_readingMode &&
                          !_presentMode)
                        Material(
                          color: scheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.l10n.readerCoachMark,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  iconSize: 18,
                                  tooltip: context.l10n.readerGotIt,
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
                                Icon(
                                  Icons.border_color,
                                  size: 18,
                                  color: scheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isTouchPlatform
                                        ? context.l10n.readerMarkingBannerTouch(
                                            AnnotationPalette.names[_color] ?? _color.toLowerCase(),
                                          )
                                        : context.l10n.readerMarkingBannerMouse(
                                            AnnotationPalette.names[_color] ?? _color.toLowerCase(),
                                          ),
                                    style: TextStyle(
                                      color: scheme.onTertiaryContainer,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                _ColorButton(
                                  color: _color,
                                  onSelected: (value) => _switchPen(color: value),
                                ),
                                TextButton(
                                  onPressed: () => setState(() => _markerMode = false),
                                  child: Text(context.l10n.readerDone),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Saat menyajikan, alat pena pindah ke bilah bawah. Di atas
                      // sini, tanpa AppBar dan dengan mode imersif, bilah ini duduk
                      // di bawah bilah status dan lubang kamera: Selesai dan Buang di
                      // ujung kanannya terlihat, tetapi sentuhannya diambil sistem.
                      if (_penMode && !_presentMode)
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
                                    _erasing
                                        ? context.l10n.readerEraserBanner
                                        : _pendingInk.isEmpty
                                        ? context.l10n.readerPenBanner
                                        : context.l10n.readerPenPending(
                                            _pendingInk.length,
                                            _inkPage ?? 1,
                                          ),
                                    style: TextStyle(
                                      color: scheme.onPrimaryContainer,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                _WidthButton(
                                  width: _inkWidth,
                                  onSelected: (value) => _switchPen(width: value),
                                ),
                                // Lewat _switchPen, sama seperti tombol warna di
                                // bilah atas: inilah tombol yang benar-benar dipakai
                                // orang **sambil** menggambar, dan mengganti warna di
                                // sini tanpa menutup goresan yang sedang terkumpul
                                // akan mewarnai ulang semuanya.
                                _ColorButton(
                                  color: _color,
                                  colors: AnnotationPalette.inkColors,
                                  onSelected: (value) => _switchPen(color: value),
                                ),
                                _whiteInkButton(),
                                _eraserButton(),
                                _pictureButton(),
                                IconButton(
                                  tooltip: context.l10n.readerUndoLastStroke,
                                  iconSize: 20,
                                  icon: const Icon(Icons.undo),
                                  onPressed: _pendingInk.isEmpty ? null : _undoStroke,
                                ),
                                IconButton(
                                  tooltip: _redoTooltip,
                                  iconSize: 20,
                                  icon: const Icon(Icons.redo),
                                  onPressed: _redoAction,
                                ),
                                IconButton(
                                  tooltip: context.l10n.readerDiscardStrokes,
                                  iconSize: 20,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: _pendingInk.isEmpty ? null : _discardInk,
                                ),
                                TextButton(
                                  onPressed: _togglePen,
                                  child: Text(context.l10n.readerDone),
                                ),
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
                                    context.l10n.readerTapWhereNote,
                                    style: TextStyle(
                                      color: scheme.onSecondaryContainer,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() => _noteMode = false),
                                  child: Text(context.l10n.readerCancel),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Expanded(child: _buildViewer(scheme)),
                            if (_presentMode && _audience != null && _presenterPanel) ...<Widget>[
                              const VerticalDivider(width: 1),
                              SizedBox(
                                width: math.min(380, MediaQuery.sizeOf(context).width * 0.34),
                                child: PresenterPanel(
                                  document: _controller.isReady ? _controller.document : null,
                                  currentPage: _currentPage,
                                  nextAnnotations: _onPage(_currentPage + 1),
                                  pictures: _pictureImages,
                                  notes: _presenterNotes[_currentPage] ?? '',
                                  onNotesChanged: _setPresenterNote,
                                  blank: _audienceBlank,
                                  onToggleBlank: () =>
                                      setState(() => _audienceBlank = !_audienceBlank),
                                  onHide: () {
                                    setState(() => _presenterPanel = false);
                                    _refitSoon();
                                  },
                                  onCloseAudience: _closeAudience,
                                  onNext: () => _stepPage(1),
                                ),
                              ),
                            ],
                            if (_showSidebar &&
                                isWide &&
                                !_readingMode &&
                                !_presentMode) ...<Widget>[
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
          ),
        ),
      ),
    );
  }

  /// Urungkan yang berlaku sekarang: goresan tertunda lebih dulu.
  void _undoAny() {
    if (_pendingInk.isNotEmpty) {
      _undoStroke();
    } else if (_undoSteps.isNotEmpty) {
      _undoLast();
    }
  }

  /// Peristiwa ini milik pena stylus, bukan tangan.
  ///
  /// Tetikus ikut dihitung supaya layar ini masih bisa dicoba di desktop.
  bool _drawsWithStylus(PointerEvent event) =>
      _penMode &&
      _stylusOnly &&
      (event.kind == PointerDeviceKind.stylus ||
          event.kind == PointerDeviceKind.invertedStylus ||
          event.kind == PointerDeviceKind.mouse);

  /// Kotak halaman [pageNumber] di layar **saat ini**.
  ///
  /// Dihitung dari tata letak dan zum yang sedang berlaku, bukan diambil dari
  /// [_pageRects] begitu saja. Kotak di sana dicatat saat lapisan halaman
  /// dibangun, dan halaman yang sudah keluar layar tidak pernah dibangun lagi
  /// — kotaknya tertinggal di tempat terakhir ia terlihat. Setelah lama
  /// menggulir, kotak basi itu menutupi separuh halaman yang sedang dibuka,
  /// goresannya jatuh ke halaman yang tidak terlihat, dan yang tersisa di
  /// layar adalah "separuh halaman tidak bisa ditulisi".
  Rect? _pageRectNow(int pageNumber) {
    if (!_controller.isReady) return _pageRects[pageNumber];
    final layouts = _controller.layout.pageLayouts;
    if (pageNumber < 1 || pageNumber > layouts.length) return null;
    final doc = layouts[pageNumber - 1];
    return Rect.fromPoints(
      _controller.documentToLocal(doc.topLeft),
      _controller.documentToLocal(doc.bottomRight),
    );
  }

  void _stylusDown(PointerDownEvent event) {
    // Satu goresan satu pointer. Stylus kedua — atau pantulan pena yang
    // terbaca dua kali — tidak boleh membajak goresan yang sedang berjalan.
    if (_stylusPointer != null || !_drawsWithStylus(event)) return;
    final pages = _controller.isReady
        ? List<int>.generate(_controller.pages.length, (i) => i + 1)
        : _pageRects.keys.toList();
    for (final pageNumber in pages) {
      final rect = _pageRectNow(pageNumber);
      if (rect == null || !rect.contains(event.localPosition)) continue;
      _pageRects[pageNumber] = rect;
      _stylusLive
        ..clear()
        ..add(event.localPosition - rect.topLeft);
      _stylusTick.value++;
      setState(() {
        _stylusPage = pageNumber;
        _stylusPointer = event.pointer;
        // Ujung penghapus stylus menghapus, tanpa perlu menyalakan sakelar.
        _stylusErase = event.kind == PointerDeviceKind.invertedStylus;
        _stylusDrawing = true;
      });
      return;
    }
  }

  void _stylusMove(PointerMoveEvent event) {
    if (event.pointer != _stylusPointer || _stylusPage == null) return;
    final rect = _pageRects[_stylusPage];
    if (rect == null) return;
    final local = event.localPosition - rect.topLeft;
    // Titik yang lebih rapat dari ini tidak menambah bentuk, hanya menambah
    // besar berkas — dan berkasnya masuk ke repositori seseorang.
    if (_stylusLive.isNotEmpty && (_stylusLive.last - local).distance < 1.5) return;
    _stylusLive.add(local);
    _stylusTick.value++;
    _sendStylusLive();
  }

  void _stylusFinish(PointerEvent event) {
    // Telapak tangan yang terangkat bukan pena yang diangkat.
    if (event.pointer != _stylusPointer) return;
    final pageNumber = _stylusPage;
    final rect = pageNumber == null ? null : _pageRects[pageNumber];
    final size = pageNumber == null
        ? null
        : (_pageSizes[pageNumber] ??
              (_controller.isReady
                  ? Size(
                      _controller.pages[pageNumber - 1].width,
                      _controller.pages[pageNumber - 1].height,
                    )
                  : null));
    final points = List<Offset>.of(_stylusLive);
    _stylusLive.clear();
    _stylusTick.value++;
    if (pageNumber != null) _sendLive(pageNumber, const <double>[]);
    setState(() {
      _stylusPage = null;
      _stylusPointer = null;
      _stylusDrawing = false;
    });
    if (rect == null || size == null || points.length < 2) return;
    if (rect.isEmpty || size.isEmpty) return;
    final scaleX = rect.width / size.width;
    final scaleY = rect.height / size.height;
    final raw = <double>[];
    for (final point in points) {
      raw
        ..add(point.dx / scaleX)
        ..add(size.height - point.dy / scaleY);
    }
    _addStroke(pageNumber!, InkPath(raw), erase: _stylusErase);
  }

  Widget _buildViewer(ColorScheme scheme) => Stack(
    children: <Widget>[
      // Listener only watches; it never claims the gesture, so the viewer's
      // own drag-to-select still runs underneath.
      Positioned.fill(
        child: MouseRegion(
          // Penunjuk menggantikan kursor: dua penanda di satu titik membuat
          // audiens bertanya mana yang dimaksud.
          cursor: _pointerMode ? SystemMouseCursors.none : MouseCursor.defer,
          onExit: (_) {
            if (_pointerMode) _hidePointer();
          },
          child: Listener(
            key: _viewerKey,
            // Goresan stylus ditangkap di sini, **di atas** penampil dan bukan di
            // dalam lapisan tinta. Alasannya terbukti di tablet: apa pun yang
            // menerima pointer di depan penampil membuat jari berhenti sampai ke
            // sana, jadi dokumennya beku selama pena aktif. `Listener` yang
            // membungkus penampil hanya menyimak — jari tetap menggeser halaman,
            // stylus tetap menulis.
            onPointerDown: (event) {
              if (_pointerMode) {
                _movePointer(event.localPosition);
                return;
              }
              _handDown(event);
              _stylusDown(event);
            },
            onPointerMove: (event) {
              if (_pointerMode) {
                _movePointer(event.localPosition);
                return;
              }
              _stylusMove(event);
              _annotationDragMove(event);
            },
            onPointerHover: (event) {
              if (_pointerMode) {
                _movePointer(event.localPosition);
                return;
              }
              if (_penMode && _stylusOnly && _isStylus(event)) _noteStylusNear();
            },
            onPointerUp: (event) {
              // Mouse tetap menunjuk setelah tombolnya dilepas; jari dan stylus
              // yang diangkat tidak lagi menunjuk apa pun.
              if (_pointerMode) {
                if (event.kind != PointerDeviceKind.mouse) _hidePointer();
                return;
              }
              _onMarkerPointerUp();
              _stylusFinish(event);
              _handUp(event);
              _annotationDragEnd(event);
            },
            onPointerCancel: (event) {
              if (_pointerMode) {
                _hidePointer();
                return;
              }
              _onMarkerPointerUp();
              _stylusFinish(event);
              _handUp(event);
              _annotationDragEnd(event);
            },
            child: _tint.filter == null
                ? _buildPdf(scheme)
                : ColorFiltered(colorFilter: _tint.filter!, child: _buildPdf(scheme)),
          ),
        ),
      ),
      // Menyajikan: separuh kiri mundur, separuh kanan maju, dan geseran ke
      // samping juga berganti halaman — gulir bebas sudah dilepas, jadi
      // seretan mendatar tidak lagi dipakai siapa pun.
      if (_presentMode && !_penMode) ...<Widget>[
        if (!_pointerMode)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v.abs() < 120) return;
                _stepPage(v < 0 ? 1 : -1);
              },
            ),
          ),
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
      // Kendali menyajikan duduk di **bawah**, bukan di kanan atas.
      //
      // Di kanan atas ia bertengkar dengan tempat yang bukan miliknya: lubang
      // kamera dan bilah status yang disembunyikan mode imersif tetap memakan
      // sentuhan di sana, jadi tombol keluar dan ganti halaman terlihat tetapi
      // tidak selalu bisa ditekan. Di bawah, di atas bilah navigasi, tidak ada
      // yang memperebutkannya — dan ibu jari memang sudah di situ.
      if (_presentMode)
        Positioned(
          left: 8 + MediaQuery.viewPaddingOf(context).left,
          right: 8 + MediaQuery.viewPaddingOf(context).right,
          bottom: 8 + MediaQuery.viewPaddingOf(context).bottom,
          child: Center(
            child: Material(
              color: scheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              // Bisa digulir ke samping kalau layarnya lebih sempit dari
              // bilahnya — tombol yang terpotong di ujung sama saja dengan
              // tombol yang tidak ada.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: context.l10n.readerPreviousPage,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _stepPage(-1),
                    ),
                    Text(
                      '$_currentPage / ${_controller.isReady ? _controller.pages.length : '…'}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    IconButton(
                      tooltip: context.l10n.readerNextPage,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _stepPage(1),
                    ),
                    const VerticalDivider(width: 10, indent: 8, endIndent: 8),
                    if (_penMode) ...<Widget>[
                      // Alat pena di bilah bawah juga, karena bilah atas tidak
                      // ada saat menyajikan: mengganti warna adalah hal yang
                      // paling sering dilakukan sambil menjelaskan, dan tanpa
                      // ini satu-satunya warna adalah warna yang dipilih
                      // sebelum mulai menyajikan.
                      _WidthButton(
                        width: _inkWidth,
                        onSelected: (value) => _switchPen(width: value),
                      ),
                      _ColorButton(
                        color: _color,
                        colors: AnnotationPalette.inkColors,
                        onSelected: (value) => _switchPen(color: value),
                      ),
                      _whiteInkButton(),
                      _eraserButton(),
                      _pictureButton(),
                      IconButton(
                        tooltip: context.l10n.readerUndoLastStroke,
                        icon: const Icon(Icons.undo),
                        onPressed: _pendingInk.isNotEmpty
                            ? _undoStroke
                            : (_undoSteps.isEmpty ? null : _undoLast),
                      ),
                      IconButton(
                        tooltip: _redoTooltip,
                        icon: const Icon(Icons.redo),
                        onPressed: _redoAction,
                      ),
                      IconButton(
                        tooltip: context.l10n.readerDiscardStrokes,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _pendingInk.isEmpty ? null : _discardInk,
                      ),
                      IconButton(
                        tooltip: _stylusOnly
                            ? context.l10n.readerStylusOnlyTooltip
                            : context.l10n.readerFingerAndStylusShort,
                        isSelected: _stylusOnly,
                        selectedIcon: const Icon(Icons.do_not_touch_outlined),
                        icon: const Icon(Icons.touch_app_outlined),
                        onPressed: () => _setStylusOnly(!_stylusOnly),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.tonal(
                        onPressed: _togglePen,
                        child: Text(context.l10n.readerDone),
                      ),
                      const SizedBox(width: 4),
                    ] else ...<Widget>[
                      IconButton(
                        tooltip: context.l10n.presenterPointer,
                        isSelected: _pointerMode,
                        selectedIcon: const Icon(Icons.highlight_alt),
                        icon: const Icon(Icons.ads_click),
                        onPressed: _togglePointer,
                      ),
                      // Selalu ada, tidak hanya saat penunjuk menyala: bilah ini
                      // rata tengah, dan tombol yang muncul menggeser tombol
                      // penunjuk keluar dari bawah kursor — klik kedua untuk
                      // mematikannya malah membuka menu buntut.
                      _TrailButton(
                        milliseconds: _pointer.trail.inMilliseconds,
                        onSelected: _setPointerTrail,
                      ),
                      if (AudienceLink.isSupported)
                        IconButton(
                          tooltip: _audience == null
                              ? context.l10n.presenterOpenAudience
                              : context.l10n.presenterStopAudience,
                          isSelected: _audience != null,
                          selectedIcon: const Icon(Icons.cancel_presentation),
                          icon: const Icon(Icons.connected_tv),
                          onPressed: _audience == null ? _openAudience : _closeAudience,
                        ),
                      if (_audience != null && !_presenterPanel)
                        IconButton(
                          tooltip: context.l10n.presenterShowPanel,
                          icon: const Icon(Icons.view_sidebar_outlined),
                          onPressed: () {
                            setState(() => _presenterPanel = true);
                            _refitSoon();
                          },
                        ),
                      const VerticalDivider(width: 10, indent: 8, endIndent: 8),
                      IconButton(
                        tooltip: context.l10n.readerZoomOut,
                        icon: const Icon(Icons.zoom_out),
                        onPressed: () => _controller.zoomDown(),
                      ),
                      IconButton(
                        tooltip: context.l10n.readerZoomIn,
                        icon: const Icon(Icons.zoom_in),
                        onPressed: () => _controller.zoomUp(),
                      ),
                      IconButton(
                        tooltip: context.l10n.readerFitPage,
                        icon: const Icon(Icons.fit_screen_outlined),
                        onPressed: _fitCurrentPage,
                      ),
                      const VerticalDivider(width: 10, indent: 8, endIndent: 8),
                      IconButton(
                        tooltip: _penMode
                            ? context.l10n.readerDoneDrawing
                            : context.l10n.readerScribble,
                        isSelected: _penMode,
                        selectedIcon: const Icon(Icons.draw),
                        icon: const Icon(Icons.draw_outlined),
                        onPressed: _togglePen,
                      ),
                      // Urungkan ikut di sini: saat menyajikan, bilah atas tidak
                      // ada, dan mencari urungkan berarti keluar dari mode
                      // menyajikan di depan orang.
                      IconButton(
                        // Saat masih menggambar, yang diurungkan adalah **goresan
                        // terakhir** — bukan seluruh gambar. Garis nyasar dari
                        // telapak tangan harus bisa dibuang sendiri, tanpa
                        // membuang semua yang sudah ditulis di halaman itu.
                        tooltip: _pendingInk.isNotEmpty
                            ? context.l10n.readerUndoLastStroke
                            : context.l10n.readerUndo,
                        icon: const Icon(Icons.undo),
                        onPressed: _pendingInk.isNotEmpty
                            ? _undoStroke
                            : (_undoSteps.isEmpty ? null : _undoLast),
                      ),
                      IconButton(
                        tooltip: _redoTooltip,
                        icon: const Icon(Icons.redo),
                        onPressed: _redoAction,
                      ),
                      IconButton(
                        tooltip: _stylusOnly
                            ? context.l10n.readerStylusOnlyTooltip
                            : context.l10n.readerFingerAndStylusShort,
                        isSelected: _stylusOnly,
                        selectedIcon: const Icon(Icons.do_not_touch_outlined),
                        icon: const Icon(Icons.touch_app_outlined),
                        onPressed: () => _setStylusOnly(!_stylusOnly),
                      ),
                      IconButton(
                        // Menyimpan dari dalam mode menyajikan: coretan yang
                        // dibuat saat menjelaskan sering justru yang paling
                        // berharga, dan sebelumnya harus keluar dulu untuk
                        // menyimpannya — kalau ingat.
                        tooltip: _savedAs == null
                            ? context.l10n.readerSaveChooseTooltip
                            : context.l10n.readerSaveTo(p.basename(_savedAs!)),
                        icon: const Icon(Icons.save_outlined),
                        onPressed: _savePdf,
                      ),
                      IconButton(
                        tooltip: context.l10n.readerAddScribbleSheet,
                        icon: const Icon(Icons.note_add_outlined),
                        onPressed: _addBlankPages,
                      ),
                      IconButton(
                        tooltip: context.l10n.readerExitPresent,
                        icon: const Icon(Icons.close_fullscreen),
                        onPressed: _togglePresent,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      // In reading mode the bar is gone, so the way back has to be on the
      // page itself — and small enough not to become part of the page.
      if (_readingMode)
        Positioned(
          // `viewPadding`, bukan `SafeArea`: mode imersif menyembunyikan bilah
          // status sehingga jarak amannya jadi nol, padahal lubang kamera masih
          // di sana dan masih memakan sentuhan.
          top: 8 + MediaQuery.viewPaddingOf(context).top,
          right: 8,
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                _ReadingChip(
                  icon: _tint.icon,
                  tooltip: context.l10n.readerPageColor(_tint.label),
                  onTap: _cycleTint,
                ),
                const SizedBox(width: 8),
                _ReadingChip(
                  icon: Icons.unfold_more,
                  tooltip: context.l10n.readerPageNumber(_currentPage),
                  onTap: _navigate,
                ),
                const SizedBox(width: 8),
                _ReadingChip(
                  icon: Icons.fullscreen_exit,
                  tooltip: context.l10n.readerExitReadMode,
                  onTap: _toggleReadingMode,
                ),
              ],
            ),
          ),
        ),
      if (_annotationDrag case final drag?) _dragGhost(drag),
      if (_annotationDrag == null &&
          !_hasSelection &&
          !_penMode &&
          !_markerMode &&
          (_selectedAnnotation != null || _clipboard != null))
        Positioned(
          left: 0,
          right: 0,
          // Di atas bilah halaman saat menyajikan, bukan menimpanya.
          bottom: _presentMode ? 72 + MediaQuery.viewPaddingOf(context).bottom : 16,
          child: Center(child: _annotationActionBar()),
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
    key: ValueKey<String>('$_path#$_reloadToken'),
    controller: _controller,
    params: PdfViewerParams(
      // Penampil sendiri menelan Ctrl+C (untuk teks) setiap kali ia memegang
      // fokus, jadi menyalin dan menghapus anotasi terpilih dicegat di sini
      // lebih dulu. Ctrl+X dan Ctrl+V tidak dipakai penampil dan naik ke
      // pintasan di atas Scaffold.
      onKey: (params, key, isRealKeyPress) {
        // Tombol menyajikan sudah dikerjakan [_onPresentKey]. Flutter tetap
        // meneruskannya ke pohon fokus, dan tanpa ini penampil ikut
        // menggulir dengan panah dan Page Up/Down — slide bergeser dua kali
        // (terbukti di tablet: 3 → 2 → 1 untuk satu Page Up).
        if (_presentMode && presenterKeyFor(key) != null) return true;
        if (_selectedAnnotation == null) return null;
        final keyboard = HardwareKeyboard.instance;
        final command = keyboard.isControlPressed || keyboard.isMetaPressed;
        if (key == LogicalKeyboardKey.keyC && command) {
          if (isRealKeyPress) _copyAnnotation();
          return true;
        }
        if (key == LogicalKeyboardKey.delete && !command) {
          if (isRealKeyPress) _deleteAnnotation(_selectedAnnotation!);
          return true;
        }
        return null;
      },
      backgroundColor: _tint.background ?? AppTheme.readerBackground(scheme),
      margin: 10,
      pagePaintCallbacks: _paintMatches,
      textSelectionParams: _penMode ? _selectOff : (_markerMode ? _selectByDrag : _selectByHandles),
      // While marking, the drag belongs to the selection; while drawing, to
      // the pen. Panning would fight either one for the same gesture.
      //
      // Saat menyajikan, gulir dan cubit dilepas sama sekali: yang menyajikan
      // ingin satu halaman penuh layar yang berganti, bukan dokumen panjang
      // yang bisa tergeser setengah halaman karena tangan menyenggol.
      // Menyajikan tetap boleh diperbesar dan digeser: yang menyajikan sering
      // perlu menunjuk satu rumus atau satu sel tabel. Yang membuatnya terasa
      // seperti slide bukan mengunci gerakannya, melainkan tata letak satu
      // halaman per layar di bawah — tetangganya sejauh satu layar penuh — dan
      // tombol "pas ke layar" yang selalu ada untuk kembali.
      // Saat "Stylus saja" menyala, pena milik stylus dan **jari milik
      // halaman**: menggeser dokumen tetap bisa sambil mencoret. Tanpa itu,
      // menulis berarti dokumennya terkunci, dan satu-satunya cara berpindah
      // adalah keluar dari mode pena dulu.
      // Saat "Stylus saja" menyala, pena milik stylus dan **jari milik
      // halaman**: menggeser dokumen tetap bisa sambil mencoret. Selama stylus
      // benar-benar menggores, geseran dimatikan sebentar — kalau tidak,
      // halamannya ikut bergeser di bawah pena.
      //
      // Telapak tangan juga tidak boleh menggeser: lihat [_palmPointers].
      panEnabled: !_markerMode && !_pointerMode && (!_penMode || (_stylusOnly && !_handLocked)),
      scaleEnabled: !_handLocked,
      // Saat menyajikan, tiap halaman diberi jarak setinggi halaman terpanjang.
      // Tanpa itu halaman sebelumnya dan berikutnya tetap menyembul di atas dan
      // di bawah — dan yang menyajikan tidak sedang memamerkan dua slide
      // sekaligus.
      layoutPages: _presentMode ? _presentLayout : null,
      onPageChanged: (pageNumber) {
        if (pageNumber == null || !mounted) return;
        setState(() => _currentPage = pageNumber);
        _scheduleRecordVisit();
      },
      onViewerReady: (document, controller) async {
        _attachSearcher();
        // Outlines are cheap to read but only exist once the document is
        // open, so this cannot be part of the annotation load.
        final outline = await document.loadOutline();
        if (mounted) setState(() => _outline = outline);
        await _resumeAndRemember();
      },
      pageOverlaysBuilder: (context, pageRect, page) {
        // Kotak halaman di layar disimpan supaya goresan stylus yang ditangkap
        // di atas viewer tahu ia mendarat di halaman mana, dan di titik mana.
        _pageRects[page.pageNumber] = pageRect;
        _pageSizes[page.pageNumber] = Size(page.width, page.height);
        return <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: AnnotationOverlayPainter(
                  annotations: _onPage(page.pageNumber),
                  pictures: _pictureImages,
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
          if (!_penMode && !_markerMode && !_pointerMode)
            ..._moveLayersFor(page: page, pageRect: pageRect),
          ..._noteBubblesFor(page: page, pageRect: pageRect),
          if (_penMode)
            Positioned.fill(
              child: InkCaptureLayer(
                // Rebuilt from scratch when the colour or width changes, so the
                // live stroke never keeps the previous pen's look.
                key: ValueKey<String>('ink-${page.pageNumber}-$_color-$_inkWidth-$_erasing'),
                pageWidth: page.width,
                pageHeight: page.height,
                color: colorFromHex(_color),
                strokeWidth: _inkWidth,
                liveColor: _erasing || _stylusErase ? const Color(0x66808080) : null,
                liveWidth: _erasing || _stylusErase ? math.max(12, _inkWidth * 3) : null,
                stylusOnly: _stylusOnly,
                liveStroke: _stylusOnly && _stylusPage == page.pageNumber ? _stylusLive : null,
                liveRepaint: _stylusTick,
                strokes: _inkPage == page.pageNumber ? _pendingInk : const <InkPath>[],
                onStrokeFinished: (stroke) => _addStroke(page.pageNumber, stroke),
                onLiveChanged: _audience == null
                    ? null
                    : (points) => _sendLive(page.pageNumber, points),
              ),
            ),
          if (_presentMode)
            Positioned.fill(
              child: LaserPointerLayer(pointer: _pointer, pageNumber: page.pageNumber),
            ),
        ];
      },
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

  /// Balon catatan yang sedang terbuka di halaman ini: isi catatannya di
  /// samping ikonnya, dengan tombol sunting dan tutup.
  List<Widget> _noteBubblesFor({required PdfPage page, required Rect pageRect}) {
    if (_openNotes.isEmpty) return const <Widget>[];
    final scaleX = pageRect.width / page.width;
    final scaleY = pageRect.height / page.height;
    final widgets = <Widget>[];
    for (final note in _onPage(page.pageNumber)) {
      if (note.type != AnnotationType.note || !_openNotes.contains(note.key)) continue;
      if (note.rects.isEmpty) continue;
      final r = note.rects.first;
      final iconRight = r.right * scaleX;
      final iconTop = (page.height - r.top) * scaleY;
      const width = 240.0;
      // Di kanan ikon bila muat, kalau tidak di kirinya.
      final left = iconRight + 6 + width <= pageRect.width
          ? iconRight + 6
          : math.max(0.0, r.left * scaleX - 6 - width);
      widgets.add(
        Positioned(
          left: left,
          top: math.max(0.0, iconTop),
          width: width,
          child: _NoteBubble(
            note: note,
            onEdit: () => _editAnnotation(note),
            onClose: () => setState(() => _openNotes.remove(note.key)),
          ),
        ),
      );
    }
    return widgets;
  }

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
        // Seluas halamannya: pegangan yang jatuh di luar halaman tidak pernah
        // menerima sentuhan, dan anotasi memang sering menempel di tepi.
        limit: pageRect.size,
        onDelete: () => _deleteAnnotation(annotation),
        // Mengetuk anotasi yang sudah terpilih: catatan dibuka atau ditutup,
        // yang lain disunting — sama seperti mengetuknya sebelum terpilih.
        onTap: () {
          if (annotation.type == AnnotationType.note) {
            _toggleNote(annotation.key);
          } else if (!PagePicture.isPicture(annotation)) {
            _editAnnotation(annotation);
          }
        },
        // Tinta dan teks di halaman bisa diubah ukuran dan diputar; gambar
        // hanya diubah ukurannya. Stabilo disimpan Zotero sebagai kotak
        // sejajar sumbu, dan catatan adalah penanda berukuran tetap.
        canRotate: !PagePicture.isPicture(annotation) && annotation.type != AnnotationType.note,
        onTransformed:
            annotation.paths.isEmpty &&
                !PagePicture.isPicture(annotation) &&
                annotation.type != AnnotationType.text
            ? null
            : ({double scale = 1, double rotation = 0}) =>
                  _transformAnnotation(annotation, page: page, scale: scale, rotation: rotation),
        onMoved: (delta) =>
            _moveAnnotation(annotation, page: page, dx: delta.dx / scaleX, dy: -delta.dy / scaleY),
        onDragStart: (global) => _startAnnotationDrag(
          annotation,
          page: page,
          pageRect: pageRect,
          bounds: bounds,
          global: global,
        ),
      ),
    ];
  }

  /// Anotasi yang sedang dipilih, bila masih ada.
  ZoteroAnnotation? get _selectedAnnotation {
    final key = _selectedAnnotationKey;
    if (key == null) return null;
    return _annotations.where((a) => a.key == key).firstOrNull;
  }

  // ------------------------------------------------------------ gambar

  /// Membaca gambar tempelan yang belum ada di memori: dari repositori untuk
  /// paper library, dan menyandikannya untuk digambar.
  Future<void> _loadPictures() async {
    final store = widget.isStandalone ? null : _workspace.pagePictures(widget.attachmentKey);
    var changed = false;
    for (final annotation in _annotations.where(PagePicture.isPicture)) {
      final file = PagePicture.fileOf(annotation)!;
      var bytes = _pictureBytes[file];
      if (bytes == null && store != null) {
        bytes = await store.bytes(file);
        if (bytes != null) _pictureBytes[file] = bytes;
      }
      if (bytes != null && !_pictureImages.containsKey(file)) {
        try {
          _pictureImages[file] = await decodeImageFromList(bytes);
          changed = true;
        } on Object {
          // Berkas rusak tetap tampil sebagai kotak abu-abu, bisa dihapus.
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  /// Menyalin anotasi juga menimpa papan klip sistem, dengan teksnya. Tanpa
  /// itu gambar yang disalin dari peramban kemarin masih di sana, dan Ctrl+V
  /// menempelkan gambar itu alih-alih anotasi yang baru disalin.
  void _claimSystemClipboard(ZoteroAnnotation annotation) {
    _clipboardPicture = PagePicture.isPicture(annotation)
        ? _pictureBytes[PagePicture.fileOf(annotation)]
        : null;
    final text = annotation.text.trim().isNotEmpty ? annotation.text : annotation.comment;
    unawaited(
      Clipboard.setData(
        ClipboardData(text: text.trim().isNotEmpty ? text : context.l10n.readerClipboardFallback),
      ).catchError((Object _) {}),
    );
  }

  /// Ctrl+V: gambar di papan klip sistem lebih dulu, lalu anotasi yang
  /// disalin di ReadPaper.
  Future<void> _pasteAny() async {
    final bytes = await ClipboardImage.read();
    if (!mounted) return;
    if (bytes != null) {
      await _insertPicture(bytes);
      return;
    }
    if (_clipboard != null) {
      await _pasteAnnotation();
      return;
    }
    _say(context.l10n.readerClipboardEmpty);
  }

  Future<void> _pasteClipboardPicture() async {
    final bytes = await ClipboardImage.read();
    if (!mounted) return;
    if (bytes == null) {
      _say(
        Platform.isIOS || Platform.isMacOS
            ? context.l10n.readerPasteImageUnsupported
            : context.l10n.readerClipboardNoImage,
      );
      return;
    }
    await _insertPicture(bytes);
  }

  Future<void> _pickPictureFile() async {
    final picked = await pickFilesOrTell(
      context,
      type: FileType.image,
      title: context.l10n.readerChooseImage,
      multiple: false,
    );
    final path = picked.firstOrNull;
    if (path == null || !mounted) return;
    final bytes = await File(path).readAsBytes();
    if (!mounted) return;
    await _insertPicture(bytes);
  }

  /// Menaruh gambar di tengah halaman yang sedang dibuka, langsung terpilih
  /// supaya bisa digeser dan diubah ukurannya.
  Future<void> _insertPicture(Uint8List raw) async {
    if (!_controller.isReady) return;
    _say(context.l10n.readerPreparingImage);
    final prepared = await Isolate.run(() => PagePicture.prepare(raw));
    if (!mounted) return;
    if (prepared == null) {
      _say(context.l10n.readerNotAnImage);
      return;
    }
    // Pena dimatikan dulu, goresannya disimpan: pegangan ubah ukuran hanya
    // tampil di luar mode pena, dan gambar yang baru ditempel hampir selalu
    // perlu dirapikan dulu.
    if (_penMode) await _togglePen();
    if (!mounted) return;

    final file = '${ZoteroKey.generate()}${prepared.extension}';
    _pictureBytes[file] = prepared.bytes;
    try {
      _pictureImages[file] = await decodeImageFromList(prepared.bytes);
    } on Object {
      // Tetap ditempel; digambar sebagai kotak sampai dibaca ulang.
    }
    if (!mounted) return;

    final pageNumber = _currentPage.clamp(1, _controller.pageCount);
    final page = _controller.pages[pageNumber - 1];
    final visible = _visibleCenterOn(pageNumber);
    final annotation = PagePicture.create(
      key: ZoteroKey.generate(),
      parentItemKey: widget.attachmentKey,
      pageIndex: pageNumber - 1,
      rect: PagePicture.placeCentered(
        width: prepared.width,
        height: prepared.height,
        pageWidth: page.width,
        pageHeight: page.height,
        centerX: visible?.dx,
        centerY: visible?.dy,
      ),
      file: file,
      pageHeight: page.height,
    );
    _recordChange(context.l10n.readerUndoPasteImage, before: null, after: annotation);
    await _persist(annotation, isNew: true, recordUndo: false);
    _say(l10n.readerImagePasted(pageNumber));
  }

  /// Tengah bagian halaman [pageNumber] yang sedang terlihat, dalam
  /// koordinat PDF. Halaman yang lebih tinggi dari layar membuat "tengah
  /// halaman" jatuh di luar pandangan — gambar yang baru ditempel lalu
  /// tidak terlihat sama sekali.
  Offset? _visibleCenterOn(int pageNumber) {
    final layouts = _controller.layout.pageLayouts;
    if (pageNumber < 1 || pageNumber > layouts.length) return null;
    final rect = layouts[pageNumber - 1];
    final seen = rect.intersect(_controller.visibleRect);
    if (seen.isEmpty || seen.width <= 0 || seen.height <= 0) return null;
    final page = _controller.pages[pageNumber - 1];
    final x = (seen.center.dx - rect.left) / rect.width * page.width;
    final fromTop = (seen.center.dy - rect.top) / rect.height * page.height;
    return Offset(x, page.height - fromTop);
  }

  /// Tombol gambar: tempel dari papan klip atau pilih berkas.
  Widget _pictureButton({double? iconSize}) => PopupMenuButton<String>(
    tooltip: context.l10n.readerInsertImage,
    iconSize: iconSize,
    icon: const Icon(Icons.add_photo_alternate_outlined),
    onSelected: (choice) => choice == 'tempel' ? _pasteClipboardPicture() : _pickPictureFile(),
    itemBuilder: (_) => <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'tempel',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.content_paste),
          title: Text(context.l10n.readerPasteImage),
          subtitle: Text(context.l10n.readerPasteImageHint),
        ),
      ),
      PopupMenuItem<String>(
        value: 'berkas',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.image_outlined),
          title: Text(context.l10n.readerChooseImageFile),
        ),
      ),
    ],
  );

  // ----------------------------------------------------- salin, potong, tempel

  void _copyShortcut() {
    if (_selectedAnnotation != null) {
      _copyAnnotation();
    } else if (_hasSelection) {
      _copySelection();
    }
  }

  void _copyAnnotation() {
    final annotation = _selectedAnnotation;
    if (annotation == null) return;
    setState(() => _clipboard = annotation);
    _claimSystemClipboard(annotation);
    _say(context.l10n.readerAnnotationCopied);
  }

  /// Memotong = menyalin lalu menghapus, sebagai satu langkah yang bisa
  /// diurungkan. Tanpa konfirmasi: isinya masih di papan klip, dan Urungkan
  /// mengembalikannya di tempat semula.
  Future<void> _cutAnnotation() async {
    final annotation = _selectedAnnotation;
    if (annotation == null) return;
    setState(() => _clipboard = annotation);
    _claimSystemClipboard(annotation);
    _recordChange(context.l10n.readerUndoCut, before: annotation, after: null);
    await _removeAnnotation(annotation);
    _say(l10n.readerAnnotationCut);
  }

  /// Menempel isi papan klip di halaman yang sedang dibuka, di posisi yang
  /// sama dengan aslinya. Kalau di sana sudah ada yang persis sama — yang
  /// disalin, atau tempelan sebelumnya — tempelan bergeser sedikit ke kanan
  /// bawah, supaya tidak tertumpuk dan terlihat seperti tidak terjadi apa-apa.
  Future<void> _pasteAnnotation() async {
    final clip = _clipboard;
    if (clip == null || !_controller.isReady) return;
    final pageNumber = _currentPage.clamp(1, _controller.pageCount);
    final page = _controller.pages[pageNumber - 1];
    final clipFile = PagePicture.fileOf(clip);
    final clipBytes = _clipboardPicture;
    if (clipFile != null && !_pictureBytes.containsKey(clipFile) && clipBytes != null) {
      _pictureBytes[clipFile] = clipBytes;
      try {
        _pictureImages[clipFile] = await decodeImageFromList(clipBytes);
      } on Object {
        // Digambar sebagai kotak sampai dibaca ulang.
      }
      if (!mounted) return;
    }
    final copy = AnnotationMove.duplicate(
      clip,
      key: ZoteroKey.generate(),
      parentItemKey: widget.attachmentKey,
    );
    final onPage = _onPage(pageNumber);

    ZoteroAnnotation placed;
    var step = 0;
    do {
      placed = AnnotationMove.toPage(
        copy,
        pageIndex: pageNumber - 1,
        dx: 12.0 * step,
        dy: -12.0 * step,
        pageWidth: page.width,
        pageHeight: page.height,
      );
      step++;
    } while (step < 20 && onPage.any((a) => _sameSpot(a, placed)));

    _recordChange(context.l10n.readerUndoPaste, before: null, after: placed);
    await _persist(placed, isNew: true, recordUndo: false);
    _say(l10n.readerPastedOnPage(pageNumber));
  }

  static bool _sameSpot(ZoteroAnnotation a, ZoteroAnnotation b) {
    final ra = AnnotationMove.rectsOf(a);
    final rb = AnnotationMove.rectsOf(b);
    if (ra.isEmpty || rb.isEmpty) return false;
    return (ra.first.left - rb.first.left).abs() < 1 && (ra.first.top - rb.first.top).abs() < 1;
  }

  /// Memindahkan ke halaman lain lewat nomornya — untuk halaman yang terlalu
  /// jauh untuk diseret. Posisinya di halaman tetap.
  Future<void> _askMoveToPage(ZoteroAnnotation annotation) async {
    if (!_controller.isReady) return;
    final count = _controller.pageCount;
    final field = TextEditingController(text: '${annotation.pageNumber}');
    final number = await showDialog<int>(
      context: context,
      builder: (context) {
        void submit() => Navigator.of(context).pop(int.tryParse(field.text.trim()));
        return AlertDialog(
          title: Text(context.l10n.readerMoveToPage),
          content: TextField(
            controller: field,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(helperText: context.l10n.readerPageRange(count)),
            onSubmitted: (_) => submit(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.readerCancel),
            ),
            FilledButton(onPressed: submit, child: Text(context.l10n.readerMove)),
          ],
        );
      },
    );
    field.dispose();
    if (number == null || number == annotation.pageNumber) return;
    if (number < 1 || number > count) {
      _say(l10n.readerNoSuchPage(number, count));
      return;
    }
    final moved = await _moveAnnotationToPage(annotation, page: _controller.pages[number - 1]);
    if (!mounted) return;
    await _goToAnnotation(moved);
  }

  Future<ZoteroAnnotation> _moveAnnotationToPage(
    ZoteroAnnotation annotation, {
    required PdfPage page,
    double dx = 0,
    double dy = 0,
  }) async {
    final moved = AnnotationMove.toPage(
      annotation,
      pageIndex: page.pageNumber - 1,
      dx: dx,
      dy: dy,
      pageWidth: page.width,
      pageHeight: page.height,
    );
    _recordChange(
      context.l10n.readerUndoMoveToPage(page.pageNumber),
      before: annotation,
      after: moved,
    );
    await _persist(moved, isNew: false, recordUndo: false);
    _say(l10n.readerMovedToPage(page.pageNumber));
    return moved;
  }

  Widget _annotationActionBar() {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedAnnotation;
    final clip = _clipboard;
    final compact = MediaQuery.sizeOf(context).width < 600;

    Widget action(IconData icon, String label, VoidCallback onPressed) => compact
        ? IconButton(tooltip: label, icon: Icon(icon), onPressed: onPressed)
        : TextButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label));

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected != null) ...<Widget>[
              action(Icons.content_copy, context.l10n.readerCopy, _copyAnnotation),
              action(Icons.content_cut, context.l10n.readerCut, _cutAnnotation),
              action(Icons.move_down, context.l10n.readerToPage, () => _askMoveToPage(selected)),
            ],
            if (clip != null) ...<Widget>[
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: _pasteAnnotation,
                icon: const Icon(Icons.content_paste, size: 20),
                label: Text(
                  compact ? context.l10n.readerPaste : context.l10n.readerPasteOnPage(_currentPage),
                ),
              ),
            ],
            IconButton(
              tooltip: selected != null
                  ? context.l10n.readerDeselect
                  : context.l10n.readerClearClipboard,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                if (selected != null) {
                  _selectedAnnotationKey = null;
                } else {
                  _clipboard = null;
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------- seret ke halaman lain

  void _startAnnotationDrag(
    ZoteroAnnotation annotation, {
    required PdfPage page,
    required Rect pageRect,
    required Rect bounds,
    required Offset global,
  }) {
    final box = _viewerKey.currentContext?.findRenderObject();
    final document = _controller.globalToDocument(global);
    if (box is! RenderBox || document == null) return;
    final hit = _controller.getPdfPageHitTestResult(document, useDocumentLayoutCoordinates: true);
    if (hit == null) return;
    final local = box.globalToLocal(global);
    setState(() {
      _annotationDrag = _AnnotationDrag(
        annotation: annotation,
        sourcePage: page,
        grab: Offset(hit.offset.x, hit.offset.y),
        // Titik pegang terhadap pojok halaman di layar, supaya bayangannya
        // mengikuti jari di titik yang sama dengan yang dipegang.
        grabOnPage: local - pageRect.topLeft,
        pageSize: pageRect.size,
        pointer: local,
        global: global,
        targetPage: page.pageNumber,
      );
    });
  }

  int? _pageAt(Offset global) {
    final document = _controller.globalToDocument(global);
    if (document == null) return null;
    return _controller
        .getPdfPageHitTestResult(document, useDocumentLayoutCoordinates: true)
        ?.page
        .pageNumber;
  }

  void _annotationDragMove(PointerEvent event) {
    final drag = _annotationDrag;
    if (drag == null) return;
    setState(() {
      drag
        ..pointer = event.localPosition
        ..global = event.position
        ..targetPage = _pageAt(event.position);
    });
    _autoScrollNear(event.localPosition);
  }

  /// Menggulir sendiri selama jari menahan anotasi di dekat tepi atas atau
  /// bawah, supaya halaman yang belum terlihat bisa dicapai. Saat menyajikan
  /// tidak, karena di sana gulir bebas memang dimatikan: pakai Potong/Tempel
  /// atau "Ke halaman…".
  void _autoScrollNear(Offset local) {
    final box = _viewerKey.currentContext?.findRenderObject();
    if (box is! RenderBox || _presentMode) return;
    const edge = 64.0;
    final height = box.size.height;
    var speed = 0.0;
    if (local.dy < edge) {
      speed = -(edge - local.dy) / edge;
    } else if (local.dy > height - edge) {
      speed = (local.dy - (height - edge)) / edge;
    }
    _dragScrollSpeed = speed.clamp(-1.0, 1.0);
    if (_dragScrollSpeed == 0) {
      _dragScroll?.cancel();
      _dragScroll = null;
      return;
    }
    _dragScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final drag = _annotationDrag;
      if (drag == null || !mounted || !_controller.isReady || _dragScrollSpeed == 0) {
        _dragScroll?.cancel();
        _dragScroll = null;
        return;
      }
      final next = Matrix4.translationValues(0, -_dragScrollSpeed * 20, 0)
        ..multiply(_controller.value);
      _controller.value = _controller.makeMatrixInSafeRange(next);
      setState(() => drag.targetPage = _pageAt(drag.global));
    });
  }

  Future<void> _annotationDragEnd(PointerEvent event) async {
    final drag = _annotationDrag;
    if (drag == null) return;
    _dragScroll?.cancel();
    _dragScroll = null;
    _dragScrollSpeed = 0;
    setState(() => _annotationDrag = null);
    if (event is PointerCancelEvent) return;

    final document = _controller.globalToDocument(event.position);
    final hit = document == null
        ? null
        : _controller.getPdfPageHitTestResult(document, useDocumentLayoutCoordinates: true);
    if (hit == null) {
      _say(context.l10n.readerDropOnPage);
      return;
    }
    // Perpindahan titik pegang, dalam koordinat PDF halaman masing-masing.
    final dx = hit.offset.x - drag.grab.dx;
    final dy = hit.offset.y - drag.grab.dy;
    if (hit.page.pageNumber == drag.sourcePage.pageNumber) {
      await _moveAnnotation(drag.annotation, page: hit.page, dx: dx, dy: dy);
    } else {
      await _moveAnnotationToPage(drag.annotation, page: hit.page, dx: dx, dy: dy);
    }
  }

  /// Bayangan anotasi yang sedang diseret, digambar di atas penampil supaya
  /// bisa melewati batas halaman, dengan nomor halaman tempat ia akan jatuh.
  Widget _dragGhost(_AnnotationDrag drag) {
    final scheme = Theme.of(context).colorScheme;
    final origin = drag.pointer - drag.grabOnPage;
    final target = drag.targetPage;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: origin.dx,
              top: origin.dy,
              width: drag.pageSize.width,
              height: drag.pageSize.height,
              child: Opacity(
                opacity: 0.75,
                child: CustomPaint(
                  painter: AnnotationOverlayPainter(
                    annotations: <ZoteroAnnotation>[drag.annotation],
                    pageWidth: drag.sourcePage.width,
                    pageHeight: drag.sourcePage.height,
                    selectedKey: drag.annotation.key,
                    pictures: _pictureImages,
                  ),
                ),
              ),
            ),
            Positioned(
              left: drag.pointer.dx + 18,
              top: drag.pointer.dy - 40,
              child: Material(
                color: target == null ? scheme.error : scheme.primary,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    target == null
                        ? context.l10n.readerOutsidePage
                        : context.l10n.readerPageNumber(target),
                    style: TextStyle(
                      color: target == null ? scheme.onError : scheme.onPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mengubah ukuran dan memutar anotasi tinta.
  ///
  /// Seluruh gerakan diterapkan sekali dari anotasi aslinya — bukan sedikit
  /// demi sedikit — karena titiknya ditulis ulang setiap kali, dan memutar
  /// seratus kali dengan satu derajat kehilangan ketelitian yang tidak bisa
  /// dikembalikan.
  Future<void> _transformAnnotation(
    ZoteroAnnotation annotation, {
    required PdfPage page,
    required double scale,
    required double rotation,
  }) async {
    final changed = AnnotationMove.transform(
      annotation,
      scale: scale,
      // Layar menghitung sudut searah jarum jam, PDF berlawanan.
      rotation: -rotation,
      pageWidth: page.width,
      pageHeight: page.height,
    );
    if (identical(changed, annotation)) return;

    _recordChange(context.l10n.readerUndoReshape, before: annotation, after: changed);
    await _persist(changed, isNew: false, recordUndo: false);
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

    _recordChange(context.l10n.readerUndoMove, before: annotation, after: moved);
    await _persist(moved, isNew: false, recordUndo: false);
  }

  // ------------------------------------------------------------------ gestures

  bool _handleTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    // Selama pena aktif, ketukan dan tekan lama milik pena. Tanpa ini stylus
    // yang mengetuk titik atau berhenti sebentar membuka penyunting anotasi,
    // membuat catatan baru, atau memilih coretan — di tengah menulis.
    if (_penMode) return true;
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
        if (annotation.type == AnnotationType.note && details.type == PdfViewerGeneralTapType.tap) {
          // Catatan: ketuk membuka balonnya, ketuk lagi menutupnya.
          _toggleNote(annotation.key);
          return true;
        }
        setState(() => _selectedAnnotationKey = annotation.key);
        // Gambar tidak punya komentar untuk disunting; mengetuknya cukup
        // memilihnya supaya bisa digeser dan diubah ukurannya.
        if (details.type == PdfViewerGeneralTapType.tap && !PagePicture.isPicture(annotation)) {
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
        label: context.l10n.readerHighlight,
        onPressed: () {
          params.dismissContextMenu();
          _createFromSelection(delegate, AnnotationType.highlight);
        },
      ),
      ContextMenuButtonItem(
        label: context.l10n.readerHighlightComment,
        onPressed: () {
          params.dismissContextMenu();
          _createFromSelection(delegate, AnnotationType.highlight, withComment: true);
        },
      ),
      ContextMenuButtonItem(
        label: context.l10n.readerUnderline,
        onPressed: () {
          params.dismissContextMenu();
          _createFromSelection(delegate, AnnotationType.underline);
        },
      ),
      if (delegate.isCopyAllowed)
        ContextMenuButtonItem(
          label: context.l10n.readerCopy,
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
        title: context.l10n.readerHighlightComment,
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
          ? context.l10n.readerTextOnPage(page.pageNumber)
          : context.l10n.readerNoteOnPage(page.pageNumber),
      fieldLabel: asText ? context.l10n.readerText : context.l10n.readerComment,
      fieldHint: asText ? context.l10n.readerTextHint : context.l10n.readerCommentHint,
    );
    if (result == null || result.action != AnnotationEditorAction.save) return;
    if (result.comment.trim().isEmpty) return;

    // The box has to fit what was typed, or a long answer would be clipped
    // at the edge of a fixed rectangle and look like it was lost.
    const fontSize = 12.0;
    final lines = result.comment.split('\n');
    final longest = lines.fold<int>(0, (m, l) => l.length > m ? l.length : m);
    // Catatan tempel adalah catatan gaya Zotero: penanda 22 x 22 pt yang
    // dibuka dengan mengetuknya. Teks di halaman (Tt) ditulis langsung.
    final noteWidth = asText ? (longest * fontSize * 0.52).clamp(40.0, page.width) : 22.0;
    final noteHeight = asText ? lines.length * fontSize * 1.18 : 22.0;
    final rect = AnnotationRect(point.x, point.y - noteHeight, point.x + noteWidth, point.y);

    final annotation = ZoteroAnnotation(
      key: ZoteroKey.generate(),
      parentItemKey: widget.attachmentKey,
      type: asText ? AnnotationType.text : AnnotationType.note,
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
      rawPosition: asText ? const <String, dynamic>{'fontSize': fontSize, 'rotation': 0} : null,
      dateAdded: DateTime.now(),
      dateModified: DateTime.now(),
    );
    // Catatan baru langsung terbuka, supaya yang baru ditulis terlihat.
    if (!asText) _openNotes.add(annotation.key);
    await _persist(annotation, isNew: true);
  }

  Future<void> _editAnnotation(ZoteroAnnotation annotation) async {
    setState(() => _selectedAnnotationKey = annotation.key);
    final result = await showAnnotationEditor(
      context,
      initialColor: annotation.color,
      initialComment: annotation.comment,
      quotedText: annotation.text,
      title: context.l10n.readerAnnotationOnPage(annotation.pageLabel),
      allowDelete: true,
    );
    if (result == null) return;

    if (result.action == AnnotationEditorAction.delete) {
      await _deleteAnnotation(annotation);
      return;
    }
    // Menyunting komentar atau warna juga bisa diurungkan: yang sudah
    // ditulis sebelumnya tidak boleh hilang hanya karena salah tekan.
    final edited = annotation.copyWith(
      comment: result.comment,
      color: result.color,
      dateModified: DateTime.now(),
    );
    _recordChange(l10n.readerUndoEdit, before: annotation, after: edited);
    await _persist(edited, isNew: false, recordUndo: false);
  }

  Future<void> _deleteAnnotation(ZoteroAnnotation annotation) async {
    // Tidak ada pagar `item == null` di sini, dan itu disengaja: PDF yang
    // dibuka lepas — dari panel berkas, dari koleksi catatan, atau lewat "buka
    // dengan" — tidak punya item Zotero, dan pagar itu dulu membuat tombol
    // hapus tidak melakukan apa pun sama sekali. Yang menekan tong sampah
    // melihat ikonnya, menekannya, dan tidak terjadi apa-apa. `_removeAnnotation`
    // sendiri sudah tahu cara menghapus di kedua keadaan.

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.readerDeleteAnnotationQuestion),
        content: Text(
          annotation.text.isNotEmpty ? annotation.text : annotation.comment,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.readerCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.readerDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // `recordUndo: false`: mengembalikannya bukan langkah baru yang perlu
    // diurungkan lagi.
    _recordChange(l10n.readerUndoDelete, before: annotation, after: null);
    await _removeAnnotation(annotation);
  }

  /// Menghapus tanpa bertanya. Dipakai penghapusan yang sudah disetujui dan
  /// oleh urungkan.
  Future<void> _removeAnnotation(ZoteroAnnotation annotation) async {
    final item = _detail?.item;

    if (widget.isStandalone) {
      setState(() {
        _annotations = _annotations.where((a) => a.key != annotation.key).toList();
        if (!_autoSaves || PagePicture.isPicture(annotation)) _unsaved = true;
        _selectedAnnotationKey = null;
      });
      if (_autoSaves && !PagePicture.isPicture(annotation)) {
        await _writeAnnotationsFile('Hapus anotasi: ${widget.title}');
        _say(l10n.readerAnnotationDeleted);
      }
      return;
    }
    if (item == null) return;

    if (PagePicture.isPicture(annotation)) {
      await _workspace.deletePagePicture(
        attachmentKey: widget.attachmentKey,
        itemTitle: widget.title,
        annotation: annotation,
      );
      if (!mounted) return;
      setState(() => _selectedAnnotationKey = null);
      await _load();
      return;
    }

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
            content: Text(
              ref.read(workspaceControllerProvider).error ?? context.l10n.readerDeleteFailed,
            ),
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
      _recordChange(
        context.l10n.readerUndoAdd(annotation.type.wire),
        before: null,
        after: annotation,
      );
    }
    if (!widget.isStandalone && PagePicture.isPicture(annotation)) {
      final saved = await _workspace.savePagePicture(
        attachmentKey: widget.attachmentKey,
        itemTitle: widget.title,
        annotation: annotation,
        isNew: isNew,
        bytes: _pictureBytes[PagePicture.fileOf(annotation)],
      );
      if (!mounted) return;
      if (!saved) {
        _say(ref.read(workspaceControllerProvider).error ?? context.l10n.readerSaveImageFailed);
      }
      setState(() => _selectedAnnotationKey = annotation.key);
      await _load();
      return;
    }
    if (widget.isStandalone) {
      final autoSave = _autoSaves && !PagePicture.isPicture(annotation);
      setState(() {
        _annotations = <ZoteroAnnotation>[
          for (final a in _annotations)
            if (a.key != annotation.key) a,
          annotation,
        ];
        if (!autoSave) _unsaved = true;
        _selectedAnnotationKey = annotation.key;
      });
      if (autoSave) {
        await _writeAnnotationsFile('${isNew ? 'Anotasi baru' : 'Ubah anotasi'}: ${widget.title}');
        _say(isNew ? l10n.readerSaved : l10n.readerChangesSaved);
        return;
      }
      _say(undoable ? context.l10n.readerAddedNotSaved : context.l10n.readerAdded);
      return;
    }

    final item = _detail?.item;
    if (item == null) return;
    // Langsung masuk daftar, sebelum disimpan: penyimpanannya menunggu git
    // (di library besar bisa beberapa detik), dan selama itu panel anotasi
    // kosong dan Urungkan tidak menemukan apa-apa. Pemuatan ulang sesudahnya
    // menyamakan daftar dengan isi berkas — termasuk bila simpannya gagal.
    // Pemuatan yang masih berjalan membawa isi berkas sebelum perubahan ini;
    // hasilnya dibuang, supaya tidak menimpa perubahan ini dan suntingan
    // berikutnya tidak dihitung dari versi lama (memperbesar teks yang baru
    // diputar dulu mengembalikan sudutnya ke nol).
    _loadGeneration++;
    setState(() {
      _annotations = <ZoteroAnnotation>[
        for (final a in _annotations)
          if (a.key != annotation.key) a,
        annotation,
      ];
      _selectedAnnotationKey = annotation.key;
    });
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
                ? (isNew ? context.l10n.readerSaved : context.l10n.readerChangesSaved)
                : ref.read(workspaceControllerProvider).error ??
                      context.l10n.readerSaveAnnotationFailed,
          ),
          // A sweep that grabbed the wrong line should cost one tap to undo,
          // not a trip through the sidebar.
          action: saved && undoable
              // Lewat tumpukan yang sama dengan tombol Urungkan, supaya
              // keduanya tidak pernah berbeda pendapat.
              ? SnackBarAction(label: context.l10n.readerUndo, onPressed: _undoLast)
              : null,
        ),
      );

    setState(() => _selectedAnnotationKey = annotation.key);
    await _load();
  }

  Future<void> _goToAnnotation(ZoteroAnnotation annotation) async {
    setState(() {
      _selectedAnnotationKey = annotation.key;
      // Catatan yang dipilih dari panel langsung terbuka di halamannya.
      if (annotation.type == AnnotationType.note) _openNotes.add(annotation.key);
    });
    // Lewat AnnotationMove: tinta tidak menyimpan kotak, batasnya dihitung
    // dari goresannya — tanpa itu yang terbuka hanya puncak halamannya.
    final bounds = AnnotationGeometry.boundsOf(AnnotationMove.rectsOf(annotation));
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

/// Balon isi catatan gaya Zotero: warna catatannya di tepi, isinya bisa
/// digulir bila panjang, dan dua tombol kecil.
class _NoteBubble extends StatelessWidget {
  const _NoteBubble({required this.note, required this.onEdit, required this.onClose});

  final ZoteroAnnotation note;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(note.color);
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: Color.alphaBlend(color.withValues(alpha: 0.18), theme.colorScheme.surface),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 4, 2, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.readerNoteBubbleTitle(note.pageLabel),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.readerEditNote,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: context.l10n.readerCloseNote,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8),
                child: SelectableText(note.comment, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.onSelected,
    this.colors = AnnotationPalette.all,
  });

  final String color;
  final ValueChanged<String> onSelected;

  /// Pilihan warnanya; pena memakai [AnnotationPalette.inkColors].
  final List<String> colors;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: context.l10n.readerHighlightColor(AnnotationPalette.names[color] ?? color),
    onSelected: onSelected,
    itemBuilder: (_) => <PopupMenuEntry<String>>[
      for (final hex in colors)
        PopupMenuItem<String>(
          value: hex,
          child: Row(
            children: <Widget>[
              Container(
                width: 16,
                height: 16,
                // Bergaris tepi: tinta putih di menu yang putih tidak terlihat.
                decoration: BoxDecoration(
                  color: colorFromHex(hex),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
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
    tooltip: context.l10n.readerStrokeWidth(width.toStringAsFixed(0)),
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

/// Anotasi yang sedang diseret dari atas penampil.
class _AnnotationDrag {
  _AnnotationDrag({
    required this.annotation,
    required this.sourcePage,
    required this.grab,
    required this.grabOnPage,
    required this.pageSize,
    required this.pointer,
    required this.global,
    required this.targetPage,
  });

  final ZoteroAnnotation annotation;
  final PdfPage sourcePage;

  /// Titik yang dipegang, dalam koordinat PDF halaman asal.
  final Offset grab;

  /// Titik yang dipegang terhadap pojok kiri atas halaman asal di layar.
  final Offset grabOnPage;

  /// Ukuran halaman asal di layar, untuk menggambar bayangannya seukuran.
  final Size pageSize;

  /// Posisi jari terhadap penampil, dan secara global.
  Offset pointer;
  Offset global;

  /// Halaman di bawah jari; null bila di celah antarhalaman.
  int? targetPage;
}

/// Satu langkah yang bisa diurungkan dan diulangi.
class _UndoStep {
  _UndoStep(this.label, {required this.before, required this.after})
    : assert(before != null || after != null);

  /// Disebut apa saat diurungkan, supaya yang menekan tahu apa yang kembali.
  final String label;

  /// Keadaan anotasinya sebelum langkah ini; null berarti belum ada.
  final ZoteroAnnotation? before;

  /// Keadaan anotasinya sesudah langkah ini; null berarti sudah dihapus.
  final ZoteroAnnotation? after;

  String get key => (after ?? before)!.key;
}

/// Koleksi yang dipilih saat memasukkan berkas ke library; null berarti
/// tidak masuk koleksi mana pun.
class _CollectionChoice {
  const _CollectionChoice(this.key) : create = false;

  /// Membuat koleksi baru dulu, di dalam [key] (null berarti di akar).
  const _CollectionChoice.create(this.key) : create = true;

  final String? key;
  final bool create;
}

/// Lama buntut penunjuk: dari tanpa buntut sampai dua detik.
class _TrailButton extends StatelessWidget {
  const _TrailButton({required this.milliseconds, required this.onSelected});

  final int milliseconds;
  final ValueChanged<int> onSelected;

  static const List<int> choices = <int>[0, 300, 600, 1000, 1500, 2000];

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: context.l10n.presenterPointerTrail,
    icon: const Icon(Icons.timelapse),
    initialValue: milliseconds,
    onSelected: onSelected,
    itemBuilder: (context) => <PopupMenuEntry<int>>[
      for (final ms in choices)
        CheckedPopupMenuItem<int>(
          value: ms,
          checked: ms == milliseconds,
          child: Text(
            ms == 0
                ? context.l10n.presenterTrailOff
                : context.l10n.presenterTrailSeconds(
                    (ms / 1000).toStringAsFixed(ms % 1000 == 0 ? 0 : 1),
                  ),
          ),
        ),
    ],
  );
}
