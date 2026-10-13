import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Mengubah dokumen Office ke PDF lewat LibreOffice, bila terpasang (hanya
/// desktop). Hasilnya tampil persis seperti di Office — huruf, tata letak,
/// bagan — dan bisa dibaca dengan semua alat pembaca PDF: cari, tandai,
/// coret, dan mode menyajikan untuk presentasi.
class OfficeConverter {
  const OfficeConverter._();

  static Future<String?>? _found;

  /// Jalur `soffice`, atau null bila LibreOffice tidak ada.
  static Future<String?> sofficePath() => _found ??= _locate();

  static Future<String?> _locate() async {
    if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) return null;
    final candidates = <String>[
      if (Platform.isWindows) ...<String>[
        r'C:\Program Files\LibreOffice\program\soffice.exe',
        r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
      ],
      if (Platform.isMacOS) '/Applications/LibreOffice.app/Contents/MacOS/soffice',
      if (Platform.isLinux) ...<String>[
        '/usr/bin/soffice',
        '/usr/bin/libreoffice',
        '/usr/local/bin/soffice',
        '/opt/libreoffice/program/soffice',
        '/var/lib/flatpak/exports/bin/org.libreoffice.LibreOffice',
        '/snap/bin/libreoffice',
      ],
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    // Di PATH, dengan nama apa pun yang dipakai distribusinya.
    final lookup = Platform.isWindows ? 'where' : 'which';
    for (final name in <String>['soffice', 'libreoffice']) {
      try {
        final result = await Process.run(lookup, <String>[name]);
        final out = '${result.stdout}'.trim().split('\n').first.trim();
        if (result.exitCode == 0 && out.isNotEmpty) return out;
      } on Object {
        // `which` tidak ada; lanjut.
      }
    }
    return null;
  }

  /// PDF hasil ubahan [path]. Disimpan per isi berkas: membuka lagi berkas
  /// yang sama tidak mengubahnya lagi, berkas yang berubah diubah ulang.
  static Future<String> toPdf(String path) async {
    final soffice = await sofficePath();
    if (soffice == null) throw StateError('LibreOffice tidak ditemukan');
    final source = File(path);
    final stat = await source.stat();
    final key = sha1
        .convert(
          utf8.encode(
            '${source.absolute.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}',
          ),
        )
        .toString()
        .substring(0, 16);
    final support = await getApplicationSupportDirectory();
    final outDir = Directory(p.join(support.path, 'office-pdf', key));
    final pdf = File(p.join(outDir.path, '${p.basenameWithoutExtension(path)}.pdf'));
    if (await pdf.exists() && await pdf.length() > 0) return pdf.path;
    await outDir.create(recursive: true);

    // Profil LibreOffice tersendiri: dengan profil pemakai, konversi diam-diam
    // gagal selama LibreOffice-nya sedang terbuka.
    final profile = Directory(p.join(support.path, 'office-pdf', 'profil-libreoffice'));
    final result = await Process.run(soffice, <String>[
      '-env:UserInstallation=${Uri.directory(profile.path)}',
      '--headless',
      '--norestore',
      '--convert-to',
      'pdf',
      '--outdir',
      outDir.path,
      source.absolute.path,
    ]).timeout(const Duration(minutes: 3));
    if (!await pdf.exists()) {
      final detail = '${result.stderr}'.trim();
      throw ProcessException(
        soffice,
        const <String>[],
        detail.isEmpty ? 'PDF tidak terbentuk' : detail,
        result.exitCode,
      );
    }
    return pdf.path;
  }
}
