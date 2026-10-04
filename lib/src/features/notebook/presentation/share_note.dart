import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/share_file.dart';
import '../data/note_document_store.dart';
import '../data/note_export.dart';

/// Membagikan berkas apa pun dari panel berkas atau daftar catatan.
///
/// Buku catatan dibagikan sebagai PDF, bukan berkas `.catatan.json`-nya:
/// penerimanya hampir pasti tidak punya ReadPaper, dan yang ingin dilihatnya
/// adalah lembarnya. Berkas lain diserahkan apa adanya.
Future<void> shareAnyFile(BuildContext context, String path, {String? title}) async {
  final messenger = ScaffoldMessenger.of(context);
  String? failure;
  try {
    if (NoteDocumentStore.isNoteDocument(path)) {
      final document = await NoteDocumentStore.read(path);
      final bytes = await NoteExport.toPdf(document, baseDir: p.dirname(path));
      if (!context.mounted) return;
      final stem = NoteDocumentStore.stemOf(path);
      failure = await shareBytes(context, bytes, '$stem.pdf', title: title ?? stem);
    } else {
      failure = await shareFile(context, path, title: title);
    }
  } on Object catch (e) {
    failure = 'Gagal membagikan: $e';
  }
  if (failure != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure)));
  }
}
