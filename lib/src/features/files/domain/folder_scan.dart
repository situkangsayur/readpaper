import 'dart:io';

import 'package:path/path.dart' as p;

/// Satu folder yang akan diimpor: berkasnya dan subfoldernya, terurut nama.
class FolderNode {
  const FolderNode({
    required this.name,
    required this.path,
    required this.files,
    required this.children,
  });

  final String name;
  final String path;
  final List<String> files;
  final List<FolderNode> children;

  int get fileCount => files.length + children.fold(0, (n, c) => n + c.fileCount);

  int get folderCount => 1 + children.fold(0, (n, c) => n + c.folderCount);

  int get totalBytes =>
      files.fold<int>(0, (n, f) => n + File(f).lengthSync()) +
      children.fold(0, (n, c) => n + c.totalBytes);
}

/// Membaca struktur folder untuk diimpor ke koleksi.
///
/// Yang dilewati: berkas dan folder tersembunyi (`.git`, `.DS_Store`),
/// berkas sementara Office (`~$laporan.docx`), `Thumbs.db` dan `desktop.ini`,
/// serta tautan simbolik — tautan bisa menunjuk ke induknya sendiri dan
/// membuat impor tidak pernah selesai.
class FolderScan {
  const FolderScan._();

  static FolderNode scan(String path) {
    final dir = Directory(path);
    final files = <String>[];
    final children = <FolderNode>[];
    final entries = dir.listSync(
      followLinks: false,
    )..sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
    for (final entry in entries) {
      final name = p.basename(entry.path);
      if (skipped(name)) continue;
      if (entry is Directory) {
        children.add(scan(entry.path));
      } else if (entry is File) {
        files.add(entry.path);
      }
    }
    return FolderNode(name: p.basename(path), path: path, files: files, children: children);
  }

  static bool skipped(String name) {
    final lower = name.toLowerCase();
    return name.startsWith('.') ||
        name.startsWith(r'~$') ||
        lower == 'thumbs.db' ||
        lower == 'desktop.ini';
  }
}
