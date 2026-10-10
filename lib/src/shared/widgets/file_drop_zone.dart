import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

/// Menerima berkas yang diseret dari pengelola berkas sistem — Nautilus,
/// Dolphin, Explorer, Finder — ke jendela ReadPaper.
///
/// Hanya di desktop; di Android dan iOS anaknya dikembalikan apa adanya.
/// [builder] menerima `hovering` supaya sasarannya bisa menyala saat berkas
/// melayang di atasnya: tanpa itu yang menyeret tidak tahu di mana lepasannya
/// akan mendarat.
class FileDropZone extends StatefulWidget {
  const FileDropZone({required this.onFiles, required this.builder, super.key});

  final Future<void> Function(List<String> paths) onFiles;
  final Widget Function(BuildContext context, bool hovering) builder;

  static bool get supported => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (!FileDropZone.supported) return widget.builder(context, false);
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) {
        setState(() => _hovering = false);
        final paths = <String>[
          for (final file in details.files)
            // Folder juga: yang menerima memutuskan apa artinya — koleksi
            // baru di pohon, atau salinan folder di panel berkas.
            if (file.path.isNotEmpty &&
                (File(file.path).existsSync() || Directory(file.path).existsSync()))
              file.path,
        ];
        if (paths.isNotEmpty) widget.onFiles(paths);
      },
      child: widget.builder(context, _hovering),
    );
  }
}
