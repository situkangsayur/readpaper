/// Satu rilis ReadPaper di GitHub, sebatas yang dibutuhkan untuk memperbarui.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.assets,
  });

  /// Dari jawaban `GET /repos/{owner}/{repo}/releases/latest`.
  factory AppRelease.fromGitHub(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').trim();
    return AppRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      notes: (json['body'] as String? ?? '').trim(),
      pageUrl: json['html_url'] as String? ?? '',
      assets: <ReleaseAsset>[
        for (final a in (json['assets'] as List<dynamic>? ?? const <dynamic>[]))
          ReleaseAsset.fromGitHub(a as Map<String, dynamic>),
      ],
    );
  }

  /// Tanpa awalan `v`, mis. `0.35.0`.
  final String version;
  final String notes;

  /// Halaman rilisnya, untuk platform yang tidak bisa memasang sendiri.
  final String pageUrl;
  final List<ReleaseAsset> assets;

  ReleaseAsset? asset(bool Function(String name) test) {
    for (final a in assets) {
      if (test(a.name)) return a;
    }
    return null;
  }
}

class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size, this.sha256});

  factory ReleaseAsset.fromGitHub(Map<String, dynamic> json) {
    final digest = json['digest'] as String?;
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      url: json['browser_download_url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      // GitHub menghitung sendiri sha256 setiap berkas rilis. Unduhan yang
      // terpotong atau tertukar ketahuan sebelum dipasang.
      sha256: digest != null && digest.startsWith('sha256:') ? digest.substring(7) : null,
    );
  }

  final String name;
  final String url;
  final int size;
  final String? sha256;
}

/// Perbandingan nomor versi `major.minor.patch` (bagian `+build` diabaikan).
///
/// Bukan perbandingan teks: `0.10.0` lebih baru daripada `0.9.9`.
int compareVersions(String a, String b) {
  List<int> parts(String v) {
    final core = v.trim().replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[+-]')).first;
    return <int>[for (final s in core.split('.')) int.tryParse(s) ?? 0];
  }

  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

bool isNewerVersion(String candidate, String current) => compareVersions(candidate, current) > 0;
