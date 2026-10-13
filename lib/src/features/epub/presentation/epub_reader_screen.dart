import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/share_file.dart';
import '../../../core/widgets/find_bar.dart';
import '../data/epub_book.dart';
import '../data/epub_search.dart';
import '../../../core/l10n.dart';

/// Warna halaman pembaca EPUB.
enum EpubTheme {
  terang(Color(0xFFFFFFFF), Color(0xFF1F1F1F)),
  sepia(Color(0xFFF4ECD8), Color(0xFF3B2F22)),
  gelap(Color(0xFF121212), Color(0xFFE2E2E2));

  const EpubTheme(this.background, this.foreground);

  String get label => switch (this) {
    EpubTheme.terang => l10n.epubThemeLight,
    EpubTheme.sepia => l10n.epubThemeSepia,
    EpubTheme.gelap => l10n.epubThemeDark,
  };
  final Color background;
  final Color foreground;
}

/// Membaca sebuah EPUB: satu bab per layar, daftar isi, ukuran huruf, dan
/// warna halaman.
///
/// Belum ada stabilo. Zotero menyimpan anotasi EPUB dengan penanda CFI, dan
/// menulisnya dengan benar adalah pekerjaan tersendiri; membaca dulu adalah
/// yang diminta. Satu bab per layar, bukan satu gulungan panjang, supaya
/// melompat dari daftar isi selalu mendarat tepat di awal babnya.
class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({required this.path, this.title, super.key});

  final String path;
  final String? title;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  EpubBook? _book;
  String? _error;
  int _chapter = 0;
  double _fontSize = 18;
  EpubTheme _theme = EpubTheme.terang;
  final ScrollController _scroll = ScrollController();
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  // Cari kata: hasil di seluruh buku sebagai (bab, ke-n di bab itu).
  bool _finding = false;
  String _findQuery = '';
  List<(int, int)> _hits = const <(int, int)>[];
  int _hit = -1;
  final GlobalKey _activeHit = GlobalKey();
  String? _markedFor;
  String? _markedHtml;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _findDelay?.cancel();
    _remember();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final book = await EpubBook.open(widget.path);
      final saved = await _Positions.read(widget.path);
      if (!mounted) return;
      setState(() {
        _book = book;
        _chapter = (saved?.chapter ?? 0).clamp(
          0,
          book.chapters.isEmpty ? 0 : book.chapters.length - 1,
        );
        _fontSize = saved?.fontSize ?? _fontSize;
        _theme = saved?.theme ?? _theme;
      });
      final offset = saved?.offset ?? 0;
      if (offset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
          }
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = context.l10n.epubUnreadable('$e'));
    }
  }

  /// Bab, posisi gulir, ukuran huruf, dan warna diingat per berkas: membuka
  /// buku lagi berarti melanjutkan, bukan mencari tempat berhenti.
  void _remember() {
    if (_book == null) return;
    _Positions.write(
      widget.path,
      _Position(
        chapter: _chapter,
        offset: _scroll.hasClients ? _scroll.offset : 0,
        fontSize: _fontSize,
        theme: _theme,
      ),
    );
  }

  Timer? _findDelay;

  /// Tiap ketikan menunggu sebentar: mencari berarti memindai semua bab, dan
  /// buku tebal tidak perlu dipindai untuk setiap huruf.
  void _findSoon(String query) {
    _findDelay?.cancel();
    _findDelay = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _find(query);
    });
  }

  void _find(String query) {
    final book = _book;
    if (book == null) return;
    final hits = <(int, int)>[];
    if (query.trim().isNotEmpty) {
      for (var c = 0; c < book.chapters.length; c++) {
        final n = EpubSearch.count(book.chapters[c].html, query);
        for (var i = 0; i < n; i++) {
          hits.add((c, i));
        }
      }
    }
    // Mulai dari bab yang sedang dibaca, bukan dari awal buku.
    final first = hits.indexWhere((h) => h.$1 >= _chapter);
    setState(() {
      _findQuery = query;
      _hits = hits;
      _hit = hits.isEmpty ? -1 : (first < 0 ? 0 : first);
    });
    _showHit();
  }

  void _stepHit(int delta) {
    if (_hits.isEmpty) return;
    setState(() => _hit = (_hit + delta) % _hits.length);
    _showHit();
  }

  void _showHit() {
    if (_hit < 0) return;
    final (chapter, _) = _hits[_hit];
    if (chapter != _chapter) _goTo(chapter);
    // Dua bingkai: bab baru dibangun dulu, baru tandanya punya tempat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _activeHit.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.3,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    });
  }

  void _closeFind() => setState(() {
    _finding = false;
    _hits = const <(int, int)>[];
    _hit = -1;
  });

  /// HTML bab dengan hasil pencarian ditandai, disimpan selama pencariannya
  /// sama.
  String _chapterHtml(EpubChapter chapter) {
    if (!_finding || _hits.isEmpty) return chapter.html;
    final active = _hit >= 0 && _hits[_hit].$1 == _chapter ? _hits[_hit].$2 : -1;
    final key = '${chapter.href}|$_findQuery|$active';
    if (_markedFor != key) {
      _markedFor = key;
      _markedHtml = EpubSearch.mark(chapter.html, _findQuery, active: active);
    }
    return _markedHtml!;
  }

  Widget _mark(ExtensionContext context) {
    final active = context.classes.contains(EpubSearch.activeClass);
    return Container(
      key: active ? _activeHit : null,
      color: active ? const Color(0xFFFF9632) : const Color(0xFFFFE066),
      child: Text(
        context.element?.text ?? '',
        style: TextStyle(fontSize: _fontSize, color: Colors.black, height: 1.3),
      ),
    );
  }

  void _goTo(int chapter) {
    final book = _book;
    if (book == null || chapter < 0 || chapter >= book.chapters.length) return;
    setState(() => _chapter = chapter);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _remember();
  }

  void _openLink(String? url) {
    final book = _book;
    if (url == null || book == null) return;
    if (url.startsWith('epub:')) {
      final index = book.chapterIndexOf(url.substring(5));
      if (index >= 0) _goTo(index);
    }
  }

  Widget _image(ExtensionContext context) {
    final src = context.attributes['src'] ?? '';
    final data = src.startsWith('epub:') ? _book?.resources[src.substring(5)] : null;
    if (data == null || src.toLowerCase().endsWith('.svg')) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Image.memory(data, fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final title = widget.title ?? book?.title ?? p.basenameWithoutExtension(widget.path);
    void openFind() {
      if (book != null) setState(() => _finding = true);
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): openFind,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): openFind,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffold,
          backgroundColor: _theme.background,
          appBar: AppBar(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: <Widget>[
              IconButton(
                tooltip: context.l10n.findTooltip,
                icon: const Icon(Icons.search),
                onPressed: book == null ? null : () => setState(() => _finding = true),
              ),
              IconButton(
                tooltip: context.l10n.epubSmallerText,
                icon: const Icon(Icons.text_decrease),
                onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(12, 34)),
              ),
              IconButton(
                tooltip: context.l10n.epubLargerText,
                icon: const Icon(Icons.text_increase),
                onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(12, 34)),
              ),
              IconButton(
                tooltip: context.l10n.epubPageColor(_theme.label),
                icon: const Icon(Icons.contrast),
                onPressed: () => setState(
                  () => _theme = EpubTheme.values[(_theme.index + 1) % EpubTheme.values.length],
                ),
              ),
              IconButton(
                tooltip: context.l10n.notesShare,
                icon: const Icon(Icons.share_outlined),
                onPressed: () async {
                  final failure = await shareFile(context, widget.path, title: title);
                  if (failure != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
                  }
                },
              ),
              IconButton(
                tooltip: context.l10n.epubContents,
                icon: const Icon(Icons.toc),
                onPressed: book == null ? null : () => _scaffold.currentState?.openEndDrawer(),
              ),
            ],
          ),
          endDrawer: book == null ? null : Drawer(child: SafeArea(child: _tocList(book))),
          body: _error != null
              ? Center(
                  child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)),
                )
              : book == null
              ? const Center(child: CircularProgressIndicator())
              : book.chapters.isEmpty
              ? Center(child: Text(context.l10n.epubNoChapters))
              : Column(
                  children: <Widget>[
                    if (_finding)
                      FindBar(
                        initialQuery: _findQuery,
                        current: _hit < 0 ? null : _hit + 1,
                        total: _findQuery.trim().isEmpty ? null : _hits.length,
                        onChanged: _findSoon,
                        onNext: () => _stepHit(1),
                        onPrevious: () => _stepHit(-1),
                        onClose: _closeFind,
                      ),
                    Expanded(child: _chapterView(book)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _chapterView(EpubBook book) {
    final chapter = book.chapters[_chapter];
    return Column(
      children: <Widget>[
        Expanded(
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _scroll,
              child: Center(
                child: ConstrainedBox(
                  // Baris yang terlalu panjang melelahkan mata di layar lebar.
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Html(
                      key: ValueKey<String>(
                        '${chapter.href}-$_fontSize-${_theme.name}-${_finding ? '$_findQuery-$_hit' : ''}',
                      ),
                      data: _chapterHtml(chapter),
                      style: <String, Style>{
                        'body': Style(
                          fontSize: FontSize(_fontSize),
                          color: _theme.foreground,
                          lineHeight: const LineHeight(1.55),
                          margin: Margins.zero,
                        ),
                        'a': Style(color: Theme.of(context).colorScheme.primary),
                      },
                      extensions: <HtmlExtension>[
                        TagExtension(tagsToExtend: <String>{'img', 'image'}, builder: _image),
                        TagExtension(tagsToExtend: <String>{'mark'}, builder: _mark),
                      ],
                      onLinkTap: (url, _, _) => _openLink(url),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Material(
          color: _theme.background,
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: context.l10n.epubPrevChapter,
                  icon: Icon(Icons.chevron_left, color: _theme.foreground),
                  onPressed: _chapter > 0 ? () => _goTo(_chapter - 1) : null,
                ),
                Expanded(
                  child: Text(
                    '${chapter.title ?? context.l10n.epubChapterN(_chapter + 1)} · ${_chapter + 1}/${book.chapters.length}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _theme.foreground, fontSize: 12.5),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.epubNextChapter,
                  icon: Icon(Icons.chevron_right, color: _theme.foreground),
                  onPressed: _chapter < book.chapters.length - 1 ? () => _goTo(_chapter + 1) : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tocList(EpubBook book) {
    if (book.toc.isEmpty) {
      return ListView(
        children: <Widget>[
          for (var i = 0; i < book.chapters.length; i++)
            ListTile(
              dense: true,
              selected: i == _chapter,
              title: Text(book.chapters[i].title ?? context.l10n.epubChapterN(i + 1)),
              onTap: () {
                Navigator.of(context).pop();
                _goTo(i);
              },
            ),
        ],
      );
    }
    return ListView(
      children: <Widget>[
        ListTile(
          title: Text(book.title.isEmpty ? context.l10n.epubContents : book.title),
          subtitle: book.author.isEmpty ? null : Text(book.author),
        ),
        const Divider(height: 1),
        for (final entry in book.toc)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(left: 16 + entry.depth * 16.0, right: 16),
            selected: book.chapterIndexOf(entry.href) == _chapter,
            title: Text(entry.title),
            onTap: () {
              Navigator.of(context).pop();
              final index = book.chapterIndexOf(entry.href);
              if (index >= 0) _goTo(index);
            },
          ),
      ],
    );
  }
}

class _Position {
  const _Position({
    required this.chapter,
    required this.offset,
    required this.fontSize,
    required this.theme,
  });

  final int chapter;
  final double offset;
  final double fontSize;
  final EpubTheme theme;
}

/// Posisi baca per berkas, dalam satu berkas JSON milik aplikasi.
class _Positions {
  static Future<File> _file() async =>
      File(p.join((await getApplicationSupportDirectory()).path, 'epub-posisi.json'));

  static Future<Map<String, dynamic>> _all() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return <String, dynamic>{};
      return (jsonDecode(await file.readAsString()) as Map).cast<String, dynamic>();
    } on Object {
      return <String, dynamic>{};
    }
  }

  static Future<_Position?> read(String path) async {
    final raw = (await _all())[path];
    if (raw is! Map) return null;
    return _Position(
      chapter: (raw['bab'] as num?)?.toInt() ?? 0,
      offset: (raw['gulir'] as num?)?.toDouble() ?? 0,
      fontSize: (raw['huruf'] as num?)?.toDouble() ?? 18,
      theme: EpubTheme.values.where((t) => t.name == raw['warna']).firstOrNull ?? EpubTheme.terang,
    );
  }

  static Future<void> write(String path, _Position position) async {
    try {
      final all = await _all();
      all[path] = <String, dynamic>{
        'bab': position.chapter,
        'gulir': position.offset,
        'huruf': position.fontSize,
        'warna': position.theme.name,
      };
      await (await _file()).writeAsString(jsonEncode(all));
    } on Object {
      // Gagal mengingat posisi bukan alasan untuk mengganggu yang membaca.
    }
  }
}
