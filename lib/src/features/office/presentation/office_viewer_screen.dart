import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../core/l10n.dart';
import '../../../core/widgets/find_bar.dart';
import '../../files/presentation/open_any_file.dart';
import '../../reader/presentation/screens/reader_screen.dart';
import '../data/emf_picture.dart';
import '../data/office_converter.dart';
import '../data/office_pdf.dart';
import '../data/office_loader.dart';
import '../domain/office_document.dart';
import 'offscreen_render.dart';

/// Membaca dokumen Word (`.docx`, `.doc`, `.rtf`), PowerPoint (`.pptx`,
/// `.ppt`), dan OpenDocument (`.odt`, `.odp`) di dalam ReadPaper, di semua
/// platform, tanpa aplikasi lain.
///
/// Word ditampilkan sebagai teks mengalir di atas lembar putih — judul,
/// butir, tabel, dan gambar — bukan halaman persis; PowerPoint per slide di
/// posisi aslinya, dengan catatan pembicara di bawahnya. Di desktop yang
/// memasang LibreOffice ada "tampilan persis": dokumennya diubah ke PDF dan
/// dibuka di pembaca PDF.
class OfficeViewerScreen extends StatefulWidget {
  const OfficeViewerScreen({required this.path, this.title, super.key});

  final String path;
  final String? title;

  @override
  State<OfficeViewerScreen> createState() => _OfficeViewerScreenState();
}

class _OfficeViewerScreenState extends State<OfficeViewerScreen> {
  OfficeDocument? _doc;
  String? _error;

  /// Paragraf → nomor urutnya di [OfficeDocument.paragraphs], untuk hasil
  /// pencarian.
  final Map<OfficeParagraph, int> _index = LinkedHashMap<OfficeParagraph, int>.identity();
  Map<int, List<OfficeMatch>> _matchesByParagraph = const <int, List<OfficeMatch>>{};
  List<OfficeMatch> _matches = const <OfficeMatch>[];
  int _current = -1;
  bool _finding = false;
  String _query = '';
  final GlobalKey _currentKey = GlobalKey();
  final ScrollController _scroll = ScrollController();

  /// Pembesaran teks dokumen Word; slide selalu pas selebar layar.
  double _textScale = 1;

  String? _soffice;
  bool _converting = false;

  /// PDF buatan ReadPaper sendiri (tanpa LibreOffice) selama layar ini terbuka.
  String? _builtPdf;

  @override
  void initState() {
    super.initState();
    _load();
    OfficeConverter.sofficePath().then((path) {
      if (mounted && path != null) setState(() => _soffice = path);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final path = widget.path;
    try {
      final doc = await _read(path);
      if (!mounted) return;
      final paragraphs = doc.paragraphs;
      for (var i = 0; i < paragraphs.length; i++) {
        _index[paragraphs[i]] = i;
      }
      setState(() => _doc = doc);
    } on Object catch (e) {
      if (!mounted) return;
      final message = e is FormatException ? e.message : '$e';
      setState(() => _error = context.l10n.officeUnreadable(message));
    }
  }

  /// Dokumen besar dibaca di isolat lain supaya layar tidak membeku. Fungsi
  /// statis: penutup yang dikirim ke isolat tidak boleh ikut membawa State.
  static Future<OfficeDocument> _read(String path) async {
    final bytes = await File(path).readAsBytes();
    final name = p.basename(path);
    return Isolate.run(() => readOffice(name, bytes));
  }

  String get _title => widget.title ?? p.basenameWithoutExtension(widget.path);

  bool get _textOnly {
    final ext = p.extension(widget.path).toLowerCase();
    return ext == '.doc' || ext == '.ppt' || ext == '.pps' || ext == '.dot' || ext == '.pot';
  }

  // ---------------------------------------------------------------- cari

  void _search(String query) {
    final doc = _doc;
    if (doc == null) return;
    final matches = searchParagraphs(doc.paragraphs, query);
    final grouped = <int, List<OfficeMatch>>{};
    for (final m in matches) {
      (grouped[m.paragraph] ??= <OfficeMatch>[]).add(m);
    }
    setState(() {
      _query = query;
      _matches = matches;
      _matchesByParagraph = grouped;
      _current = matches.isEmpty ? -1 : 0;
    });
    _reveal();
  }

  void _step(int delta) {
    if (_matches.isEmpty) return;
    setState(() => _current = (_current + delta) % _matches.length);
    _reveal();
  }

  void _reveal() {
    if (_current < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _currentKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(target, alignment: 0.3, duration: const Duration(milliseconds: 200));
    });
  }

  void _openFind() => setState(() => _finding = true);

  void _closeFind() => setState(() {
    _finding = false;
    _matches = const <OfficeMatch>[];
    _matchesByParagraph = const <int, List<OfficeMatch>>{};
    _current = -1;
  });

  // --------------------------------------------------- tampilan persis (PDF)

  /// PDF dokumen ini: lewat LibreOffice bila ada (persis seperti di Office),
  /// atau dibuat sendiri — slide digambar seperti di layar ini, Word dan
  /// teksnya ditulis ulang. Yang kedua yang dipakai di Android.
  Future<String> _pdfPath() async {
    if (_soffice != null) return OfficeConverter.toPdf(widget.path);
    final built = _builtPdf;
    if (built != null && File(built).existsSync()) return built;
    final bytes = await _buildPdf();
    final dir = await Directory.systemTemp.createTemp('readpaper-office-');
    final file = File(p.join(dir.path, '${p.basenameWithoutExtension(widget.path)}.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return _builtPdf = file.path;
  }

  Future<Uint8List> _buildPdf() async {
    final doc = _doc!;
    if (!doc.isPresentation) return OfficePdf.document(doc);
    final messenger = ScaffoldMessenger.of(context);
    // Gambar slide harus sudah terurai sebelum digambar di luar layar.
    for (final slide in doc.slides) {
      final images = <Uint8List>[
        ?slide.backgroundImage,
        for (final shape in slide.shapes) ?shape.image,
      ];
      for (final bytes in images) {
        final emf = EmfPicture.of(bytes);
        if (emf != null) {
          await prepareEmfImages(emf);
        } else if (mounted) {
          await precacheImage(MemoryImage(bytes), context, onError: (_, _) {});
        }
      }
    }
    if (!mounted) throw StateError('closed');
    final render = OffscreenRender(context);
    // Sorotan hasil pencarian tidak ikut ke PDF.
    final matches = _matchesByParagraph;
    final current = _current;
    _matchesByParagraph = const <int, List<OfficeMatch>>{};
    _current = -1;
    final pngs = <Uint8List>[];
    try {
      final size = doc.slideSize;
      for (final slide in doc.slides) {
        // clearSnackBars, bukan hideCurrentSnackBar: pesan per slide yang
        // mengantre ikut terbawa ke layar presentasi.
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(minutes: 1),
              content: Text(l10n.officeMakingPdfSlides(slide.number, doc.slides.length)),
            ),
          );
        final png = await render.png(
          slide.hasLayout ? _slideCanvas(slide) : _plainSlide(slide),
          size,
          pixelRatio: 1600 / size.width,
        );
        if (png == null) throw StateError('slide ${slide.number}');
        pngs.add(png);
      }
    } finally {
      _matchesByParagraph = matches;
      _current = current;
      messenger.clearSnackBars();
    }
    return OfficePdf.slides(doc, pngs);
  }

  Future<void> _openAsPdf({bool present = false}) async {
    if (_converting) return;
    setState(() => _converting = true);
    try {
      final pdf = await _pdfPath();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(
            itemKey: '',
            itemFilePath: '',
            attachmentKey: '',
            filePath: pdf,
            title: _title,
            startPresenting: present,
          ),
        ),
      );
    } on Object catch (e) {
      _pdfFailed(e);
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _saveAsPdf() async {
    if (_converting) return;
    setState(() => _converting = true);
    try {
      final bytes = await File(await _pdfPath()).readAsBytes();
      if (!mounted) return;
      final uri = await FilePicker.saveFile(
        fileName: '${p.basenameWithoutExtension(widget.path)}.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: context.l10n.officeSaveAsPdf,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(uri == null ? l10n.officePdfNotSaved : l10n.officePdfSaved)),
        );
    } on Object catch (e) {
      _pdfFailed(e);
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _pdfFailed(Object e) {
    if (!mounted) return;
    final message = e is ProcessException ? e.message : '$e';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _soffice != null
                ? context.l10n.officeConvertFailed(message)
                : context.l10n.officePdfFailed(message),
          ),
        ),
      );
  }

  // ------------------------------------------------------------- tampilan

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final actions = <Widget>[
      if (doc != null)
        IconButton(
          tooltip: context.l10n.findTooltip,
          icon: const Icon(Icons.search),
          onPressed: _openFind,
        ),
      if (doc != null && !doc.isPresentation) ...<Widget>[
        IconButton(
          tooltip: context.l10n.officeTextSmaller,
          icon: const Icon(Icons.text_decrease),
          onPressed: _textScale > 0.7
              ? () => setState(() => _textScale = math.max(0.7, _textScale - 0.1))
              : null,
        ),
        IconButton(
          tooltip: context.l10n.officeTextLarger,
          icon: const Icon(Icons.text_increase),
          onPressed: _textScale < 2
              ? () => setState(() => _textScale = math.min(2, _textScale + 0.1))
              : null,
        ),
      ],
      if (doc != null && doc.isPresentation)
        IconButton(
          tooltip: context.l10n.officePlay,
          icon: const Icon(Icons.slideshow_outlined),
          onPressed: _converting ? null : () => _openAsPdf(present: true),
        ),
      if (doc != null)
        IconButton(
          tooltip: _soffice != null ? context.l10n.officeOpenExact : context.l10n.officeOpenAsPdf,
          icon: _converting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          onPressed: _converting ? null : _openAsPdf,
        ),
      DownloadFileButton(
        path: widget.path,
        onSavePdf: doc == null || _converting ? null : _saveAsPdf,
      ),
      if (canOpenWithSystem)
        IconButton(
          tooltip: context.l10n.filesOpenWithOtherApp,
          icon: const Icon(Icons.open_in_new),
          onPressed: () => openWithSystem(context, widget.path),
        ),
    ];

    final Widget body;
    if (_error != null) {
      body = Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)),
      );
    } else if (doc == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (doc.blocks.isEmpty && doc.slides.isEmpty) {
      body = Center(child: Text(context.l10n.officeEmpty));
    } else {
      body = Column(
        children: <Widget>[
          if (_finding)
            FindBar(
              initialQuery: _query,
              current: _current < 0 ? null : _current + 1,
              total: _query.trim().isEmpty ? null : _matches.length,
              onChanged: _search,
              onNext: () => _step(1),
              onPrevious: () => _step(-1),
              onClose: _closeFind,
            ),
          if (_textOnly)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _soffice != null
                            ? context.l10n.officeTextOnlyWithExact
                            : context.l10n.officeTextOnly,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: doc.isPresentation ? _slides(doc) : _sheet(doc),
              ),
            ),
          ),
        ],
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openFind,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openFind,
        const SingleActivator(LogicalKeyboardKey.f3): () => _finding ? _step(1) : _openFind(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: actions,
          ),
          body: body,
        ),
      ),
    );
  }

  // ------------------------------------------------------- dokumen Word

  Widget _sheet(OfficeDocument doc) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 32, 36, 40),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final block in doc.blocks) _block(block, constraints.maxWidth),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Ukuran huruf dasar dokumen Word dalam piksel logis (≈ 11 pt).
  double get _base => 15 * _textScale;

  Widget _block(OfficeBlock block, double width) => switch (block) {
    OfficeParagraph() => _docParagraph(block),
    OfficeTable() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _table(block, (p) => _docParagraph(p, compact: true)),
    ),
    OfficeImage() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(alignment: Alignment.centerLeft, child: _docImage(block, width)),
    ),
  };

  Widget _docImage(OfficeImage block, double width) {
    final shown = block.width == null ? null : math.min(width, block.width! * 1.33 * _textScale);
    final emf = EmfPicture.of(block.bytes);
    if (emf != null) {
      final w = shown ?? math.min(width, emf.bounds.width);
      return SizedBox(
        width: w,
        height: w * emf.bounds.height / emf.bounds.width,
        child: EmfImage(emf),
      );
    }
    return Image.memory(
      block.bytes,
      width: shown,
      fit: BoxFit.contain,
      // WMF dan format lain yang tidak bisa digambar Flutter.
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _docParagraph(OfficeParagraph para, {bool compact = false}) {
    final heading = para.heading;
    final factor = switch (heading) {
      1 => 1.6,
      2 => 1.35,
      3 => 1.18,
      0 => 1.0,
      _ => 1.08,
    };
    final text = _rich(
      para,
      baseSize: _base * factor,
      sizeScale: 1.36 * _textScale,
      bold: heading > 0,
      color: const Color(0xFF1F1F1F),
    );
    final top = compact ? 2.0 : (heading > 0 ? 14.0 : 4.0);
    final bottom = compact ? 2.0 : (heading > 0 ? 6.0 : 6.0);
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom, left: para.level * 22.0),
      child: para.bullet == null
          ? text
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 28,
                  child: Text(
                    para.bullet!,
                    style: TextStyle(fontSize: _base, color: const Color(0xFF1F1F1F)),
                  ),
                ),
                Expanded(child: text),
              ],
            ),
    );
  }

  Widget _table(OfficeTable table, Widget Function(OfficeParagraph) paragraph) {
    final columns = table.rows.fold<int>(0, (m, r) => math.max(m, r.length));
    if (columns == 0) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: math.min(columns * 120.0, 780)),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: const Color(0xFFBDBDBD), width: 0.7),
          children: <TableRow>[
            for (final row in table.rows)
              TableRow(
                children: <Widget>[
                  for (var c = 0; c < columns; c++)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[if (c < row.length) ...row[c].map(paragraph)],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Teks paragraf dengan gaya tiap potongannya, dan hasil pencarian
  /// disorot. Paragraf yang memuat hasil aktif diberi [_currentKey] supaya
  /// bisa digulir ke sana.
  Widget _rich(
    OfficeParagraph para, {
    required double baseSize,
    required double sizeScale,
    bool bold = false,
    Color? color,
    bool softWrap = true,
  }) {
    final index = _index[para];
    final matches = index == null ? null : _matchesByParagraph[index];
    final active = _current >= 0 && index != null && _matches[_current].paragraph == index
        ? _matches[_current]
        : null;
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final run in para.runs) {
      // Superskrip/subskrip cukup diperkecil: TextStyle tidak bisa menggeser
      // garis dasar, dan WidgetSpan memutus sorotan hasil pencarian.
      final size =
          (run.size == null ? baseSize : run.size! * sizeScale) * (run.script == 0 ? 1 : 0.65);
      final style = TextStyle(
        fontSize: size,
        fontWeight: run.bold || bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
        decoration: TextDecoration.combine(<TextDecoration>[
          if (run.underline) TextDecoration.underline,
          if (run.strike) TextDecoration.lineThrough,
        ]),
        color: run.link != null ? const Color(0xFF1A56B0) : (run.color ?? color),
        height: 1.35,
      );
      final start = offset;
      final end = offset + run.text.length;
      offset = end;
      // Huruf kapital dari gaya (`cap="all"`); hanya bila panjangnya tetap,
      // supaya letak hasil pencarian tidak bergeser.
      final upper = run.caps ? run.text.toUpperCase() : run.text;
      final shown = upper.length == run.text.length ? upper : run.text;
      if (matches == null) {
        spans.add(TextSpan(text: shown, style: style));
        continue;
      }
      // Potong run di batas hasil pencarian.
      var cursor = start;
      for (final m in matches) {
        if (m.end <= cursor || m.start >= end) continue;
        final from = math.max(m.start, cursor);
        final to = math.min(m.end, end);
        if (from > cursor) {
          spans.add(TextSpan(text: shown.substring(cursor - start, from - start), style: style));
        }
        spans.add(
          TextSpan(
            text: shown.substring(from - start, to - start),
            style: style.copyWith(
              backgroundColor: identical(m, active)
                  ? const Color(0xFFFF9632)
                  : const Color(0xFFFFE066),
              color: const Color(0xFF000000),
            ),
          ),
        );
        cursor = to;
      }
      if (cursor < end) spans.add(TextSpan(text: shown.substring(cursor - start), style: style));
    }
    return Text.rich(
      TextSpan(children: spans),
      key: active != null ? _currentKey : null,
      softWrap: softWrap,
      textAlign: switch (para.align) {
        OfficeAlign.center => TextAlign.center,
        OfficeAlign.end => TextAlign.end,
        OfficeAlign.justify => TextAlign.justify,
        OfficeAlign.start => TextAlign.start,
      },
      textScaler: TextScaler.noScaling,
    );
  }

  // ---------------------------------------------------------- PowerPoint

  Widget _slides(OfficeDocument doc) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final slide in doc.slides) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
              child: Text(
                context.l10n.officeSlideN(slide.number),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            if (slide.hasLayout)
              Material(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(4),
                child: AspectRatio(
                  aspectRatio: doc.slideSize.width / doc.slideSize.height,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox.fromSize(size: doc.slideSize, child: _slideCanvas(slide)),
                  ),
                ),
              )
            else
              _plainSlide(slide),
            if (slide.notes.isNotEmpty) _notes(slide),
            const SizedBox(height: 22),
          ],
        ],
      ),
    ),
  );

  Widget _slideCanvas(OfficeSlide slide) => Stack(
    clipBehavior: Clip.hardEdge,
    children: <Widget>[
      Positioned.fill(child: ColoredBox(color: slide.background ?? Colors.white)),
      if (slide.backgroundImage != null)
        Positioned.fill(
          child: Image.memory(
            slide.backgroundImage!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
      for (final shape in slide.shapes)
        if (shape.frame != null)
          Positioned.fromRect(
            rect: shape.frame!,
            child: Transform.rotate(angle: shape.rotation * math.pi / 180, child: _shape(shape)),
          ),
    ],
  );

  Widget _shape(OfficeShape shape) {
    final image = shape.image;
    if (image != null) {
      final emf = EmfPicture.of(image);
      if (emf != null) return EmfImage(emf);
      return Image.memory(
        image,
        fit: BoxFit.fill,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      );
    }
    final table = shape.table;
    if (table != null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: _table(
          table,
          (p) => _rich(p, baseSize: 14, sizeScale: 1, color: const Color(0xFF1F1F1F)),
        ),
      );
    }
    final decoration = ShapeDecoration(
      color: shape.fill,
      shape: switch (shape.geometry) {
        OfficeGeometry.ellipse => OvalBorder(
          side: shape.line == null ? BorderSide.none : BorderSide(color: shape.line!, width: 1),
        ),
        OfficeGeometry.rounded => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: shape.line == null ? BorderSide.none : BorderSide(color: shape.line!, width: 1),
        ),
        OfficeGeometry.rect => RoundedRectangleBorder(
          side: shape.line == null ? BorderSide.none : BorderSide(color: shape.line!, width: 1),
        ),
      },
    );
    final alignment = switch (shape.anchor) {
      OfficeAnchor.top => Alignment.topLeft,
      OfficeAnchor.center => Alignment.centerLeft,
      OfficeAnchor.bottom => Alignment.bottomLeft,
    };
    return DecoratedBox(
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7.2, vertical: 3.6),
        // Teks yang lebih panjang dari kotaknya tetap terlihat, seperti di
        // PowerPoint, dan tidak membuat galat tata letak.
        // Tinggi minimum 0: tanpa itu kotaknya memaksa teks setinggi bentuk,
        // dan jangkar tengah/bawah tidak berlaku.
        child: OverflowBox(
          alignment: alignment,
          minHeight: 0,
          maxHeight: double.infinity,
          minWidth: shape.wrap ? null : 0,
          maxWidth: shape.wrap ? null : double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Tanpa pembungkusan baris lebarnya tak terbatas: tidak bisa
            // direntangkan.
            crossAxisAlignment: shape.wrap ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
            children: <Widget>[
              for (final para in shape.paragraphs) _slideParagraph(para, shape.wrap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slideParagraph(OfficeParagraph para, bool wrap) {
    final size = para.runs.isEmpty ? 18.0 : (para.runs.first.size ?? 18.0);
    final color = para.runs.isEmpty ? null : para.runs.first.color;
    final text = _rich(para, baseSize: size, sizeScale: 1, softWrap: wrap);
    if (para.isEmpty) return SizedBox(height: size * 1.2);
    return Padding(
      padding: EdgeInsets.only(left: para.level * size * 1.1, bottom: size * 0.2),
      child: para.bullet == null
          ? text
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: wrap ? MainAxisSize.max : MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: size * 1.1,
                  child: Text(
                    para.bullet!,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: size, color: color, height: 1.35),
                  ),
                ),
                if (wrap) Flexible(child: text) else text,
              ],
            ),
    );
  }

  /// Slide `.ppt` lama: hanya teks, judul di atas.
  Widget _plainSlide(OfficeSlide slide) => Material(
    color: Colors.white,
    elevation: 2,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final shape in slide.shapes)
            for (final para in shape.paragraphs)
              Padding(
                padding: EdgeInsets.only(bottom: shape.isTitle ? 12 : 6),
                child: para.bullet == null
                    ? _rich(
                        para,
                        baseSize: shape.isTitle ? 26 : 17,
                        sizeScale: shape.isTitle ? 0.8 : 0.85,
                        color: const Color(0xFF1F1F1F),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 22,
                            child: Text(
                              para.bullet!,
                              style: const TextStyle(fontSize: 17, color: Color(0xFF1F1F1F)),
                            ),
                          ),
                          Expanded(
                            child: _rich(
                              para,
                              baseSize: 17,
                              sizeScale: 0.85,
                              color: const Color(0xFF1F1F1F),
                            ),
                          ),
                        ],
                      ),
              ),
        ],
      ),
    ),
  );

  Widget _notes(OfficeSlide slide) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.officeSpeakerNotes,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          for (final para in slide.notes)
            _rich(para, baseSize: 14, sizeScale: 1, color: scheme.onSurface),
        ],
      ),
    );
  }
}
