import 'dart:convert';
import 'dart:typed_data';

import '../../library/domain/entities/zotero_annotation.dart';

/// Apa yang ditampilkan layar audiens: satu halaman, anotasinya, coretan yang
/// belum tersimpan, goresan yang sedang ditarik, dan warna halaman.
///
/// Layar audiens berjalan di mesin Flutter terpisah — jendela lain di
/// desktop, layar eksternal di Android — jadi tidak bisa membaca status
/// pembaca secara langsung. Presenter mengirimkannya sebagai pesan JSON;
/// semua yang ada di sini harus bisa dikodekan.
class AudienceState {
  const AudienceState({
    this.path,
    this.page = 1,
    this.annotations = const <ZoteroAnnotation>[],
    this.pending = const <InkPath>[],
    this.pendingColor = '#000000',
    this.pendingWidth = 2,
    this.live = const <double>[],
    this.liveColor = '#000000',
    this.liveWidth = 2,
    this.tint = 'normal',
    this.blank = false,
  });

  /// Berkas PDF yang ditampilkan. Berganti saat presenter menambah halaman
  /// kosong (berkas kerja baru).
  final String? path;
  final int page;

  /// Anotasi halaman [page] — hanya halaman itu yang terlihat di audiens.
  final List<ZoteroAnnotation> annotations;

  /// Goresan yang sudah selesai ditarik tetapi belum menjadi anotasi.
  final List<InkPath> pending;
  final String pendingColor;
  final double pendingWidth;

  /// Goresan yang sedang ditarik, titik x, y bergantian dalam koordinat PDF.
  final List<double> live;
  final String liveColor;
  final double liveWidth;

  /// Nama [PageTint] (normal, sepia, …).
  final String tint;

  /// Layar audiens disembunyikan (layar hitam) — presenter menekan "Layar
  /// hitam", misalnya saat menjawab pertanyaan.
  final bool blank;

  AudienceState copyWith({
    String? path,
    int? page,
    List<ZoteroAnnotation>? annotations,
    List<InkPath>? pending,
    String? pendingColor,
    double? pendingWidth,
    List<double>? live,
    String? liveColor,
    double? liveWidth,
    String? tint,
    bool? blank,
  }) => AudienceState(
    path: path ?? this.path,
    page: page ?? this.page,
    annotations: annotations ?? this.annotations,
    pending: pending ?? this.pending,
    pendingColor: pendingColor ?? this.pendingColor,
    pendingWidth: pendingWidth ?? this.pendingWidth,
    live: live ?? this.live,
    liveColor: liveColor ?? this.liveColor,
    liveWidth: liveWidth ?? this.liveWidth,
    tint: tint ?? this.tint,
    blank: blank ?? this.blank,
  );
}

/// Pesan dari presenter ke layar audiens.
///
/// Dua jenis, karena frekuensinya sangat berbeda:
/// - `scene`: seluruh isi halaman (berkas, halaman, anotasi, coretan yang
///   belum tersimpan, warna, layar hitam) — dikirim saat ada yang berubah;
/// - `live`: goresan yang sedang ditarik — sampai puluhan kali sedetik, jadi
///   isinya hanya titik-titiknya.
/// Ditambah `pictures` untuk gambar tempelan (dikirim sekali per gambar) dan
/// `close` saat presentasi selesai.
class AudienceMessage {
  const AudienceMessage._();

  static Map<String, dynamic> scene(AudienceState s) => <String, dynamic>{
    'type': 'scene',
    'path': s.path,
    'page': s.page,
    'annotations': <dynamic>[for (final a in s.annotations) a.toJson()],
    'pending': <dynamic>[for (final p in s.pending) p.toList()],
    'pendingColor': s.pendingColor,
    'pendingWidth': s.pendingWidth,
    'tint': s.tint,
    'blank': s.blank,
  };

  static Map<String, dynamic> live({
    required List<double> points,
    required String color,
    required double width,
  }) => <String, dynamic>{'type': 'live', 'points': points, 'color': color, 'width': width};

  static Map<String, dynamic> pictures(Map<String, Uint8List> files) => <String, dynamic>{
    'type': 'pictures',
    'files': <String, String>{for (final e in files.entries) e.key: base64Encode(e.value)},
  };

  static const Map<String, dynamic> close = <String, dynamic>{'type': 'close'};

  /// Menerapkan satu pesan ke status audiens. Gambar dikembalikan terpisah,
  /// karena dibaca (didekode) di luar model ini.
  static AudienceState apply(AudienceState state, Map<String, dynamic> message) {
    switch (message['type']) {
      case 'scene':
        return state.copyWith(
          path: message['path'] as String?,
          page: (message['page'] as num?)?.toInt() ?? state.page,
          annotations: <ZoteroAnnotation>[
            for (final a in (message['annotations'] as List?) ?? const <dynamic>[])
              ZoteroAnnotation.fromJson((a as Map).cast<String, dynamic>()),
          ],
          pending: <InkPath>[
            for (final p in (message['pending'] as List?) ?? const <dynamic>[])
              InkPath.fromList(p as List),
          ],
          pendingColor: message['pendingColor'] as String?,
          pendingWidth: (message['pendingWidth'] as num?)?.toDouble(),
          tint: message['tint'] as String?,
          blank: message['blank'] as bool?,
          // Halaman baru: goresan yang sedang ditarik milik halaman lama.
          live: (message['page'] as num?)?.toInt() == state.page ? null : const <double>[],
        );
      case 'live':
        return state.copyWith(
          live: <double>[
            for (final v in (message['points'] as List?) ?? const <dynamic>[])
              (v as num).toDouble(),
          ],
          liveColor: message['color'] as String?,
          liveWidth: (message['width'] as num?)?.toDouble(),
        );
    }
    return state;
  }

  /// Gambar tempelan dari pesan `pictures`.
  static Map<String, Uint8List> picturesOf(Map<String, dynamic> message) => <String, Uint8List>{
    for (final e in ((message['files'] as Map?) ?? const <String, dynamic>{}).entries)
      e.key as String: base64Decode(e.value as String),
  };
}
