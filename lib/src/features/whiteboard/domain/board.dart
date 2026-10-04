import 'dart:ui';

import 'package:meta/meta.dart';

/// Satu goresan di papan tulis.
///
/// Titiknya disimpan dalam koordinat halaman — titik PDF, bukan piksel layar —
/// supaya papan yang digambar di tablet kecil dan yang digambar di layar
/// besar menghasilkan berkas yang sama.
@immutable
class BoardStroke {
  const BoardStroke({required this.points, required this.color, required this.width, this.widths});

  final List<Offset> points;
  final Color color;

  /// Tebal goresannya; kalau [widths] ada, ini tebal dasarnya.
  final double width;

  /// Tebal di tiap titik, dari tekanan stylus. Null berarti tebal tetap —
  /// jari dan tetikus tidak melaporkan tekanan.
  final List<double>? widths;

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

/// Arah kertas papan tulis.
///
/// Dua-duanya perlu, dan bukan karena selera: menulis catatan rapat berbaris
/// ke bawah muat di kertas tegak, sementara menggambar alur atau tabel di
/// depan orang butuh kertas mendatar — di kertas tegak, gambarnya mentok di
/// tepi kanan sebelum ceritanya selesai.
enum BoardOrientation {
  tegak('Tegak'),
  mendatar('Mendatar');

  const BoardOrientation(this.label);

  final String label;

  BoardOrientation get lain => this == tegak ? mendatar : tegak;

  /// Ukuran lembarnya dalam titik PDF.
  Size get size => this == tegak
      ? const Size(BoardSize.width, BoardSize.height)
      : const Size(BoardSize.height, BoardSize.width);
}

/// Satu lembar papan tulis.
@immutable
class BoardPage {
  const BoardPage({
    required this.background,
    this.strokes = const <BoardStroke>[],
    this.orientation = BoardOrientation.tegak,
  });

  final Color background;
  final List<BoardStroke> strokes;

  /// Arah kertas lembar **ini**, bukan seluruh papan: satu papan boleh
  /// mencampur, karena satu penjelasan bisa butuh daftar tegak dan bagan
  /// mendatar sekaligus.
  final BoardOrientation orientation;

  Size get size => orientation.size;

  BoardPage copyWith({
    Color? background,
    List<BoardStroke>? strokes,
    BoardOrientation? orientation,
  }) => BoardPage(
    background: background ?? this.background,
    strokes: strokes ?? this.strokes,
    orientation: orientation ?? this.orientation,
  );

  BoardPage withStroke(BoardStroke stroke) => copyWith(strokes: <BoardStroke>[...strokes, stroke]);

  /// Tanpa goresan yang dekat dengan [point] — penghapus per goresan.
  BoardPage erasedAt(Offset point, double radius) => copyWith(
    strokes: <BoardStroke>[
      for (final stroke in strokes)
        if (stroke.distanceTo(point) > radius) stroke,
    ],
  );

  /// Memutar kertasnya seperempat putaran, **beserta coretannya**.
  ///
  /// Memutar kertas tanpa memutar isinya berarti coretan yang tadinya di
  /// dalam kertas tegak mendadak keluar dari tepi kertas mendatar — hilang
  /// dari pandangan tanpa pernah dihapus. Memutar keduanya tidak kehilangan
  /// apa pun, tidak mengubah bentuk goresan sedikit pun, dan bisa dibalik
  /// dengan memutar tiga kali lagi.
  BoardPage turned() {
    final from = size;
    return BoardPage(
      background: background,
      orientation: orientation.lain,
      strokes: <BoardStroke>[
        for (final stroke in strokes)
          BoardStroke(
            // Searah jarum jam: yang di kiri atas pindah ke kanan atas.
            points: <Offset>[
              for (final point in stroke.points) Offset(from.height - point.dy, point.dx),
            ],
            color: stroke.color,
            width: stroke.width,
            widths: stroke.widths,
          ),
      ],
    );
  }
}

/// Ukuran lembar papan tulis, dalam titik PDF.
///
/// A4, sama dengan kertas yang keluar dari pencetak mana pun — supaya papan
/// tulis yang dicetak atau digabung dengan paper tidak berbeda ukuran. Sisi
/// mana yang jadi lebar ditentukan [BoardOrientation].
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
