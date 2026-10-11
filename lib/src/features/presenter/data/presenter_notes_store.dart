import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/app_paths.dart';

/// Catatan presenter per slide: hanya terlihat di layar presenter, tidak
/// pernah di layar audiens.
///
/// Tempatnya mengikuti dokumennya supaya ikut tersinkron:
/// - paper library: `presenter/<kunci lampiran>.json` di akar repositori —
///   di luar folder ekspor Zotero, yang strukturnya dijaga plugin
///   sinkronisasi;
/// - PDF di Catatan: `presenter.json` di folder catatan itu (ikut terhapus
///   dan tersalin bersama catatannya);
/// - PDF lepas: folder data aplikasi di perangkat ini (tidak ada repositori
///   yang bisa menampungnya).
class PresenterNotesStore {
  const PresenterNotesStore(this.path, {this.synced = true});

  factory PresenterNotesStore.forLibrary({
    required String repoRoot,
    required String attachmentKey,
  }) => PresenterNotesStore(p.join(repoRoot, dirName, '$attachmentKey.json'));

  factory PresenterNotesStore.forNote(String noteFilePath) =>
      PresenterNotesStore(p.join(p.dirname(noteFilePath), 'presenter.json'));

  factory PresenterNotesStore.forLooseFile(String filePath) => PresenterNotesStore(
    p.join(
      AppPaths.instance.supportDir.path,
      dirName,
      '${sha1.convert(utf8.encode(p.normalize(filePath)))}.json',
    ),
    synced: false,
  );

  static const String dirName = 'presenter';

  final String path;

  /// Ada di dalam repositori, jadi perubahannya menunggu Kirim.
  final bool synced;

  /// Catatan per nomor halaman (mulai 1). Kosong bila belum ada.
  Future<Map<int, String>> load() async {
    final file = File(path);
    if (!file.existsSync()) return <int, String>{};
    try {
      final json = jsonDecode(await file.readAsString());
      final notes = json is Map ? json['notes'] : null;
      if (notes is! Map) return <int, String>{};
      return <int, String>{
        for (final e in notes.entries)
          if (int.tryParse('${e.key}') != null && '${e.value}'.trim().isNotEmpty)
            int.parse('${e.key}'): '${e.value}',
      };
    } on FormatException {
      return <int, String>{};
    }
  }

  /// Menyimpan semua catatan; yang kosong dibuang, dan berkasnya dihapus bila
  /// tidak ada catatan lagi.
  Future<void> save(Map<int, String> notes) async {
    final kept = <int, String>{
      for (final e in notes.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value,
    };
    final file = File(path);
    if (kept.isEmpty) {
      if (file.existsSync()) await file.delete();
      return;
    }
    final pages = kept.keys.toList()..sort();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('\t').convert(<String, dynamic>{
        'schema': 1,
        'notes': <String, String>{for (final page in pages) '$page': kept[page]!},
      })}\n',
      flush: true,
    );
  }
}
