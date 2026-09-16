import 'package:meta/meta.dart';

import '../../../../core/utils/formatting.dart';
import 'zotero_annotation.dart';

/// Where an attachment's bytes live inside the repository.
enum AttachmentStorage { git, lfs, missing }

/// A file attached to an item (normally the PDF or EPUB of the paper).
@immutable
class ZoteroAttachment {
  const ZoteroAttachment({
    required this.key,
    required this.parentItemKey,
    required this.title,
    this.filename = '',
    this.contentType = '',
    this.linkMode = '',
    this.url,
    this.relativePath,
    this.storage = AttachmentStorage.missing,
    this.sizeBytes = 0,
    this.annotationCount = 0,
    this.status = 'missing',
  });

  final String key;
  final String parentItemKey;
  final String title;
  final String filename;
  final String contentType;
  final String linkMode;
  final String? url;

  /// Path relative to the library directory, e.g. `attachments/4B/4BTNYYX4/paper.pdf`.
  final String? relativePath;
  final AttachmentStorage storage;
  final int sizeBytes;
  final int annotationCount;
  final String status;

  bool get isPdf => contentType == 'application/pdf' || filename.toLowerCase().endsWith('.pdf');

  bool get isEpub =>
      contentType == 'application/epub+zip' || filename.toLowerCase().endsWith('.epub');

  bool get isAvailable => relativePath != null && status == 'ok';

  bool get isReadable => isPdf && isAvailable;

  String get displayName => filename.isNotEmpty ? filename : title;

  String get sizeLabel => sizeBytes > 0 ? humanFileSize(sizeBytes) : '';

  /// Parses the `meta.attachments[]` entry of an item file.
  static ZoteroAttachment fromMeta(Map<String, dynamic> json, String parentItemKey) {
    final files = (json['files'] as List?) ?? const <dynamic>[];
    String? relativePath;
    var storage = AttachmentStorage.missing;
    var size = 0;
    if (files.isNotEmpty && files.first is Map) {
      final file = (files.first as Map).cast<String, dynamic>();
      relativePath = file['path'] as String?;
      size = (file['size'] as num?)?.toInt() ?? 0;
      storage = switch (file['storage'] as String?) {
        'lfs' => AttachmentStorage.lfs,
        'git' => AttachmentStorage.git,
        _ => AttachmentStorage.git,
      };
    }
    return ZoteroAttachment(
      key: json['key'] as String? ?? '',
      parentItemKey: parentItemKey,
      title: json['title'] as String? ?? 'Attachment',
      filename: json['filename'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      linkMode: json['linkMode'] as String? ?? '',
      url: json['url'] as String?,
      relativePath: relativePath,
      storage: storage,
      sizeBytes: size,
      annotationCount: (json['annotationCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? (relativePath == null ? 'missing' : 'ok'),
    );
  }
}

/// A child note stored inside the item JSON.
@immutable
class ZoteroNote {
  const ZoteroNote({required this.key, required this.html, this.dateModified});

  final String key;
  final String html;
  final DateTime? dateModified;

  /// Very small HTML → text reduction, good enough for list previews.
  String get plainText => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}

/// A top-level library item: a paper, book, book section or standalone file.
@immutable
class ZoteroItem {
  const ZoteroItem({
    required this.key,
    required this.title,
    required this.itemType,
    required this.filePath,
    this.creators = const <String>[],
    this.creatorDetails = const <ZoteroCreator>[],
    this.year = '',
    this.date = '',
    this.collectionKeys = const <String>[],
    this.collectionPaths = const <String>[],
    this.attachments = const <ZoteroAttachment>[],
    this.notes = const <ZoteroNote>[],
    this.annotationCount = 0,
    this.tags = const <String>[],
    this.publication = '',
    this.doi = '',
    this.url = '',
    this.abstractNote = '',
    this.publisher = '',
    this.dateAdded,
    this.dateModified,
    this.extraFields = const <String, dynamic>{},
  });

  final String key;
  final String title;
  final String itemType;

  /// Absolute path of `items/<XX>/<KEY>.json` on disk.
  final String filePath;
  final List<String> creators;
  final List<ZoteroCreator> creatorDetails;
  final String year;
  final String date;
  final List<String> collectionKeys;
  final List<String> collectionPaths;
  final List<ZoteroAttachment> attachments;
  final List<ZoteroNote> notes;
  final int annotationCount;
  final List<String> tags;
  final String publication;
  final String doi;
  final String url;
  final String abstractNote;
  final String publisher;
  final DateTime? dateAdded;
  final DateTime? dateModified;

  /// Everything else from the `zotero` block, kept for the details pane.
  final Map<String, dynamic> extraFields;

  String get creatorLabel => formatCreators(creators);

  String get subtitle {
    final parts = <String>[
      if (creatorLabel.isNotEmpty) creatorLabel,
      if (year.isNotEmpty) year,
      if (publication.isNotEmpty) publication,
    ];
    return parts.join(' · ');
  }

  /// The attachment a reader should open by default.
  ZoteroAttachment? get primaryReadable {
    for (final a in attachments) {
      if (a.isReadable) return a;
    }
    for (final a in attachments) {
      if (a.isAvailable) return a;
    }
    return attachments.isEmpty ? null : attachments.first;
  }

  bool get hasReadableFile => attachments.any((a) => a.isAvailable);

  String get searchHaystack => <String>[
    title,
    ...creators,
    year,
    publication,
    doi,
    itemType,
    ...tags,
  ].join(' ').toLowerCase();
}

/// One creator entry (author, editor, …) of an item.
@immutable
class ZoteroCreator {
  const ZoteroCreator({
    required this.creatorType,
    this.firstName = '',
    this.lastName = '',
    this.name = '',
  });

  factory ZoteroCreator.fromJson(Map<String, dynamic> json) => ZoteroCreator(
    creatorType: json['creatorType'] as String? ?? 'author',
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  final String creatorType;
  final String firstName;
  final String lastName;
  final String name;

  String get display {
    if (name.isNotEmpty) return name;
    if (firstName.isEmpty) return lastName;
    if (lastName.isEmpty) return firstName;
    return '$lastName, $firstName';
  }
}

/// A fully parsed item file, including the annotation children.
@immutable
class ItemDetail {
  const ItemDetail({required this.item, required this.annotations, required this.rawJson});

  final ZoteroItem item;
  final List<ZoteroAnnotation> annotations;
  final Map<String, dynamic> rawJson;

  List<ZoteroAnnotation> annotationsFor(String attachmentKey) =>
      annotations.where((a) => a.parentItemKey == attachmentKey).toList(growable: false);
}
