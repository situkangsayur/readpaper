import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Seberapa besar sebuah repositori, untuk memilih di antara beberapa.
class RepoStats {
  const RepoStats({
    required this.cloned,
    this.diskBytes = 0,
    this.attachmentBytes = 0,
    this.items = 0,
    this.collections = 0,
    this.unsent = 0,
    this.behind = 0,
  });

  /// Folder clone-nya ada. Tanpa itu angka lainnya tidak bermakna.
  final bool cloned;

  /// Seluruh folder clone di disk, termasuk riwayat git.
  final int diskBytes;

  /// Lampiran yang sudah ada di perangkat ini — bagian yang bisa dibuang
  /// untuk menghemat ruang, karena bisa diunduh lagi.
  final int attachmentBytes;

  final int items;
  final int collections;

  /// Perubahan yang belum terkirim: berkas yang berubah ditambah commit yang
  /// belum di-push.
  final int unsent;

  /// Commit di GitHub yang belum ditarik.
  final int behind;

  /// Ringkasan satu baris: "1.741 item · 61 koleksi · 412 MB · 3 belum terkirim".
  String get summary {
    if (!cloned) return 'belum diambil ke perangkat ini';
    return <String>[
      '${_thousands(items)} item',
      '${_thousands(collections)} koleksi',
      formatBytes(diskBytes),
      if (attachmentBytes > 0) 'lampiran ${formatBytes(attachmentBytes)}',
      if (unsent > 0) '$unsent belum terkirim',
      if (behind > 0) '$behind baru di GitHub',
    ].join(' · ');
  }

  /// Menghitung ukuran di isolate tersendiri: menelusuri ribuan berkas di
  /// thread utama membuat layar tersendat persis saat daftar repositori dibuka.
  static Future<({int disk, int attachments})> measure(String repoPath) =>
      Isolate.run(() => _measure(repoPath));

  static ({int disk, int attachments}) _measure(String repoPath) {
    final root = Directory(repoPath);
    if (!root.existsSync()) return (disk: 0, attachments: 0);
    var disk = 0;
    var attachments = 0;
    try {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final size = entity.lengthSync();
        disk += size;
        final parts = p.split(p.relative(entity.path, from: repoPath));
        if (parts.contains('.git')) continue;
        if (parts.contains('attachments') || parts.contains('attachments-lfs')) {
          attachments += size;
        }
      }
    } on FileSystemException {
      // Berkas yang hilang di tengah penelusuran (git sedang menulis) bukan
      // alasan untuk tidak menampilkan apa pun.
    }
    return (disk: disk, attachments: attachments);
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value < 10 ? value.toStringAsFixed(1).replaceAll('.', ',') : value.round()} ${units[unit]}';
}

String _thousands(int n) {
  final s = '$n';
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}
