import 'dart:io';

/// Sidik murah sekumpulan berkas dan folder di disk: berubah begitu ada berkas
/// yang ditambah, dihapus, atau ditulis ulang di bawahnya.
///
/// Hanya ukuran dan waktu ubah yang dibaca, bukan isinya. Untuk library
/// 2.500 item itu sekitar 50 ms di desktop — cukup murah untuk diulang setiap
/// beberapa detik di isolate lain, dan jauh lebih bisa dipercaya daripada
/// `Directory.watch(recursive: true)`, yang di Linux dan Android tidak melihat
/// isi sub-folder sama sekali.
///
/// Urutan daftar folder tidak dijamin sama setiap kali dibaca, jadi setiap
/// berkas digabung dengan operasi yang tidak peduli urutan.
String treeSignatureSync(List<String> paths) {
  final out = StringBuffer();
  for (final path in paths) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      out.write('-;');
      continue;
    }
    if (type != FileSystemEntityType.directory) {
      final stat = File(path).statSync();
      out.write('${stat.size}@${stat.modified.microsecondsSinceEpoch};');
      continue;
    }
    var count = 0;
    var sum = 0;
    var mix = 0;
    try {
      for (final entity in Directory(path).listSync(recursive: true, followLinks: false)) {
        final stat = entity.statSync();
        final v = stat.modified.microsecondsSinceEpoch * 31 + stat.size + entity.path.hashCode;
        count++;
        sum += v;
        mix ^= v;
      }
    } on FileSystemException {
      // Folder yang sedang ditulis ulang (pull di tengah jalan) dibaca lagi
      // di putaran berikutnya.
      out.write('!;');
      continue;
    }
    out.write('$count/$sum/$mix;');
  }
  return out.toString();
}
