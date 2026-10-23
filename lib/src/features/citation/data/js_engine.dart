import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Mesin JavaScript yang menjalankan citeproc-js di dalam ReadPaper, untuk
/// editor yang tidak punya mesin sendiri (LibreOffice).
///
/// JavaScriptCore, lewat API C-nya, bukan paket pub: dari semua mesin yang
/// bisa dimuat dari Dart hanya ia yang punya JIT. Itu bukan soal selera —
/// membangun mesin citeproc untuk APA makan ±1 detik di JavaScriptCore dan di
/// V8, tetapi 26 detik di QuickJS, karena citeproc menjabarkan setiap makro di
/// setiap tempat ia dipakai dan APA punya ratusan. Dua puluh enam detik
/// menunggu satu sitasi melanggar aturan 2 dengan telak.
///
/// Di Linux ia datang bersama WebKitGTK (`libjavascriptcoregtk`), di macOS ia
/// bagian dari sistem. Kalau tidak ada, [JsEngine.open] mengembalikan null dan
/// yang memanggil menjelaskan apa yang harus dipasang.
abstract interface class JsEngine {
  /// Mesin pertama yang bisa dimuat di sistem ini, atau null.
  static JsEngine? open() => JscEngine.open();

  /// Nama mesin yang tersedia, atau null — untuk pengaturan. Diperiksa
  /// sekali; memasang pustakanya baru terlihat setelah ReadPaper dibuka ulang.
  static final String? availableName = () {
    final e = open();
    final name = e?.description;
    e?.dispose();
    return name;
  }();

  /// Menjalankan [code] dan mengembalikan nilainya sebagai string. Galat
  /// JavaScript dilempar sebagai [JsException]. Job Promise yang dibuat
  /// [code] sudah selesai ketika fungsi ini kembali.
  String eval(String code, {String name});

  /// Fungsi global [name] yang memanggil [handler] dengan argumen-argumennya
  /// sebagai string dan mengembalikan string yang diberikannya — serempak,
  /// jadi JavaScript bisa memakainya seperti fungsi biasa.
  void defineFunction(String name, String Function(List<String> args) handler);

  /// Nama pustakanya, untuk ditampilkan di pengaturan.
  String get description;

  void dispose();
}

class JsException implements Exception {
  const JsException(this.message);

  final String message;

  @override
  String toString() => 'JsException: $message';
}

// ------------------------------------------------------------- JavaScriptCore

typedef _Ctx = Pointer<Void>;
typedef _Val = Pointer<Void>;
typedef _Str = Pointer<Void>;

typedef _CallbackNative =
    _Val Function(
      _Ctx ctx,
      Pointer<Void> fn,
      Pointer<Void> self,
      Size argc,
      Pointer<_Val> argv,
      Pointer<_Val> exc,
    );

class _Jsc {
  _Jsc(this.lib)
    : contextCreate = lib
          .lookupFunction<_Ctx Function(Pointer<Void>), _Ctx Function(Pointer<Void>)>(
            'JSGlobalContextCreate',
          ),
      contextRelease = lib.lookupFunction<Void Function(_Ctx), void Function(_Ctx)>(
        'JSGlobalContextRelease',
      ),
      globalObject = lib.lookupFunction<Pointer<Void> Function(_Ctx), Pointer<Void> Function(_Ctx)>(
        'JSContextGetGlobalObject',
      ),
      stringCreate = lib.lookupFunction<_Str Function(Pointer<Utf8>), _Str Function(Pointer<Utf8>)>(
        'JSStringCreateWithUTF8CString',
      ),
      stringRelease = lib.lookupFunction<Void Function(_Str), void Function(_Str)>(
        'JSStringRelease',
      ),
      stringMaxSize = lib.lookupFunction<Size Function(_Str), int Function(_Str)>(
        'JSStringGetMaximumUTF8CStringSize',
      ),
      stringToUtf8 = lib
          .lookupFunction<
            Size Function(_Str, Pointer<Utf8>, Size),
            int Function(_Str, Pointer<Utf8>, int)
          >('JSStringGetUTF8CString'),
      evaluate = lib
          .lookupFunction<
            _Val Function(_Ctx, _Str, Pointer<Void>, _Str, Int32, Pointer<_Val>),
            _Val Function(_Ctx, _Str, Pointer<Void>, _Str, int, Pointer<_Val>)
          >('JSEvaluateScript'),
      toStringCopy = lib
          .lookupFunction<
            _Str Function(_Ctx, _Val, Pointer<_Val>),
            _Str Function(_Ctx, _Val, Pointer<_Val>)
          >('JSValueToStringCopy'),
      makeString = lib.lookupFunction<_Val Function(_Ctx, _Str), _Val Function(_Ctx, _Str)>(
        'JSValueMakeString',
      ),
      makeFunction = lib
          .lookupFunction<
            Pointer<Void> Function(_Ctx, _Str, Pointer<NativeFunction<_CallbackNative>>),
            Pointer<Void> Function(_Ctx, _Str, Pointer<NativeFunction<_CallbackNative>>)
          >('JSObjectMakeFunctionWithCallback'),
      setProperty = lib
          .lookupFunction<
            Void Function(_Ctx, Pointer<Void>, _Str, _Val, Uint32, Pointer<_Val>),
            void Function(_Ctx, Pointer<Void>, _Str, _Val, int, Pointer<_Val>)
          >('JSObjectSetProperty');

  final DynamicLibrary lib;
  final _Ctx Function(Pointer<Void>) contextCreate;
  final void Function(_Ctx) contextRelease;
  final Pointer<Void> Function(_Ctx) globalObject;
  final _Str Function(Pointer<Utf8>) stringCreate;
  final void Function(_Str) stringRelease;
  final int Function(_Str) stringMaxSize;
  final int Function(_Str, Pointer<Utf8>, int) stringToUtf8;
  final _Val Function(_Ctx, _Str, Pointer<Void>, _Str, int, Pointer<_Val>) evaluate;
  final _Str Function(_Ctx, _Val, Pointer<_Val>) toStringCopy;
  final _Val Function(_Ctx, _Str) makeString;
  final Pointer<Void> Function(_Ctx, _Str, Pointer<NativeFunction<_CallbackNative>>) makeFunction;
  final void Function(_Ctx, Pointer<Void>, _Str, _Val, int, Pointer<_Val>) setProperty;

  _Str string(String s) {
    final p = s.toNativeUtf8();
    try {
      return stringCreate(p);
    } finally {
      malloc.free(p);
    }
  }

  String read(_Str s) {
    final size = stringMaxSize(s);
    final buf = malloc<Uint8>(size).cast<Utf8>();
    try {
      final n = stringToUtf8(s, buf, size);
      // n menghitung NUL penutup.
      return n <= 1 ? '' : buf.toDartString(length: n - 1);
    } finally {
      malloc.free(buf);
    }
  }

  String valueToString(_Ctx ctx, _Val v) {
    final s = toStringCopy(ctx, v, nullptr);
    if (s == nullptr) return '';
    try {
      return read(s);
    } finally {
      stringRelease(s);
    }
  }
}

/// Satu konteks global JavaScriptCore.
///
/// Fungsi dari [defineFunction] dipanggil lewat satu callback C yang sama;
/// karena callback FFI tidak membawa data, konteks yang hidup dicari di peta
/// statis [_live].
class JscEngine implements JsEngine {
  JscEngine._(this._jsc, this._ctx, this.description);

  static final Map<int, JscEngine> _live = <int, JscEngine>{};

  /// Dicoba berurutan: versi yang dipakai GTK 4 dan GTK 3 di distribusi saat
  /// ini, lalu nama lama. Nama berkas tanpa nomor versi (`.so`) hanya ada
  /// kalau paket -dev terpasang, jadi tidak bisa diandalkan.
  static const List<String> linuxLibraries = <String>[
    'libjavascriptcoregtk-4.1.so.0',
    'libjavascriptcoregtk-6.0.so.1',
    'libjavascriptcoregtk-4.0.so.18',
  ];

  static const String macLibrary =
      '/System/Library/Frameworks/JavaScriptCore.framework/JavaScriptCore';

  static JscEngine? open() {
    final candidates = Platform.isLinux
        ? linuxLibraries
        : Platform.isMacOS
        ? const <String>[macLibrary]
        : const <String>[];
    for (final name in candidates) {
      DynamicLibrary lib;
      try {
        lib = DynamicLibrary.open(name);
      } on ArgumentError {
        continue;
      }
      final jsc = _Jsc(lib);
      final ctx = jsc.contextCreate(nullptr);
      if (ctx == nullptr) continue;
      final engine = JscEngine._(jsc, ctx, 'JavaScriptCore ($name)');
      _live[ctx.address] = engine;
      return engine;
    }
    return null;
  }

  final _Jsc _jsc;
  _Ctx _ctx;
  final Map<int, String Function(List<String>)> _functions = <int, String Function(List<String>)>{};

  @override
  final String description;

  static final Pointer<NativeFunction<_CallbackNative>> _callback =
      Pointer.fromFunction<_CallbackNative>(_dispatch);

  static _Val _dispatch(
    _Ctx ctx,
    Pointer<Void> fn,
    Pointer<Void> self,
    int argc,
    Pointer<_Val> argv,
    Pointer<_Val> exc,
  ) {
    // Konteks yang diterima callback bisa berupa konteks eksekusi, bukan
    // konteks global yang dibuat; fungsinya dicari menurut alamat objeknya.
    for (final engine in _live.values) {
      final handler = engine._functions[fn.address];
      if (handler == null) continue;
      final jsc = engine._jsc;
      String out;
      try {
        out = handler(<String>[for (var i = 0; i < argc; i++) jsc.valueToString(ctx, argv[i])]);
      } catch (e) {
        final msg = jsc.string('ReadPaper: $e');
        exc.value = jsc.makeString(ctx, msg);
        jsc.stringRelease(msg);
        return nullptr;
      }
      final s = jsc.string(out);
      try {
        return jsc.makeString(ctx, s);
      } finally {
        jsc.stringRelease(s);
      }
    }
    return nullptr;
  }

  void _check() {
    if (_ctx == nullptr) throw StateError('Mesin JavaScript sudah ditutup.');
  }

  @override
  String eval(String code, {String name = '<eval>'}) {
    _check();
    final jsc = _jsc;
    final script = jsc.string(code);
    final url = jsc.string(name);
    final exc = calloc<_Val>();
    try {
      final v = jsc.evaluate(_ctx, script, nullptr, url, 1, exc);
      if (exc.value != nullptr) throw JsException(jsc.valueToString(_ctx, exc.value));
      return v == nullptr ? '' : jsc.valueToString(_ctx, v);
    } finally {
      calloc.free(exc);
      jsc.stringRelease(script);
      jsc.stringRelease(url);
    }
  }

  @override
  void defineFunction(String name, String Function(List<String> args) handler) {
    _check();
    final jsc = _jsc;
    final n = jsc.string(name);
    try {
      final fn = jsc.makeFunction(_ctx, n, _callback);
      _functions[fn.address] = handler;
      jsc.setProperty(_ctx, jsc.globalObject(_ctx), n, fn, 0, nullptr);
    } finally {
      jsc.stringRelease(n);
    }
  }

  @override
  void dispose() {
    if (_ctx == nullptr) return;
    _live.remove(_ctx.address);
    _functions.clear();
    _jsc.contextRelease(_ctx);
    _ctx = nullptr;
  }
}
