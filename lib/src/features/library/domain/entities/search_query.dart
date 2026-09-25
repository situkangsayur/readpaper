import 'package:meta/meta.dart';

import 'zotero_item.dart';

/// Which part of an item a search term is aimed at.
enum SearchField {
  any(<String>['']),
  title(<String>['judul', 'title']),
  creator(<String>['pengarang', 'penulis', 'author', 'creator']),
  year(<String>['tahun', 'year']),
  tag(<String>['tag', 'label']),
  type(<String>['jenis', 'type']),
  publication(<String>['jurnal', 'publikasi', 'journal', 'publication']),
  doi(<String>['doi']),
  abstract(<String>['abstrak', 'abstract', 'ringkasan']),
  collection(<String>['koleksi', 'collection']);

  const SearchField(this.prefixes);

  /// Both languages are accepted, because the field names are typed from
  /// memory and nobody should have to remember which one this app chose.
  final List<String> prefixes;

  static SearchField? fromPrefix(String prefix) {
    final lower = prefix.toLowerCase();
    for (final field in values) {
      if (field != any && field.prefixes.contains(lower)) return field;
    }
    return null;
  }
}

/// One `field:value` term, or a bare word that matches anything.
@immutable
class SearchTerm {
  const SearchTerm(this.field, this.value, {this.negated = false});

  final SearchField field;
  final String value;

  /// True for a term written with a leading `-`, which must not match.
  final bool negated;

  bool matches(ZoteroItem item) {
    final hit = _hit(item);
    return negated ? !hit : hit;
  }

  bool _hit(ZoteroItem item) {
    switch (field) {
      case SearchField.any:
        return item.matchesAnywhere(value);
      case SearchField.title:
        return item.title.toLowerCase().contains(value);
      case SearchField.creator:
        return item.creators.any((c) => c.toLowerCase().contains(value));
      case SearchField.year:
        // A year is asked for exactly; "202" should not bring back 2020-2029.
        return item.year.toLowerCase() == value;
      case SearchField.tag:
        return item.tags.any((t) => t.toLowerCase().contains(value));
      case SearchField.type:
        return item.itemType.toLowerCase().contains(value);
      case SearchField.publication:
        return item.publication.toLowerCase().contains(value);
      case SearchField.doi:
        return item.doi.toLowerCase().contains(value);
      case SearchField.abstract:
        return item.abstractNote.toLowerCase().contains(value);
      case SearchField.collection:
        return item.collectionPaths.any((p) => p.toLowerCase().contains(value));
    }
  }
}

/// A parsed search box.
///
/// Bare words search everything; `pengarang:nama` narrows to one field; a
/// leading `-` excludes. Quotes keep a phrase together so
/// `judul:"deep learning"` is one term rather than two.
@immutable
class SearchQuery {
  const SearchQuery(this.terms);

  factory SearchQuery.parse(String raw) {
    final terms = <SearchTerm>[];
    for (final token in _tokenize(raw)) {
      var text = token;
      var negated = false;
      if (text.startsWith('-') && text.length > 1) {
        negated = true;
        text = text.substring(1);
      }

      final colon = text.indexOf(':');
      if (colon > 0) {
        final field = SearchField.fromPrefix(text.substring(0, colon));
        final value = _unquote(text.substring(colon + 1)).toLowerCase();
        if (field != null) {
          // A known prefix with nothing after it is a query halfway through
          // being typed. Blanking the list on every colon is only noise, so
          // the term is dropped until a value arrives.
          if (value.isNotEmpty) terms.add(SearchTerm(field, value, negated: negated));
          continue;
        }
      }

      final value = _unquote(text).toLowerCase();
      if (value.isNotEmpty) terms.add(SearchTerm(SearchField.any, value, negated: negated));
    }
    return SearchQuery(terms);
  }

  final List<SearchTerm> terms;

  bool get isEmpty => terms.isEmpty;

  /// Every term must match: narrowing is what people expect from typing more.
  bool matches(ZoteroItem item) => terms.every((t) => t.matches(item));

  List<ZoteroItem> filter(List<ZoteroItem> items) =>
      isEmpty ? items : items.where(matches).toList(growable: false);

  /// Splits on spaces, except inside double quotes.
  static List<String> _tokenize(String raw) {
    final out = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '"') {
        inQuotes = !inQuotes;
        buffer.write(ch);
      } else if (!inQuotes && ch.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          out.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) out.add(buffer.toString());
    return out;
  }

  static String _unquote(String s) {
    var out = s.trim();
    if (out.length >= 2 && out.startsWith('"') && out.endsWith('"')) {
      out = out.substring(1, out.length - 1);
    }
    // An unterminated quote is a half-typed phrase, not an error.
    return out.replaceAll('"', '').trim();
  }
}
