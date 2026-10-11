import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Penunjuk laser saat menyajikan: titik merah yang mengikuti mouse, jari,
/// atau stylus, dengan buntut yang memudar di belakangnya.
///
/// Posisinya pecahan halaman (0–1 dari kiri atas), bukan piksel: layar
/// presenter dan layar audiens menggambar halaman yang sama dalam ukuran yang
/// berbeda, dan titik yang ditunjuk harus jatuh di kata yang sama di keduanya.
/// Buntutnya dihitung dari waktu tiba tiap titik di perangkat yang
/// menggambarnya, jadi layar audiens tidak perlu jam yang sama dengan
/// presenter.
class LaserPointer extends ChangeNotifier {
  LaserPointer({Duration trail = const Duration(milliseconds: 600)}) : _trail = trail;

  /// Halaman yang sedang ditunjuk; null bila penunjuknya tidak terlihat.
  int? get page => _page;
  int? _page;

  /// Lama buntut. Nol: hanya titiknya.
  Duration get trail => _trail;
  Duration _trail;
  set trail(Duration value) {
    if (value == _trail) return;
    _trail = value;
    notifyListeners();
  }

  final List<({Offset at, Duration time})> _points = <({Offset at, Duration time})>[];

  /// Titik terakhir, atau null bila penunjuknya disembunyikan.
  Offset? get head => _visible && _points.isNotEmpty ? _points.last.at : null;
  bool _visible = false;

  final Stopwatch _clock = Stopwatch()..start();

  /// Waktu sekarang menurut penunjuk ini, untuk melukis buntutnya.
  Duration get now => _clock.elapsed;

  /// Penunjuk pindah ke [at] (pecahan halaman) di halaman [page].
  void moveTo(int page, Offset at) {
    if (page != _page) _points.clear();
    _page = page;
    _visible = true;
    _points.add((at: at, time: _clock.elapsed));
    _prune();
    notifyListeners();
  }

  /// Penunjuk disembunyikan; buntutnya tetap memudar sampai habis.
  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  /// Titik buntut yang masih hidup, dari yang tertua, dengan umurnya dalam
  /// pecahan [trail] (0 = baru, 1 = hampir hilang).
  List<({Offset at, double age})> trailAt(Duration now) {
    _prune(now);
    final span = _trail.inMicroseconds;
    return <({Offset at, double age})>[
      for (final p in _points)
        (at: p.at, age: span <= 0 ? 0 : ((now - p.time).inMicroseconds / span).clamp(0.0, 1.0)),
    ];
  }

  /// Masih ada yang perlu dilukis: titiknya, atau buntut yang belum habis.
  bool get isActive => _visible || _points.isNotEmpty;

  void _prune([Duration? now]) {
    final t = now ?? _clock.elapsed;
    // Titik terakhir selalu disimpan selama penunjuknya terlihat: mouse yang
    // diam tetap menunjuk.
    while (_points.length > (_visible ? 1 : 0) && t - _points.first.time > _trail) {
      _points.removeAt(0);
    }
    // Penjaga: buntut panjang dari gerakan cepat tidak boleh tumbuh tanpa
    // batas.
    if (_points.length > 400) _points.removeRange(0, _points.length - 400);
  }

  /// Pesan `pointer` untuk layar audiens.
  Map<String, dynamic> toMessage() => <String, dynamic>{
    'type': 'pointer',
    'page': head == null ? null : _page,
    'x': head?.dx,
    'y': head?.dy,
    'trail': _trail.inMilliseconds,
  };

  /// Menerapkan pesan `pointer` dari presenter.
  void apply(Map<String, dynamic> message) {
    trail = Duration(milliseconds: (message['trail'] as num?)?.toInt() ?? _trail.inMilliseconds);
    final page = (message['page'] as num?)?.toInt();
    final x = (message['x'] as num?)?.toDouble();
    final y = (message['y'] as num?)?.toDouble();
    if (page == null || x == null || y == null) {
      hide();
    } else {
      moveTo(page, Offset(x, y));
    }
  }
}

/// Melukis [pointer] di atas satu halaman bila halamannya [pageNumber].
///
/// Hidup selama penunjuknya aktif: buntut memudar walaupun tidak ada gerakan
/// baru, jadi pelukisnya didorong ticker, bukan oleh pesan masuk.
class LaserPointerLayer extends StatefulWidget {
  const LaserPointerLayer({required this.pointer, required this.pageNumber, super.key});

  final LaserPointer pointer;
  final int pageNumber;

  @override
  State<LaserPointerLayer> createState() => _LaserPointerLayerState();
}

class _LaserPointerLayerState extends State<LaserPointerLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      _frame.value++;
      if (!widget.pointer.isActive) _ticker.stop();
    });
    widget.pointer.addListener(_wake);
    _wake();
  }

  @override
  void didUpdateWidget(LaserPointerLayer old) {
    super.didUpdateWidget(old);
    if (old.pointer != widget.pointer) {
      old.pointer.removeListener(_wake);
      widget.pointer.addListener(_wake);
    }
  }

  void _wake() {
    if (widget.pointer.isActive && !_ticker.isActive) _ticker.start();
    _frame.value++;
  }

  @override
  void dispose() {
    widget.pointer.removeListener(_wake);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: LaserPointerPainter(
        pointer: widget.pointer,
        pageNumber: widget.pageNumber,
        repaint: _frame,
      ),
    ),
  );
}

class LaserPointerPainter extends CustomPainter {
  LaserPointerPainter({required this.pointer, required this.pageNumber, super.repaint});

  final LaserPointer pointer;
  final int pageNumber;

  static const Color color = Color(0xFFFF1744);

  @override
  void paint(Canvas canvas, Size size) {
    if (pointer.page != pageNumber || size.isEmpty) return;
    final trail = pointer.trailAt(pointer.now);
    if (trail.isEmpty) return;
    // Ukurannya mengikuti halaman, supaya di proyektor sama mencoloknya
    // dengan di layar presenter.
    final radius = math.max(5.0, size.shortestSide * 0.011);
    Offset at(Offset f) => Offset(f.dx * size.width, f.dy * size.height);

    for (var i = 1; i < trail.length; i++) {
      final a = trail[i - 1];
      final b = trail[i];
      final life = 1 - b.age;
      if (life <= 0) continue;
      canvas.drawLine(
        at(a.at),
        at(b.at),
        Paint()
          ..color = color.withValues(alpha: 0.55 * life)
          ..strokeWidth = radius * 1.6 * (0.35 + 0.65 * life)
          ..strokeCap = StrokeCap.round,
      );
    }

    final head = pointer.head;
    if (head == null) return;
    final c = at(head);
    canvas
      ..drawCircle(
        c,
        radius * 2.4,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius),
      )
      ..drawCircle(c, radius, Paint()..color = color)
      ..drawCircle(c, radius * 0.4, Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(LaserPointerPainter old) =>
      old.pointer != pointer || old.pageNumber != pageNumber;
}
