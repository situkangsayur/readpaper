import 'dart:math' as math;
import 'dart:ui';

/// Menghaluskan goresan tinta.
///
/// Titik yang datang dari layar selalu bersudut: jari dan stylus melaporkan
/// posisinya beberapa puluh kali per detik, dan menyambungnya dengan garis
/// lurus membuat tulisan tangan terlihat seperti patah-patah — paling terasa
/// pada huruf melingkar dan tanda tangan.
///
/// Yang dipakai di sini kurva kuadratik yang melewati **titik tengah** antar
/// titik, dengan titik aslinya sebagai kendali. Hasilnya melengkung mulus
/// tanpa pernah melenceng jauh dari yang ditulis — dan perhitungannya cukup
/// murah untuk dijalankan ulang di setiap bingkai selagi menulis.
class InkSmoothing {
  const InkSmoothing._();

  /// Titik jarak minimum antar titik yang layak disimpan, dalam titik PDF.
  ///
  /// Terlalu rapat hanya menambah besar berkas tanpa mengubah bentuknya;
  /// terlalu jarang membuat lengkungnya bersudut.
  static const double minStep = 0.9;

  /// Satu ruas kurva: kendalinya dan ujungnya.
  static List<({Offset control, Offset end})> quads(List<Offset> points) {
    if (points.length < 2) return const <({Offset control, Offset end})>[];
    if (points.length == 2) {
      return <({Offset control, Offset end})>[(control: points.first, end: points.last)];
    }

    final out = <({Offset control, Offset end})>[];
    for (var i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      out.add((control: points[i], end: mid));
    }
    // Ruas terakhir ditarik sampai titik terakhir yang sungguhan, supaya ujung
    // goresan berhenti tepat di tempat jarinya diangkat.
    out.add((control: points[points.length - 1], end: points.last));
    return out;
  }

  /// Jalur yang sudah dihaluskan, untuk digambar di kanvas.
  static Path path(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    for (final quad in quads(points)) {
      path.quadraticBezierTo(quad.control.dx, quad.control.dy, quad.end.dx, quad.end.dy);
    }
    return path;
  }

  /// Tebal goresan untuk satu titik, dari tekanan stylus.
  ///
  /// Tekanan menulis biasa berada di sekitar separuh, jadi di situlah tebalnya
  /// sama dengan tebal pena yang dipilih: menekan lebih keras menebalkan,
  /// menyentuh ringan menipiskan. Batas bawahnya tidak nol — garis yang hilang
  /// sama sekali saat tangan melemah terasa seperti pena yang rusak.
  static double widthFor(double base, double pressure) {
    final p = pressure.clamp(0.0, 1.0);
    return base * (0.55 + 0.9 * p);
  }

  /// Menggambar satu goresan, bertebal tetap atau bertebal berubah.
  ///
  /// Yang bertebal berubah digambar ruas demi ruas, masing-masing dengan
  /// tebalnya sendiri; ujung bulat membuat sambungannya tidak terlihat. Tetap
  /// memakai kurva yang sama, jadi goresan bertekanan tidak mendadak jadi
  /// bersudut.
  static void paintStroke(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    required double width,
    List<double>? widths,
  }) {
    if (points.isEmpty) return;
    if (widths == null || widths.length < points.length) {
      paint.strokeWidth = width;
      canvas.drawPath(path(points), paint);
      return;
    }

    var from = points.first;
    var i = 0;
    for (final quad in quads(points)) {
      final at = math.min(i + 1, widths.length - 1);
      paint.strokeWidth = widths[at];
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(quad.control.dx, quad.control.dy, quad.end.dx, quad.end.dy),
        paint,
      );
      from = quad.end;
      i++;
    }
  }

  /// Kurva kuadratik sebagai kubik — bentuk yang dimengerti PDF.
  ///
  /// Keduanya menggambarkan kurva yang sama persis, jadi cetakannya tidak
  /// pernah berbeda dari yang terlihat di layar.
  static ({Offset c1, Offset c2, Offset end}) toCubic(Offset from, Offset control, Offset end) => (
    c1: Offset(from.dx + 2 / 3 * (control.dx - from.dx), from.dy + 2 / 3 * (control.dy - from.dy)),
    c2: Offset(end.dx + 2 / 3 * (control.dx - end.dx), end.dy + 2 / 3 * (control.dy - end.dy)),
    end: end,
  );
}
