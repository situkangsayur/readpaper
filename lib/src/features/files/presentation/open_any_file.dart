import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../epub/presentation/epub_reader_screen.dart';
import '../../notes/presentation/screens/image_viewer_screen.dart';
import '../../reader/presentation/screens/reader_screen.dart';
import 'screens/table_viewer_screen.dart';

/// Jenis berkas menurut cara ReadPaper membukanya.
enum FileKind { pdf, epub, image, table, other }

FileKind fileKindOf(String path) => switch (p.extension(path).toLowerCase()) {
  '.pdf' => FileKind.pdf,
  '.epub' => FileKind.epub,
  '.png' || '.jpg' || '.jpeg' || '.webp' || '.gif' || '.bmp' => FileKind.image,
  '.csv' || '.tsv' || '.xlsx' || '.xlsm' => FileKind.table,
  _ => FileKind.other,
};

/// Berkas yang bisa dibuka di dalam ReadPaper sendiri.
bool canOpenInApp(String path) => fileKindOf(path) != FileKind.other;

/// Di desktop, berkas apa pun bisa diserahkan ke aplikasi bawaan sistem.
bool get canOpenWithSystem => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Membuka [path]: PDF di pembaca (sebagai PDF lepas), EPUB di pembaca EPUB,
/// gambar dan tabel di penampilnya, sisanya di aplikasi bawaan sistem.
Future<void> openAnyFile(BuildContext context, String path, {String? title}) async {
  final name = title ?? p.basenameWithoutExtension(path);
  final Widget? screen = switch (fileKindOf(path)) {
    FileKind.pdf => ReaderScreen(
      itemKey: '',
      itemFilePath: '',
      attachmentKey: '',
      filePath: path,
      title: name,
    ),
    FileKind.epub => EpubReaderScreen(path: path, title: name),
    FileKind.image => ImageViewerScreen(path: path, title: name),
    FileKind.table => TableViewerScreen(path: path, title: name),
    FileKind.other => null,
  };
  if (screen != null) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return;
  }
  await openWithSystem(context, path);
}

/// Menyerahkan berkas ke aplikasi bawaan sistem (Word, LibreOffice, dsb.).
Future<void> openWithSystem(BuildContext context, String path) async {
  final ext = p.extension(path).isEmpty ? 'ini' : p.extension(path);
  if (!canOpenWithSystem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Berkas $ext belum bisa dibuka di dalam ReadPaper. Yang bisa: PDF, EPUB, '
          'gambar, CSV, dan Excel.',
        ),
      ),
    );
    return;
  }
  var ok = false;
  try {
    ok = await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
  } on Object {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tidak ada aplikasi di sistem ini yang membuka berkas $ext.')),
    );
  }
}
