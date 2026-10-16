import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../epub/presentation/epub_reader_screen.dart';
import '../../library/data/datasources/zotero_writer.dart';
import '../../notes/presentation/screens/image_viewer_screen.dart';
import '../../office/data/office_loader.dart';
import '../../office/presentation/office_viewer_screen.dart';
import '../../reader/presentation/screens/reader_screen.dart';
import 'screens/table_viewer_screen.dart';
import '../../../core/l10n.dart';

/// Jenis berkas menurut cara ReadPaper membukanya.
enum FileKind { pdf, epub, image, table, office, other }

FileKind fileKindOf(String path) => switch (p.extension(path).toLowerCase()) {
  '.pdf' => FileKind.pdf,
  '.epub' => FileKind.epub,
  '.png' || '.jpg' || '.jpeg' || '.webp' || '.gif' || '.bmp' => FileKind.image,
  '.csv' || '.tsv' || '.xlsx' || '.xlsm' || '.xls' => FileKind.table,
  final ext when odfSheetExtensions.contains(ext) => FileKind.table,
  final ext when officeExtensions.contains(ext) => FileKind.office,
  _ => FileKind.other,
};

/// Berkas yang bisa dibuka di dalam ReadPaper sendiri.
bool canOpenInApp(String path) => fileKindOf(path) != FileKind.other;

/// Di desktop, berkas apa pun bisa diserahkan ke aplikasi bawaan sistem.
bool get canOpenWithSystem => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Membuka [path]: PDF di pembaca (sebagai PDF lepas), EPUB di pembaca EPUB,
/// gambar, tabel, dan dokumen Word/PowerPoint di penampilnya, sisanya di
/// aplikasi bawaan sistem.
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
    FileKind.office => OfficeViewerScreen(path: path, title: name),
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
  final ext = p.extension(path);
  if (!canOpenWithSystem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ext.isEmpty ? context.l10n.filesCannotOpenThis : context.l10n.filesCannotOpenExt(ext),
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
      SnackBar(
        content: Text(
          ext.isEmpty ? context.l10n.filesNoAppForThis : context.l10n.filesNoAppForExt(ext),
        ),
      ),
    );
  }
}

/// Menyimpan salinan berkas [path] apa adanya — `.docx` tetap `.docx`, `.ods`
/// tetap `.ods` — lewat dialog simpan sistem. Di Android dan iOS ini satu-satunya
/// jalan mengeluarkan berkas aslinya dari ReadPaper; "Simpan sebagai PDF"
/// mengubahnya.
Future<void> saveOriginalFile(BuildContext context, String path) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final bytes = await File(path).readAsBytes();
    if (!context.mounted) return;
    final uri = await FilePicker.saveFile(
      fileName: p.basename(path),
      bytes: bytes,
      mimeType: ZoteroWriter.contentTypeOf(path),
      dialogTitle: l10n.officeSaveOriginal,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(uri == null ? l10n.officeOriginalNotSaved : l10n.officeOriginalSaved),
        ),
      );
  } on Object catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.officeOriginalFailed('$e'))));
  }
}
