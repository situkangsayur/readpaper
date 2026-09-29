import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Folder kerja ReadPaper: tempat papan tulis, buku catatan, berkas yang
/// disalin masuk, dan PDF hasil suntingan mendarat.
///
/// Satu definisi, dipakai panel berkas dan setiap layar yang menyimpan sesuatu.
/// Sebelumnya tiap tempat menghitungnya sendiri, dan berkas yang disimpan lewat
/// dialog Android berakhir di tempat yang tidak pernah muncul di panel berkas —
/// tersimpan, tetapi hilang dari pandangan.
class WorkFolder {
  const WorkFolder._();

  static const String name = 'readpaper';

  static Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(base.path, name));
    if (!folder.existsSync()) await folder.create(recursive: true);
    return folder;
  }

  /// Folder kerja beserta sub-foldernya, untuk dipilih sebagai tujuan simpan.
  ///
  /// Hanya satu tingkat ke bawah: daftar yang lebih dalam dari itu lebih mirip
  /// penjelajah berkas daripada pertanyaan "disimpan di mana".
  static Future<List<Directory>> choices() async {
    final root = await dir();
    final out = <Directory>[root];
    try {
      for (final entry in root.listSync(followLinks: false)) {
        if (entry is Directory) out.add(entry);
      }
    } on FileSystemException {
      // Folder yang tidak bisa dibaca cukup tidak ditawarkan.
    }
    out.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
    return out;
  }

  /// Nama berkas yang belum dipakai di [folder].
  static File freshFile(Directory folder, String stem, String extension) {
    var file = File(p.join(folder.path, '$stem$extension'));
    for (var n = 2; file.existsSync() && n < 1000; n++) {
      file = File(p.join(folder.path, '$stem-$n$extension'));
    }
    return file;
  }

  /// Nama folder yang enak dibaca: "Folder kerja" untuk akarnya.
  static String label(Directory folder) {
    final base = p.basename(folder.path);
    return base == name ? 'Folder kerja' : base;
  }
}
