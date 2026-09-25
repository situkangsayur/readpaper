import '../constants/app_constants.dart';
import 'package:flutter/material.dart';

/// Parses a `#rrggbb` string into a [Color]; falls back to the Zotero yellow.
Color colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return colorFromHex(AnnotationPalette.yellow);
  var value = hex.replaceFirst('#', '').trim();
  if (value.length == 3) {
    value = value.split('').map((c) => '$c$c').join();
  }
  if (value.length == 6) value = 'ff$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return const Color(0xffffd400);
  return Color(parsed);
}

/// Renders a [Color] back into the `#rrggbb` form Zotero stores.
String hexFromColor(Color color) {
  String two(double channel) => ((channel * 255).round() & 0xff).toRadixString(16).padLeft(2, '0');
  return '#${two(color.r)}${two(color.g)}${two(color.b)}';
}

/// Zotero timestamps are UTC `yyyy-MM-ddTHH:mm:ssZ`.
String zoteroTimestamp([DateTime? time]) {
  final t = (time ?? DateTime.now()).toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}Z';
}

/// Timestamp format used inside the note markdown front matter.
String noteTimestamp(DateTime time) {
  final t = time.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

DateTime? parseZoteroTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

/// Shortens a creator list the way Zotero's item list does.
String formatCreators(List<String> creators) {
  if (creators.isEmpty) return '';
  if (creators.length == 1) return creators.first;
  if (creators.length == 2) return '${creators.first}; ${creators[1]}';
  return '${creators.first} et al.';
}

String humanFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

/// How long ago something happened, in words.
///
/// Reading history is glanced at, not studied — "2 jam lalu" answers the
/// question faster than a timestamp does, and the exact minute never matters.
String relativeTime(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.isNegative) return 'baru saja';
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'kemarin';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} pekan lalu';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} bulan lalu';
  return '${(diff.inDays / 365).floor()} tahun lalu';
}
