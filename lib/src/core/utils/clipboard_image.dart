import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Gambar di papan klip sistem — "Salin gambar" di peramban, tangkapan
/// layar, atau berkas gambar yang disalin dari pengelola berkas.
///
/// Flutter hanya bisa membaca teks dari papan klip, jadi tiap platform
/// dibaca dengan caranya sendiri: Android lewat kanal ke `MainActivity`,
/// Linux lewat `wl-paste` atau `xclip`, Windows lewat PowerShell. Null bila
/// tidak ada gambar atau platformnya tidak bisa (iOS, macOS).
class ClipboardImage {
  const ClipboardImage._();

  static const MethodChannel _channel = MethodChannel('readpaper/berkas-masuk');

  static const List<String> _imageTypes = <String>[
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
    'image/bmp',
  ];

  static Future<Uint8List?> read() async {
    try {
      if (Platform.isAndroid) return await _channel.invokeMethod<Uint8List>('clipboardImage');
      if (Platform.isLinux) return await _linux();
      if (Platform.isWindows) return await _windows();
    } on Object {
      return null;
    }
    return null;
  }

  static Future<Uint8List?> _linux() async {
    final wayland = (Platform.environment['WAYLAND_DISPLAY'] ?? '').isNotEmpty;
    // wl-paste dulu di Wayland, xclip sebagai cadangan (XWayland ikut
    // menyediakan papan klip X11).
    for (final tool in wayland ? <String>['wl-paste', 'xclip'] : <String>['xclip', 'wl-paste']) {
      final types = await _run(
        tool,
        tool == 'wl-paste'
            ? <String>['--list-types']
            : <String>['-selection', 'clipboard', '-t', 'TARGETS', '-o'],
      );
      if (types == null) continue;
      final offered = utf8.decode(types, allowMalformed: true).split('\n').map((t) => t.trim());
      final type = _imageTypes.where(offered.contains).firstOrNull;
      if (type != null) {
        return _run(
          tool,
          tool == 'wl-paste'
              ? <String>['--no-newline', '--type', type]
              : <String>['-selection', 'clipboard', '-t', type, '-o'],
        );
      }
      // Berkas gambar yang disalin dari pengelola berkas.
      if (offered.contains('text/uri-list')) {
        final list = await _run(
          tool,
          tool == 'wl-paste'
              ? <String>['--no-newline', '--type', 'text/uri-list']
              : <String>['-selection', 'clipboard', '-t', 'text/uri-list', '-o'],
        );
        if (list != null) return _firstImageFile(utf8.decode(list, allowMalformed: true));
      }
      return null;
    }
    return null;
  }

  static Future<Uint8List?> _windows() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$i = [System.Windows.Forms.Clipboard]::GetImage()
if ($i -ne $null) {
  $m = New-Object System.IO.MemoryStream
  $i.Save($m, [System.Drawing.Imaging.ImageFormat]::Png)
  [Convert]::ToBase64String($m.ToArray())
  exit
}
$f = [System.Windows.Forms.Clipboard]::GetFileDropList()
if ($f.Count -gt 0) { 'FILE:' + $f[0] }
''';
    final out = await _run('powershell', <String>[
      '-NoProfile',
      '-STA',
      '-NonInteractive',
      '-Command',
      script,
    ]);
    if (out == null) return null;
    final text = utf8.decode(out, allowMalformed: true).trim();
    if (text.isEmpty) return null;
    if (text.startsWith('FILE:')) return _firstImageFile(text.substring(5));
    return base64Decode(text);
  }

  static Future<Uint8List?> _firstImageFile(String list) async {
    for (final line in const LineSplitter().convert(list)) {
      final entry = line.trim();
      if (entry.isEmpty || entry.startsWith('#')) continue;
      final path = entry.startsWith('file://') ? Uri.parse(entry).toFilePath() : entry;
      final lower = path.toLowerCase();
      if (!RegExp(r'\.(png|jpe?g|webp|gif|bmp)$').hasMatch(lower)) continue;
      final file = File(path);
      if (file.existsSync()) return file.readAsBytes();
    }
    return null;
  }

  static Future<Uint8List?> _run(String tool, List<String> args) async {
    try {
      final result = await Process.run(
        tool,
        args,
        stdoutEncoding: null,
      ).timeout(const Duration(seconds: 4));
      if (result.exitCode != 0) return null;
      final bytes = result.stdout as List<int>;
      return bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } on Object {
      return null;
    }
  }
}
