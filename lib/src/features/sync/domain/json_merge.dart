import 'dart:collection';
import 'dart:convert';

/// Menggabungkan dua versi sebuah berkas JSON yang sama-sama diubah sejak
/// versi bersama terakhirnya.
///
/// Hampir semua yang ditulis ReadPaper ke repositori adalah JSON berisi daftar
/// benda berkunci: koleksi catatan, item catatan, item Zotero beserta
/// anotasinya. Dua perangkat yang mengubah berkas yang sama hampir selalu
/// mengubah benda yang **berbeda** — laptop menambah koleksi "phd", tablet
/// menambah "proposal" — dan git, yang membaca baris, menyebutnya bentrok lalu
/// berhenti. Dibaca sebagai data, keduanya tinggal disatukan per kunci.
///
/// Aturannya tiga arah, dengan [base] sebagai versi bersama terakhir:
/// - yang hanya diubah satu sisi, ambil sisi itu — termasuk penghapusan;
/// - yang diubah kedua sisi dengan hasil sama, ambil itu;
/// - yang diubah kedua sisi dengan hasil berbeda, **lokal menang**: itu yang
///   baru saja dikerjakan orang di perangkat ini.
///
/// Hasilnya ditulis dengan format yang sama dengan plugin Zotero — identasi
/// tab, kunci terurut, baris baru di akhir — supaya diff-nya tetap kecil.
class JsonMerge {
  const JsonMerge._();

  /// Hasil gabungan, atau null kalau salah satu versinya bukan JSON.
  ///
  /// [base] boleh null: berkas yang dibuat di kedua sisi tanpa versi bersama.
  static String? mergeText({required String? base, required String remote, required String local}) {
    final Object? b;
    final Object? r;
    final Object? l;
    try {
      b = base == null ? _missing : jsonDecode(base);
      r = jsonDecode(remote);
      l = jsonDecode(local);
    } on FormatException {
      return null;
    }
    final merged = merge(b, r, l);
    if (identical(merged, _missing)) return null;
    return encode(merged);
  }

  /// Penanda "tidak ada" yang berbeda dari `null` di dalam JSON.
  static const Object _missing = _Missing();

  static String encode(Object? value) =>
      '${const JsonEncoder.withIndent('\t').convert(_sortKeys(value))}\n';

  /// Menggabungkan satu nilai tiga arah. Nilai yang hilang di satu sisi
  /// diwakili [_missing].
  static Object? merge(Object? base, Object? remote, Object? local) {
    if (_same(remote, local)) return remote;
    if (_same(base, remote)) return local;
    if (_same(base, local)) return remote;

    // Keduanya berubah, dengan hasil berbeda.
    if (remote is Map && local is Map) {
      return _mergeMaps(base is Map ? base : null, remote, local);
    }
    if (remote is List && local is List && _isKeyed(remote) && _isKeyed(local)) {
      return _mergeKeyedLists(base is List && _isKeyed(base) ? base : null, remote, local);
    }
    // Nilai tunggal, atau satu sisi menghapus sementara sisi lain mengubah:
    // pekerjaan lokal yang dipertahankan. Menghapus sesuatu yang baru saja
    // diubah di tempat lain akan membuang perubahan itu tanpa jejak.
    if (identical(local, _missing)) return remote;
    return local;
  }

  static Map<String, Object?> _mergeMaps(Map? base, Map remote, Map local) {
    final out = <String, Object?>{};
    final keys = <String>{
      ...remote.keys.map((k) => k.toString()),
      ...local.keys.map((k) => k.toString()),
    };
    for (final key in keys) {
      final value = merge(
        base == null ? _missing : (base.containsKey(key) ? base[key] : _missing),
        remote.containsKey(key) ? remote[key] : _missing,
        local.containsKey(key) ? local[key] : _missing,
      );
      if (!identical(value, _missing)) out[key] = value;
    }
    return out;
  }

  static List<Object?> _mergeKeyedLists(List? base, List remote, List local) {
    Map<String, Map> byKey(List list) => <String, Map>{
      for (final item in list.cast<Map>()) item['key'] as String: item,
    };
    final b = base == null ? const <String, Map>{} : byKey(base);
    final r = byKey(remote);
    final l = byKey(local);

    // Urutan: kalau daftarnya memang terurut menurut kunci (koleksi catatan,
    // misalnya), hasilnya ikut terurut. Kalau tidak, urutan GitHub
    // dipertahankan dan benda yang hanya ada di lokal menyusul di belakang.
    final order = <String>[
      ...r.keys,
      ...l.keys.where((k) => !r.containsKey(k)),
      ...b.keys.where((k) => !r.containsKey(k) && !l.containsKey(k)),
    ];
    if (_sortedByKey(remote) && _sortedByKey(local)) order.sort();

    final out = <Object?>[];
    for (final key in order) {
      final value = merge(
        b.containsKey(key) ? b[key] : _missing,
        r.containsKey(key) ? r[key] : _missing,
        l.containsKey(key) ? l[key] : _missing,
      );
      if (!identical(value, _missing)) out.add(value);
    }
    return out;
  }

  static bool _isKeyed(List list) =>
      list.every((item) => item is Map && item['key'] is String) &&
      list.map((item) => (item as Map)['key']).toSet().length == list.length;

  static bool _sortedByKey(List list) {
    for (var i = 1; i < list.length; i++) {
      final a = (list[i - 1] as Map)['key'] as String;
      final b = (list[i] as Map)['key'] as String;
      if (a.compareTo(b) > 0) return false;
    }
    return true;
  }

  static bool _same(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (identical(a, _missing) || identical(b, _missing)) return false;
    return jsonEncode(_sortKeys(a)) == jsonEncode(_sortKeys(b));
  }

  static Object? _sortKeys(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted[entry.key.toString()] = _sortKeys(entry.value);
      }
      return sorted;
    }
    if (value is List) return value.map(_sortKeys).toList();
    return value;
  }
}

class _Missing {
  const _Missing();
}
