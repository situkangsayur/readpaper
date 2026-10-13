import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Berkas Office Open XML (`.docx`, `.pptx`): zip berisi XML yang saling
/// merujuk lewat berkas relasi `_rels/*.rels`.
class OoxmlPackage {
  OoxmlPackage(Uint8List bytes) : _archive = ZipDecoder().decodeBytes(bytes);

  final Archive _archive;
  final Map<String, Map<String, String>> _relsCache = <String, Map<String, String>>{};

  Uint8List? bytes(String path) {
    final file = _archive.findFile(path);
    if (file == null) return null;
    return Uint8List.fromList(file.content as List<int>);
  }

  XmlDocument? xml(String path) {
    final data = bytes(path);
    if (data == null) return null;
    return XmlDocument.parse(utf8.decode(data, allowMalformed: true));
  }

  /// Relasi milik [part]: id → jalur bagian yang dirujuk (di dalam zip).
  /// Tautan keluar (`TargetMode="External"`) dibiarkan apa adanya.
  Map<String, String> rels(String part) => _relsCache.putIfAbsent(part, () {
    final dir = p.posix.dirname(part);
    final doc = xml(p.posix.join(dir, '_rels', '${p.posix.basename(part)}.rels'));
    final out = <String, String>{};
    if (doc == null) return out;
    for (final rel in doc.findAllElements('Relationship')) {
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      if (id == null || target == null) continue;
      if (rel.getAttribute('TargetMode') == 'External') {
        out[id] = target;
      } else if (target.startsWith('/')) {
        out[id] = target.substring(1);
      } else {
        out[id] = p.posix.normalize(p.posix.join(dir, target));
      }
    }
    return out;
  });

  /// Bagian pertama yang dirujuk [part] dengan tipe relasi berakhiran [type]
  /// (mis. `slideLayout`, `notesSlide`).
  String? relOfType(String part, String type) {
    final dir = p.posix.dirname(part);
    final doc = xml(p.posix.join(dir, '_rels', '${p.posix.basename(part)}.rels'));
    if (doc == null) return null;
    for (final rel in doc.findAllElements('Relationship')) {
      if ((rel.getAttribute('Type') ?? '').endsWith('/$type')) {
        return rels(part)[rel.getAttribute('Id')];
      }
    }
    return null;
  }
}

/// Atribut berawalan namespace, mis. `r:embed` atau `r:id`, tanpa peduli
/// awalan yang dipakai berkasnya.
String? attr(XmlElement e, String local) =>
    e.attributes.where((a) => a.name.local == local).map((a) => a.value).firstOrNull;

XmlElement? child(XmlElement? e, String local) {
  if (e == null) return null;
  for (final c in e.childElements) {
    if (c.name.local == local) return c;
  }
  return null;
}

Iterable<XmlElement> children(XmlElement? e, String local) =>
    e == null ? const <XmlElement>[] : e.childElements.where((c) => c.name.local == local);

/// Turunan pertama bernama [local], di kedalaman berapa pun.
XmlElement? descendant(XmlElement? e, String local) {
  if (e == null) return null;
  for (final d in e.descendantElements) {
    if (d.name.local == local) return d;
  }
  return null;
}

/// `FF0000` → warna; null untuk `auto` atau nilai rusak.
Color? hexColor(String? hex) {
  if (hex == null || hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Atribut boolean OOXML: hadir tanpa nilai berarti benar.
bool onOff(XmlElement? e) {
  if (e == null) return false;
  final value = attr(e, 'val');
  return value == null || !(value == '0' || value == 'false' || value == 'off');
}

/// EMU (English Metric Unit) ke poin.
double emuToPt(num emu) => emu / 12700;

/// Atribut `val` milik [e] — bentuk paling umum nilai di OOXML.
String? val(XmlElement? e) => e == null ? null : attr(e, 'val');

/// Semua turunan bernama [local], di kedalaman berapa pun.
Iterable<XmlElement> all(XmlNode node, String local) =>
    node.descendantElements.where((e) => e.name.local == local);

/// Rujukan relasi (`r:id`, `r:embed`): atribut di namespace relasi, bukan
/// atribut tanpa awalan bernama sama — `<p:sldId id="256" r:id="rId7"/>`.
String? relId(XmlElement e, [String local = 'id']) => e.attributes
    .where(
      (a) =>
          a.name.local == local &&
          ((a.name.namespaceUri ?? '').endsWith('/relationships') || a.name.prefix == 'r'),
    )
    .map((a) => a.value)
    .firstOrNull;
