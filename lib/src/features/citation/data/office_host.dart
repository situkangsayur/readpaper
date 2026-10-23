import 'dart:convert';

import 'js_engine.dart';

/// Jawaban sebuah "fetch" dari dalam mesin JavaScript.
typedef HostResponse = ({int status, String body});

/// Menjawab permintaan inti sitasi ke `/api/...` tanpa lewat jaringan.
/// Serempak: JavaScript menunggunya seperti fungsi biasa.
typedef HostFetch = HostResponse Function(String method, String path, Object? body);

/// Menjalankan perintah sitasi untuk editor tanpa mesin JavaScript sendiri.
///
/// Isinya kode yang SAMA dengan panel Word dan OnlyOffice —
/// `integrations/core/` — ditambah `host.js` yang menjalankannya di atas
/// potret dokumen. Ekstensi LibreOffice mengirim potret itu ke
/// `POST /api/run`, dan daftar perubahan yang kembali ditulisnya ke dokumen.
/// Jadi sitasi dan daftar pustaka di LibreOffice sama persis dengan di Word,
/// sampai ke satu karakter, karena memang mesin yang sama yang menulisnya.
///
/// Satu mesin dipakai ulang selama ReadPaper hidup: membangun citeproc untuk
/// sebuah gaya mahal, merender dengannya murah.
class OfficeHost {
  OfficeHost._(this._engine);

  /// Urutan muat; `polyfill.js` menyediakan yang biasanya diberikan peramban.
  static const List<String> scripts = <String>[
    'polyfill.js',
    'vendor/citeproc.js',
    'citations.js',
    'readpaper-api.js',
    'controller.js',
    'host.js',
  ];

  final JsEngine _engine;

  String get engineName => _engine.description;

  /// Null kalau tidak ada mesin JavaScript yang bisa dimuat di sistem ini.
  ///
  /// [loadScript] membaca berkas di bawah `integrations/core/`.
  static Future<OfficeHost?> start({
    required Future<String> Function(String path) loadScript,
    required HostFetch fetch,
    JsEngine? Function() openEngine = JsEngine.open,
  }) async {
    final sources = <String, String>{for (final s in scripts) s: await loadScript(s)};
    final engine = openEngine();
    if (engine == null) return null;
    try {
      engine.defineFunction('__rpFetch', (args) {
        final req = jsonDecode(args.isEmpty ? '{}' : args.first) as Map<String, dynamic>;
        final url = Uri.parse(req['url'] as String? ?? '');
        final raw = req['body'];
        final r = fetch(
          (req['method'] as String? ?? 'GET').toUpperCase(),
          url.path,
          raw is String ? jsonDecode(raw) : null,
        );
        return jsonEncode(<String, Object>{'status': r.status, 'body': r.body});
      });
      for (final s in scripts) {
        engine.eval(sources[s]!, name: s);
      }
      engine.eval(_boot, name: 'boot.js');
    } catch (_) {
      engine.dispose();
      rethrow;
    }
    return OfficeHost._(engine);
  }

  static const String _boot = r'''
var __rpHost = new ReadPaperHost.Host({
  fetch: function (url, init) {
    var r = JSON.parse(__rpFetch(JSON.stringify({ url: url, method: init.method, body: init.body || null })));
    return Promise.resolve({
      ok: r.status >= 200 && r.status < 300,
      status: r.status,
      text: function () { return Promise.resolve(r.body); },
      json: function () { return Promise.resolve(JSON.parse(r.body)); },
    });
  },
});
'ok';
''';

  /// Satu perintah: `{command, args, doc}` → `{ok, result, changes}` atau
  /// `{ok: false, error}`. Lihat `integrations/core/host.js`.
  Map<String, dynamic> run(Map<String, dynamic> request) {
    final id = _engine.eval('__rpHost.start(${jsonEncode(jsonEncode(request))})', name: 'run.js');
    // JavaScriptCore menjalankan antrean job sebelum eval kembali, dan semua
    // fetch-nya serempak, jadi perintahnya sudah selesai di sini.
    final out = _engine.eval('__rpHost.take(${jsonEncode(id)})', name: 'take.js');
    if (out == 'null' || out.isEmpty) {
      return <String, dynamic>{
        'ok': false,
        'error': 'Perintah tidak selesai di dalam mesin sitasi.',
      };
    }
    return jsonDecode(out) as Map<String, dynamic>;
  }

  void dispose() => _engine.dispose();
}
