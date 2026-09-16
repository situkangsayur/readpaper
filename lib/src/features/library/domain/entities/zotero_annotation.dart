import 'dart:convert';

import 'package:meta/meta.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/utils/zotero_key.dart';

/// The annotation kinds ReadPaper understands.
enum AnnotationType {
  highlight,
  underline,
  note,
  text,
  image,
  ink;

  static AnnotationType parse(String? raw) => switch (raw) {
    'highlight' => AnnotationType.highlight,
    'underline' => AnnotationType.underline,
    'note' => AnnotationType.note,
    'text' => AnnotationType.text,
    'image' => AnnotationType.image,
    'ink' => AnnotationType.ink,
    _ => AnnotationType.highlight,
  };

  String get wire => name;

  /// Kinds whose rectangles are painted over the page text.
  bool get isTextMarker => this == AnnotationType.highlight || this == AnnotationType.underline;
}

/// A rectangle in PDF page coordinates (origin bottom-left, unit = points).
@immutable
class AnnotationRect {
  const AnnotationRect(this.left, this.bottom, this.right, this.top);

  factory AnnotationRect.fromList(List<dynamic> list) => AnnotationRect(
    (list[0] as num).toDouble(),
    (list[1] as num).toDouble(),
    (list[2] as num).toDouble(),
    (list[3] as num).toDouble(),
  );

  final double left;
  final double bottom;
  final double right;
  final double top;

  double get width => right - left;
  double get height => top - bottom;

  /// Serialised the way Zotero (JavaScript) writes them: at most three
  /// decimals, and whole numbers without a trailing `.0`.
  List<num> toList() => <num>[
    _round(left),
    _round(bottom),
    _round(right),
    _round(top),
  ];

  static num _round(double v) {
    final rounded = (v * 1000).roundToDouble() / 1000;
    return rounded == rounded.roundToDouble() ? rounded.toInt() : rounded;
  }
}

/// A Zotero annotation attached to a PDF attachment.
@immutable
class ZoteroAnnotation {
  const ZoteroAnnotation({
    required this.key,
    required this.parentItemKey,
    required this.type,
    required this.color,
    required this.pageIndex,
    this.rects = const <AnnotationRect>[],
    this.text = '',
    this.comment = '',
    this.pageLabel = '',
    this.sortIndex = '',
    this.authorName = '',
    this.tags = const <String>[],
    this.dateAdded,
    this.dateModified,
    this.rawPosition,
  });

  /// Builds an annotation from the Zotero API JSON stored in the item file.
  factory ZoteroAnnotation.fromJson(Map<String, dynamic> json) {
    final positionRaw = json['annotationPosition'];
    Map<String, dynamic> position = <String, dynamic>{};
    if (positionRaw is String && positionRaw.isNotEmpty) {
      try {
        position = (jsonDecode(positionRaw) as Map).cast<String, dynamic>();
      } catch (_) {
        position = <String, dynamic>{};
      }
    } else if (positionRaw is Map) {
      position = positionRaw.cast<String, dynamic>();
    }

    final rectsRaw = position['rects'];
    final rects = <AnnotationRect>[];
    if (rectsRaw is List) {
      for (final entry in rectsRaw) {
        if (entry is List && entry.length >= 4) {
          rects.add(AnnotationRect.fromList(entry));
        }
      }
    }

    return ZoteroAnnotation(
      key: json['key'] as String? ?? ZoteroKey.generate(),
      parentItemKey: json['parentItem'] as String? ?? '',
      type: AnnotationType.parse(json['annotationType'] as String?),
      color: json['annotationColor'] as String? ?? AnnotationPalette.yellow,
      pageIndex: (position['pageIndex'] as num?)?.toInt() ?? 0,
      rects: rects,
      text: json['annotationText'] as String? ?? '',
      comment: json['annotationComment'] as String? ?? '',
      pageLabel: json['annotationPageLabel'] as String? ?? '',
      sortIndex: json['annotationSortIndex'] as String? ?? '',
      authorName: json['annotationAuthorName'] as String? ?? '',
      tags: _parseTags(json['tags']),
      dateAdded: parseZoteroTimestamp(json['dateAdded'] as String?),
      dateModified: parseZoteroTimestamp(json['dateModified'] as String?),
      rawPosition: position,
    );
  }

  final String key;
  final String parentItemKey;
  final AnnotationType type;
  final String color;
  final int pageIndex;
  final List<AnnotationRect> rects;
  final String text;
  final String comment;
  final String pageLabel;
  final String sortIndex;
  final String authorName;
  final List<String> tags;
  final DateTime? dateAdded;
  final DateTime? dateModified;

  /// Extra position fields (fontSize, rotation, …) preserved on round-trip.
  final Map<String, dynamic>? rawPosition;

  int get pageNumber => pageIndex + 1;

  bool get hasComment => comment.trim().isNotEmpty;

  ZoteroAnnotation copyWith({
    String? color,
    String? comment,
    String? text,
    AnnotationType? type,
    List<String>? tags,
    DateTime? dateModified,
  }) => ZoteroAnnotation(
    key: key,
    parentItemKey: parentItemKey,
    type: type ?? this.type,
    color: color ?? this.color,
    pageIndex: pageIndex,
    rects: rects,
    text: text ?? this.text,
    comment: comment ?? this.comment,
    pageLabel: pageLabel,
    sortIndex: sortIndex,
    authorName: authorName,
    tags: tags ?? this.tags,
    dateAdded: dateAdded,
    dateModified: dateModified ?? DateTime.now(),
    rawPosition: rawPosition,
  );

  /// Serialises back into the exact shape the Zotero GitHub export uses.
  Map<String, dynamic> toJson() {
    final position = <String, dynamic>{
      ...?rawPosition,
      'pageIndex': pageIndex,
      'rects': rects.map((r) => r.toList()).toList(),
    };
    if (rects.isEmpty) position.remove('rects');

    return <String, dynamic>{
      'annotationAuthorName': authorName,
      'annotationColor': color,
      'annotationComment': comment,
      'annotationPageLabel': pageLabel,
      'annotationPosition': jsonEncode(position),
      'annotationSortIndex': sortIndex,
      if (type != AnnotationType.note || text.isNotEmpty) 'annotationText': text,
      'annotationType': type.wire,
      'dateAdded': zoteroTimestamp(dateAdded),
      'dateModified': zoteroTimestamp(dateModified),
      'itemType': 'annotation',
      'key': key,
      'parentItem': parentItemKey,
      'relations': <String, dynamic>{},
      'tags': tags.map((t) => <String, dynamic>{'tag': t}).toList(),
    };
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((e) => e is Map ? e['tag'] as String? : e as String?)
        .whereType<String>()
        .toList(growable: false);
  }

  /// Builds the `pageIndex|offset|top` sort index Zotero uses to order annotations.
  static String buildSortIndex({
    required int pageIndex,
    required int textOffset,
    required double topFromPageTop,
  }) {
    final page = pageIndex.clamp(0, 99999).toString().padLeft(5, '0');
    final offset = textOffset.clamp(0, 999999).toString().padLeft(6, '0');
    final top = topFromPageTop.round().clamp(0, 99999).toString().padLeft(5, '0');
    return '$page|$offset|$top';
  }
}
