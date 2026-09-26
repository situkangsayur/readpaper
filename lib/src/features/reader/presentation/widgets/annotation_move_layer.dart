import 'package:flutter/material.dart';

/// Kotak yang bisa diseret di atas anotasi yang sedang dipilih.
///
/// Tanda tangan yang mendarat dua sentimeter dari kotak isian dulu berarti
/// menghapusnya lalu menggambar ulang. Yang kurang hanyalah cara memegangnya:
/// begitu sebuah anotasi terpilih, kotak inilah yang menerima seretan, dan
/// hanya di dalam batas anotasinya — sisa halaman tetap bisa digulir.
class AnnotationMoveLayer extends StatefulWidget {
  const AnnotationMoveLayer({
    required this.bounds,
    required this.onMoved,
    required this.onDelete,
    super.key,
  });

  /// Batas anotasinya pada kanvas halaman, bukan koordinat PDF.
  final Rect bounds;

  /// Dipanggil sekali saat seretan selesai, dengan perpindahan pada kanvas.
  final ValueChanged<Offset> onMoved;

  final VoidCallback onDelete;

  @override
  State<AnnotationMoveLayer> createState() => _AnnotationMoveLayerState();
}

class _AnnotationMoveLayerState extends State<AnnotationMoveLayer> {
  Offset _drag = Offset.zero;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Kotak sempit sulit dipegang dengan jari, jadi daerah sentuhnya
    // diperlebar sedikit di luar gambarnya.
    const grip = 12.0;
    final box = widget.bounds.shift(_drag).inflate(grip);

    return Positioned(
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => setState(() => _drag += d.delta),
        onPanEnd: (_) {
          final moved = _drag;
          setState(() {
            _dragging = false;
            _drag = Offset.zero;
          });
          if (moved != Offset.zero) widget.onMoved(moved);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _dragging ? scheme.primary : scheme.primary.withValues(alpha: 0.6),
                    width: _dragging ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: scheme.primary.withValues(alpha: _dragging ? 0.10 : 0.04),
                ),
              ),
            ),
            // Dua petunjuk: yang satu mengatakan kotak ini bisa digeser, yang
            // lain memberi jalan membuangnya tanpa lewat daftar di samping.
            Positioned(
              left: -6,
              top: -18,
              child: _Chip(
                icon: Icons.open_with,
                color: scheme.primary,
                onTap: null,
                tooltip: 'Seret untuk memindahkan',
              ),
            ),
            Positioned(
              right: -6,
              top: -18,
              child: _Chip(
                icon: Icons.delete_outline,
                color: scheme.error,
                onTap: widget.onDelete,
                tooltip: 'Hapus',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.tooltip, this.onTap});

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    ),
  );
}
