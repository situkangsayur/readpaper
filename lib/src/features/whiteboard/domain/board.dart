import 'dart:ui';

import 'package:meta/meta.dart';

/// Satu goresan di papan tulis.
///
/// Titiknya disimpan dalam koordinat halaman — titik PDF, bukan piksel layar —
/// supaya papan yang digambar di tablet kecil dan yang digambar di layar
/// besar menghasilkan berkas yang sama.
@immutable
class BoardStroke {
  const BoardStroke({required this.points, required this.color, required this.width});

  final List<Offset> points;
  final Color color;
  final double width;

  bool get isEmpty => points.length < 2;

  /// Jarak terdekat dari [point] ke goresan ini.
  ///
  /// Dipakai penghapus per goresan: yang disentuh adalah goresan terdekat,
  /// bukan kotak pembatasnya — kotak membuat coretan panjang yang melengkung
  /// terhapus padahal jarinya jauh dari garisnya.
  double distanceTo(Offset point) {
    var best = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final d = _distanceToSegment(point, points[i], points[i + 1]);
      if (d < best) best = d;
    }
    if (points.length == 1) return (points.first - point).distance;
    return best;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }
}

/// Satu lembar papan tulis.
@immutable
class BoardPage {
  const BoardPage({required this.background, this.strokes = const <BoardStroke>[]});

  final Color background;
  final List<BoardStroke> strokes;

  BoardPage copyWith({Color? background, List<BoardStroke>? strokes}) =>
      BoardPage(background: background ?? this.background, strokes: strokes ?? this.strokes);

  BoardPage withStroke(BoardStroke stroke) => copyWith(strokes: <BoardStroke>[...strokes, stroke]);

  /// Tanpa goresan yang dekat dengan [point] — penghapus per goresan.
  BoardPage erasedAt(Offset point, double radius) => copyWith(
    strokes: <BoardStroke>[
      for (final stroke in strokes)
        if (stroke.distanceTo(point) > radius) stroke,
    ],
  );
}

/// Ukuran lembar papan tulis, dalam titik PDF.
///
/// A4 tegak, sama dengan kertas yang keluar dari pencetak mana pun — supaya
/// papan tulis yang dicetak atau digabung dengan paper tidak berbeda ukuran.
class BoardSize {
  const BoardSize._();

  static const double width = 595.276;
  static const double height = 841.89;
}

/// Warna latar yang ditawarkan.
///
/// Hitam bukan sekadar gaya: menulis di ruang gelap dengan latar putih
/// menyilaukan, dan papan tulis dipakai justru saat memaparkan sesuatu.
class BoardBackgrounds {
  const BoardBackgrounds._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF12100E);
  static const Color green = Color(0xFF12372A);
  static const Color cream = Color(0xFFF6EFE2);
  static const Color navy = Color(0xFF10233F);

  static const List<({String name, Color color})> all = <({String name, Color color})>[
    (name: 'Putih', color: white),
    (name: 'Hitam', color: black),
    (name: 'Hijau papan', color: green),
    (name: 'Krem', color: cream),
    (name: 'Biru malam', color: navy),
  ];

  /// Warna pena yang terbaca di atas latar tertentu.
  ///
  /// Pena hitam di atas papan hitam adalah cara tercepat membuat orang
  /// mengira aplikasinya rusak.
  static Color penFor(Color background) {
    final luminance = background.computeLuminance();
    return luminance < 0.4 ? const Color(0xFFF5F5F5) : const Color(0xFF1B1C18);
  }
}
