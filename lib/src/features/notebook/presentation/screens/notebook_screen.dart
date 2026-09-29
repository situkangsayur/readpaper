import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../../../../core/utils/ink_palette.dart';
import '../../../../core/utils/ink_smoothing.dart';
import '../../../../core/utils/shape_geometry.dart';
import '../../../library/presentation/controllers/library_controllers.dart';
import '../../../notes/domain/note_target.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../data/note_document_store.dart';
import '../../data/note_export.dart';
import '../../data/pdf_to_notebook.dart';
import '../../domain/note_document.dart';
import '../../domain/note_history.dart';
import '../widgets/component_frame.dart';
import '../widgets/note_canvas.dart';

/// Alat yang sedang dipegang.
enum NoteTool { pena, hapusGoresan, hapusSebagian, pilih, bangun, hubung, teks, gambar, diagram }

/// Buku catatan: berlembar-lembar, ditulis dengan stylus, isinya komponen yang
/// masih bisa disentuh satu per satu.
///
/// Bedanya dengan papan tulis: papan tulis menghasilkan gambar, buku catatan
/// menghasilkan dokumen. Tiap gerakan pena jadi satu komponen tinta yang bisa
/// digeser, diputar, diwarnai, dan dihapus sendiri — dan seluruhnya disimpan
/// dalam bentuk yang bisa dibuka dan disunting lagi.
class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({required this.path, this.title, super.key});

  /// Berkas `.catatan.json`-nya. Boleh belum ada — dibuat saat disimpan.
  final String path;

  final String? title;

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  late NoteHistory _history;
  late NoteDocument _document;
  int _page = 0;
  bool _dirty = false;
  String? _error;

  NoteTool _tool = NoteTool.pena;
  Color _pen = const Color(0xFF1A1A1A);
  double _penWidth = 2.5;
  double _eraserRadius = 14;

  String? _selectedId;
  List<Offset> _live = const <Offset>[];
  List<double> _liveWidths = const <double>[];
  Offset? _eraserAt;

  /// Tekanan stylus terakhir, 0..1. Null berarti alatnya tidak melaporkan
  /// tekanan — jari dan tetikus tidak — dan goresannya bertebal tetap.
  double? _pressure;

  /// Bangun yang sedang dipilih untuk disisipkan.
  ShapeKind _shape = ShapeKind.kotak;

  /// Sudut tarik bangun yang sedang dibuat: dari mana ke mana.
  Offset? _shapeFrom;
  Offset? _shapeTo;

  /// Benda pertama yang sudah diketuk dengan alat penghubung.
  String? _connectFrom;

  /// Boleh menggambar dengan jari.
  ///
  /// Dimatikan berarti hanya stylus yang menggambar — dan itulah penolak
  /// telapak tangan yang sebenarnya: tangan yang bertumpu di kertas tidak
  /// meninggalkan garis, karena sentuhannya tidak pernah sampai ke kanvas.
  bool _finger = true;

  /// Yang boleh menggambar. Tetikus ikut, supaya di layar tanpa stylus —
  /// termasuk saat diuji — kanvasnya tetap bisa dipakai.
  Set<PointerDeviceKind>? get _drawWith => _finger
      ? null
      : const <PointerDeviceKind>{
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.mouse,
        };

  /// Satu gerakan tangan = satu langkah urungkan, bukan satu per piksel.
  bool _touchedThisGesture = false;

  /// Sudah menjelaskan sekali kenapa seretan tidak menggambar apa pun.
  bool _explainedIdleDrag = false;

  /// Tempat jari mulai menekan, untuk mengenali seretan yang sia-sia.
  Offset? _dragFrom;

  /// Zum kanvas: dikerjakan sendiri, **bukan** dengan InteractiveViewer.
  ///
  /// InteractiveViewer memasang pengenal gerakan yang ikut bersaing untuk
  /// seretan satu jari. Hasilnya terukur: awal setiap goresan hilang sekitar
  /// enam puluh piksel sebelum kanvas menang di arena, dan seretan pendek —
  /// satu ketukan penghapus — tidak pernah sampai sama sekali. Zum di sini
  /// dihitung langsung dari peristiwa pointer, jadi tidak ada arena yang perlu
  /// dimenangkan siapa pun.
  double _userScale = 1;
  Offset _userOffset = Offset.zero;

  /// Pointer yang sedang menyentuh layar, beserta tempatnya.
  final Map<int, Offset> _pointers = <int, Offset>{};

  final GlobalKey _viewportKey = GlobalKey();

  double? _pinchDistance;
  double _pinchScale = 1;

  /// Titik lembar yang berada di bawah jari saat cubitan dimulai; itulah yang
  /// dijaga tetap di bawah jari selama mencubit.
  Offset _pinchScene = Offset.zero;

  /// Tempat jari terakhir saat menggeser kanvas dengan satu jari.
  Offset? _panFrom;

  /// Kotak pilih yang sedang ditarik, dalam koordinat lembar.
  Rect? _marquee;

  /// Benda-benda yang terpilih lewat kotak pilih.
  Set<String> _picked = const <String>{};

  @override
  void initState() {
    super.initState();
    _document = _load();
    _history = NoteHistory(_document);
  }

  void _resetZoom() => setState(() {
    _userScale = 1;
    _userOffset = Offset.zero;
  });

  /// Memperbesar atau memperkecil dari tombol, berporos di tengah kotak.
  ///
  /// Perlu ada karena di mode "Stylus saja" layar memang tidak menanggapi
  /// sentuhan sama sekali — termasuk cubitan — dan tanpa tombol ini tidak ada
  /// jalan memperbesar.
  void _zoomBy(double factor) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final centre = box == null
        ? Offset.zero
        : Offset(box.size.width / 2, box.size.height / 2);
    final scene = (centre - _userOffset) / _userScale;
    setState(() {
      _userScale = (_userScale * factor).clamp(1.0, 8.0);
      _userOffset = _userScale == 1 ? Offset.zero : centre - scene * _userScale;
    });
  }

  NoteDocument _load() {
    final file = File(widget.path);
    if (!file.existsSync()) {
      return NoteDocument.blank(title: widget.title ?? '');
    }
    try {
      // Dibaca langsung: catatan berukuran kecil, dan layar yang terbuka
      // sebaiknya sudah berisi tulisannya.
      return NoteDocumentStore.decodeSync(file.readAsStringSync());
    } on Object catch (e) {
      _error = '$e';
      return NoteDocument.blank(title: widget.title ?? '');
    }
  }

  NotePage get _sheet => _document.pages[_page];

  String get _baseDir => p.dirname(widget.path);

  /// Mengganti isi dokumen. [commit] menandai akhir sebuah gerakan, dan
  /// hanya di situ langkah urungkan dicatat.
  void _apply(NoteDocument next, {bool commit = true}) {
    setState(() {
      _document = next;
      _dirty = true;
      if (commit) _history.push(next);
    });
  }

  void _replaceComponents(List<NoteComponent> components, {bool commit = true}) =>
      _apply(_document.replacePage(_page, _sheet.copyWith(components: components)), commit: commit);

  NoteComponent? get _selected => _sheet.components.where((c) => c.id == _selectedId).firstOrNull;

  void _update(NoteComponent replacement, {bool commit = false}) {
    _replaceComponents(<NoteComponent>[
      for (final component in _sheet.components)
        if (component.id == replacement.id) replacement else component,
    ], commit: commit);
  }

  // ------------------------------------------------------------------ menulis

  /// Tebal untuk titik yang baru: mengikuti tekanan kalau alatnya melaporkan.
  double get _nextWidth =>
      _pressure == null ? _penWidth : InkSmoothing.widthFor(_penWidth, _pressure!);

  /// Mencatat tekanan dari peristiwa pointer mentah.
  ///
  /// Hanya stylus: banyak layar melaporkan tekanan tetap untuk jari, dan
  /// mengikutinya membuat tebal goresan berubah tanpa sebab.
  /// Titik layar jadi titik di dalam kotak kanvas, sebelum zum.
  Offset _toViewport(Offset global) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  /// Pembagian tugas antara stylus dan jari.
  ///
  /// Di mode "Stylus saja": stylus **menggambar**, jari **menavigasi** — satu
  /// jari menggeser, dua jari memperbesar. Sebelumnya jari dilarang menyentuh
  /// apa pun di mode ini, dan akibatnya layar terasa beku: tidak bisa digeser,
  /// tidak bisa diperbesar, tidak bisa apa-apa kecuali dengan stylus. Yang
  /// sebenarnya dihindari cuma satu — telapak tangan meninggalkan garis — dan
  /// itu sudah ditangani dengan membatasi **menggambar** pada stylus saja.
  bool _navigates(PointerEvent event) =>
      !_finger &&
      (event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.unknown);

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2) {
      _startPinch();
      return;
    }
    // Satu jari menggeser, tetapi tidak di tengah goresan yang sedang ditarik:
    // yang sedang menulis dengan stylus tidak sedang meminta kertasnya bergeser.
    if (_navigates(event) && _live.isEmpty) {
      _panFrom = event.position;
      return;
    }
    _notePressure(event);
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2) {
      _updatePinch();
      return;
    }

    final from = _panFrom;
    if (from != null && _navigates(event)) {
      final delta = event.position - from;
      _panFrom = event.position;
      // Saat belum diperbesar, lembarnya sudah pas di layar dan menggesernya
      // hanya membuat bingung.
      if (_userScale > 1.001) setState(() => _userOffset += delta);
      return;
    }
    _notePressure(event);
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchDistance = null;
    if (_pointers.isEmpty) _panFrom = null;
  }

  /// Mulai mencubit: goresan yang sedang ditarik dibuang.
  ///
  /// Jari kedua yang mendarat berarti yang dimaksud memperbesar, bukan
  /// menggambar — dan garis nyasar yang tertinggal dari gerakan itu harus
  /// dihapus sendiri oleh yang mencubit, yang menjengkelkan.
  void _startPinch() {
    final points = _pointers.values.toList();
    final a = _toViewport(points[0]);
    final b = _toViewport(points[1]);
    final focus = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    setState(() {
      _live = const <Offset>[];
      _liveWidths = const <double>[];
      _shapeFrom = null;
      _shapeTo = null;
      _marquee = null;
      _panFrom = null;
      _pinchDistance = (a - b).distance;
      _pinchScale = _userScale;
      _pinchScene = (focus - _userOffset) / _userScale;
    });
  }

  void _updatePinch() {
    final start = _pinchDistance;
    if (start == null || start < 1) return;
    final points = _pointers.values.toList();
    final a = _toViewport(points[0]);
    final b = _toViewport(points[1]);
    final focus = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

    final scale = (_pinchScale * (a - b).distance / start).clamp(1.0, 8.0);
    setState(() {
      _userScale = scale;
      // Titik lembar yang tadi di bawah jari tetap di bawah jari: itulah yang
      // membuat mencubit terasa memegang kertas, bukan menggeser jendela.
      _userOffset = scale == 1 ? Offset.zero : focus - _pinchScene * scale;
    });
  }

  void _notePressure(PointerEvent event) {
    _watchIdleDrag(event);

    final stylus =
        event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus;
    if (!stylus || event.pressureMax <= event.pressureMin) {
      _pressure = null;
      return;
    }
    _pressure = ((event.pressure - event.pressureMin) / (event.pressureMax - event.pressureMin))
        .clamp(0.0, 1.0);
  }

  /// Memperhatikan seretan yang tidak meninggalkan apa pun.
  ///
  /// Diperhatikan dari peristiwa pointer, **bukan** dengan memasang pengenal
  /// gerakan di kanvas: pengenal gerakan di kanvas ikut bersaing di arena dan
  /// membuat bingkai komponen tidak bisa diseret lagi. Itu pernah terjadi.
  void _watchIdleDrag(PointerEvent event) {
    final menggambar =
        _tool == NoteTool.pena ||
        _tool == NoteTool.hapusGoresan ||
        _tool == NoteTool.hapusSebagian ||
        _tool == NoteTool.bangun;
    if (menggambar) return;

    if (event is PointerDownEvent) {
      _dragFrom = event.position;
      return;
    }
    final from = _dragFrom;
    if (from == null || _selectedId != null) return;
    if ((event.position - from).distance < 24) return;
    _dragFrom = null;
    _explainIdleDrag();
  }

  void _onPanStart(Offset sheetPoint) {
    _touchedThisGesture = false;
    switch (_tool) {
      case NoteTool.pena:
        setState(() {
          _live = <Offset>[sheetPoint];
          _liveWidths = <double>[_nextWidth];
        });
      case NoteTool.hapusGoresan:
      case NoteTool.hapusSebagian:
        setState(() => _eraserAt = sheetPoint);
        _erase(sheetPoint);
      case NoteTool.bangun:
        setState(() {
          _shapeFrom = sheetPoint;
          _shapeTo = sheetPoint;
        });
      case NoteTool.pilih:
      case NoteTool.hubung:
      case NoteTool.teks:
      case NoteTool.gambar:
      case NoteTool.diagram:
        break;
    }
  }

  void _onPanUpdate(Offset sheetPoint) {
    switch (_tool) {
      case NoteTool.pena:
        // Titik yang terlalu rapat hanya menambah besar berkas tanpa
        // mengubah bentuk garisnya.
        if (_live.isNotEmpty && (_live.last - sheetPoint).distance < InkSmoothing.minStep) {
          return;
        }
        setState(() {
          _live = <Offset>[..._live, sheetPoint];
          _liveWidths = <double>[..._liveWidths, _nextWidth];
        });
      case NoteTool.hapusGoresan:
      case NoteTool.hapusSebagian:
        setState(() => _eraserAt = sheetPoint);
        _erase(sheetPoint);
      case NoteTool.bangun:
        setState(() => _shapeTo = sheetPoint);
      case NoteTool.pilih:
      case NoteTool.hubung:
      case NoteTool.teks:
      case NoteTool.gambar:
      case NoteTool.diagram:
        break;
    }
  }

  void _onPanEnd() {
    if (_tool == NoteTool.pena && _live.length > 1) {
      _commitStroke();
    } else if (_tool == NoteTool.bangun) {
      _commitShape();
    } else if (_touchedThisGesture) {
      setState(() => _history.push(_document));
    }
    setState(() {
      _live = const <Offset>[];
      _liveWidths = const <double>[];
      _eraserAt = null;
      _shapeFrom = null;
      _shapeTo = null;
      _touchedThisGesture = false;
    });
  }

  /// Menjadikan bangun yang baru ditarik sebuah komponen.
  ///
  /// Seretan yang terlalu kecil diabaikan: itu ketukan yang tidak sengaja,
  /// dan bangun setitik hanya jadi sampah di lembar.
  void _commitShape() {
    final from = _shapeFrom;
    final to = _shapeTo;
    if (from == null || to == null) return;
    final box = Rect.fromPoints(from, to);
    if (box.width < 6 && box.height < 6) return;

    // Garis dan panah memakai arah tarikannya, jadi ujungnya tidak boleh
    // dinormalkan jadi kotak — panah ke kiri atas harus tetap menunjuk ke
    // kiri atas.
    final berarah = _shape == ShapeKind.garis || _shape == ShapeKind.panah;
    _replaceComponents(<NoteComponent>[
      ..._sheet.components,
      NoteShape(
        id: _freshId('bangun'),
        position: berarah ? from : box.topLeft,
        size: berarah
            ? Size(to.dx - from.dx, to.dy - from.dy)
            : Size(math.max(box.width, 6), math.max(box.height, 6)),
        shape: _shape,
        strokeWidth: _penWidth,
        color: _pen.toARGB32(),
      ),
    ]);
  }

  /// Menghubungkan dua benda: ketuk yang pertama, lalu yang kedua.
  void _connect(Offset sheetPoint) {
    final hit = _sheet.hitTest(sheetPoint);
    if (hit == null || hit is NoteConnector) {
      setState(() => _connectFrom = null);
      return;
    }
    final first = _connectFrom;
    if (first == null) {
      setState(() => _connectFrom = hit.id);
      _say('Sekarang ketuk benda yang kedua.');
      return;
    }
    if (first == hit.id) {
      setState(() => _connectFrom = null);
      return;
    }
    _replaceComponents(<NoteComponent>[
      ..._sheet.components,
      NoteConnector(
        id: _freshId('hubung'),
        fromId: first,
        toId: hit.id,
        color: _pen.toARGB32(),
        strokeWidth: math.max(1.2, _penWidth * 0.7),
      ),
    ]);
    setState(() => _connectFrom = null);
  }

  /// Menjadikan goresan yang baru ditarik sebuah komponen.
  ///
  /// Satu gerakan pena = satu komponen. Itu batas yang jujur untuk sekarang:
  /// mengelompokkan beberapa goresan jadi satu kata adalah pekerjaan
  /// pengenalan tulisan, dan menebaknya di sini akan sering salah.
  void _commitStroke() {
    // Daftar tebal hanya disimpan kalau tekanannya memang berubah: menyimpan
    // daftar yang isinya angka sama semua hanya menggandakan besar berkasnya.
    final varied =
        _liveWidths.length == _live.length && _liveWidths.any((w) => (w - _penWidth).abs() > 0.01);

    final stroke = NoteStroke(points: _live, width: _penWidth);
    final bounds = stroke.bounds;
    final local = NoteStroke(
      points: <Offset>[for (final point in _live) point - bounds.topLeft],
      width: _penWidth,
      widths: varied ? List<double>.of(_liveWidths) : null,
    );
    final ink = NoteInk(
      id: _freshId('tinta'),
      position: bounds.topLeft,
      size: Size(math.max(bounds.width, 1), math.max(bounds.height, 1)),
      strokes: <NoteStroke>[local],
      color: _pen.toARGB32(),
    );
    _replaceComponents(<NoteComponent>[..._sheet.components, ink]);
  }

  /// Menghapus di [at]: seluruh goresan, atau hanya bagian yang dilewati.
  void _erase(Offset at) {
    final radius = _eraserRadius;
    final kept = <NoteComponent>[];
    var changed = false;

    for (final component in _sheet.components) {
      if (component is! NoteInk) {
        kept.add(component);
        continue;
      }
      final origin = component.position;
      final local = at - origin;
      final strokes = <NoteStroke>[];
      for (final stroke in component.strokes) {
        if (stroke.distanceTo(local) > radius) {
          strokes.add(stroke);
          continue;
        }
        changed = true;
        if (_tool == NoteTool.hapusSebagian) {
          strokes.addAll(stroke.erase(local, radius));
        }
        // Penghapus per goresan: goresannya hilang seluruhnya.
      }
      if (strokes.isEmpty) continue;
      kept.add(strokes == component.strokes ? component : component.copyWith(strokes: strokes));
    }

    if (!changed) return;
    _touchedThisGesture = true;
    _replaceComponents(kept, commit: false);
  }

  String _freshId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  // --------------------------------------------------------------- komponen

  /// Benda yang baru ditaruh langsung terpilih, dan alatnya pindah ke Pilih.
  ///
  /// Tanpa ini, benda yang baru disisipkan tidak bisa digeser, diubah ukuran,
  /// diputar, atau dihapus sampai alatnya diganti sendiri — dan tidak ada yang
  /// mengatakan bahwa itu yang kurang. Menempelkan sesuatu hampir selalu
  /// diikuti membetulkan tempatnya.
  void _placed(NoteComponent component) {
    _replaceComponents(<NoteComponent>[..._sheet.components, component]);
    setState(() {
      _tool = NoteTool.pilih;
      _selectedId = component.id;
      _picked = const <String>{};
    });
  }

  Future<void> _addText(Offset at) async {
    final text = await _ask(title: 'Teks baru', hint: 'Tulis teksnya');
    if (text == null || text.trim().isEmpty) return;
    _placed(
      NoteText(
        id: _freshId('teks'),
        position: at,
        size: const Size(280, 60),
        text: text.trim(),
        color: _pen.toARGB32(),
      ),
    );
  }

  Future<void> _addDiagram(Offset at) async {
    final source = await _ask(
      title: 'Diagram baru',
      hint: 'Sumber Mermaid',
      initial: 'graph TD\n  A[Mulai] --> B[Selesai]',
      lines: 6,
    );
    if (source == null || source.trim().isEmpty) return;
    _placed(
      NoteDiagram(
        id: _freshId('diagram'),
        position: at,
        size: const Size(260, 180),
        source: source.trim(),
      ),
    );
  }

  Future<void> _addImage(Offset at) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: 'Pilih gambar untuk catatan',
    );
    if (picked.isEmpty) return;
    final source = picked.first.path;
    if (source == null) {
      // Beberapa penyedia berkas Android hanya menyerahkan URI tanpa jalur
      // berkas. Dikatakan, bukan didiamkan — yang memilih gambar berhak tahu
      // kenapa gambarnya tidak muncul.
      _say('Gambar itu tidak bisa dibaca dari tempatnya. Salin dulu ke folder kerja.');
      return;
    }

    // Gambarnya disalin ke sebelah dokumennya dan dirujuk secara relatif,
    // supaya catatan yang ikut tersinkron tetap menemukan gambarnya.
    final stem = NoteDocumentStore.stemOf(widget.path);
    final dir = Directory(p.join(_baseDir, '$stem-berkas'));
    await dir.create(recursive: true);
    var target = File(p.join(dir.path, p.basename(source)));
    for (var n = 2; target.existsSync() && n < 100; n++) {
      target = File(
        p.join(dir.path, '${p.basenameWithoutExtension(source)}-$n${p.extension(source)}'),
      );
    }
    await File(source).copy(target.path);

    _placed(
      NoteImage(
        id: _freshId('gambar'),
        position: at,
        size: const Size(200, 150),
        file: p.relative(target.path, from: _baseDir).replaceAll(r'\', '/'),
        alt: p.basenameWithoutExtension(source),
      ),
    );
    if (mounted) _say('Gambar ditaruh — sekarang bisa digeser, diubah ukuran, atau dihapus.');
  }

  Future<void> _editSelected() async {
    final component = _selected;
    switch (component) {
      case NoteText():
        final text = await _ask(title: 'Ubah teks', initial: component.text, lines: 4);
        if (text == null) return;
        _update(component.copyWith(text: text), commit: true);
      case NoteDiagram():
        final source = await _ask(title: 'Ubah diagram', initial: component.source, lines: 8);
        if (source == null) return;
        _update(component.copyWith(source: source), commit: true);
      case NoteImage():
      case NoteInk():
      case NoteShape():
      case NoteConnector():
      case null:
        break;
    }
  }

  void _deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    // `without` ikut membuang penghubung yang menempel: garis yang salah satu
    // ujungnya hilang bukan penghubung lagi.
    _apply(_document.replacePage(_page, _sheet.without(id)));
    setState(() => _selectedId = null);
  }

  // --------------------------------------------------------------- halaman

  void _addPage() {
    _apply(
      _document.copyWith(
        pages: <NotePage>[
          ..._document.pages,
          // Kertasnya ikut lembar yang sedang dibuka: yang sedang menggambar
          // bagan A3 mendatar hampir selalu butuh satu lagi.
          NotePage(
            rule: _sheet.rule,
            background: _sheet.background,
            paper: _sheet.paper,
            orientation: _sheet.orientation,
          ),
        ],
      ),
    );
    setState(() {
      _page = _document.pages.length - 1;
      _selectedId = null;
    });
  }

  /// Menyisipkan halaman sebuah PDF sebagai lembar-lembar baru.
  ///
  /// Inilah jawaban untuk "lembar baru dari PDF": halamannya jadi alas lembar,
  /// dan di atasnya bisa ditulis seperti lembar lain. Disisipkan **setelah**
  /// lembar yang sedang dibuka, bukan di ujung buku — yang menyisipkan biasanya
  /// sedang berada di tempat yang dimaksud.
  Future<void> _insertPdfPages() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
      dialogTitle: 'Pilih PDF untuk disisipkan sebagai lembar',
    );
    if (picked.isEmpty) return;
    final source = picked.first.path;
    if (source == null) return;

    _say('Menyiapkan lembar dari ${p.basename(source)}…');
    try {
      final relativeDir = '${NoteDocumentStore.stemOf(widget.path)}-berkas';
      final pages = await PdfToNotebook.pagesOf(
        pdfPath: source,
        assetDir: p.join(_baseDir, relativeDir),
        relativeDir: relativeDir,
        prefix: p.basenameWithoutExtension(source),
      );
      if (!mounted) return;
      if (pages.isEmpty) {
        _say('PDF itu tidak punya halaman yang bisa dibaca.');
        return;
      }

      final at = _page + 1;
      _apply(
        _document.copyWith(
          pages: <NotePage>[..._document.pages.take(at), ...pages, ..._document.pages.skip(at)],
        ),
      );
      setState(() {
        _page = at;
        _selectedId = null;
      });
      _say('${pages.length} lembar disisipkan dari ${p.basename(source)}.');
    } on Object catch (e) {
      if (mounted) _say('Gagal menyisipkan PDF: $e');
    }
  }

  void _deletePage() {
    if (_document.pages.length == 1) {
      // Satu-satunya lembar tidak dihapus melainkan dikosongkan: menutup
      // buku karena menekan hapus bukan yang dimaksud siapa pun.
      _replaceComponents(const <NoteComponent>[]);
      return;
    }
    final pages = <NotePage>[..._document.pages]..removeAt(_page);
    _apply(_document.copyWith(pages: pages));
    setState(() {
      _page = _page.clamp(0, pages.length - 1);
      _selectedId = null;
    });
  }

  // --------------------------------------------------------------- menyimpan

  Future<bool> _save() async {
    try {
      await NoteDocumentStore.write(widget.path, _document);
      if (!mounted) return true;
      setState(() => _dirty = false);
      _say('Tersimpan: ${p.basename(widget.path)}');
      return true;
    } on Object catch (e) {
      if (mounted) _say('Gagal menyimpan: $e');
      return false;
    }
  }

  Future<void> _exportMarkdown() async {
    final stem = NoteDocumentStore.stemOf(widget.path);
    try {
      final markdown = await NoteExport.toMarkdown(
        _document,
        assetDir: p.join(_baseDir, '$stem-berkas'),
        assetPrefix: '$stem-tinta',
      );
      // Tinta tersimpan di folder sebelah, jadi rujukannya ikut berawalan.
      final fixed = markdown.replaceAll('($stem-tinta', '($stem-berkas/$stem-tinta');
      final file = File(p.join(_baseDir, '$stem.md'));
      await file.writeAsString(fixed, flush: true);
      if (mounted) _say('Markdown tersimpan: ${p.basename(file.path)}');
    } on Object catch (e) {
      if (mounted) _say('Gagal menulis Markdown: $e');
    }
  }

  Future<void> _exportPdf() async {
    try {
      final bytes = await NoteExport.toPdf(_document, baseDir: _baseDir);
      final file = File(p.join(_baseDir, '${NoteDocumentStore.stemOf(widget.path)}.pdf'));
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('PDF tersimpan: ${p.basename(file.path)}'),
            action: SnackBarAction(
              label: 'Cetak',
              onPressed: () => Printing.layoutPdf(onLayout: (_) async => bytes),
            ),
          ),
        );
    } on Object catch (e) {
      if (mounted) _say('Gagal menulis PDF: $e');
    }
  }

  /// Menyimpan catatan ini ke koleksi catatan yang sedang dipilih.
  Future<void> _saveToCollection() async {
    final target = NoteTarget.of(ref.read(selectionProvider));
    if (!target.isAllowed) {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Belum bisa disimpan sebagai catatan'),
          content: Text(target.refusal!),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Mengerti')),
          ],
        ),
      );
      return;
    }
    if (!await _save()) return;
    final key = await ref
        .read(notesControllerProvider.notifier)
        .addFile(
          sourcePath: widget.path,
          title: _document.title.isEmpty ? NoteDocumentStore.stemOf(widget.path) : _document.title,
          collectionKey: target.collectionKey,
        );
    if (!mounted) return;
    _say(
      key == null
          ? (ref.read(notesErrorProvider) ?? 'Gagal menyimpan ke koleksi')
          : 'Masuk ke koleksi catatan',
    );
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<String?> _ask({required String title, String initial = '', String? hint, int lines = 1}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: lines,
          decoration: InputDecoration(hintText: hint),
          style: lines > 1 ? const TextStyle(fontFamily: 'monospace', fontSize: 13) : null,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Simpan dulu?'),
        content: const Text('Ada tulisan yang belum disimpan.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop('batal'),
            child: const Text('Kembali menulis'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop('buang'),
            child: const Text('Buang'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop('simpan'),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (choice == 'simpan') return _save();
    return choice == 'buang';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (!leave || !mounted) return;
        Navigator.of(this.context).pop(widget.path);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.title ?? NoteDocumentStore.stemOf(widget.path)),
              Text(
                'Lembar ${_page + 1} dari ${_document.pages.length} · '
                '${_sheet.paper.label} ${_sheet.orientation.label.toLowerCase()} · '
                'alat: ${_toolLabel(_tool)}'
                '${_dirty ? ' · belum disimpan' : ''}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Perkecil',
              icon: const Icon(Icons.zoom_out),
              onPressed: _userScale <= 1.001 ? null : () => _zoomBy(1 / 1.4),
            ),
            IconButton(
              tooltip: 'Perbesar',
              icon: const Icon(Icons.zoom_in),
              onPressed: _userScale >= 7.99 ? null : () => _zoomBy(1.4),
            ),
            IconButton(
              tooltip: 'Pas ke layar — kembalikan zum',
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: _userScale == 1 ? null : _resetZoom,
            ),
            IconButton(
              tooltip: 'Urungkan',
              icon: const Icon(Icons.undo),
              onPressed: _history.canUndo
                  ? () => setState(() {
                      _document = _history.undo();
                      _dirty = true;
                      _selectedId = null;
                      _page = _page.clamp(0, _document.pages.length - 1);
                    })
                  : null,
            ),
            IconButton(
              tooltip: 'Ulangi',
              icon: const Icon(Icons.redo),
              onPressed: _history.canRedo
                  ? () => setState(() {
                      _document = _history.redo();
                      _dirty = true;
                      _selectedId = null;
                      _page = _page.clamp(0, _document.pages.length - 1);
                    })
                  : null,
            ),
            PopupMenuButton<String>(
              tooltip: 'Simpan dan bagikan',
              onSelected: (choice) => switch (choice) {
                'markdown' => _exportMarkdown(),
                'pdf' => _exportPdf(),
                'koleksi' => _saveToCollection(),
                'garis' => _cycleRule(),
                _ => null,
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'markdown',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notes_outlined),
                    title: Text('Simpan sebagai Markdown'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'pdf',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Simpan sebagai PDF'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'koleksi',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.sticky_note_2_outlined),
                    title: Text('Simpan ke koleksi catatan'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'garis',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.grid_4x4),
                    title: Text('Garis bantu lembar'),
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Simpan',
              icon: const Icon(Icons.save_outlined),
              onPressed: _dirty ? _save : null,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: <Widget>[
            if (_error != null)
              Material(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ),
            _Tools(
              tool: _tool,
              pen: _pen,
              penWidth: _penWidth,
              eraserRadius: _eraserRadius,
              shape: _shape,
              finger: _finger,
              selected: _selected,
              onTool: (tool) {
                // Alat penempel butuh satu ketukan lagi di lembarnya. Tanpa
                // dikatakan, memilihnya terasa seperti tidak terjadi apa-apa —
                // dan kesimpulannya "tidak bisa", bukan "belum".
                final tempel = switch (tool) {
                  NoteTool.teks => 'teks',
                  NoteTool.gambar => 'gambar',
                  NoteTool.diagram => 'diagram',
                  NoteTool.hubung => null,
                  _ => null,
                };
                if (tempel != null) _say('Ketuk lembar untuk menaruh $tempel.');
                if (tool == NoteTool.hubung) {
                  _say('Ketuk benda pertama, lalu benda kedua.');
                }
                setState(() {
                  _tool = tool;
                  _explainedIdleDrag = false;
                  if (tool != NoteTool.pilih) {
                    _selectedId = null;
                    _picked = const <String>{};
                  }
                  if (tool != NoteTool.hubung) _connectFrom = null;
                });
              },
              onFinger: (value) => setState(() => _finger = value),
              onShape: (kind) => setState(() {
                _shape = kind;
                // Memilih bangun berarti mau menggambarnya: alatnya ikut
                // berpindah, supaya tidak perlu dua ketukan untuk satu maksud.
                _tool = NoteTool.bangun;
                _selectedId = null;
              }),
              onPen: (color) => setState(() => _pen = color),
              onPenWidth: (width) => setState(() => _penWidth = width),
              onEraser: (radius) => setState(() => _eraserRadius = radius),
              onColor: (color) {
                final component = _selected;
                if (component != null) {
                  _update(component.copyWith(color: color.toARGB32()), commit: true);
                }
              },
              onOpacity: (opacity) {
                final component = _selected;
                if (component != null) _update(component.copyWith(opacity: opacity), commit: true);
              },
            ),
            if (_picked.isNotEmpty)
              Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text('${_picked.length} benda dipilih')),
                      TextButton.icon(
                        onPressed: _deletePicked,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hapus'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _picked = const <String>{}),
                        child: const Text('Lepas'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: _sheetArea()),
            _PageBar(
              page: _page,
              count: _document.pages.length,
              paper: _sheet.paper,
              orientation: _sheet.orientation,
              onGo: (index) => setState(() {
                _page = index;
                _selectedId = null;
              }),
              onAdd: _addPage,
              onAddPdf: _insertPdfPages,
              onDelete: _deletePage,
              onPaper: _setPaper,
              onTurn: _turnPage,
            ),
          ],
        ),
      ),
    );
  }

  /// Mengganti ukuran kertas lembar ini.
  ///
  /// Isinya tidak diikutkan mengecil atau membesar: kertas yang diperbesar
  /// memberi ruang, bukan tulisan yang membengkak. Kalau diperkecil dan ada
  /// yang jadi di luar kertas, itu dikatakan — memindahkannya sendiri akan
  /// mengacaukan tata letak yang sudah diatur.
  void _setPaper(NotePaper paper) {
    final next = _sheet.copyWith(paper: paper);
    _apply(_document.replacePage(_page, next));
    final outside = next.outsidePaper;
    if (outside == 0) return;
    _say('Kertas jadi ${paper.label}. $outside benda sekarang di luar kertas.');
  }

  /// Memutar kertas lembar ini seperempat putaran, beserta isinya.
  void _turnPage() {
    final turned = _sheet.turned();
    _apply(_document.replacePage(_page, turned));
    if (_sheet.components.isEmpty) return;
    _say(
      'Kertas jadi ${turned.orientation.label.toLowerCase()} — '
      'isinya ikut berputar, tidak ada yang keluar tepi.',
    );
  }

  void _cycleRule() {
    const order = NotePageRule.values;
    final next = order[(order.indexOf(_sheet.rule) + 1) % order.length];
    _apply(_document.replacePage(_page, _sheet.copyWith(rule: next)));
  }

  /// Ruang di sekeliling lembar, tempat pegangan bingkai komponen duduk.
  ///
  /// Bukan hiasan: anak yang digambar di luar batas induknya **tidak pernah
  /// menerima sentuhan**. Tanpa ruang ini, komponen yang menempel di tepi atas
  /// lembar punya tombol hapus yang terlihat jelas tetapi tidak bisa ditekan —
  /// dan itu memang yang terjadi.
  static const double _margin = ComponentFrame.grip + 6;

  Widget _sheetArea() => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math.min(
        (constraints.maxWidth - _margin * 2) / _sheet.size.width,
        (constraints.maxHeight - _margin * 2) / _sheet.size.height,
      );
      final selected = _selected;

      // Alat yang menggambar mengambil seretan; alat yang tidak menggambar
      // melepaskannya sama sekali. Itu bukan penghematan: selama kanvas masih
      // memasang pengenal seretan, bingkai komponen di atasnya kalah di arena
      // gerakan dan komponennya tidak pernah bisa digeser.
      final menggambar =
          _tool == NoteTool.pena ||
          _tool == NoteTool.hapusGoresan ||
          _tool == NoteTool.hapusSebagian ||
          _tool == NoteTool.bangun;

      // Kotak pilih hanya saat tidak ada satu benda yang sedang terpilih —
      // kalau ada, seretan itu milik bingkainya.
      final menandai = _tool == NoteTool.pilih && selected == null;

      /// Titik layar jadi titik lembar.
      Offset toSheet(Offset local) => (local - const Offset(_margin, _margin)) / scale;

      return Center(
        child: Listener(
          key: _viewportKey,
          // Tekanan stylus dan cubitan dua jari sama-sama dibaca dari
          // peristiwa pointer mentah: GestureDetector tidak menyerahkan
          // tekanan, dan pengenal gerakan untuk zum akan merebut seretan satu
          // jari milik pena.
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          // Transform di luar GestureDetector: Flutter memetakan balik
          // koordinat sentuhan lewat transform, jadi titik yang digambar tetap
          // mendarat di tempat yang terlihat — sedekat apa pun zumnya.
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(_userOffset.dx, _userOffset.dy, 0, 1)
              ..scaleByDouble(_userScale, _userScale, 1, 1),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              supportedDevices: _drawWith,
              onTapUp: (details) => _onTap(toSheet(details.localPosition)),
              onPanStart: menggambar
                  ? (details) => _onPanStart(toSheet(details.localPosition))
                  : (menandai ? (details) => _markStart(toSheet(details.localPosition)) : null),
              onPanUpdate: menggambar
                  ? (details) => _onPanUpdate(toSheet(details.localPosition))
                  : (menandai ? (details) => _markUpdate(toSheet(details.localPosition)) : null),
              onPanEnd: menggambar ? (_) => _onPanEnd() : (menandai ? (_) => _markEnd() : null),
              onPanCancel: menggambar ? _onPanEnd : (menandai ? _markEnd : null),
              child: SizedBox(
                width: _sheet.size.width * scale + _margin * 2,
                height: _sheet.size.height * scale + _margin * 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: _margin,
                      top: _margin,
                      child: NoteCanvas(
                        page: _sheet,
                        scale: scale,
                        baseDir: _baseDir,
                        selectedId: _selectedId,
                        pickedIds: _picked,
                        marquee: _marquee,
                        liveStroke: _live.length > 1
                            ? NoteStroke(
                                points: _live,
                                width: _penWidth,
                                widths: _liveWidths.length == _live.length ? _liveWidths : null,
                              )
                            : null,
                        liveColor: _pen,
                        liveWidth: _penWidth,
                        eraserAt: _eraserAt,
                        eraserRadius: _eraserRadius,
                        previewShape: _shapeFrom == null || _shapeTo == null
                            ? null
                            : (kind: _shape, from: _shapeFrom!, to: _shapeTo!),
                        connectFromId: _connectFrom,
                      ),
                    ),
                    if (selected != null && _tool == NoteTool.pilih)
                      ComponentFrame(
                        rect: Rect.fromLTWH(
                          selected.position.dx * scale + _margin,
                          selected.position.dy * scale + _margin,
                          selected.size.width * scale,
                          selected.size.height * scale,
                        ),
                        rotation: selected.rotation,
                        onMove: (delta) =>
                            _update(selected.copyWith(position: selected.position + delta / scale)),
                        onResize: (delta) => _update(
                          selected.copyWith(
                            size: Size(
                              math.max(12, selected.size.width + delta.dx / scale),
                              math.max(12, selected.size.height + delta.dy / scale),
                            ),
                          ),
                        ),
                        onRotate: (delta) => _update(
                          selected.copyWith(rotation: snapAngle(selected.rotation + delta)),
                        ),
                        onDelete: _deleteSelected,
                        onSettled: () => setState(() => _history.push(_document)),
                        onEdit: selected is NoteText || selected is NoteDiagram
                            ? _editSelected
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  // ------------------------------------------------------------- kotak pilih

  void _markStart(Offset at) => setState(() {
    _picked = const <String>{};
    _marquee = Rect.fromPoints(at, at);
  });

  void _markUpdate(Offset at) {
    final from = _marquee;
    if (from == null) return;
    setState(() => _marquee = Rect.fromPoints(from.topLeft, at));
  }

  /// Menutup kotak pilih: semua benda yang tersentuh kotaknya jadi terpilih.
  ///
  /// Tersentuh, bukan harus termuat seluruhnya — menuntut benda masuk penuh
  /// membuat memilih coretan panjang hampir tidak mungkin.
  void _markEnd() {
    final box = _marquee;
    setState(() => _marquee = null);
    if (box == null || (box.width < 8 && box.height < 8)) return;

    final picked = <String>{};
    for (final component in _sheet.components) {
      final bounds = component is NoteConnector
          ? () {
              final ends = _sheet.endsOf(component);
              return ends == null ? null : Rect.fromPoints(ends.$1, ends.$2);
            }()
          : component.bounds;
      if (bounds == null) continue;
      if (box.overlaps(bounds)) picked.add(component.id);
    }
    setState(() {
      _picked = picked;
      _selectedId = null;
    });
  }

  void _deletePicked() {
    if (_picked.isEmpty) return;
    var page = _sheet;
    for (final id in _picked) {
      page = page.without(id);
    }
    _apply(_document.replacePage(_page, page));
    setState(() => _picked = const <String>{});
  }

  /// Menjelaskan sekali kenapa seretan tidak meninggalkan apa pun.
  ///
  /// Yang paling membingungkan dari alat yang bukan pena adalah diamnya: jari
  /// digerakkan, tidak ada yang terjadi, dan tidak ada yang mengatakan kenapa.
  void _explainIdleDrag() {
    if (_explainedIdleDrag) return;
    _explainedIdleDrag = true;
    _say('Alat sekarang "${_toolLabel(_tool)}" — pilih ikon pena untuk menggambar.');
  }

  void _onTap(Offset sheetPoint) {
    switch (_tool) {
      case NoteTool.pilih:
        setState(() => _selectedId = _sheet.hitTest(sheetPoint)?.id);
      case NoteTool.hubung:
        _connect(sheetPoint);
      case NoteTool.teks:
        _addText(sheetPoint);
      case NoteTool.diagram:
        _addDiagram(sheetPoint);
      case NoteTool.gambar:
        _addImage(sheetPoint);
      case NoteTool.bangun:
      case NoteTool.pena:
      case NoteTool.hapusGoresan:
      case NoteTool.hapusSebagian:
        break;
    }
  }
}

/// Bilah alat: pena, dua penghapus, pilih, dan penyisip komponen.
class _Tools extends StatelessWidget {
  const _Tools({
    required this.tool,
    required this.pen,
    required this.penWidth,
    required this.eraserRadius,
    required this.shape,
    required this.finger,
    required this.selected,
    required this.onTool,
    required this.onShape,
    required this.onFinger,
    required this.onPen,
    required this.onPenWidth,
    required this.onEraser,
    required this.onColor,
    required this.onOpacity,
  });

  final NoteTool tool;
  final Color pen;
  final double penWidth;
  final double eraserRadius;
  final ShapeKind shape;
  final bool finger;
  final NoteComponent? selected;
  final ValueChanged<NoteTool> onTool;
  final ValueChanged<ShapeKind> onShape;
  final ValueChanged<bool> onFinger;
  final ValueChanged<Color> onPen;
  final ValueChanged<double> onPenWidth;
  final ValueChanged<double> onEraser;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onOpacity;

  /// Palet bersama dengan papan tulis: satu daftar, supaya warna yang dipakai
  /// di catatan dan di papan tulis sama namanya dan sama nilainya.
  static const List<({String name, Color color})> palette = InkPalette.all;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _Tool(icon: Icons.edit, label: 'Pena', value: NoteTool.pena, tool: tool, onTool: onTool),
          _Tool(
            icon: Icons.auto_fix_normal,
            label: 'Hapus goresan',
            value: NoteTool.hapusGoresan,
            tool: tool,
            onTool: onTool,
          ),
          _Tool(
            icon: Icons.cleaning_services_outlined,
            label: 'Hapus sebagian',
            value: NoteTool.hapusSebagian,
            tool: tool,
            onTool: onTool,
          ),
          _Tool(
            icon: Icons.touch_app_outlined,
            label: 'Pilih',
            value: NoteTool.pilih,
            tool: tool,
            onTool: onTool,
          ),
          PopupMenuButton<ShapeKind>(
            tooltip: 'Bangun: ${shape.label}',
            onSelected: onShape,
            icon: Icon(
              _shapeIcon(shape),
              color: tool == NoteTool.bangun ? Theme.of(context).colorScheme.primary : null,
            ),
            itemBuilder: (_) => <PopupMenuEntry<ShapeKind>>[
              for (final kind in ShapeKind.values)
                PopupMenuItem<ShapeKind>(
                  value: kind,
                  child: Row(
                    children: <Widget>[
                      Icon(_shapeIcon(kind), size: 18),
                      const SizedBox(width: 10),
                      Text(kind.label),
                    ],
                  ),
                ),
            ],
          ),
          _Tool(
            icon: Icons.linear_scale,
            label: 'Hubungkan dua benda',
            value: NoteTool.hubung,
            tool: tool,
            onTool: onTool,
          ),
          const VerticalDivider(width: 12),
          _Tool(icon: Icons.title, label: 'Teks', value: NoteTool.teks, tool: tool, onTool: onTool),
          _Tool(
            icon: Icons.account_tree_outlined,
            label: 'Diagram',
            value: NoteTool.diagram,
            tool: tool,
            onTool: onTool,
          ),
          _Tool(
            icon: Icons.image_outlined,
            label: 'Gambar',
            value: NoteTool.gambar,
            tool: tool,
            onTool: onTool,
          ),
          const VerticalDivider(width: 12),
          PopupMenuButton<Color>(
            tooltip: selected == null ? 'Warna pena' : 'Warna komponen',
            icon: Icon(Icons.circle, color: selected == null ? pen : Color(selected!.color)),
            onSelected: selected == null ? onPen : onColor,
            itemBuilder: (_) => <PopupMenuEntry<Color>>[
              for (final option in palette)
                PopupMenuItem<Color>(
                  value: option.color,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.circle, color: option.color, size: 18),
                      const SizedBox(width: 10),
                      Text(option.name),
                    ],
                  ),
                ),
            ],
          ),
          PopupMenuButton<double>(
            tooltip: tool == NoteTool.pena ? 'Tebal pena' : 'Ukuran penghapus',
            icon: const Icon(Icons.line_weight),
            onSelected: tool == NoteTool.pena ? onPenWidth : onEraser,
            itemBuilder: (_) => <PopupMenuEntry<double>>[
              for (final value
                  in tool == NoteTool.pena
                      ? const <double>[1.5, 2.5, 4, 7]
                      : const <double>[8, 14, 22, 34])
                PopupMenuItem<double>(
                  value: value,
                  child: Text(
                    tool == NoteTool.pena
                        ? 'Tebal ${value.toStringAsFixed(1)}'
                        : 'Penghapus ${value.toStringAsFixed(0)}',
                  ),
                ),
            ],
          ),
          if (selected != null)
            PopupMenuButton<double>(
              tooltip: 'Kepekatan',
              icon: const Icon(Icons.opacity),
              onSelected: onOpacity,
              itemBuilder: (_) => <PopupMenuEntry<double>>[
                for (final value in const <double>[1, 0.75, 0.5, 0.25])
                  PopupMenuItem<double>(value: value, child: Text('${(value * 100).round()}%')),
              ],
            ),
          const VerticalDivider(width: 12),
          // Berdiri di ujung, terpisah dari tombol alat, dan ikonnya bukan
          // pena: sebelumnya ia duduk di antara alat-alat dengan ikon pena,
          // dan itu terbaca seperti memilih alat — ditekan, lalu bingung
          // kenapa tidak bisa menggambar lagi.
          _ModeChip(finger: finger, onFinger: onFinger),
          const SizedBox(width: 8),
        ],
      ),
    ),
  );
}

/// Keping kertas: menyebut ukuran **dan** arahnya, dan keduanya bisa diubah
/// dari situ — ketuk ikonnya untuk memutar, ketuk labelnya untuk ukuran.
class _PaperChip extends StatelessWidget {
  const _PaperChip({
    required this.paper,
    required this.orientation,
    required this.onPaper,
    required this.onTurn,
  });

  final NotePaper paper;
  final NoteOrientation orientation;
  final ValueChanged<NotePaper> onPaper;
  final VoidCallback onTurn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PopupMenuButton<NotePaper>(
          tooltip: 'Ukuran kertas: ${paper.label}',
          onSelected: onPaper,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  paper.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
                ),
                Icon(Icons.arrow_drop_down, size: 18, color: scheme.primary),
              ],
            ),
          ),
          itemBuilder: (_) => <PopupMenuEntry<NotePaper>>[
            for (final option in NotePaper.values)
              PopupMenuItem<NotePaper>(
                value: option,
                child: Row(
                  children: <Widget>[
                    Icon(option == paper ? Icons.check : Icons.description_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(option.label),
                  ],
                ),
              ),
          ],
        ),
        // Arahnya tidak disembunyikan di dalam menu: memutar kertas adalah satu
        // ketukan, dan namanya ikut tertulis supaya jelas sekarang sedang apa.
        Tooltip(
          message: orientation == NoteOrientation.tegak
              ? 'Kertas tegak — ketuk untuk mendatar'
              : 'Kertas mendatar — ketuk untuk tegak',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTurn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    orientation == NoteOrientation.tegak
                        ? Icons.crop_portrait
                        : Icons.crop_landscape,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    orientation.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _toolLabel(NoteTool tool) => switch (tool) {
  NoteTool.pena => 'Pena',
  NoteTool.hapusGoresan => 'Hapus goresan',
  NoteTool.hapusSebagian => 'Hapus sebagian',
  NoteTool.pilih => 'Pilih',
  NoteTool.bangun => 'Bangun',
  NoteTool.hubung => 'Hubungkan',
  NoteTool.teks => 'Teks',
  NoteTool.gambar => 'Gambar',
  NoteTool.diagram => 'Diagram',
};

/// Sakelar "siapa yang boleh menggambar" — bukan alat, jadi tidak berbentuk
/// tombol alat.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.finger, required this.onFinger});

  final bool finger;
  final ValueChanged<bool> onFinger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: finger
          ? 'Jari dan stylus sama-sama menggambar. Ketuk untuk hanya stylus — '
                'jari lalu dipakai menggeser dan memperbesar saja.'
          : 'Stylus menggambar, jari menggeser dan memperbesar. Ketuk untuk '
                'mengizinkan jari menggambar lagi.',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onFinger(!finger),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: <Widget>[
              Icon(
                finger ? Icons.touch_app_outlined : Icons.do_not_touch_outlined,
                size: 18,
                color: finger ? scheme.onSurfaceVariant : scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                finger ? 'Jari + stylus' : 'Stylus saja',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: finger ? scheme.onSurfaceVariant : scheme.primary,
                  fontWeight: finger ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _shapeIcon(ShapeKind kind) => switch (kind) {
  ShapeKind.kotak => Icons.crop_square,
  ShapeKind.bulat => Icons.circle_outlined,
  ShapeKind.belahKetupat => Icons.change_history,
  ShapeKind.segitiga => Icons.details,
  ShapeKind.garis => Icons.horizontal_rule,
  ShapeKind.panah => Icons.arrow_right_alt,
};

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.value,
    required this.tool,
    required this.onTool,
  });

  final IconData icon;
  final String label;
  final NoteTool value;
  final NoteTool tool;
  final ValueChanged<NoteTool> onTool;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    isSelected: tool == value,
    iconSize: 20,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      backgroundColor: tool == value ? Theme.of(context).colorScheme.primaryContainer : null,
    ),
    onPressed: () => onTool(value),
  );
}

class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.page,
    required this.count,
    required this.paper,
    required this.orientation,
    required this.onGo,
    required this.onAdd,
    required this.onAddPdf,
    required this.onDelete,
    required this.onPaper,
    required this.onTurn,
  });

  final int page;
  final int count;
  final NotePaper paper;
  final NoteOrientation orientation;
  final ValueChanged<int> onGo;
  final VoidCallback onAdd;
  final VoidCallback onAddPdf;
  final VoidCallback onDelete;
  final ValueChanged<NotePaper> onPaper;
  final VoidCallback onTurn;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    // Di atas bilah navigasi Android, bukan di bawahnya. Tanpa ini bilah ini
    // terlihat tetapi tidak bisa ditekan — tombolnya ada, sentuhannya diambil
    // sistem, dan yang memakainya menyimpulkan fiturnya tidak ada.
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              tooltip: 'Lembar sebelumnya',
              icon: const Icon(Icons.chevron_left),
              onPressed: page == 0 ? null : () => onGo(page - 1),
            ),
            Text('${page + 1} / $count', style: Theme.of(context).textTheme.labelMedium),
            IconButton(
              tooltip: 'Lembar berikutnya',
              icon: const Icon(Icons.chevron_right),
              onPressed: page >= count - 1 ? null : () => onGo(page + 1),
            ),
            const SizedBox(width: 12),
            // Kertas dan arahnya di depan, sebelum tombol tambah dan hapus:
            // keduanya dulu paling ujung di bilah yang bisa tergulir, dan di layar
            // sempit tidak pernah terlihat — sama saja dengan tidak ada.
            _PaperChip(paper: paper, orientation: orientation, onPaper: onPaper, onTurn: onTurn),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Lembar kosong baru',
              icon: const Icon(Icons.note_add_outlined),
              onPressed: onAdd,
            ),
            IconButton(
              tooltip: 'Sisipkan halaman PDF sebagai lembar',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: onAddPdf,
            ),
            IconButton(
              tooltip: 'Hapus lembar ini',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    ),
  );
}
