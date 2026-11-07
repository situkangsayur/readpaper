import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/reader/domain/zoom_steps.dart';

void main() {
  // Halaman potret di jendela lebar: pas halaman 0,6, pas lebar 1,2.
  final stops = readerZoomStops(minScale: 0.3, maxScale: 8, coverScale: 1.2, fitPageScale: 0.6);

  test('urut naik, dalam batas, pas halaman dan pas lebar ada persis', () {
    expect(stops, orderedEquals([...stops]..sort()));
    expect(stops.first, greaterThanOrEqualTo(0.3));
    expect(stops.last, lessThanOrEqualTo(8));
    expect(stops, contains(0.6));
    expect(stops, contains(1.2));
  });

  test('tiap langkah paling jauh ~1,25×, bukan berlipat dua', () {
    for (var i = 1; i < stops.length; i++) {
      final step = stops[i] / stops[i - 1];
      expect(step, lessThanOrEqualTo(1.25 * 1.06 + 1e-9), reason: '${stops[i - 1]} → ${stops[i]}');
      expect(step, greaterThanOrEqualTo(1.06));
    }
  });

  test('dari pas lebar, satu tekan + hanya sedikit lebih dekat', () {
    final next = stops.firstWhere((z) => z > 1.2 + 1e-9);
    expect(next / 1.2, closeTo(1.25, 0.08));
  });
}
