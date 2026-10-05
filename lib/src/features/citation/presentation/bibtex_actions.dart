import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/share_file.dart';
import '../../../core/utils/work_folder.dart';
import '../../library/domain/entities/zotero_item.dart';
import '../domain/bibtex.dart';
import '../domain/csl_json.dart';

/// Menulis `.bib` untuk [items] ke folder kerja, lalu menawarkan untuk
/// membagikannya.
///
/// Folder kerja, bukan dialog simpan: dari sana berkasnya bisa diseret ke
/// proyek, disalin ke folder naskah, atau dikirim ke WritePaperTeX, dan
/// mengekspor ulang menimpa berkas yang sama — kunci sitasinya stabil, jadi
/// `\cite{…}` di naskah tetap menunjuk ke entri yang sama.
Future<void> exportBibTex(
  BuildContext context, {
  required List<ZoteroItem> items,
  required String name,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (items.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Koleksi ini belum berisi paper.')));
    return;
  }
  final text = BibTex.export(CslJson.ofAll(items));
  final folder = await WorkFolder.dir();
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
  final file = File(p.join(folder.path, '${safe.isEmpty ? 'pustaka' : safe}.bib'));
  await file.writeAsString(text, flush: true);
  if (!context.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('${items.length} entri ditulis ke ${p.basename(file.path)} di folder kerja'),
        action: SnackBarAction(
          label: 'Bagikan',
          onPressed: () => shareFile(context, file.path, title: p.basename(file.path)),
        ),
      ),
    );
}

/// Menyalin entri BibTeX satu paper ke papan klip.
Future<void> copyBibTex(BuildContext context, ZoteroItem item) async {
  final text = BibTex.export(<Map<String, dynamic>>[CslJson.of(item)]);
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  final key = text.substring(text.indexOf('{') + 1, text.indexOf(','));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('BibTeX disalin — kuncinya $key')));
}
