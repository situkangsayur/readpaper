import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/utils/zotero_key.dart';
import '../../domain/entities/zotero_annotation.dart';
import '../../domain/entities/zotero_collection.dart';
import 'zotero_fs_datasource.dart';
import 'zotero_json.dart';

/// Writes annotations back into the Zotero export.
///
/// Everything is written in the plugin's own format (tab indented, sorted
/// keys) so that a later **Import from GitHub** in Zotero picks the
/// annotations up and so that git diffs stay small.
class ZoteroWriter {
  const ZoteroWriter();

  /// Inserts or replaces [annotation] inside its item file.
  ///
  /// Returns the list of files that were touched, for the commit message.
  Future<List<String>> upsertAnnotation({
    required String itemFilePath,
    required String libraryDir,
    required ZoteroAnnotation annotation,
  }) async {
    final json = await _readItem(itemFilePath);
    final children = _children(json);

    final index = children.indexWhere(
      (c) => c is Map && c['itemType'] == 'annotation' && c['key'] == annotation.key,
    );
    final encoded = ZoteroJson.sortKeys(annotation.toJson()) as Map<String, Object?>;
    if (index >= 0) {
      children[index] = encoded;
    } else {
      children.add(encoded);
    }

    return _persist(json: json, itemFilePath: itemFilePath, libraryDir: libraryDir);
  }

  /// Removes the annotation with [annotationKey] from its item file.
  Future<List<String>> deleteAnnotation({
    required String itemFilePath,
    required String libraryDir,
    required String annotationKey,
  }) async {
    final json = await _readItem(itemFilePath);
    final children = _children(json);
    children.removeWhere(
      (c) => c is Map && c['itemType'] == 'annotation' && c['key'] == annotationKey,
    );
    return _persist(json: json, itemFilePath: itemFilePath, libraryDir: libraryDir);
  }

  /// Menghapus sebuah item beserta lampiran dan catatannya.
  ///
  /// Pasangan dari [createItemFromPdf]: begitu item bisa ditambahkan, ia
  /// harus bisa dicabut lagi — termasuk yang ditambahkan karena salah pencet.
  /// Yang dihapus hanya berkas milik item itu: berkas item, folder lampiran
  /// per kunci lampiran, dan catatan markdown-nya.
  Future<List<String>> deleteItem({
    required String libraryDir,
    required String itemFilePath,
  }) async {
    // Pagar yang sengaja galak. Yang dihapus di sini adalah berkas di dalam
    // repositori orang, dan satu jalur yang meleset berarti paper atau
    // daftar koleksi yang hilang. Jadi tempatnya diperiksa dulu: hanya
    // berkas item di dalam `items/` yang boleh disentuh, tidak akar library,
    // tidak `collections.json`, tidak folder lain.
    final itemsRoot = p.normalize(p.join(libraryDir, 'items'));
    final target = p.normalize(itemFilePath);
    if (!p.isWithin(itemsRoot, target) || p.extension(target) != '.json') {
      throw LibraryFailure(
        'Menolak menghapus: berkas ini bukan item di dalam items/',
        details: itemFilePath,
      );
    }

    final json = await _readItem(itemFilePath);
    final touched = <String>[itemFilePath];

    // Lampiran hidup di folder bernama kunci lampirannya, jadi seluruh
    // folder itu yang dibuang — bukan hanya berkasnya, supaya tidak ada
    // folder kosong yang tertinggal di dalam repositori.
    for (final child in _children(json)) {
      if (child is! Map) continue;
      if (child['itemType'] != 'attachment') continue;
      final key = child['key'] as String?;
      if (key == null || key.isEmpty) continue;
      final attachmentsRoot = p.normalize(p.join(libraryDir, 'attachments'));
      final dir = Directory(p.join(attachmentsRoot, ZoteroKey.bucket(key), key));
      // Kunci yang aneh — berisi `..` atau garis miring — tidak boleh
      // mengarahkan penghapusan ke luar folder lampiran.
      if (!p.isWithin(attachmentsRoot, p.normalize(dir.path))) continue;
      if (dir.existsSync()) {
        touched.add(dir.path);
        await dir.delete(recursive: true);
      }
    }

    final itemKey = ((json['zotero'] as Map?)?['key'] as String?) ?? '';
    if (itemKey.isNotEmpty) {
      final notePath = await findNoteFile(libraryDir, itemKey);
      if (notePath != null) {
        touched.add(notePath);
        await File(notePath).delete();
      }
    }

    await File(itemFilePath).delete();

    // Folder bucket yang jadi kosong ikut dibuang: `items/AB/` tanpa isi
    // hanya menambah kebisingan di dalam repositori.
    final bucket = File(itemFilePath).parent;
    if (p.isWithin(itemsRoot, p.normalize(bucket.path)) &&
        bucket.existsSync() &&
        bucket.listSync().isEmpty) {
      await bucket.delete();
    }
    return touched;
  }

  /// Membuat koleksi Zotero baru di `<library>/collections.json`.
  ///
  /// Ini satu-satunya tempat ReadPaper menulis berkas **struktur** Zotero, dan
  /// karena itu pagarnya rapat. Yang sudah ada tidak pernah diubah maupun
  /// diurutkan ulang: entri baru ditambahkan di ujung, dengan bentuk tulisan
  /// yang sama persis seperti yang dipakai plugin — array beridentasi tab,
  /// kunci terurut, `parentKey: null` untuk akar, `relations: {}`. Dengan
  /// begitu diff-nya hanya satu blok yang bertambah, dan impor di Zotero tetap
  /// menerimanya.
  ///
  /// Nama kembar di bawah induk yang sama ditolak: dua koleksi bernama sama di
  /// tempat yang sama hanya membuat yang memakainya salah pilih.
  Future<ZoteroCollection> createCollection({
    required String libraryDir,
    required String name,
    String? parentKey,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const LibraryFailure('Nama koleksi tidak boleh kosong');
    }
    if (trimmed.contains('/')) {
      // Garis miring adalah pemisah jalur koleksi di berkas ini; nama yang
      // memuatnya akan membuat jalurnya tidak bisa dibaca kembali.
      throw const LibraryFailure('Nama koleksi tidak boleh memuat garis miring');
    }

    final file = File(p.join(libraryDir, 'collections.json'));
    final existing = <Map<String, dynamic>>[];
    if (file.existsSync()) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        throw LibraryFailure(
          'collections.json tidak berisi daftar koleksi — menolak menulisinya',
          details: file.path,
        );
      }
      for (final entry in decoded) {
        if (entry is! Map) {
          throw LibraryFailure(
            'Ada entri di collections.json yang bukan koleksi — menolak menulisinya',
            details: file.path,
          );
        }
        existing.add(entry.cast<String, dynamic>());
      }
    }

    String? parentPath;
    if (parentKey != null) {
      final parent = existing.where((e) => e['key'] == parentKey).firstOrNull;
      if (parent == null) {
        throw LibraryFailure('Koleksi induk tidak ada', details: parentKey);
      }
      parentPath = (parent['path'] as String?) ?? (parent['name'] as String? ?? '');
    }

    final kembar = existing.any(
      (e) =>
          (e['parentKey'] as String?) == parentKey &&
          ((e['name'] as String?) ?? '').toLowerCase() == trimmed.toLowerCase(),
    );
    if (kembar) {
      throw LibraryFailure('Sudah ada koleksi bernama "$trimmed" di tempat yang sama');
    }

    final keys = <String>{for (final e in existing) (e['key'] as String?) ?? ''};
    var key = ZoteroKey.generate();
    for (var attempt = 0; keys.contains(key) && attempt < 32; attempt++) {
      key = ZoteroKey.generate();
    }
    if (keys.contains(key)) {
      throw const LibraryFailure('Gagal membuat kunci koleksi baru');
    }

    final created = ZoteroCollection(
      key: key,
      name: trimmed,
      path: parentPath == null || parentPath.isEmpty ? trimmed : '$parentPath/$trimmed',
      parentKey: parentKey,
    );

    final written = <Map<String, dynamic>>[
      ...existing,
      <String, dynamic>{
        'key': created.key,
        'name': created.name,
        'parentKey': created.parentKey,
        'path': created.path,
        'relations': <String, dynamic>{},
      },
    ];

    await file.writeAsString(
      '${_pretty.convert(ZoteroJson.sortKeys(written))}\n',
      flush: true,
    );
    return created;
  }

  static final JsonEncoder _pretty = JsonEncoder.withIndent('\t');

  /// Memindahkan sebuah item ke koleksi lain.
  ///
  /// Zotero menyimpan keanggotaan koleksi **di dalam berkas itemnya**, bukan di
  /// `collections.json` — dua tempat: kuncinya di `zotero.collections` dan
  /// jalur namanya di `meta.collections`. Keduanya harus ikut, karena yang
  /// pertama dipakai Zotero saat mengimpor dan yang kedua dipakai manusia yang
  /// membaca repositorinya.
  ///
  /// Daftar kosong berarti item tanpa koleksi, dan itu sah.
  Future<List<String>> setItemCollections({
    required String itemFilePath,
    required String libraryDir,
    required List<String> collectionKeys,
    required List<String> collectionPaths,
  }) async {
    final json = await _readItem(itemFilePath);

    final zotero = (json['zotero'] as Map?)?.cast<String, dynamic>();
    if (zotero == null) {
      throw LibraryFailure('Berkas item tidak punya bagian zotero', details: itemFilePath);
    }
    zotero['collections'] = <dynamic>[...collectionKeys];
    zotero['dateModified'] = _stamp(DateTime.now());

    final meta = (json['meta'] as Map?)?.cast<String, dynamic>();
    if (meta != null) meta['collections'] = <dynamic>[...collectionPaths];

    return _persist(json: json, itemFilePath: itemFilePath, libraryDir: libraryDir);
  }

  Future<Map<String, dynamic>> _readItem(String itemFilePath) async {
    final file = File(itemFilePath);
    if (!file.existsSync()) {
      throw LibraryFailure('Berkas item tidak ditemukan', details: itemFilePath);
    }
    return ZoteroJson.decodeObject(await file.readAsString());
  }

  List<dynamic> _children(Map<String, dynamic> json) {
    final existing = json['children'];
    if (existing is List) return existing;
    final created = <dynamic>[];
    json['children'] = created;
    return created;
  }

  Future<List<String>> _persist({
    required Map<String, dynamic> json,
    required String itemFilePath,
    required String libraryDir,
  }) async {
    final children = _children(json);
    children.sort((a, b) => _childKey(a).compareTo(_childKey(b)));

    final detail = buildItemDetail(json, itemFilePath);
    _refreshAnnotationCounts(json, detail.annotations);

    await File(itemFilePath).writeAsString(ZoteroJson.encodeFile(json), flush: true);
    final touched = <String>[itemFilePath];

    final notePath = await findNoteFile(libraryDir, detail.item.key);
    if (notePath != null) {
      final updated = await _rewriteNoteAnnotations(notePath, detail.annotations);
      if (updated) touched.add(notePath);
    }
    return touched;
  }

  /// The plugin writes `children` sorted by Zotero key, regardless of type.
  /// Matching that keeps an added annotation to a few added lines in the diff
  /// instead of rewriting the whole file.
  String _childKey(dynamic child) => child is Map ? (child['key'] as String? ?? '') : '';

  void _refreshAnnotationCounts(Map<String, dynamic> json, List<ZoteroAnnotation> annotations) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>();
    if (meta == null) return;
    final attachments = meta['attachments'];
    if (attachments is! List) return;
    for (final entry in attachments) {
      if (entry is! Map) continue;
      final key = entry['key'] as String?;
      if (key == null) continue;
      entry['annotationCount'] = annotations.where((a) => a.parentItemKey == key).length;
    }
  }

  /// Membuat item baru dari sebuah berkas PDF, lengkap dengan lampirannya.
  ///
  /// Inilah yang membuat "tambahkan ke koleksi" mungkin: PDF yang dibuka
  /// lepas — formulir yang ditandatangani, catatan rapat, paper yang dikirim
  /// lewat pesan — bisa masuk ke library dan ikut tersinkron.
  ///
  /// Formatnya mengikuti tulisan `zotero-github-sync` persis: berkas item di
  /// `items/<XX>/<KEY>.json`, lampiran di `attachments/<XX>/<KEY>/<berkas>`,
  /// dan catatan di `notes/<X>/<judul> (KEY).md`. Yang ditulis di sini harus
  /// bisa dibaca kembali oleh Zotero, jadi tidak ada satu pun bidang yang
  /// ditambahkan sendiri.
  Future<CreatedItem> createItemFromPdf({
    required String libraryDir,
    required String libraryName,
    required int libraryId,
    required String pdfPath,
    required String title,
    String? collectionKey,
    String? collectionPath,
    DateTime? now,
  }) async {
    final source = File(pdfPath);
    if (!source.existsSync()) {
      throw LibraryFailure('Berkas PDF tidak ditemukan', details: pdfPath);
    }

    final moment = now ?? DateTime.now();
    final itemKey = ZoteroKey.generate();
    final attachmentKey = ZoteroKey.generate();
    final stamp = _stamp(moment);
    final filename = p.basename(pdfPath);

    // Lampirannya disalin lebih dulu: kalau penyalinan gagal, tidak ada item
    // setengah jadi yang menunjuk ke berkas yang tidak ada.
    final relativeAttachment = <String>[
      'attachments',
      ZoteroKey.bucket(attachmentKey),
      attachmentKey,
      filename,
    ].join('/');
    final attachmentFile = File(p.join(libraryDir, relativeAttachment));
    await attachmentFile.parent.create(recursive: true);
    await source.copy(attachmentFile.path);
    final size = await attachmentFile.length();

    final json = <String, dynamic>{
      'children': <dynamic>[
        <String, dynamic>{
          'charset': '',
          'contentType': 'application/pdf',
          'dateAdded': stamp,
          'dateModified': stamp,
          'filename': filename,
          'itemType': 'attachment',
          'key': attachmentKey,
          'linkMode': 'imported_file',
          'parentItem': itemKey,
          'relations': <String, dynamic>{},
          'tags': <dynamic>[],
          'title': 'PDF',
        },
      ],
      'meta': <String, dynamic>{
        'attachments': <dynamic>[
          <String, dynamic>{
            'annotationCount': 0,
            'contentType': 'application/pdf',
            'filename': filename,
            'files': <dynamic>[
              <String, dynamic>{'path': relativeAttachment, 'size': size, 'storage': 'git'},
            ],
            'key': attachmentKey,
            'linkMode': 'imported_file',
            'status': 'ok',
            'title': 'PDF',
            'url': null,
          },
        ],
        'collections': <dynamic>[
          if (collectionPath != null && collectionPath.isNotEmpty) collectionPath,
        ],
        'creators': <dynamic>[],
        'itemType': 'document',
        'libraryID': libraryId,
        'libraryName': libraryName,
        'notes': <dynamic>[],
        'title': title,
        'year': '${moment.year}',
        'zoteroURI': 'zotero://select/library/items/$itemKey',
      },
      'zotero': <String, dynamic>{
        'accessDate': stamp,
        'collections': <dynamic>[
          if (collectionKey != null && collectionKey.isNotEmpty) collectionKey,
        ],
        'creators': <dynamic>[],
        'dateAdded': stamp,
        'dateModified': stamp,
        'itemType': 'document',
        'key': itemKey,
        'relations': <String, dynamic>{},
        'tags': <dynamic>[],
        'title': title,
      },
    };

    final itemPath = p.join(libraryDir, 'items', ZoteroKey.bucket(itemKey), '$itemKey.json');
    final itemFile = File(itemPath);
    await itemFile.parent.create(recursive: true);
    await itemFile.writeAsString(ZoteroJson.encodeFile(json), flush: true);

    final notePath = await _writeNote(
      libraryDir: libraryDir,
      itemKey: itemKey,
      title: title,
      relativeAttachment: relativeAttachment,
      filename: filename,
    );

    return CreatedItem(
      itemKey: itemKey,
      attachmentKey: attachmentKey,
      itemFilePath: itemPath,
      attachmentPath: attachmentFile.path,
      touchedFiles: <String>[itemPath, attachmentFile.path, ?notePath],
    );
  }

  /// Catatan markdown pendamping, seperti yang ditulis plugin.
  Future<String?> _writeNote({
    required String libraryDir,
    required String itemKey,
    required String title,
    required String relativeAttachment,
    required String filename,
  }) async {
    final notesDir = Directory(p.join(libraryDir, 'notes'));
    // Kalau library ini memang tidak memakai catatan, jangan memulai
    // kebiasaan baru yang tidak diminta siapa pun.
    if (!notesDir.existsSync()) return null;

    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
    final bucket = safeTitle.isEmpty ? '_' : safeTitle[0].toUpperCase();
    final path = p.join(notesDir.path, bucket, '$safeTitle ($itemKey).md');
    final file = File(path);
    await file.parent.create(recursive: true);

    final depth = p.split(p.relative(file.parent.path, from: libraryDir)).length;
    final back = List<String>.filled(depth, '..').join('/');
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('title: "$safeTitle"')
      ..writeln('zotero-key: "$itemKey"')
      ..writeln('---')
      ..writeln()
      ..writeln('# $safeTitle')
      ..writeln()
      ..writeln('## Attachments')
      ..writeln()
      ..writeln('- [$filename]($back/$relativeAttachment)')
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln('[Open in Zotero](zotero://select/library/items/$itemKey)');
    await file.writeAsString(buffer.toString(), flush: true);
    return path;
  }

  /// Cap waktu dalam bentuk yang dipakai Zotero: UTC, tanpa pecahan detik.
  static String _stamp(DateTime when) => '${when.toUtc().toIso8601String().split('.').first}Z';

  /// Locates `notes/<bucket>/<title> (KEY).md` for an item key.
  Future<String?> findNoteFile(String libraryDir, String itemKey) async {
    final notesDir = Directory(p.join(libraryDir, 'notes'));
    if (!notesDir.existsSync()) return null;
    final suffix = '($itemKey).md';
    for (final entity in notesDir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith(suffix)) return entity.path;
    }
    return null;
  }

  /// Replaces the `## Annotations` section of a note markdown file.
  Future<bool> _rewriteNoteAnnotations(String notePath, List<ZoteroAnnotation> annotations) async {
    final file = File(notePath);
    final original = await file.readAsString();
    final rendered = renderAnnotationsSection(annotations);

    final lines = original.split('\n');
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimRight() == '## Annotations') {
        start = i;
        break;
      }
    }

    String updated;
    if (start >= 0) {
      var end = lines.length;
      for (var i = start + 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.startsWith('## ') || line == '---') {
          end = i;
          break;
        }
      }
      final rebuilt = <String>[...lines.sublist(0, start), ...rendered, ...lines.sublist(end)];
      updated = rebuilt.join('\n');
    } else if (rendered.isEmpty) {
      return false;
    } else {
      // Insert before the trailing `---` / "Open in Zotero" footer when present.
      var insertAt = lines.length;
      for (var i = lines.length - 1; i >= 0; i--) {
        if (lines[i].trimRight() == '---') {
          insertAt = i;
          break;
        }
      }
      updated = <String>[
        ...lines.sublist(0, insertAt),
        ...rendered,
        ...lines.sublist(insertAt),
      ].join('\n');
    }

    if (updated == original) return false;
    await file.writeAsString(updated, flush: true);
    return true;
  }

  /// Renders the markdown block the plugin writes for annotations.
  static List<String> renderAnnotationsSection(List<ZoteroAnnotation> annotations) {
    if (annotations.isEmpty) return const <String>[];
    final lines = <String>['## Annotations', ''];
    for (final annotation in annotations) {
      final page = annotation.pageLabel.isNotEmpty
          ? annotation.pageLabel
          : '${annotation.pageIndex + 1}';
      final head = '- **p. $page, ${annotation.type.wire}**';
      // The quoted text is written verbatim: the plugin keeps the double
      // spaces that come out of the PDF's text layer, and normalising them
      // here would rewrite every existing line on the next save.
      if (annotation.text.isNotEmpty) {
        lines.add('$head “${annotation.text}”');
      } else {
        lines.add(head);
      }
      final comment = _oneLine(annotation.comment);
      if (comment.isNotEmpty) lines.add('  $comment');
    }
    lines.add('');
    return lines;
  }

  /// A comment always lands on a single line: its lines are trimmed and joined
  /// with a space, the way the plugin writes them.
  static String _oneLine(String value) =>
      value.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).join(' ');
}

/// Builds a human readable commit message for an annotation change.
String annotationCommitMessage({
  required String action,
  required String itemTitle,
  required ZoteroAnnotation annotation,
}) {
  final page = annotation.pageLabel.isNotEmpty
      ? annotation.pageLabel
      : '${annotation.pageIndex + 1}';
  final title = itemTitle.length > 60 ? '${itemTitle.substring(0, 57)}...' : itemTitle;
  return '$action ${annotation.type.wire} p.$page — $title\n\n'
      'ReadPaper ${zoteroTimestamp()}';
}

/// Item yang baru dibuat, beserta berkas yang tersentuh.
class CreatedItem {
  const CreatedItem({
    required this.itemKey,
    required this.attachmentKey,
    required this.itemFilePath,
    required this.attachmentPath,
    required this.touchedFiles,
  });

  final String itemKey;
  final String attachmentKey;
  final String itemFilePath;
  final String attachmentPath;

  /// Untuk pesan commit, dan untuk memastikan semuanya ikut terdorong.
  final List<String> touchedFiles;
}
