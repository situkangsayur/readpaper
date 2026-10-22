import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../../core/widgets/find_bar.dart';
import '../../../office/data/office_pdf.dart';
import '../../domain/table_data.dart';
import '../open_any_file.dart';
import '../../../../core/l10n.dart';

/// Menampilkan CSV, TSV, Excel (`.xlsx`, `.xls`), atau Calc (`.ods`) sebagai tabel, hanya
/// untuk dibaca, dan bisa dicari. Lembar-lembar Excel jadi tab; menyunting tetap di aplikasi
/// spreadsheet lewat "Buka dengan aplikasi lain".
class TableViewerScreen extends StatefulWidget {
  const TableViewerScreen({required this.path, this.title, super.key});

  final String path;
  final String? title;

  @override
  State<TableViewerScreen> createState() => _TableViewerScreenState();
}

class _TableViewerScreenState extends State<TableViewerScreen> {
  late final Future<List<TableSheet>> _sheets = _load();

  // Cari: sel yang memuat kata, di semua lembar, sebagai (lembar, baris, kolom).
  bool _finding = false;
  String _query = '';
  List<(int, int, int)> _hits = const <(int, int, int)>[];
  int _hit = -1;

  void _find(List<TableSheet> sheets, String query, TabController? tabs) {
    final needle = query.trim().toLowerCase();
    final hits = <(int, int, int)>[];
    if (needle.isNotEmpty) {
      for (var s = 0; s < sheets.length; s++) {
        final rows = sheets[s].rows;
        for (var r = 0; r < rows.length; r++) {
          for (var c = 0; c < rows[r].length; c++) {
            if (rows[r][c].toLowerCase().contains(needle)) hits.add((s, r, c));
          }
        }
      }
    }
    final current = tabs?.index ?? 0;
    final first = hits.indexWhere((h) => h.$1 >= current);
    setState(() {
      _query = query;
      _hits = hits;
      _hit = hits.isEmpty ? -1 : (first < 0 ? 0 : first);
    });
    _showSheet(tabs);
  }

  void _step(int delta, TabController? tabs) {
    if (_hits.isEmpty) return;
    setState(() => _hit = (_hit + delta) % _hits.length);
    _showSheet(tabs);
  }

  void _showSheet(TabController? tabs) {
    if (_hit < 0 || tabs == null) return;
    final sheet = _hits[_hit].$1;
    if (tabs.index != sheet) tabs.animateTo(sheet);
  }

  void _closeFind() => setState(() {
    _finding = false;
    _hits = const <(int, int, int)>[];
    _hit = -1;
  });

  Future<List<TableSheet>> _load() async {
    final path = widget.path;
    final bytes = await File(path).readAsBytes();
    // Lembar besar dibaca di isolat lain supaya layar tidak membeku.
    return Isolate.run(() => TableData.read(p.basename(path), bytes));
  }

  /// Lembar-lembarnya sebagai PDF (mendatar, satu lembar per bagian).
  Future<void> _saveAsPdf(List<TableSheet> sheets) async {
    final messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.officeMakingPdf)));
    try {
      final bytes = await OfficePdf.sheets(sheets);
      if (!mounted) return;
      final uri = await FilePicker.saveFile(
        fileName: '${p.basenameWithoutExtension(widget.path)}.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: context.l10n.officeSaveAsPdf,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(uri == null ? l10n.officePdfNotSaved : l10n.officePdfSaved)),
        );
    } on Object catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.officePdfFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TableSheet>>(
    future: _sheets,
    builder: (context, snapshot) {
      final sheets = snapshot.data ?? const <TableSheet>[];
      final title = widget.title ?? p.basename(widget.path);
      final actions = <Widget>[
        if (sheets.isNotEmpty)
          IconButton(
            tooltip: context.l10n.findTooltip,
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _finding = true),
          ),
        DownloadFileButton(
          path: widget.path,
          onSavePdf: sheets.isEmpty ? null : () => _saveAsPdf(sheets),
        ),
        if (canOpenWithSystem)
          IconButton(
            tooltip: context.l10n.filesOpenWithOtherApp,
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openWithSystem(context, widget.path),
          ),
      ];
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.l10n.filesTableUnreadable('${snapshot.error}')),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (sheets.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          body: Center(child: Text(context.l10n.filesNoSheets)),
        );
      }
      return DefaultTabController(
        length: sheets.length,
        child: Builder(
          builder: (context) {
            final tabs = DefaultTabController.maybeOf(context);
            void openFind() => setState(() => _finding = true);
            final active = _hit >= 0 ? _hits[_hit] : null;
            return CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.keyF, control: true): openFind,
                const SingleActivator(LogicalKeyboardKey.keyF, meta: true): openFind,
              },
              child: Focus(
                autofocus: true,
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(title),
                    actions: actions,
                    bottom: sheets.length > 1
                        ? TabBar(
                            isScrollable: true,
                            tabs: <Widget>[for (final s in sheets) Tab(text: s.name)],
                          )
                        : null,
                  ),
                  body: Column(
                    children: <Widget>[
                      if (_finding)
                        FindBar(
                          initialQuery: _query,
                          current: _hit < 0 ? null : _hit + 1,
                          total: _query.trim().isEmpty ? null : _hits.length,
                          onChanged: (q) => _find(sheets, q, tabs),
                          onNext: () => _step(1, tabs),
                          onPrevious: () => _step(-1, tabs),
                          onClose: _closeFind,
                        ),
                      Expanded(
                        child: TabBarView(
                          children: <Widget>[
                            for (var i = 0; i < sheets.length; i++)
                              _SheetView(
                                sheet: sheets[i],
                                query: _finding ? _query : '',
                                active: active != null && active.$1 == i
                                    ? (active.$2, active.$3)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _SheetView extends StatefulWidget {
  const _SheetView({required this.sheet, this.query = '', this.active});

  final TableSheet sheet;

  /// Kata yang dicari; sel yang memuatnya disorot.
  final String query;

  /// Sel hasil yang sedang dituju (baris, kolom), digulir sampai terlihat.
  final (int, int)? active;

  @override
  State<_SheetView> createState() => _SheetViewState();
}

class _SheetViewState extends State<_SheetView> {
  static const double _cellWidth = 160;
  static const double _rowHeight = 30;
  static const double _numberWidth = 52;

  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(_SheetView old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) _reveal();
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _reveal() {
    final active = widget.active;
    if (active == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final (row, col) = active;
      if (_vertical.hasClients) {
        final view = _vertical.position.viewportDimension;
        final target = (row * _rowHeight - view / 3).clamp(0.0, _vertical.position.maxScrollExtent);
        _vertical.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      if (_horizontal.hasClients) {
        final view = _horizontal.position.viewportDimension;
        final left = _numberWidth + col * _cellWidth;
        final offset = _horizontal.offset;
        if (left < offset || left + _cellWidth > offset + view) {
          final target = (left - view / 3).clamp(0.0, _horizontal.position.maxScrollExtent);
          _horizontal.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    final needle = widget.query.trim().toLowerCase();
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall;
    final columns = sheet.columnCount;
    if (sheet.rows.isEmpty || columns == 0) {
      return Center(child: Text(context.l10n.filesSheetEmpty));
    }
    final width = _numberWidth + columns * _cellWidth;

    Widget cell(String text, {bool header = false, bool hit = false, bool active = false}) =>
        Container(
          width: _cellWidth,
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFF9632)
                : hit
                ? const Color(0xFFFFE066)
                : header
                ? scheme.surfaceContainerHigh
                : null,
            border: Border(
              right: BorderSide(color: scheme.outlineVariant, width: 0.5),
              bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          child: Tooltip(
            message: text.length > 24 ? text : '',
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hit || active ? style?.copyWith(color: Colors.black) : style,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Scrollbar(
            controller: _horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: ListView.builder(
                  controller: _vertical,
                  itemExtent: _rowHeight,
                  itemCount: sheet.rows.length,
                  itemBuilder: (context, index) {
                    final row = sheet.rows[index];
                    return Row(
                      children: <Widget>[
                        Container(
                          width: _numberWidth,
                          height: _rowHeight,
                          alignment: Alignment.center,
                          color: scheme.surfaceContainerHighest,
                          child: Text('${index + 1}', style: style),
                        ),
                        for (var c = 0; c < columns; c++)
                          cell(
                            c < row.length ? row[c] : '',
                            header: index == 0,
                            hit:
                                needle.isNotEmpty &&
                                c < row.length &&
                                row[c].toLowerCase().contains(needle),
                            active: widget.active == (index, c),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (sheet.rows.length >= TableData.maxRows)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(context.l10n.filesOnlyFirstRows(TableData.maxRows), style: style),
          ),
      ],
    );
  }
}
