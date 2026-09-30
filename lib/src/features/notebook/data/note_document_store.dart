import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/errors/failure.dart';
import '../domain/note_document.dart';

/// Membaca dan menulis berkas catatan yang **bisa disunting lagi**.
///
/// Markdown dan PDF keduanya kehilangan sesuatu — yang satu posisi, yang lain
/// kemampuan disunting — jadi keduanya saja tidak cukup untuk catatan yang
/// akan dibuka kembali. Bentuk yang dipilih: JSON biasa berakhiran
/// `.catatan.json`, di samping berkas ekspornya.
///
/// JSON dan bukan format biner, karena catatan ini hidup di dalam repositori
/// git: berkas teks bisa dibaca diff-nya, bisa di-merge kalau perlu, dan masih
/// terbuka lima tahun lagi oleh apa pun yang bisa membaca JSON. Kunci diurut
/// dan indentasinya tab, sama seperti berkas lain di repositori ini, supaya
/// perubahan satu goresan tidak menulis ulang seluruh berkas di dalam diff.
class NoteDocumentStore {
  const NoteDocumentStore._();

  /// Akhiran yang menandai berkas catatan.
  static const String extension = '.catatan.json';

  static bool isNoteDocument(String path) => path.toLowerCase().endsWith(extension);

  /// Nama berkas ekspor yang sepadan: `rapat.catatan.json` → `rapat`.
  ///
  /// Dipotong dengan `p.basename`, bukan dengan [Platform.pathSeparator].
  /// Di Windows pemisahnya `\`, jadi jalur bergaris miring maju — yang datang
  /// dari dialog berkas, dari berkas yang disimpan di platform lain, dan dari
  /// uji — tidak terpotong sama sekali, dan nama ekspornya menjadi seluruh
  /// jalurnya. Ketahuan saat tesnya dijalankan di runner Windows.
  static String stemOf(String path) {
    final name = p.basename(path);
    return name.toLowerCase().endsWith(extension)
        ? name.substring(0, name.length - extension.length)
        : name;
  }

  static Future<NoteDocument> read(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw LibraryFailure('Berkas catatan tidak ditemukan', details: path);
    }
    return decodeSync(await file.readAsString(), path: path);
  }

  /// Membaca isi berkas yang sudah di tangan.
  ///
  /// Dipakai layar buku catatan, yang membaca berkasnya langsung supaya layar
  /// yang terbuka sudah berisi tulisannya — tanpa keadaan "sedang memuat" yang
  /// bisa menggantung.
  static NoteDocument decodeSync(String source, {String? path}) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw LibraryFailure('Isi berkas catatan tidak dikenali', details: path);
    }
    final json = decoded.cast<String, dynamic>();

    // Berkas dari versi yang lebih baru ditolak dengan jelas, bukan dibaca
    // setengah-setengah lalu disimpan balik dalam keadaan rusak.
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version > NoteDocument.formatVersion) {
      throw LibraryFailure(
        'Catatan ini ditulis versi ReadPaper yang lebih baru (format $version). '
        'Perbarui aplikasinya dulu supaya isinya tidak rusak.',
        details: path,
      );
    }
    return NoteDocument.fromJson(json);
  }

  static Future<void> write(String path, NoteDocument document) async {
    final file = File(path);
    // Ditulis langsung: begitu "Tersimpan" muncul, tulisannya memang sudah ada
    // di disk — bukan sedang dalam perjalanan ke sana.
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(encode(document), flush: true);
  }

  static String encode(NoteDocument document) =>
      '${const JsonEncoder.withIndent('\t').convert(_sorted(document.toJson()))}\n';

  static Object? _sorted(Object? value) {
    if (value is Map) {
      final out = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        out[entry.key.toString()] = _sorted(entry.value);
      }
      return out;
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }
}
