import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../../../library/presentation/controllers/library_controllers.dart';
import '../../../notes/domain/note_target.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../data/note_document_store.dart';
import '../../data/note_export.dart';
import '../../domain/note_document.dart';
import '../../domain/note_history.dart';
import '../../../../core/utils/ink_palette.dart';
import '../../../../core/utils/shape_geometry.dart';
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
  Offset? _eraserAt;

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

  @override
  void initState() {
    super.initState();
    _document = _load();
    _history = NoteHistory(_document);
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

  NoteComponent? get _selected =>
      _sheet.components.where((c) => c.id == _selectedId).firstOrNull;

  void _update(NoteComponent replacement, {bool commit = false}) {
    _replaceComponents(<NoteComponent>[
      for (final component in _sheet.components)
        if (component.id == replacement.id) replacement else component,
    ], commit: commit);
  }

  // ------------------------------------------------------------------ menulis

  void _onPanStart(Offset sheetPoint) {
    _touchedThisGesture = false;
    switch (_tool) {
      case NoteTool.pena:
        setState(() => _live = <Offset>[sheetPoint]);
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
        if (_live.isNotEmpty && (_live.last - sheetPoint).distance < 1.2) return;
        setState(() => _live = <Offset>[..._live, sheetPoint]);
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
    final stroke = NoteStroke(points: _live, width: _penWidth);
    final bounds = stroke.bounds;
    final local = NoteStroke(
      points: <Offset>[for (final point in _live) point - bounds.topLeft],
      width: _penWidth,
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

  Future<void> _addText(Offset at) async {
    final text = await _ask(title: 'Teks baru', hint: 'Tulis teksnya');
    if (text == null || text.trim().isEmpty) return;
    _replaceComponents(<NoteComponent>[
      ..._sheet.components,
      NoteText(
        id: _freshId('teks'),
        position: at,
        size: const Size(280, 60),
        text: text.trim(),
        color: _pen.toARGB32(),
      ),
    ]);
  }

  Future<void> _addDiagram(Offset at) async {
    final source = await _ask(
      title: 'Diagram baru',
      hint: 'Sumber Mermaid',
      initial: 'graph TD\n  A[Mulai] --> B[Selesai]',
      lines: 6,
    );
    if (source == null || source.trim().isEmpty) return;
    _replaceComponents(<NoteComponent>[
      ..._sheet.components,
      NoteDiagram(
        id: _freshId('diagram'),
        position: at,
        size: const Size(260, 180),
        source: source.trim(),
      ),
    ]);
  }

  Future<void> _addImage(Offset at) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: 'Pilih gambar untuk catatan',
    );
    if (picked.isEmpty) return;
    final source = picked.first.path;
    if (source == null) return;

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

    _replaceComponents(<NoteComponent>[
      ..._sheet.components,
      NoteImage(
        id: _freshId('gambar'),
        position: at,
        size: const Size(200, 150),
        file: p.relative(target.path, from: _baseDir).replaceAll(r'\', '/'),
        alt: p.basenameWithoutExtension(source),
      ),
    ]);
  }

  Future<void> _editSelected() async {
    final component = _selected;
    switch (component) {
      case NoteText():
        final text = await _ask(title: 'Ubah teks', initial: component.text, lines: 4);
        if (text == null) return;
        _update(component.copyWith(text: text), commit: true);
      case NoteDiagram():
        final source = await _ask(
          title: 'Ubah diagram',
          initial: component.source,
          lines: 8,
        );
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
        pages: <NotePage>[..._document.pages, NotePage(rule: _sheet.rule, background: _sheet.background)],
      ),
    );
    setState(() {
      _page = _document.pages.length - 1;
      _selectedId = null;
    });
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
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Mengerti'),
            ),
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
          title: _document.title.isEmpty
              ? NoteDocumentStore.stemOf(widget.path)
              : _document.title,
          collectionKey: target.collectionKey,
        );
    if (!mounted) return;
    _say(key == null
        ? (ref.read(notesErrorProvider) ?? 'Gagal menyimpan ke koleksi')
        : 'Masuk ke koleksi catatan');
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<String?> _ask({
    required String title,
    String initial = '',
    String? hint,
    int lines = 1,
  }) {
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
                'Lembar ${_page + 1} dari ${_document.pages.length}'
                '${_dirty ? ' · belum disimpan' : ''}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: <Widget>[
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
              onTool: (tool) => setState(() {
                _tool = tool;
                if (tool != NoteTool.pilih) _selectedId = null;
                if (tool != NoteTool.hubung) _connectFrom = null;
              }),
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
                if (component != null) _update(component.copyWith(color: color.toARGB32()), commit: true);
              },
              onOpacity: (opacity) {
                final component = _selected;
                if (component != null) _update(component.copyWith(opacity: opacity), commit: true);
              },
            ),
            Expanded(child: _sheetArea()),
            _PageBar(
              page: _page,
              count: _document.pages.length,
              onGo: (index) => setState(() {
                _page = index;
                _selectedId = null;
              }),
              onAdd: _addPage,
              onDelete: _deletePage,
            ),
          ],
        ),
      ),
    );
  }

  void _cycleRule() {
    const order = NotePageRule.values;
    final next = order[(order.indexOf(_sheet.rule) + 1) % order.length];
    _apply(_document.replacePage(_page, _sheet.copyWith(rule: next)));
  }

  Widget _sheetArea() => LayoutBuilder(
    builder: (context, constraints) {
      const margin = 12.0;
      final scale = math.min(
        (constraints.maxWidth - margin * 2) / NoteSheet.width,
        (constraints.maxHeight - margin * 2) / NoteSheet.height,
      );
      final selected = _selected;

      // Alat yang menggambar mengambil seretan; alat yang tidak menggambar
      // melepaskannya sama sekali. Itu bukan penghematan: selama kanvas masih
      // memasang pengenal seretan, bingkai komponen di atasnya kalah di arena
      // gerakan dan komponennya tidak pernah bisa digeser.
      final menggambar = _tool == NoteTool.pena ||
          _tool == NoteTool.hapusGoresan ||
          _tool == NoteTool.hapusSebagian ||
          _tool == NoteTool.bangun;

      return Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          supportedDevices: _drawWith,
          onTapUp: (details) => _onTap(details.localPosition / scale),
          onPanStart: menggambar ? (details) => _onPanStart(details.localPosition / scale) : null,
          onPanUpdate: menggambar ? (details) => _onPanUpdate(details.localPosition / scale) : null,
          onPanEnd: menggambar ? (_) => _onPanEnd() : null,
          onPanCancel: menggambar ? _onPanEnd : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              NoteCanvas(
                page: _sheet,
                scale: scale,
                baseDir: _baseDir,
                selectedId: _selectedId,
                liveStroke: _live.length > 1
                    ? NoteStroke(points: _live, width: _penWidth)
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
              if (selected != null && _tool == NoteTool.pilih)
                ComponentFrame(
                  rect: Rect.fromLTWH(
                    selected.position.dx * scale,
                    selected.position.dy * scale,
                    selected.size.width * scale,
                    selected.size.height * scale,
                  ),
                  rotation: selected.rotation,
                  onMove: (delta) => _update(selected.copyWith(
                    position: selected.position + delta / scale,
                  )),
                  onResize: (delta) => _update(selected.copyWith(
                    size: Size(
                      math.max(12, selected.size.width + delta.dx / scale),
                      math.max(12, selected.size.height + delta.dy / scale),
                    ),
                  )),
                  onRotate: (delta) => _update(
                    selected.copyWith(rotation: snapAngle(selected.rotation + delta)),
                  ),
                  onDelete: _deleteSelected,
                  onSettled: () => setState(() => _history.push(_document)),
                  onEdit: selected is NoteText || selected is NoteDiagram ? _editSelected : null,
                ),
            ],
          ),
        ),
      );
    },
  );

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
              color: tool == NoteTool.bangun
                  ? Theme.of(context).colorScheme.primary
                  : null,
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
          _Tool(
            icon: Icons.title,
            label: 'Teks',
            value: NoteTool.teks,
            tool: tool,
            onTool: onTool,
          ),
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
          IconButton(
            tooltip: finger
                ? 'Jari boleh menggambar — ketuk untuk hanya stylus'
                : 'Hanya stylus yang menggambar — telapak tangan diabaikan',
            isSelected: !finger,
            iconSize: 20,
            icon: Icon(finger ? Icons.touch_app_outlined : Icons.draw),
            style: IconButton.styleFrom(
              backgroundColor: finger ? null : Theme.of(context).colorScheme.primaryContainer,
            ),
            onPressed: () => onFinger(!finger),
          ),
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
              for (final value in tool == NoteTool.pena
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
                  PopupMenuItem<double>(
                    value: value,
                    child: Text('${(value * 100).round()}%'),
                  ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
    ),
  );
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
      backgroundColor: tool == value
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
    ),
    onPressed: () => onTool(value),
  );
}

class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.page,
    required this.count,
    required this.onGo,
    required this.onAdd,
    required this.onDelete,
  });

  final int page;
  final int count;
  final ValueChanged<int> onGo;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
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
        IconButton(tooltip: 'Lembar baru', icon: const Icon(Icons.note_add_outlined), onPressed: onAdd),
        IconButton(
          tooltip: 'Hapus lembar ini',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ],
    ),
  );
}
