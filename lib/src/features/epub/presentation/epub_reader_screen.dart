import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/share_file.dart';
import '../data/epub_book.dart';

/// Warna halaman pembaca EPUB.
enum EpubTheme {
  terang('Terang', Color(0xFFFFFFFF), Color(0xFF1F1F1F)),
  sepia('Sepia', Color(0xFFF4ECD8), Color(0xFF3B2F22)),
  gelap('Gelap', Color(0xFF121212), Color(0xFFE2E2E2));

  const EpubTheme(this.label, this.background, this.foreground);

  final String label;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
      if (mounted) setState(() => _error = 'EPUB ini tidak bisa dibaca: $e');
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
    return Scaffold(
      key: _scaffold,
      backgroundColor: _theme.background,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: 'Perkecil huruf',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(12, 34)),
          ),
          IconButton(
            tooltip: 'Perbesar huruf',
            icon: const Icon(Icons.text_increase),
            onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(12, 34)),
          ),
          IconButton(
            tooltip: 'Warna halaman: ${_theme.label}',
            icon: const Icon(Icons.contrast),
            onPressed: () => setState(
              () => _theme = EpubTheme.values[(_theme.index + 1) % EpubTheme.values.length],
            ),
          ),
          IconButton(
            tooltip: 'Bagikan',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final failure = await shareFile(context, widget.path, title: title);
              if (failure != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
              }
            },
          ),
          IconButton(
            tooltip: 'Daftar isi',
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
          ? const Center(child: Text('EPUB ini tidak punya bab yang bisa dibaca.'))
          : _chapterView(book),
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
                      key: ValueKey<String>('${chapter.href}-$_fontSize-${_theme.name}'),
                      data: chapter.html,
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
                  tooltip: 'Bab sebelumnya',
                  icon: Icon(Icons.chevron_left, color: _theme.foreground),
                  onPressed: _chapter > 0 ? () => _goTo(_chapter - 1) : null,
                ),
                Expanded(
                  child: Text(
                    '${chapter.title ?? 'Bab ${_chapter + 1}'} · ${_chapter + 1}/${book.chapters.length}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _theme.foreground, fontSize: 12.5),
                  ),
                ),
                IconButton(
                  tooltip: 'Bab berikutnya',
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
              title: Text(book.chapters[i].title ?? 'Bab ${i + 1}'),
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
          title: Text(book.title.isEmpty ? 'Daftar isi' : book.title),
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
