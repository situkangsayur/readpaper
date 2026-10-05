import '../../library/domain/entities/zotero_annotation.dart';

/// Penghapus goresan: mana yang dilewati sapuan penghapus.
///
/// Semua dalam koordinat halaman PDF, jadi hasilnya sama di zum berapa pun.
/// Satu goresan dibuang utuh bila sapuannya lewat dalam jarak [reach] dari
/// garisnya — seperti penghapus goresan di papan tulis, bukan penghapus
/// piksel: memotong goresan di tengah menghasilkan potongan yang tidak
/// dimaksud siapa pun.
class InkEraser {
  const InkEraser._();

  /// Goresan [strokes] yang tersisa setelah disapu [eraser].
  static List<InkPath> keep(List<InkPath> strokes, InkPath eraser, double reach) => <InkPath>[
    for (final stroke in strokes)
      if (!touches(stroke, eraser, reach)) stroke,
  ];

  static bool touches(InkPath stroke, InkPath eraser, double reach) {
    if (stroke.length == 0 || eraser.length == 0) return false;
    final limit = reach * reach;
    // Titik-titik sapuan dirapatkan dulu: stylus yang bergerak cepat
    // meninggalkan titik berjauhan, dan goresan tipis yang tepat di antara dua
    // titik itu tidak boleh lolos.
    for (final (ex, ey) in _dense(eraser, reach)) {
      if (stroke.length == 1) {
        final dx = stroke.xAt(0) - ex;
        final dy = stroke.yAt(0) - ey;
        if (dx * dx + dy * dy <= limit) return true;
        continue;
      }
      for (var i = 1; i < stroke.length; i++) {
        final d = _segmentDistance2(
          ex,
          ey,
          stroke.xAt(i - 1),
          stroke.yAt(i - 1),
          stroke.xAt(i),
          stroke.yAt(i),
        );
        if (d <= limit) return true;
      }
    }
    return false;
  }

  static Iterable<(double, double)> _dense(InkPath path, double reach) sync* {
    yield (path.xAt(0), path.yAt(0));
    for (var i = 1; i < path.length; i++) {
      final ax = path.xAt(i - 1);
      final ay = path.yAt(i - 1);
      final bx = path.xAt(i);
      final by = path.yAt(i);
      final dx = bx - ax;
      final dy = by - ay;
      final distance2 = dx * dx + dy * dy;
      final steps = distance2 <= reach * reach ? 1 : (distance2 / (reach * reach)).ceil();
      for (var s = 1; s <= steps; s++) {
        yield (ax + dx * s / steps, ay + dy * s / steps);
      }
    }
  }

  static double _segmentDistance2(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    final length2 = dx * dx + dy * dy;
    var t = length2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / length2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx - px;
    final cy = ay + t * dy - py;
    return cx * cx + cy * cy;
  }
}
