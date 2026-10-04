import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/share_file.dart';

/// Melihat satu gambar: hasil pindaian, tangkapan layar, foto papan tulis.
///
/// Gambar adalah bentuk catatan yang paling sering datang dari luar, dan sampai
/// sekarang ia satu-satunya yang tidak bisa dibuka di dalam aplikasi — ketukan
/// di daftar catatan hanya menjawab "belum bisa dibuka". Yang dibutuhkan bukan
/// penyunting, hanya cara melihatnya cukup besar untuk dibaca.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({required this.path, this.title, super.key});

  final String path;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title ?? p.basenameWithoutExtension(path)),
            Text(p.basename(path), style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: <Widget>[
          // Lewat shareFile, bukan SharePlus langsung: di iPad lembar bagikan
          // wajib punya titik asal, dan Builder memberi konteks tombol ini
          // sendiri — bukan seluruh layar — sebagai titik itu.
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: 'Bagikan',
              icon: const Icon(Icons.share_outlined),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(buttonContext);
                final failure = await shareFile(
                  buttonContext,
                  path,
                  title: title ?? p.basenameWithoutExtension(path),
                );
                if (failure != null) {
                  messenger.showSnackBar(SnackBar(content: Text(failure)));
                }
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !file.existsSync()
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Berkas gambarnya tidak ada lagi:\n$path', textAlign: TextAlign.center),
              ),
            )
          // Dua jari memperbesar: gambar pindaian sering perlu diperbesar untuk
          // dibaca, dan itu satu-satunya alasan layar ini ada.
          : InteractiveViewer(
              maxScale: 8,
              child: Center(child: Image.file(file, fit: BoxFit.contain)),
            ),
    );
  }
}
