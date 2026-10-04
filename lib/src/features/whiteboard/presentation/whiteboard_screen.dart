import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/share_file.dart';
import '../../library/presentation/controllers/library_controllers.dart';
import '../../notes/domain/note_target.dart';
import '../../notes/presentation/controllers/notes_controller.dart';
import '../../../core/utils/ink_palette.dart';
import '../../../core/utils/shape_geometry.dart';
import '../../../core/utils/ink_smoothing.dart';
import '../data/board_export.dart';
import '../domain/board.dart';

/// Papan tulis berdiri sendiri: berlembar-lembar, bisa dicoreti, lalu
/// disimpan sebagai PDF.
///
/// Berbeda dari halaman kosong yang ditempelkan ke sebuah dokumen — yang itu
/// menempel pada paper. Ini dimulai dari tidak ada apa-apa: menjelaskan
/// sesuatu di depan orang, mencatat rapat, menghitung di sisi kertas.
class WhiteboardScreen extends ConsumerStatefulWidget {
  const WhiteboardScreen({
    required this.background,
    required this.saveDir,
    this.orientation = BoardOrientation.tegak,
    this.name,
    super.key,
  });

  final Color background;

  /// Arah kertas lembar pertama; lembar berikutnya mengikuti lembar yang
  /// sedang dibuka.
  final BoardOrientation orientation;

  /// Folder tempat PDF-nya disimpan — folder kerja panel berkas, supaya
  /// hasilnya langsung terlihat dan bisa diseret ke koleksi.
  final String saveDir;

  final String? name;

  @override
  ConsumerState<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends ConsumerState<WhiteboardScreen> {
  late List<BoardPage> _pages = <BoardPage>[
    BoardPage(background: widget.background, orientation: widget.orientation),
  ];
  int _current = 0;

  late Color _pen = BoardBackgrounds.penFor(widget.background);
  double _width = 2.5;
  bool _erasing = false;
  bool _saved = false;

  /// Boleh menggambar dengan jari. Dimatikan berarti hanya stylus — dan itulah
  /// penolak telapak tangan yang sebenarnya: tangan yang bertumpu di kertas
  /// tidak meninggalkan garis karena sentuhannya tidak sampai ke kanvas.
  bool _finger = true;

  /// Bangun yang sedang disisipkan; null berarti tangan bebas.
  ShapeKind? _shape;

  BoardPage get _page => _pages[_current];

  void _replace(BoardPage page) {
    setState(() => _pages = <BoardPage>[..._pages]..[_current] = page);
  }

  void _addPage() {
    setState(() {
      _pages = <BoardPage>[
        ..._pages,
        // Arah kertasnya ikut lembar yang sedang dibuka: yang sedang
        // menggambar bagan mendatar hampir selalu butuh satu lagi.
        BoardPage(background: widget.background, orientation: _page.orientation),
      ];
      _current = _pages.length - 1;
    });
  }

  void _undo() {
    if (_page.strokes.isEmpty) return;
    _replace(_page.copyWith(strokes: _page.strokes.sublist(0, _page.strokes.length - 1)));
  }

  /// Memutar kertas lembar ini seperempat putaran.
  ///
  /// Coretannya ikut berputar, jadi tidak ada yang keluar dari tepi kertas dan
  /// hilang dari pandangan. Memutar lagi tiga kali mengembalikannya persis.
  void _turnPage() {
    final turned = _page.turned();
    _replace(turned);
    if (_page.strokes.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Kertas jadi ${turned.orientation.label.toLowerCase()} — '
            'coretannya ikut berputar, tidak ada yang hilang.',
          ),
        ),
      );
  }

  Future<void> _deletePage() async {
    if (_pages.length == 1) {
      // Papan satu lembar tidak dihapus, dikosongkan: menutup layar karena
      // menekan hapus bukan yang dimaksud siapa pun.
      _replace(BoardPage(background: widget.background, orientation: _page.orientation));
      return;
    }
    setState(() {
      _pages = <BoardPage>[..._pages]..removeAt(_current);
      if (_current >= _pages.length) _current = _pages.length - 1;
    });
  }

  String get _stem {
    final name = widget.name?.trim();
    return (name == null || name.isEmpty) ? 'papan-${DateTime.now().millisecondsSinceEpoch}' : name;
  }

  /// Menulis seluruh papan sebagai satu PDF di folder kerja.
  ///
  /// Selalu lewat folder kerja, bahkan saat tujuannya koleksi catatan: kalau
  /// langkah berikutnya gagal, gambarnya tetap ada di suatu tempat yang bisa
  /// ditemukan lagi.
  Future<File?> _writePdf() async {
    try {
      final bytes = await BoardExport.toPdf(_pages);
      var file = File(p.join(widget.saveDir, '$_stem.pdf'));
      for (var n = 2; file.existsSync() && n < 100; n++) {
        file = File(p.join(widget.saveDir, '$_stem-$n.pdf'));
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) setState(() => _saved = true);
      return file;
    } on Object catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      return null;
    }
  }

  /// Membagikan papan ini sebagai PDF, tanpa menyimpannya ke folder kerja.
  ///
  /// Sering yang diinginkan hanya mengirim coretan barusan ke grup kelas;
  /// menyimpannya adalah keputusan lain.
  Future<void> _share() async {
    try {
      final bytes = await BoardExport.toPdf(_pages);
      if (!mounted) return;
      final failure = await shareBytes(context, bytes, '$_stem.pdf', title: _stem);
      if (failure != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure)));
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal membagikan: $e')));
    }
  }

  /// Menyimpan seluruh papan sebagai satu PDF di folder kerja.
  Future<void> _save() async {
    final file = await _writePdf();
    if (file == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Tersimpan sebagai ${p.basename(file.path)}')));
    Navigator.of(context).pop(file.path);
  }

  /// Menyimpan papan ini sebagai catatan, ke koleksi yang sedang dipilih di
  /// pohon koleksi.
  ///
  /// Hanya akar catatan yang boleh menerimanya, dan penolakannya menjelaskan
  /// sebabnya — memaksanya masuk ke akar paper berarti menulis item Zotero
  /// tanpa rujukan maupun bibliografi.
  Future<void> _saveToNotes() async {
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

    final file = await _writePdf();
    if (file == null || !mounted) return;
    final key = await ref
        .read(notesControllerProvider.notifier)
        .addFile(sourcePath: file.path, title: _stem, collectionKey: target.collectionKey);
    if (!mounted) return;
    if (key == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ref.read(notesErrorProvider) ?? 'Gagal menyimpan catatan')),
        );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Tersimpan sebagai catatan')));
    Navigator.of(context).pop(file.path);
  }

  Future<bool> _confirmLeave() async {
    final drawn = _pages.any((page) => page.strokes.isNotEmpty);
    if (_saved || !drawn) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tinggalkan papan ini?'),
        content: const Text('Coretannya belum disimpan, dan tidak bisa dikembalikan.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Kembali menggambar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tinggalkan'),
          ),
        ],
      ),
    );
    return leave ?? false;
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
        // Navigator diambil dari State, yang sudah dipastikan masih hidup.
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.name?.isNotEmpty ?? false ? widget.name! : 'Papan tulis'),
              Text(
                'Lembar ${_current + 1} dari ${_pages.length} · '
                'kertas ${_page.orientation.label.toLowerCase()}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: <Widget>[
            _WidthButton(width: _width, onSelected: (v) => setState(() => _width = v)),
            _PenColorButton(
              color: _pen,
              background: widget.background,
              onSelected: (v) => setState(() {
                _pen = v;
                _erasing = false;
              }),
            ),
            PopupMenuButton<String>(
              tooltip: _shape == null ? 'Tangan bebas' : 'Bangun: ${_shape!.label}',
              icon: Icon(
                _shape == null ? Icons.gesture : _shapeIcon(_shape!),
                color: _shape == null ? null : Theme.of(context).colorScheme.primary,
              ),
              onSelected: (value) => setState(() {
                _shape = value == 'bebas' ? null : ShapeKind.parse(value);
                _erasing = false;
              }),
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'bebas',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.gesture),
                    title: Text('Tangan bebas'),
                  ),
                ),
                for (final kind in ShapeKind.values)
                  PopupMenuItem<String>(
                    value: kind.name,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_shapeIcon(kind)),
                      title: Text(kind.label),
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: _finger
                  ? 'Jari + stylus boleh menggambar — ketuk untuk hanya stylus'
                  : 'Stylus saja — sentuhan tangan tidak menggambar apa pun',
              isSelected: !_finger,
              selectedIcon: const Icon(Icons.draw),
              icon: const Icon(Icons.touch_app_outlined),
              onPressed: () => setState(() => _finger = !_finger),
            ),
            IconButton(
              tooltip: _erasing ? 'Penghapus aktif' : 'Penghapus — sentuh goresan',
              isSelected: _erasing,
              selectedIcon: const Icon(Icons.auto_fix_normal),
              icon: const Icon(Icons.auto_fix_off),
              onPressed: () => setState(() => _erasing = !_erasing),
            ),
            IconButton(
              tooltip: _page.orientation == BoardOrientation.tegak
                  ? 'Kertas tegak — ketuk untuk memutar jadi mendatar'
                  : 'Kertas mendatar — ketuk untuk memutar jadi tegak',
              icon: Icon(
                _page.orientation == BoardOrientation.tegak
                    ? Icons.crop_portrait
                    : Icons.crop_landscape,
              ),
              onPressed: _turnPage,
            ),
            IconButton(
              tooltip: 'Urungkan goresan terakhir',
              icon: const Icon(Icons.undo),
              onPressed: _page.strokes.isEmpty ? null : _undo,
            ),
            IconButton(
              tooltip: 'Kosongkan lembar ini',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePage,
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Bagikan sebagai PDF',
              icon: const Icon(Icons.share_outlined),
              onPressed: _share,
            ),
            IconButton(
              tooltip: 'Simpan sebagai catatan',
              icon: const Icon(Icons.sticky_note_2_outlined),
              onPressed: _saveToNotes,
            ),
            FilledButton.tonalIcon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Simpan PDF'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AspectRatio(
                    aspectRatio: _page.size.width / _page.size.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: scheme.shadow.withValues(alpha: 0.2), blurRadius: 8),
                        ],
                      ),
                      child: _BoardCanvas(
                        finger: _finger,
                        shape: _shape,
                        page: _page,
                        penColor: _pen,
                        penWidth: _width,
                        erasing: _erasing,
                        onChanged: _replace,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _PageBar(
              count: _pages.length,
              current: _current,
              onSelect: (i) => setState(() => _current = i),
              onAdd: _addPage,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kanvas satu lembar: menerima goresan, dan menghapus saat penghapus aktif.
class _BoardCanvas extends StatefulWidget {
  const _BoardCanvas({
    required this.page,
    required this.penColor,
    required this.penWidth,
    required this.erasing,
    required this.finger,
    required this.shape,
    required this.onChanged,
  });

  final BoardPage page;

  /// Jari boleh menggambar; kalau tidak, hanya stylus.
  final bool finger;

  /// Bangun yang disisipkan saat diseret; null berarti tangan bebas.
  final ShapeKind? shape;
  final Color penColor;
  final double penWidth;
  final bool erasing;
  final ValueChanged<BoardPage> onChanged;

  @override
  State<_BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends State<_BoardCanvas> {
  final List<Offset> _live = <Offset>[];
  final List<double> _liveWidths = <double>[];
  Size _size = Size.zero;

  /// Tekanan stylus terakhir, 0..1; null kalau alatnya tidak melaporkannya.
  double? _pressure;

  double get _nextWidth =>
      _pressure == null ? widget.penWidth : InkSmoothing.widthFor(widget.penWidth, _pressure!);

  /// Hanya stylus: banyak layar melaporkan tekanan tetap untuk jari, dan
  /// mengikutinya membuat tebal goresan berubah tanpa sebab.
  void _notePressure(PointerEvent event) {
    final stylus =
        event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus;
    if (!stylus || event.pressureMax <= event.pressureMin) {
      _pressure = null;
      return;
    }
    _pressure = ((event.pressure - event.pressureMin) / (event.pressureMax - event.pressureMin))
        .clamp(0.0, 1.0);
  }

  Offset _toBoard(Offset local) => Offset(
    local.dx / _size.width * widget.page.size.width,
    local.dy / _size.height * widget.page.size.height,
  );

  /// Garis-garis bangun yang sedang ditarik, dalam koordinat lembar.
  List<List<Offset>> _shapeLines(Offset from, Offset to) {
    final kind = widget.shape;
    if (kind == null) return const <List<Offset>>[];
    // Garis dan panah mengikuti arah tarikan; bangun lain dinormalkan jadi
    // kotak, supaya menarik ke kiri atas pun menghasilkan bangun yang benar.
    final berarah = kind == ShapeKind.garis || kind == ShapeKind.panah;
    final box = Rect.fromPoints(from, to);
    final origin = berarah ? from : box.topLeft;
    final extent = berarah ? Size(to.dx - from.dx, to.dy - from.dy) : box.size;
    return <List<Offset>>[
      for (final line in ShapeGeometry.outline(kind, extent))
        <Offset>[for (final point in line) point + origin],
    ];
  }

  void _down(Offset local) {
    if (widget.erasing) {
      // Radius penghapus mengikuti tebal pena: yang menulis halus
      // menghapus halus.
      widget.onChanged(widget.page.erasedAt(_toBoard(local), widget.penWidth * 3));
      return;
    }
    setState(() {
      _live
        ..clear()
        ..add(_toBoard(local));
      _liveWidths
        ..clear()
        ..add(_nextWidth);
    });
  }

  void _move(Offset local) {
    final point = _toBoard(local);
    if (widget.erasing) {
      widget.onChanged(widget.page.erasedAt(point, widget.penWidth * 3));
      return;
    }
    // Titik yang terlalu rapat hanya menambah besar berkas.
    if (_live.isNotEmpty && (_live.last - point).distance < 0.8) return;
    setState(() {
      _live.add(point);
      _liveWidths.add(_nextWidth);
    });
  }

  void _clearLive() {
    _live.clear();
    _liveWidths.clear();
  }

  void _up() {
    if (_live.length < 2) {
      setState(_clearLive);
      return;
    }

    final kind = widget.shape;
    if (kind != null) {
      final lines = _shapeLines(_live.first, _live.last);
      var page = widget.page;
      for (final line in lines) {
        page = page.withStroke(
          BoardStroke(points: line, color: widget.penColor, width: widget.penWidth),
        );
      }
      widget.onChanged(page);
      setState(_clearLive);
      return;
    }

    // Daftar tebal hanya disimpan kalau tekanannya memang berubah.
    final varied =
        _liveWidths.length == _live.length &&
        _liveWidths.any((w) => (w - widget.penWidth).abs() > 0.01);
    widget.onChanged(
      widget.page.withStroke(
        BoardStroke(
          points: List<Offset>.of(_live),
          color: widget.penColor,
          width: widget.penWidth,
          widths: varied ? List<double>.of(_liveWidths) : null,
        ),
      ),
    );
    setState(_clearLive);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      // Tekanan stylus dibaca dari peristiwa pointer mentah; GestureDetector
      // tidak menyerahkannya.
      return Listener(
        onPointerDown: _notePressure,
        onPointerMove: _notePressure,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Tetikus ikut, supaya layar tanpa stylus tetap bisa dipakai.
          supportedDevices: widget.finger
              ? null
              : const <PointerDeviceKind>{
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                  PointerDeviceKind.mouse,
                },
          onPanStart: (d) => _down(d.localPosition),
          onPanUpdate: (d) => _move(d.localPosition),
          onPanEnd: (_) => _up(),
          onPanCancel: _up,
          child: CustomPaint(
            size: _size,
            painter: _BoardPainter(
              page: widget.page,
              live: _live,
              // Bangun yang sedang ditarik digambar dengan perhitungan yang sama
              // dengan bangun yang sudah jadi, jadi yang terlihat saat menarik
              // sama dengan yang mendarat.
              preview: widget.shape == null || _live.length < 2
                  ? const <List<Offset>>[]
                  : _shapeLines(_live.first, _live.last),
              penColor: widget.penColor,
              penWidth: widget.penWidth,
              liveWidths: _liveWidths.length == _live.length ? _liveWidths : null,
            ),
          ),
        ),
      );
    },
  );
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.page,
    required this.live,
    required this.penColor,
    required this.penWidth,
    this.preview = const <List<Offset>>[],
    this.liveWidths,
  });

  final BoardPage page;
  final List<Offset> live;

  /// Garis bangun yang sedang ditarik.
  final List<List<Offset>> preview;

  /// Tebal per titik goresan yang sedang ditarik, kalau stylus melaporkannya.
  final List<double>? liveWidths;
  final Color penColor;
  final double penWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / page.size.width;
    final scaleY = size.height / page.size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = page.background);

    void drawStroke(List<Offset> points, Color color, double width, [List<double>? widths]) {
      if (points.length < 2) return;
      // Dihaluskan, bukan disambung garis lurus: tulisan tangan yang
      // disambung lurus terlihat patah-patah, paling terasa pada huruf
      // melingkar dan tanda tangan.
      InkSmoothing.paintStroke(
        canvas,
        <Offset>[for (final point in points) Offset(point.dx * scaleX, point.dy * scaleY)],
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
        width: width * scaleX,
        widths: widths == null ? null : <double>[for (final w in widths) w * scaleX],
      );
    }

    for (final stroke in page.strokes) {
      drawStroke(stroke.points, stroke.color, stroke.width, stroke.widths);
    }
    if (preview.isEmpty) {
      drawStroke(live, penColor, penWidth, liveWidths);
      return;
    }
    for (final line in preview) {
      drawStroke(line, penColor, penWidth);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.page != page || old.live.length != live.length || old.penColor != penColor;
}

/// Deretan lembar di bawah, dengan tombol tambah.
class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.count,
    required this.current,
    required this.onSelect,
    required this.onAdd,
  });

  final int count;
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      // Di atas bilah navigasi Android, bukan di bawahnya: tanpa ini tombolnya
      // terlihat tetapi sentuhannya diambil sistem.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: count,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: ChoiceChip(
                      selected: i == current,
                      label: Text('${i + 1}'),
                      onSelected: (_) => onSelect(i),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Lembar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidthButton extends StatelessWidget {
  const _WidthButton({required this.width, required this.onSelected});

  final double width;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<double>(
    tooltip: 'Tebal goresan',
    icon: const Icon(Icons.line_weight),
    onSelected: onSelected,
    itemBuilder: (_) => <PopupMenuEntry<double>>[
      for (final value in <double>[1.2, 2.5, 5, 9])
        PopupMenuItem<double>(
          value: value,
          child: Row(
            children: <Widget>[
              Icon(value == width ? Icons.check : Icons.remove, size: 16),
              const SizedBox(width: 10),
              Text('${value.toStringAsFixed(1)} pt'),
            ],
          ),
        ),
    ],
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

class _PenColorButton extends StatelessWidget {
  const _PenColorButton({required this.color, required this.background, required this.onSelected});

  final Color color;
  final Color background;
  final ValueChanged<Color> onSelected;

  /// Palet bersama dengan buku catatan.
  static const List<({String name, Color color})> _choices = InkPalette.all;

  @override
  Widget build(BuildContext context) => PopupMenuButton<Color>(
    tooltip: 'Warna pena',
    icon: Icon(Icons.circle, color: color),
    onSelected: onSelected,
    itemBuilder: (_) => <PopupMenuEntry<Color>>[
      for (final choice in _choices)
        PopupMenuItem<Color>(
          value: choice.color,
          child: Row(
            children: <Widget>[
              // Contoh warnanya digambar di atas warna papan, karena di
              // situlah ia akan dipakai.
              Container(
                width: 28,
                height: 20,
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Center(child: Icon(Icons.edit, size: 13, color: choice.color)),
              ),
              const SizedBox(width: 10),
              Text(choice.name),
              if (choice.color == color) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(Icons.check, size: 16),
              ],
            ],
          ),
        ),
    ],
  );
}
