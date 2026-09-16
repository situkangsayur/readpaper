import 'dart:collection';
import 'dart:convert';

/// Encodes JSON exactly the way `zotero-github-sync` writes it:
/// tab indentation, keys sorted alphabetically, trailing newline.
///
/// Matching the plugin byte-for-byte keeps git diffs limited to what actually
/// changed, which matters because every annotation edit is committed.
class ZoteroJson {
  const ZoteroJson._();

  static final JsonEncoder _pretty = JsonEncoder.withIndent('\t');

  /// Pretty form used for the files the plugin writes.
  static String encodeFile(Map<String, dynamic> value) => '${_pretty.convert(sortKeys(value))}\n';

  /// Compact form used for embedded strings such as `annotationPosition`.
  static String encodeCompact(Object? value) => jsonEncode(value);

  /// Recursively replaces every map with a key-sorted copy.
  static Object? sortKeys(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted[entry.key.toString()] = sortKeys(entry.value);
      }
      return sorted;
    }
    if (value is List) {
      return value.map(sortKeys).toList();
    }
    return value;
  }

  static Map<String, dynamic> decodeObject(String source) =>
      (jsonDecode(source) as Map).cast<String, dynamic>();

  static List<dynamic> decodeArray(String source) => jsonDecode(source) as List<dynamic>;
}
