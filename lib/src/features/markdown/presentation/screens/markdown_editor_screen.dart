import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../../../../core/utils/share_file.dart';
import '../../../../core/utils/layout_size.dart';
import '../../data/markdown_pdf.dart';
import '../../domain/markdown_doc.dart';
import '../widgets/markdown_view.dart';

/// Apa yang sedang ditampilkan.
enum MarkdownPane { sunting, pratinjau, keduanya }

/// Membaca dan menyunting satu berkas Markdown.
///
/// Pratinjaunya bisa diketuk: ketukan di sebuah blok — terutama diagram
/// mermaid — membawa kursor ke barisnya di sumber. Itulah yang membuat
/// diagram "bisa disunting" dan bukan sekadar dilihat.
class MarkdownEditorScreen extends StatefulWidget {
  const MarkdownEditorScreen({
    required this.path,
    this.title,
    this.startInEdit = false,
    super.key,
  });

  /// Berkas `.md` yang dibuka. Boleh belum ada — dibuat saat disimpan.
  final String path;

  final String? title;

  /// Berkas baru dibuka langsung di mode sunting; berkas yang sudah ada
  /// dibuka untuk dibaca.
  final bool startInEdit;

  @override
  State<MarkdownEditorScreen> createState() => _MarkdownEditorScreenState();
}

class _MarkdownEditorScreenState extends State<MarkdownEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _editScroll = ScrollController();
  final FocusNode _focus = FocusNode();

  MarkdownDoc _doc = MarkdownDoc.empty;
  late MarkdownPane _pane = widget.startInEdit ? MarkdownPane.sunting : MarkdownPane.pratinjau;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _editScroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Membaca berkasnya — langsung, tanpa menunggu.
  ///
  /// Catatan berukuran beberapa kilobita, dan membacanya sekejap. Yang
  /// ditukar di sini adalah sepersekian milidetik dengan hilangnya seluruh
  /// keadaan "sedang memuat": layar yang terbuka sudah berisi teksnya, dan
  /// tidak pernah ada putaran tunggu yang menggantung.
  void _load() {
    try {
      final file = File(widget.path);
      final text = file.existsSync() ? file.readAsStringSync() : '';
      _controller.text = text;
      _doc = MarkdownDoc.parse(text);
    } on Object catch (e) {
      _error = 'Gagal membaca berkas: $e';
    }
  }

  void _onChanged() {
    // Diurai ulang di setiap ketikan. Dokumen catatan berukuran ribuan huruf,
    // dan penguraiannya sekadar membaca baris — jauh lebih murah daripada
    // menyusun ulang tampilannya, yang memang harus terjadi.
    setState(() {
      _doc = MarkdownDoc.parse(_controller.text);
      _dirty = true;
    });
  }

  Future<bool> _save() async {
    try {
      final file = File(widget.path);
      // Ditulis langsung juga: begitu "Tersimpan" muncul, berkasnya memang
      // sudah ada di disk — bukan sedang dalam perjalanan ke sana.
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(_controller.text, flush: true);
      if (!mounted) return true;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Tersimpan: ${p.basename(widget.path)}')));
      return true;
    } on Object catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      return false;
    }
  }

  /// Membagikan dokumen ini ke aplikasi lain, sebagai Markdown atau PDF.
  ///
  /// Yang belum disimpan disimpan dulu: yang dibagikan harus yang terlihat di
  /// layar, bukan versi terakhir di disk. PDF-nya dibuat di folder sementara,
  /// tidak menambah berkas di sebelah catatannya.
  Future<void> _share({required bool asPdf}) async {
    if (_dirty && !await _save()) return;
    if (!mounted) return;
    final stem = p.basenameWithoutExtension(widget.path);
    final String? failure;
    if (asPdf) {
      final bytes = await MarkdownPdf.build(_doc, baseDir: p.dirname(widget.path));
      if (!mounted) return;
      failure = await shareBytes(context, bytes, '$stem.pdf', title: stem);
    } else {
      failure = await shareFile(context, widget.path, title: stem);
    }
    if (failure != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  /// Menulis dokumen ini sebagai PDF di sebelah berkasnya.
  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Menulis PDF…')));
    try {
      final bytes = await MarkdownPdf.build(_doc, baseDir: p.dirname(widget.path));
      final stem = p.basenameWithoutExtension(widget.path);
      var file = File(p.join(p.dirname(widget.path), '$stem.pdf'));
      for (var n = 2; file.existsSync() && n < 100; n++) {
        file = File(p.join(p.dirname(widget.path), '$stem-$n.pdf'));
      }
      file.writeAsBytesSync(bytes, flush: true);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('PDF tersimpan: ${p.basename(file.path)}'),
            action: SnackBarAction(
              label: 'Cetak',
              onPressed: () => Printing.layoutPdf(onLayout: (_) async => bytes),
            ),
          ),
        );
    } on Object catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menulis PDF: $e')));
    }
  }

  /// Membawa kursor ke baris awal sebuah blok, lalu membuka mode sunting.
  void _editBlock(MdBlock block) {
    final lines = _controller.text.split('\n');
    var offset = 0;
    for (var i = 0; i < block.startLine && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    final end = () {
      var to = offset;
      for (var i = block.startLine; i <= block.endLine && i < lines.length; i++) {
        to += lines[i].length + 1;
      }
      return (to - 1).clamp(offset, _controller.text.length);
    }();

    setState(() => _pane = _pane == MarkdownPane.keduanya ? _pane : MarkdownPane.sunting);
    _controller.selection = TextSelection(baseOffset: offset, extentOffset: end);
    _focus.requestFocus();
  }

  /// Menyisipkan cuplikan di posisi kursor.
  void _insert(String snippet, {int? caretBack}) {
    final selection = _controller.selection;
    final text = _controller.text;
    final at = selection.isValid ? selection.start : text.length;
    final before = text.substring(0, at);
    final after = text.substring(selection.isValid ? selection.end : text.length);
    // Cuplikan blok selalu mulai di barisnya sendiri.
    final prefix = (snippet.startsWith('\n') || before.isEmpty || before.endsWith('\n'))
        ? ''
        : '\n';
    final inserted = '$prefix$snippet';
    _controller.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(
        offset: before.length + inserted.length - (caretBack ?? 0),
      ),
    );
    setState(() => _pane = _pane == MarkdownPane.pratinjau ? MarkdownPane.sunting : _pane);
    _focus.requestFocus();
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Simpan dulu?'),
        content: const Text('Ada perubahan yang belum disimpan.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop('batal'),
            child: const Text('Kembali menyunting'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop('buang'),
            child: const Text('Buang perubahan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop('simpan'),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (choice == 'simpan') return _save();
    return choice == 'buang';
  }

  @override
  Widget build(BuildContext context) {
    final wide = LayoutSize.of(context) != LayoutSize.compact;
    final pane = (!wide && _pane == MarkdownPane.keduanya) ? MarkdownPane.pratinjau : _pane;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (!leave || !mounted) return;
        Navigator.of(this.context).pop(_controller.text);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.title ?? p.basenameWithoutExtension(widget.path)),
              Text(
                _dirty ? 'Belum disimpan' : p.basename(widget.path),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: <Widget>[
            SegmentedButton<MarkdownPane>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: <ButtonSegment<MarkdownPane>>[
                const ButtonSegment<MarkdownPane>(
                  value: MarkdownPane.sunting,
                  icon: Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Sunting',
                ),
                const ButtonSegment<MarkdownPane>(
                  value: MarkdownPane.pratinjau,
                  icon: Icon(Icons.visibility_outlined, size: 18),
                  tooltip: 'Pratinjau',
                ),
                if (wide)
                  const ButtonSegment<MarkdownPane>(
                    value: MarkdownPane.keduanya,
                    icon: Icon(Icons.vertical_split_outlined, size: 18),
                    tooltip: 'Keduanya',
                  ),
              ],
              selected: <MarkdownPane>{pane},
              onSelectionChanged: (value) => setState(() => _pane = value.first),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Lainnya',
              onSelected: (value) => switch (value) {
                'pdf' => _exportPdf(),
                'bagikan' => _share(asPdf: false),
                'bagikan-pdf' => _share(asPdf: true),
                'salin' => Clipboard.setData(ClipboardData(text: _controller.text)),
                _ => null,
              },
              itemBuilder: (menu) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'pdf',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Simpan sebagai PDF'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'bagikan',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.share_outlined),
                    title: Text('Bagikan berkas Markdown'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'bagikan-pdf',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.ios_share),
                    title: Text('Bagikan sebagai PDF'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'salin',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.copy_all_outlined),
                    title: Text('Salin seluruh teks'),
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Simpan',
              icon: const Icon(Icons.save_outlined),
              onPressed: _dirty ? _save : null,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : Column(
                children: <Widget>[
                  if (pane != MarkdownPane.pratinjau) _Toolbar(onInsert: _insert),
                  Expanded(
                    child: switch (pane) {
                      MarkdownPane.sunting => _editor(),
                      MarkdownPane.pratinjau => _preview(),
                      MarkdownPane.keduanya => Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(child: _editor()),
                          const VerticalDivider(width: 1),
                          Expanded(child: _preview()),
                        ],
                      ),
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _editor() => Scrollbar(
    controller: _editScroll,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _editScroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.45),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Tulis di sini. Markdown: # tajuk, **tebal**, - daftar, ```mermaid diagram.',
        ),
      ),
    ),
  );

  Widget _preview() => MarkdownView(
    doc: _doc,
    baseDir: p.dirname(widget.path),
    onEditBlock: _editBlock,
  );
}

/// Tombol sisip untuk hal-hal yang sulit diingat tandanya.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onInsert});

  final void Function(String snippet, {int? caretBack}) onInsert;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _Insert(
            icon: Icons.title,
            tooltip: 'Tajuk',
            onTap: () => onInsert('## Tajuk\n'),
          ),
          _Insert(
            icon: Icons.format_bold,
            tooltip: 'Tebal',
            onTap: () => onInsert('****', caretBack: 2),
          ),
          _Insert(
            icon: Icons.format_italic,
            tooltip: 'Miring',
            onTap: () => onInsert('**', caretBack: 1),
          ),
          _Insert(
            icon: Icons.format_list_bulleted,
            tooltip: 'Daftar',
            onTap: () => onInsert('- '),
          ),
          _Insert(
            icon: Icons.checklist,
            tooltip: 'Daftar tugas',
            onTap: () => onInsert('- [ ] '),
          ),
          _Insert(
            icon: Icons.format_quote,
            tooltip: 'Kutipan',
            onTap: () => onInsert('> '),
          ),
          _Insert(
            icon: Icons.code,
            tooltip: 'Kode',
            onTap: () => onInsert('```\n\n```\n', caretBack: 5),
          ),
          _Insert(
            icon: Icons.table_chart_outlined,
            tooltip: 'Tabel',
            onTap: () => onInsert('| Kolom | Nilai |\n| --- | --- |\n|  |  |\n'),
          ),
          _Insert(
            icon: Icons.account_tree_outlined,
            tooltip: 'Diagram mermaid',
            onTap: () => onInsert(
              '```mermaid\ngraph TD\n  A[Mulai] --> B{Sudah?}\n  B -->|ya| C(Selesai)\n'
              '  B -->|belum| A\n```\n',
            ),
          ),
        ],
      ),
    ),
  );
}

class _Insert extends StatelessWidget {
  const _Insert({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    iconSize: 19,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon),
    onPressed: onTap,
  );
}
