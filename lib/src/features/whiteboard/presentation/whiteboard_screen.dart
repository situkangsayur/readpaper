import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/board_export.dart';
import '../domain/board.dart';

/// Papan tulis berdiri sendiri: berlembar-lembar, bisa dicoreti, lalu
/// disimpan sebagai PDF.
///
/// Berbeda dari halaman kosong yang ditempelkan ke sebuah dokumen — yang itu
/// menempel pada paper. Ini dimulai dari tidak ada apa-apa: menjelaskan
/// sesuatu di depan orang, mencatat rapat, menghitung di sisi kertas.
class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({required this.background, required this.saveDir, this.name, super.key});

  final Color background;

  /// Folder tempat PDF-nya disimpan — folder kerja panel berkas, supaya
  /// hasilnya langsung terlihat dan bisa diseret ke koleksi.
  final String saveDir;

  final String? name;

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  late List<BoardPage> _pages = <BoardPage>[BoardPage(background: widget.background)];
  int _current = 0;

  late Color _pen = BoardBackgrounds.penFor(widget.background);
  double _width = 2.5;
  bool _erasing = false;
  bool _saved = false;

  BoardPage get _page => _pages[_current];

  void _replace(BoardPage page) {
    setState(() => _pages = <BoardPage>[..._pages]..[_current] = page);
  }

  void _addPage() {
    setState(() {
      _pages = <BoardPage>[..._pages, BoardPage(background: widget.background)];
      _current = _pages.length - 1;
    });
  }

  void _undo() {
    if (_page.strokes.isEmpty) return;
    _replace(_page.copyWith(strokes: _page.strokes.sublist(0, _page.strokes.length - 1)));
  }

  Future<void> _deletePage() async {
    if (_pages.length == 1) {
      // Papan satu lembar tidak dihapus, dikosongkan: menutup layar karena
      // menekan hapus bukan yang dimaksud siapa pun.
      _replace(BoardPage(background: widget.background));
      return;
    }
    setState(() {
      _pages = <BoardPage>[..._pages]..removeAt(_current);
      if (_current >= _pages.length) _current = _pages.length - 1;
    });
  }

  /// Menyimpan seluruh papan sebagai satu PDF di folder kerja.
  Future<void> _save() async {
    final name = widget.name?.trim();
    final stem = (name == null || name.isEmpty)
        ? 'papan-${DateTime.now().millisecondsSinceEpoch}'
        : name;

    try {
      final bytes = await BoardExport.toPdf(_pages);
      var file = File(p.join(widget.saveDir, '$stem.pdf'));
      for (var n = 2; file.existsSync() && n < 100; n++) {
        file = File(p.join(widget.saveDir, '$stem-$n.pdf'));
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Tersimpan sebagai ${p.basename(file.path)}')));
      Navigator.of(context).pop(file.path);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
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
                'Lembar ${_current + 1} dari ${_pages.length}',
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
            IconButton(
              tooltip: _erasing ? 'Penghapus aktif' : 'Penghapus — sentuh goresan',
              isSelected: _erasing,
              selectedIcon: const Icon(Icons.auto_fix_normal),
              icon: const Icon(Icons.auto_fix_off),
              onPressed: () => setState(() => _erasing = !_erasing),
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
                    aspectRatio: BoardSize.width / BoardSize.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: scheme.shadow.withValues(alpha: 0.2), blurRadius: 8),
                        ],
                      ),
                      child: _BoardCanvas(
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
    required this.onChanged,
  });

  final BoardPage page;
  final Color penColor;
  final double penWidth;
  final bool erasing;
  final ValueChanged<BoardPage> onChanged;

  @override
  State<_BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends State<_BoardCanvas> {
  final List<Offset> _live = <Offset>[];
  Size _size = Size.zero;

  Offset _toBoard(Offset local) =>
      Offset(local.dx / _size.width * BoardSize.width, local.dy / _size.height * BoardSize.height);

  void _down(Offset local) {
    if (widget.erasing) {
      // Radius penghapus mengikuti tebal pena: yang menulis halus
      // menghapus halus.
      widget.onChanged(widget.page.erasedAt(_toBoard(local), widget.penWidth * 3));
      return;
    }
    setState(
      () => _live
        ..clear()
        ..add(_toBoard(local)),
    );
  }

  void _move(Offset local) {
    final point = _toBoard(local);
    if (widget.erasing) {
      widget.onChanged(widget.page.erasedAt(point, widget.penWidth * 3));
      return;
    }
    // Titik yang terlalu rapat hanya menambah besar berkas.
    if (_live.isNotEmpty && (_live.last - point).distance < 0.8) return;
    setState(() => _live.add(point));
  }

  void _up() {
    if (_live.length < 2) {
      setState(_live.clear);
      return;
    }
    widget.onChanged(
      widget.page.withStroke(
        BoardStroke(points: List<Offset>.of(_live), color: widget.penColor, width: widget.penWidth),
      ),
    );
    setState(_live.clear);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _down(d.localPosition),
        onPanUpdate: (d) => _move(d.localPosition),
        onPanEnd: (_) => _up(),
        onPanCancel: _up,
        child: CustomPaint(
          size: _size,
          painter: _BoardPainter(
            page: widget.page,
            live: _live,
            penColor: widget.penColor,
            penWidth: widget.penWidth,
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
  });

  final BoardPage page;
  final List<Offset> live;
  final Color penColor;
  final double penWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / BoardSize.width;
    final scaleY = size.height / BoardSize.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = page.background);

    void drawStroke(List<Offset> points, Color color, double width) {
      if (points.length < 2) return;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = points[i].dx * scaleX;
        final y = points[i].dy * scaleY;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = width * scaleX
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final stroke in page.strokes) {
      drawStroke(stroke.points, stroke.color, stroke.width);
    }
    drawStroke(live, penColor, penWidth);
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

class _PenColorButton extends StatelessWidget {
  const _PenColorButton({required this.color, required this.background, required this.onSelected});

  final Color color;
  final Color background;
  final ValueChanged<Color> onSelected;

  static const List<Color> _choices = <Color>[
    Color(0xFF1B1C18),
    Color(0xFFF5F5F5),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFDD835),
  ];

  @override
  Widget build(BuildContext context) => PopupMenuButton<Color>(
    tooltip: 'Warna pena',
    icon: Icon(Icons.circle, color: color),
    onSelected: onSelected,
    itemBuilder: (_) => <PopupMenuEntry<Color>>[
      for (final choice in _choices)
        PopupMenuItem<Color>(
          value: choice,
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
                child: Center(child: Icon(Icons.edit, size: 13, color: choice)),
              ),
              const SizedBox(width: 10),
              if (choice == color) const Icon(Icons.check, size: 16),
            ],
          ),
        ),
    ],
  );
}
