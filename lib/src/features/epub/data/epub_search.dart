import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

/// Mencari kata di bab EPUB dan menandai hasilnya di HTML-nya.
///
/// Hitungan dan penandaan memakai penelusuran yang sama — per simpul teks —
/// supaya hasil ke-n yang dihitung adalah `<mark>` ke-n yang digambar. Kata
/// yang terbelah dua tag (`ka<b>ta</b>`) tidak terhitung; pembaca EPUB lain
/// berlaku sama.
class EpubSearch {
  const EpubSearch._();

  /// Kelas `<mark>` untuk hasil yang sedang dituju.
  static const String activeClass = 'rp-aktif';

  /// Jumlah kemunculan [query] di [chapterHtml], tanpa membedakan huruf
  /// besar-kecil.
  static int count(String chapterHtml, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return 0;
    var total = 0;
    _walk(html.parseFragment(chapterHtml), (text) {
      total += _positions(text.data.toLowerCase(), needle).length;
    });
    return total;
  }

  /// [chapterHtml] dengan setiap kemunculan [query] dibungkus `<mark>`; yang
  /// ke-[active] (mulai 0) diberi kelas [activeClass].
  static String mark(String chapterHtml, String query, {int active = -1}) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return chapterHtml;
    final fragment = html.parseFragment(chapterHtml);
    final texts = <dom.Text>[];
    _walk(fragment, texts.add);
    var n = 0;
    for (final node in texts) {
      final data = node.data;
      final hits = _positions(data.toLowerCase(), needle);
      if (hits.isEmpty) continue;
      final parent = node.parentNode!;
      final replacement = <dom.Node>[];
      var cursor = 0;
      for (final at in hits) {
        if (at < cursor || at >= data.length) continue;
        // Huruf kecil bisa lebih panjang dari aslinya (İ → i̇); jangan lewat.
        final end = at + needle.length > data.length ? data.length : at + needle.length;
        if (at > cursor) replacement.add(dom.Text(data.substring(cursor, at)));
        final mark = dom.Element.tag('mark')..append(dom.Text(data.substring(at, end)));
        if (n == active) mark.classes.add(activeClass);
        replacement.add(mark);
        cursor = end;
        n++;
      }
      if (cursor < data.length) replacement.add(dom.Text(data.substring(cursor)));
      for (final r in replacement) {
        parent.insertBefore(r, node);
      }
      node.remove();
    }
    return fragment.outerHtml;
  }

  static List<int> _positions(String haystack, String needle) {
    final out = <int>[];
    var from = 0;
    while (true) {
      final at = haystack.indexOf(needle, from);
      if (at < 0 || at + needle.length > haystack.length) return out;
      out.add(at);
      from = at + needle.length;
    }
  }

  static void _walk(dom.Node node, void Function(dom.Text) visit) {
    for (final child in node.nodes.toList()) {
      if (child is dom.Text) {
        visit(child);
      } else if (child is dom.Element) {
        final tag = child.localName;
        if (tag == 'script' || tag == 'style') continue;
        _walk(child, visit);
      }
    }
  }
}
