import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../library/domain/entities/library_index.dart';
import '../../library/domain/entities/zotero_annotation.dart';
import '../../library/domain/entities/zotero_item.dart';
import '../domain/csl_catalog.dart';
import '../domain/csl_json.dart';

/// Semua yang dibutuhkan server dari aplikasi, dan tidak lebih.
///
/// Sengaja berupa fungsi, bukan rujukan ke controller atau `rootBundle`:
/// server harus bisa diuji dengan library palsu dan berkas gaya yang dibaca
/// langsung dari disk, tanpa satu pun widget Flutter berdiri.
class CitationSource {
  const CitationSource({
    required this.index,
    required this.loadDetail,
    required this.loadAsset,
    required this.version,
  });

  /// Library yang sedang terbuka, atau null kalau belum ada.
  ///
  /// Dipanggil setiap permintaan, bukan disalin sekali saat server menyala:
  /// orang berpindah library tanpa mematikan server, dan pencarian harus
  /// langsung mengikuti.
  final LibraryIndex? Function() index;

  /// Isi lengkap satu item, termasuk anotasinya — yang tidak ada di indeks.
  final Future<ItemDetail> Function(ZoteroItem item) loadDetail;

  /// Membaca berkas di bawah `assets/csl/`, mis. `styles.json` atau
  /// `styles/apa.csl`.
  final Future<String> Function(String path) loadAsset;

  /// Versi ReadPaper yang dilaporkan `/api/ping`.
  final String version;
}

/// Galat yang dijawab ke add-in sebagai `{"error": ...}`.
class _ApiError implements Exception {
  const _ApiError(this.status, this.message);

  final int status;
  final String message;
}

/// Server HTTP lokal untuk add-in Word dan plugin OnlyOffice.
///
/// Kontraknya ada di `docs/api-sitasi.md` dan berkas itulah yang mengikat;
/// berkas ini hanya pelaksanaannya. Server ini tidak merender sitasi apa pun —
/// itu tugas citeproc-js di dalam add-in — ia hanya menyerahkan data.
class CitationServer {
  CitationServer({
    required this.source,
    required String token,
    this.port = defaultPort,
    InternetAddress? address,
  }) : _token = token,
       address = address ?? InternetAddress.loopbackIPv4;

  /// Zotero memakai 23119. Yang ini berbeda supaya keduanya bisa berjalan
  /// bersamaan di komputer yang sama.
  static const int defaultPort = 23121;

  /// Versi kontrak API, bukan versi aplikasi. Naik hanya kalau bentuk
  /// jawabannya berubah sampai add-in lama tidak lagi mengerti.
  static const int apiVersion = 1;

  static const int defaultLimit = 25;
  static const int maxLimit = 100;

  final CitationSource source;

  /// Port yang diminta; 0 berarti "pilihkan yang kosong" (dipakai pengujian).
  final int port;

  /// Selalu loopback: mendengarkan di semua antarmuka berarti membuka
  /// library seseorang ke seluruh jaringan Wi-Fi kafe tempat ia menulis.
  final InternetAddress address;

  String _token;
  HttpServer? _server;
  CslCatalog? _catalog;

  /// Token bisa diganti tanpa mematikan server: membuat token baru dimaksudkan
  /// untuk langsung menolak add-in yang masih memegang token lama.
  set token(String value) => _token = value;

  bool get isRunning => _server != null;

  /// Port yang benar-benar dipakai, setelah [start].
  int? get boundPort => _server?.port;

  /// Menyalakan server. Melempar [SocketException] kalau port sudah dipakai;
  /// yang memanggil memutuskan bagaimana itu dilaporkan.
  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(address, port);
    // Tanpa ini, setiap jawaban membawa `X-Frame-Options` dan kawan-kawannya
    // yang tidak berguna bagi pemanggil fetch() dan hanya memperbesar jawaban.
    server.defaultResponseHeaders.clear();
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  // ----------------------------------------------------------------- routing

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    _cors(request);
    try {
      if (request.method == 'OPTIONS') {
        // Preflight tidak pernah membawa Authorization — peramban memang
        // tidak mengirimnya — jadi menuntut token di sini berarti tidak ada
        // permintaan sungguhan yang pernah diizinkan lewat.
        response.headers.set('Access-Control-Allow-Private-Network', 'true');
        response.headers.set('Access-Control-Max-Age', '600');
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;
      }

      final segments = request.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length < 2 || segments.first != 'api') {
        throw const _ApiError(HttpStatus.notFound, 'Alamat tidak dikenal.');
      }
      final route = segments.sublist(1);

      if (route.length == 1 && route.first == 'ping') {
        _expectMethod(request, 'GET');
        return _json(response, _ping());
      }

      // Diperiksa sebelum alamatnya dicocokkan: situs yang menebak-nebak
      // tidak boleh bisa membedakan alamat yang ada dari yang tidak.
      _authorize(request);

      switch (route) {
        case ['search']:
          _expectMethod(request, 'GET');
          return _json(response, _search(request.uri.queryParameters));
        case ['items']:
          _expectMethod(request, 'POST');
          return _json(response, _items(await _readJson(request)));
        case ['items', final key, 'annotations']:
          _expectMethod(request, 'GET');
          return _json(response, await _annotations(key));
        case ['styles']:
          _expectMethod(request, 'GET');
          return _json(response, await _styles());
        case ['styles', final id]:
          _expectMethod(request, 'GET');
          return _xml(response, await _style(id));
        case ['locales', final tag]:
          _expectMethod(request, 'GET');
          return _xml(response, await _locale(tag));
      }
      throw const _ApiError(HttpStatus.notFound, 'Alamat tidak dikenal.');
    } on _ApiError catch (e) {
      await _error(response, e.status, e.message);
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Galat di ReadPaper: $e');
    }
  }

  void _cors(HttpRequest request) {
    final headers = request.response.headers;
    final origin = request.headers.value('origin');
    // Dipantulkan, bukan `*`: token yang menjaga, bukan CORS — dan `*` tidak
    // boleh dipakai bersama Authorization di sebagian peramban.
    if (origin != null && origin.isNotEmpty) {
      headers.set('Access-Control-Allow-Origin', origin);
      headers.set('Vary', 'Origin');
    }
    headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  }

  void _authorize(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    const prefix = 'bearer ';
    final given = header.length > prefix.length && header.toLowerCase().startsWith(prefix)
        ? header.substring(prefix.length).trim()
        : '';
    if (given.isEmpty || !_sameToken(given, _token)) {
      throw const _ApiError(
        HttpStatus.unauthorized,
        'Token tidak ada atau salah. Salin token dari pengaturan ReadPaper.',
      );
    }
  }

  /// Membandingkan tanpa berhenti di huruf pertama yang berbeda, supaya
  /// lamanya jawaban tidak membocorkan berapa huruf tebakan yang sudah benar.
  static bool _sameToken(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final x = utf8.encode(a);
    final y = utf8.encode(b);
    var diff = x.length ^ y.length;
    for (var i = 0; i < x.length; i++) {
      diff |= x[i] ^ y[i % y.length];
    }
    return diff == 0;
  }

  void _expectMethod(HttpRequest request, String method) {
    if (request.method != method) {
      throw _ApiError(HttpStatus.methodNotAllowed, 'Alamat ini hanya menerima $method.');
    }
  }

  Future<Object?> _readJson(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const _ApiError(HttpStatus.badRequest, 'Isi permintaan bukan JSON yang sah.');
    }
  }

  Future<void> _json(HttpResponse response, Object body) async {
    response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _xml(HttpResponse response, String body) async {
    response.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
    response.write(body);
    await response.close();
  }

  Future<void> _error(HttpResponse response, int status, String message) async {
    try {
      response.statusCode = status;
      await _json(response, <String, Object>{'error': message});
    } catch (_) {
      // Jawabannya sudah separuh terkirim atau sambungannya putus; tidak ada
      // lagi yang bisa diberitahu.
    }
  }

  // ---------------------------------------------------------------- endpoints

  Map<String, Object?> _ping() => <String, Object?>{
    'app': 'ReadPaper',
    'version': source.version,
    'api': apiVersion,
    'library': source.index()?.library.name,
  };

  Map<String, Object> _search(Map<String, String> query) {
    final index = source.index();
    if (index == null) return <String, Object>{'items': const <Object>[]};

    final rawLimit = query['limit'];
    var limit = defaultLimit;
    if (rawLimit != null && rawLimit.isNotEmpty) {
      final parsed = int.tryParse(rawLimit);
      if (parsed == null || parsed < 1) {
        throw const _ApiError(HttpStatus.badRequest, '`limit` harus bilangan bulat positif.');
      }
      limit = parsed > maxLimit ? maxLimit : parsed;
    }

    final found = searchItems(index.allItems, query['q'] ?? '');
    return <String, Object>{
      'items': <Map<String, Object?>>[for (final item in found.take(limit)) _summary(item)],
    };
  }

  Map<String, Object?> _summary(ZoteroItem item) => <String, Object?>{
    'key': item.key,
    'title': item.title,
    'creators': creatorSummary(item),
    'year': item.year,
    'type': item.itemType,
    'collections': item.collectionPaths,
    'annotationCount': item.annotationCount,
  };

  Map<String, Object> _items(Object? body) {
    final keys = body is Map ? body['keys'] : null;
    if (keys is! List || keys.any((k) => k is! String)) {
      throw const _ApiError(
        HttpStatus.badRequest,
        'Isi permintaan harus berbentuk {"keys": ["KUNCI", ...]}.',
      );
    }
    final index = source.index();
    final items = <Map<String, dynamic>>[];
    final missing = <String>[];
    for (final key in keys.cast<String>()) {
      final item = index?.items[key];
      if (item == null) {
        missing.add(key);
      } else {
        // Kontraknya: `id` sama dengan kunci, apa pun yang ditulis CslJson.
        // Dokumen menyimpan id ini sebagai identitas sitasi.
        items.add(<String, dynamic>{...CslJson.of(item), 'id': key});
      }
    }
    return <String, Object>{'items': items, 'missing': missing};
  }

  Future<Map<String, Object>> _annotations(String key) async {
    final item = source.index()?.items[key];
    if (item == null) {
      throw _ApiError(HttpStatus.notFound, 'Item $key tidak ada di library yang terbuka.');
    }
    final detail = await source.loadDetail(item);
    final annotations = <ZoteroAnnotation>[...detail.annotations]
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return <String, Object>{
      'annotations': <Map<String, Object>>[
        for (final a in annotations)
          <String, Object>{
            'key': a.key,
            'type': a.type.wire,
            'color': a.color,
            'text': a.text,
            'comment': a.comment,
            // PDF tanpa label halaman tetap punya nomor halaman, dan lokator
            // "12" jauh lebih berguna daripada lokator kosong.
            'pageLabel': a.pageLabel.isNotEmpty ? a.pageLabel : '${a.pageNumber}',
          },
      ],
    };
  }

  Future<CslCatalog> _loadCatalog() async =>
      _catalog ??= CslCatalog.parse(await source.loadAsset('styles.json'));

  Future<Map<String, Object>> _styles() async {
    final catalog = await _loadCatalog();
    return <String, Object>{
      'styles': <Map<String, Object?>>[
        for (final s in catalog.choices)
          <String, Object?>{
            'id': s.id,
            'title': s.title,
            'kind': s.kind,
            'format': s.format.isEmpty ? null : s.format,
            'parent': s.parent,
          },
      ],
    };
  }

  Future<String> _style(String id) async {
    final catalog = await _loadCatalog();
    if (catalog.byId(id) == null) {
      throw _ApiError(HttpStatus.notFound, 'Gaya "$id" tidak dibundel di ReadPaper.');
    }
    // citeproc-js tidak bisa merender gaya dependen; yang dikirim adalah
    // gaya yang benar-benar berisi aturannya.
    final resolved = catalog.resolve(id);
    if (resolved == null) {
      throw _ApiError(
        HttpStatus.internalServerError,
        'Gaya induk untuk "$id" tidak ikut dibundel.',
      );
    }
    return source.loadAsset(resolved.file);
  }

  Future<String> _locale(String tag) async {
    final catalog = await _loadCatalog();
    final wanted = tag.toLowerCase();
    String? match;
    for (final l in catalog.locales) {
      if (l.toLowerCase() == wanted) match = l;
    }
    // `id` atau `id-XX` masih lebih dekat ke `id-ID` daripada ke bahasa
    // Inggris.
    if (match == null) {
      final language = wanted.split('-').first;
      for (final l in catalog.locales) {
        if (l.toLowerCase().split('-').first == language) {
          match = l;
          break;
        }
      }
    }
    // Bukan 404: sitasi tanpa locale lebih buruk daripada sitasi berbahasa
    // Inggris.
    return source.loadAsset('locales/locales-${match ?? 'en-US'}.xml');
  }
}

/// Item yang cocok dengan [query], terbaik dan terbaru lebih dulu.
///
/// Setiap kata harus muncul di salah satu medan — judul, nama pengarang,
/// tahun, atau abstrak — supaya "mcclean 2018" menemukan paper McClean dari
/// 2018 dan bukan semua paper tahun 2018. Item yang judulnya memuat seluruh
/// teks pencarian naik ke atas: itulah yang biasanya dicari orang yang
/// mengetik di kotak sitasi.
List<ZoteroItem> searchItems(Iterable<ZoteroItem> items, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  int newestFirst(ZoteroItem a, ZoteroItem b) {
    final da = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byDate = db.compareTo(da);
    return byDate != 0 ? byDate : b.year.compareTo(a.year);
  }

  if (words.isEmpty) return items.toList()..sort(newestFirst);

  bool matches(ZoteroItem item, String word) {
    if (item.title.toLowerCase().contains(word)) return true;
    for (final c in item.creators) {
      if (c.toLowerCase().contains(word)) return true;
    }
    for (final c in item.creatorDetails) {
      if (c.display.toLowerCase().contains(word)) return true;
    }
    if (item.year.contains(word)) return true;
    return item.abstractNote.toLowerCase().contains(word);
  }

  final phrase = words.join(' ');
  final found = items.where((item) => words.every((w) => matches(item, w))).toList()
    ..sort((a, b) {
      final ta = a.title.toLowerCase().contains(phrase) ? 0 : 1;
      final tb = b.title.toLowerCase().contains(phrase) ? 0 : 1;
      return ta != tb ? ta - tb : newestFirst(a, b);
    });
  return found;
}

/// Ringkasan pengarang untuk daftar hasil, mis. "McClean, Boixo, Smelyanskiy
/// dkk.".
///
/// Hanya nama keluarga dan paling banyak tiga: daftar ini dibaca sekilas
/// sambil mengetik, dan nama lengkap dua belas pengarang hanya mendorong
/// judulnya keluar dari layar.
String creatorSummary(ZoteroItem item, {int max = 3}) {
  final details = item.creatorDetails;
  final authors = details.where((c) => c.creatorType == 'author').toList();
  final chosen = authors.isNotEmpty ? authors : details;
  final names = <String>[
    for (final c in chosen)
      if ((c.lastName.isNotEmpty ? c.lastName : c.name).trim().isNotEmpty)
        (c.lastName.isNotEmpty ? c.lastName : c.name).trim(),
  ];
  if (names.isEmpty) {
    for (final raw in item.creators) {
      final family = raw.split(',').first.trim();
      if (family.isNotEmpty) names.add(family);
    }
  }
  if (names.length <= max) return names.join(', ');
  return '${names.take(max).join(', ')} dkk.';
}
