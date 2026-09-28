import 'dart:math' as math;
import 'dart:ui';

/// Bangun dua dimensi yang bisa disisipkan ke lembar catatan atau papan tulis.
enum ShapeKind {
  kotak('Kotak'),
  bulat('Bulat'),
  belahKetupat('Belah ketupat'),
  segitiga('Segitiga'),
  garis('Garis'),
  panah('Panah');

  const ShapeKind(this.label);

  final String label;

  static ShapeKind parse(String name) =>
      values.firstWhere((k) => k.name == name, orElse: () => ShapeKind.kotak);
}

/// Bentuk bangun dan garis penghubung, dihitung sebagai kumpulan polyline.
///
/// Satu tempat untuk seluruh keluaran — kanvas di layar, PDF, dan PNG —
/// karena bangun yang dihitung tiga kali akan tergambar tiga macam, dan yang
/// mencetak tidak akan tahu mana yang benar.
class ShapeGeometry {
  const ShapeGeometry._();

  /// Berapa potong garis dipakai untuk mendekati satu lingkaran.
  ///
  /// 48 sudah tidak terlihat bersudut pada ukuran lembar A4, bahkan dicetak.
  static const int _ellipseSteps = 48;

  /// Garis-garis bangun [kind] di dalam kotak berukuran [size], koordinat lokal.
  static List<List<Offset>> outline(ShapeKind kind, Size size) {
    final w = math.max(size.width, 0.1);
    final h = math.max(size.height, 0.1);

    switch (kind) {
      case ShapeKind.kotak:
        return <List<Offset>>[
          <Offset>[
            const Offset(0, 0),
            Offset(w, 0),
            Offset(w, h),
            Offset(0, h),
            const Offset(0, 0),
          ],
        ];

      case ShapeKind.bulat:
        final points = <Offset>[
          for (var i = 0; i <= _ellipseSteps; i++)
            () {
              final t = i / _ellipseSteps * 2 * math.pi;
              return Offset(w / 2 + w / 2 * math.cos(t), h / 2 + h / 2 * math.sin(t));
            }(),
        ];
        return <List<Offset>>[points];

      case ShapeKind.belahKetupat:
        return <List<Offset>>[
          <Offset>[
            Offset(w / 2, 0),
            Offset(w, h / 2),
            Offset(w / 2, h),
            Offset(0, h / 2),
            Offset(w / 2, 0),
          ],
        ];

      case ShapeKind.segitiga:
        return <List<Offset>>[
          <Offset>[Offset(w / 2, 0), Offset(w, h), Offset(0, h), Offset(w / 2, 0)],
        ];

      case ShapeKind.garis:
        return <List<Offset>>[
          <Offset>[const Offset(0, 0), Offset(w, h)],
        ];

      case ShapeKind.panah:
        final from = const Offset(0, 0);
        final to = Offset(w, h);
        return <List<Offset>>[
          <Offset>[from, to],
          arrowHead(tip: to, from: from, size: math.max(8, math.min(w, h) * 0.22)),
        ];
    }
  }

  /// Mata panah di [tip], menghadap menjauh dari [from].
  static List<Offset> arrowHead({
    required Offset tip,
    required Offset from,
    double size = 10,
    double spread = 0.42,
  }) {
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    return <Offset>[
      Offset(tip.dx - size * math.cos(angle - spread), tip.dy - size * math.sin(angle - spread)),
      tip,
      Offset(tip.dx - size * math.cos(angle + spread), tip.dy - size * math.sin(angle + spread)),
    ];
  }

  /// Ujung garis penghubung antara dua kotak.
  ///
  /// Berhenti di tepi kotak yang saling berhadapan, bukan di titik tengahnya,
  /// supaya garisnya tidak terlihat menembus benda yang dihubungkannya.
  static (Offset, Offset) between(Rect a, Rect b) {
    final dx = b.center.dx - a.center.dx;
    final dy = b.center.dy - a.center.dy;

    if (dy.abs() >= dx.abs()) {
      return dy >= 0
          ? (Offset(a.center.dx, a.bottom), Offset(b.center.dx, b.top))
          : (Offset(a.center.dx, a.top), Offset(b.center.dx, b.bottom));
    }
    return dx >= 0
        ? (Offset(a.right, a.center.dy), Offset(b.left, b.center.dy))
        : (Offset(a.left, a.center.dy), Offset(b.right, b.center.dy));
  }
}
