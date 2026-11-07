import 'package:pdfrx/pdfrx.dart';

/// Tangga zum tombol +/− yang rapat: kira-kira 1,25× per langkah.
///
/// Bawaan pdfrx melipatgandakan zum setiap langkah (pas → 2× → 4×). Satu
/// tekan + langsung terlalu dekat, satu tekan − kembali ke pas halaman yang
/// terlalu jauh, dan tidak ada yang di antaranya. Pas halaman dan pas lebar
/// tetap jadi anak tangga, supaya keduanya bisa dicapai persis.
List<double> readerZoomStops({
  required double minScale,
  required double maxScale,
  required double coverScale,
  double? fitPageScale,
  double factor = 1.25,
}) {
  final anchors = <double>[coverScale, ?fitPageScale].where((z) => z > 0).toList();
  final base = anchors.reduce((a, b) => a < b ? a : b);
  final stops = <double>[...anchors];
  for (var z = base * factor; z < maxScale; z *= factor) {
    stops.add(z);
  }
  stops.add(maxScale);
  for (var z = base / factor; z > minScale; z /= factor) {
    stops.add(z);
  }
  stops.add(minScale);
  stops.sort();
  // Anak tangga yang hampir sama dengan pas halaman/lebar dibuang: dua
  // langkah yang nyaris tidak berbeda terasa seperti tombol yang macet.
  final out = <double>[];
  for (final z in stops) {
    if (z < minScale - 1e-9 || z > maxScale + 1e-9) continue;
    if (out.isNotEmpty && z / out.last < 1.06) {
      if (anchors.any((a) => (a - z).abs() < 1e-9)) out[out.length - 1] = z;
      continue;
    }
    out.add(z);
  }
  return out;
}

class ReaderZoomStepsProvider extends PdfViewerZoomStepsDelegateProvider {
  const ReaderZoomStepsProvider();

  @override
  PdfViewerZoomStepsDelegate create() => _ReaderZoomSteps();

  @override
  bool operator ==(Object other) => other is ReaderZoomStepsProvider;

  @override
  int get hashCode => (ReaderZoomStepsProvider).hashCode;
}

class _ReaderZoomSteps implements PdfViewerZoomStepsDelegate {
  @override
  void dispose() {}

  @override
  List<double> generateZoomStops(PdfViewerLayoutMetrics metrics) => readerZoomStops(
    minScale: metrics.minScale,
    maxScale: metrics.maxScale,
    coverScale: metrics.coverScale,
    fitPageScale: metrics.alternativeFitScale,
  );
}
