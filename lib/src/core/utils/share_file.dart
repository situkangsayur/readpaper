import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Menyerahkan sebuah berkas ke lembar bagikan sistem: aplikasi chat, surel,
/// Drive, atau aplikasi lain yang mau menerimanya.
///
/// Satu tempat untuk semua layar, supaya tipe berkas dan titik asal lembar
/// bagikan — yang wajib di iPad, kalau tidak lembarnya muncul di pojok tanpa
/// panah atau tidak muncul sama sekali — tidak dihitung ulang di setiap layar.
/// Mengembalikan pesan kegagalan, atau null kalau lembarnya berhasil dibuka.
Future<String?> shareFile(BuildContext context, String path, {String? title}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(path, mimeType: mimeTypeOf(path))],
        subject: title ?? p.basenameWithoutExtension(path),
        sharePositionOrigin: origin,
      ),
    );
    return null;
  } on Object catch (e) {
    // Linux tidak punya lembar bagikan untuk berkas. Lebih baik dikatakan
    // daripada tombolnya diam.
    return 'Berbagi berkas belum didukung di sini ($e). Berkasnya ada di $path';
  }
}

/// Menulis [bytes] ke folder sementara lalu membagikannya.
///
/// Dipakai untuk hasil yang tidak perlu menetap di folder kerja — PDF dari
/// buku catatan atau Markdown yang hanya hendak dikirim ke seseorang.
Future<String?> shareBytes(
  BuildContext context,
  List<int> bytes,
  String fileName, {
  String? title,
}) async {
  final dir = await getTemporaryDirectory();
  final out = Directory(p.join(dir.path, 'bagikan'));
  await out.create(recursive: true);
  final file = File(p.join(out.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  if (!context.mounted) return null;
  return shareFile(context, file.path, title: title);
}

String mimeTypeOf(String path) => switch (p.extension(path).toLowerCase()) {
  '.pdf' => 'application/pdf',
  '.md' => 'text/markdown',
  '.txt' => 'text/plain',
  '.png' => 'image/png',
  '.jpg' || '.jpeg' => 'image/jpeg',
  '.epub' => 'application/epub+zip',
  '.json' => 'application/json',
  _ => 'application/octet-stream',
};
