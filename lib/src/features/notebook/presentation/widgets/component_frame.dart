import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bingkai di atas komponen yang sedang dipilih: geser, ubah ukuran, putar,
/// hapus.
///
/// Pegangannya duduk **di dalam** kotaknya. Anak yang digambar di luar batas
/// induknya terlihat tetapi tidak pernah menerima sentuhan — Flutter tidak
/// mengirim pointer ke sana — dan itu pernah membuat tombol hapus yang
/// tampak jelas tidak bisa dipencet sama sekali.
class ComponentFrame extends StatelessWidget {
  const ComponentFrame({
    required this.rect,
    required this.rotation,
    required this.onMove,
    required this.onResize,
    required this.onRotate,
    required this.onDelete,
    required this.onSettled,
    this.onEdit,
    super.key,
  });

  /// Kotak komponennya pada kanvas, dalam piksel layar.
  final Rect rect;

  final double rotation;

  /// Perpindahan sejak panggilan terakhir, dalam piksel layar.
  final ValueChanged<Offset> onMove;

  /// Perubahan ukuran sejak panggilan terakhir.
  final ValueChanged<Offset> onResize;

  /// Perubahan sudut sejak panggilan terakhir, dalam radian.
  final ValueChanged<double> onRotate;

  final VoidCallback onDelete;

  /// Dipanggil sekali saat sebuah gerakan selesai, untuk mencatat satu langkah
  /// urungkan — bukan satu langkah per piksel.
  final VoidCallback onSettled;

  final VoidCallback? onEdit;

  static const double grip = 26;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = rect.inflate(grip);

    return Positioned(
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: Transform.rotate(
        angle: rotation,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => onMove(d.delta),
                onPanEnd: (_) => onSettled(),
                onPanCancel: onSettled,
                child: Padding(
                  padding: const EdgeInsets.all(grip),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 1.4),
                      color: scheme.primary.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: _Grip(
                icon: Icons.open_with,
                color: scheme.primary,
                tooltip: 'Seret untuk memindahkan',
                onUpdate: onMove,
                onEnd: onSettled,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _Grip(
                icon: Icons.open_in_full,
                color: scheme.primary,
                tooltip: 'Seret untuk mengubah ukuran',
                onUpdate: onResize,
                onEnd: onSettled,
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: _Grip(
                icon: Icons.rotate_right,
                color: scheme.primary,
                tooltip: 'Seret untuk memutar',
                // Satu layar penuh ke samping memutar setengah lingkaran:
                // cukup halus untuk meluruskan tulisan yang miring.
                onUpdate: (delta) => onRotate(delta.dx * 0.01),
                onEnd: onSettled,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Row(
                children: <Widget>[
                  if (onEdit != null)
                    _Chip(icon: Icons.edit_outlined, color: scheme.primary, onTap: onEdit!),
                  _Chip(icon: Icons.delete_outline, color: scheme.error, onTap: onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onUpdate,
    required this.onEnd,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanUpdate: (d) => onUpdate(d.delta),
    onPanEnd: (_) => onEnd(),
    onPanCancel: onEnd,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
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

/// Sudut putar yang dibulatkan ke kelipatan terdekat saat mendekatinya.
///
/// Tulisan yang hampir lurus lebih sering dimaksudkan lurus.
double snapAngle(double radians, {double step = math.pi / 12, double within = 0.06}) {
  final nearest = (radians / step).roundToDouble() * step;
  return (radians - nearest).abs() <= within ? nearest : radians;
}
