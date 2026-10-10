import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Pemilih berkas dan folder yang tidak pernah gagal diam-diam.
///
/// Di Linux, `file_picker` berbicara ke XDG Desktop Portal lewat D-Bus. Bila
/// portalnya tidak ada atau menolak — WM ringan tanpa backend FileChooser,
/// sesi tanpa D-Bus, permintaan lama yang tertinggal — panggilannya melempar
/// galat, dan tanpa penangkap galat itu hilang begitu saja: tombolnya ditekan,
/// tidak terjadi apa-apa. Di sini galat itu ditangkap, lalu zenity atau kdialog
/// dicoba. Bila semuanya gagal, [FilePickFailure] dilempar dengan pesan yang
/// bisa ditampilkan.
///
/// Penyaring ekstensi juga dibuat tidak peka huruf besar: pola portal
/// (`*.pdf`) peka huruf besar, jadi `LAPORAN.PDF` tidak terlihat di dialog.
class FilePick {
  const FilePick._();

  /// Jalur berkas yang dipilih; kosong bila dibatalkan.
  static Future<List<String>> files({
    String? title,
    List<String>? extensions,
    FileType type = FileType.any,
    bool multiple = true,
  }) async {
    final allowed = extensions == null ? null : _bothCases(extensions);
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: title,
        type: allowed == null ? type : FileType.custom,
        allowedExtensions: allowed,
      );
      final paths = <String>[
        for (final file in picked)
          if (file.path != null) file.path!,
      ];
      // Beberapa penyedia berkas Android hanya menyerahkan URI tanpa jalur.
      // Dikatakan, bukan didiamkan.
      if (paths.isEmpty && picked.isNotEmpty) {
        throw const FilePickFailure(
          'Berkas itu tidak bisa dibaca dari tempatnya. Salin dulu ke folder kerja.',
        );
      }
      return multiple ? paths : paths.take(1).toList();
    } on FilePickFailure {
      rethrow;
    } on Object catch (error) {
      if (!Platform.isLinux) throw FilePickFailure('Pemilih berkas gagal dibuka: $error');
      final fallback = await _linuxFiles(
        title: title,
        extensions: extensions ?? _extensionsFor(type),
        multiple: multiple,
      );
      if (fallback != null) return fallback;
      throw FilePickFailure(_linuxHelp(error));
    }
  }

  /// Folder yang dipilih, atau null bila dibatalkan.
  static Future<String?> directory({String? title}) async {
    try {
      return await FilePicker.getDirectoryPath(dialogTitle: title);
    } on Object catch (error) {
      if (!Platform.isLinux) throw FilePickFailure('Pemilih folder gagal dibuka: $error');
      final fallback = await _linuxDirectory(title: title);
      if (fallback != null) return fallback.isEmpty ? null : fallback;
      throw FilePickFailure(_linuxHelp(error));
    }
  }

  /// `pdf` → `pdf`, `PDF`; daftar yang sudah memuat keduanya tidak digandakan.
  static List<String> _bothCases(List<String> extensions) => <String>{
    for (final ext in extensions) ...<String>[ext.toLowerCase(), ext.toUpperCase()],
  }.toList();

  static List<String>? _extensionsFor(FileType type) => switch (type) {
    FileType.image => const <String>['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
    _ => null,
  };

  static String _linuxHelp(Object error) =>
      'Dialog pilih berkas tidak bisa dibuka ($error). Pasang xdg-desktop-portal '
      'beserta backend-nya (mis. xdg-desktop-portal-gtk), atau zenity.';

  /// Hasil zenity/kdialog: null bila keduanya tidak ada; daftar kosong bila
  /// dibatalkan.
  static Future<List<String>?> _linuxFiles({
    String? title,
    List<String>? extensions,
    required bool multiple,
  }) async {
    final patterns = extensions == null
        ? null
        : _bothCases(extensions).map((e) => '*.$e').join(' ');
    final zenity = await _run('zenity', <String>[
      '--file-selection',
      if (title != null) '--title=$title',
      if (multiple) ...<String>['--multiple', '--separator=\n'],
      if (patterns != null) '--file-filter=$patterns',
    ]);
    if (zenity != null) return zenity;
    final kdialog = await _run('kdialog', <String>[
      if (multiple) ...<String>[
        '--getopenfilename',
        '.',
        ?patterns,
        '--multiple',
        '--separate-output',
      ] else ...<String>['--getopenfilename', '.', ?patterns],
      if (title != null) ...<String>['--title', title],
    ]);
    return kdialog;
  }

  static Future<String?> _linuxDirectory({String? title}) async {
    final zenity = await _run('zenity', <String>[
      '--file-selection',
      '--directory',
      if (title != null) '--title=$title',
    ]);
    if (zenity != null) return zenity.firstOrNull ?? '';
    final kdialog = await _run('kdialog', <String>[
      '--getexistingdirectory',
      '.',
      if (title != null) ...<String>['--title', title],
    ]);
    if (kdialog != null) return kdialog.firstOrNull ?? '';
    return null;
  }

  /// Baris keluaran program; kosong bila dibatalkan (kode keluar 1), null bila
  /// programnya tidak ada atau gagal.
  static Future<List<String>?> _run(String program, List<String> args) async {
    try {
      final result = await Process.run(program, args);
      // Kode 1 dengan stderr kosong = dibatalkan. Kode 1 dengan pesan galat
      // (mis. "cannot open display") = programnya tidak bisa dipakai, dan itu
      // harus dilaporkan, bukan dianggap batal.
      if (result.exitCode == 1 && (result.stderr as String).trim().isEmpty) {
        return const <String>[];
      }
      if (result.exitCode != 0) return null;
      return (result.stdout as String)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } on ProcessException {
      return null;
    }
  }
}

class FilePickFailure implements Exception {
  const FilePickFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// [FilePick.files], dengan galatnya ditampilkan sebagai pesan alih-alih
/// dilempar. Daftar kosong bila dibatalkan atau gagal.
Future<List<String>> pickFilesOrTell(
  BuildContext context, {
  String? title,
  List<String>? extensions,
  FileType type = FileType.any,
  bool multiple = true,
}) async {
  try {
    return await FilePick.files(
      title: title,
      extensions: extensions,
      type: type,
      multiple: multiple,
    );
  } on FilePickFailure catch (failure) {
    if (context.mounted) _tell(context, failure.message);
    return const <String>[];
  }
}

/// [FilePick.directory], dengan galatnya ditampilkan sebagai pesan.
Future<String?> pickDirectoryOrTell(BuildContext context, {String? title}) async {
  try {
    return await FilePick.directory(title: title);
  } on FilePickFailure catch (failure) {
    if (context.mounted) _tell(context, failure.message);
    return null;
  }
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text(message)));
}
