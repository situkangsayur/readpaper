import 'dart:math';

/// Generates Zotero-compatible object keys.
///
/// Zotero keys are 8 characters drawn from a base32 alphabet that omits the
/// ambiguous characters `0`, `1`, `O` and `8`.
class ZoteroKey {
  const ZoteroKey._();

  static const String _alphabet = '23456789ABCDEFGHIJKLMNPQRSTUVWXYZ';
  static final Random _random = Random.secure();

  static String generate() {
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Two-character bucket Zotero's GitHub export uses for `items/<XX>/<KEY>.json`.
  static String bucket(String key) => key.length >= 2 ? key.substring(0, 2) : key.padRight(2, '_');

  static bool isValid(String key) =>
      key.length == 8 && key.split('').every((c) => _alphabet.contains(c));
}
