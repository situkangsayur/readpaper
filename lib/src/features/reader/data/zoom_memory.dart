import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/utils/app_paths.dart';

/// Zum terakhir setiap dokumen, sebagai kelipatan "pas lebar".
///
/// Membuka dokumen selalu mulai dari pas lebar, yang di layar lebar sering
/// terlalu jauh untuk dibaca, jadi zumnya diatur ulang setiap kali dibuka.
/// Sekarang dokumen dibuka lagi pada zum yang terakhir dipakai. Disimpan
/// relatif terhadap pas lebar, bukan angka mutlak, supaya tetap pas di
/// jendela atau perangkat dengan lebar lain.
class ZoomMemory {
  ZoomMemory._();

  static const _maxEntries = 300;
  static Map<String, double>? _cache;

  static File get _file => File(p.join(AppPaths.instance.supportDir.path, 'zum.json'));

  static Map<String, double> _load() {
    final cached = _cache;
    if (cached != null) return cached;
    var map = <String, double>{};
    try {
      final json = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      map = <String, double>{
        for (final e in json.entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      };
    } on Object {
      // Belum ada atau rusak: mulai kosong.
    }
    return _cache = map;
  }

  static double? ratioFor(String path) => _load()[path];

  /// Menyimpan [ratio]; zum yang praktis sama dengan pas lebar dilupakan.
  static void remember(String path, double ratio) {
    final map = _load();
    if ((ratio - 1).abs() < 0.03) {
      if (map.remove(path) == null) return;
    } else {
      final old = map[path];
      if (old != null && (old - ratio).abs() < 0.01) return;
      // Yang terbaru di belakang; yang paling lama dibuang lebih dulu.
      map
        ..remove(path)
        ..[path] = ratio;
      while (map.length > _maxEntries) {
        map.remove(map.keys.first);
      }
    }
    try {
      _file.writeAsStringSync(jsonEncode(map));
    } on Object {
      // Hanya kenyamanan; gagal menyimpannya tidak apa-apa.
    }
  }
}
