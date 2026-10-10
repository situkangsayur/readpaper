import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../domain/table_data.dart';
import '../open_any_file.dart';

/// Menampilkan CSV, TSV, atau Excel (`.xlsx`) sebagai tabel, hanya untuk
/// dibaca. Lembar-lembar Excel jadi tab; menyunting tetap di aplikasi
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

  Future<List<TableSheet>> _load() async {
    final path = widget.path;
    final bytes = await File(path).readAsBytes();
    // Lembar besar dibaca di isolat lain supaya layar tidak membeku.
    return Isolate.run(() => TableData.read(p.basename(path), bytes));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TableSheet>>(
    future: _sheets,
    builder: (context, snapshot) {
      final sheets = snapshot.data ?? const <TableSheet>[];
      final title = widget.title ?? p.basename(widget.path);
      final actions = <Widget>[
        if (canOpenWithSystem)
          IconButton(
            tooltip: 'Buka dengan aplikasi lain',
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
              child: Text('Tabel ini tidak bisa dibaca: ${snapshot.error}'),
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
          body: const Center(child: Text('Tidak ada lembar di berkas ini.')),
        );
      }
      return DefaultTabController(
        length: sheets.length,
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
          body: TabBarView(children: <Widget>[for (final s in sheets) _SheetView(sheet: s)]),
        ),
      );
    },
  );
}

class _SheetView extends StatelessWidget {
  const _SheetView({required this.sheet});

  final TableSheet sheet;

  static const double _cellWidth = 160;
  static const double _rowHeight = 30;
  static const double _numberWidth = 52;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall;
    final columns = sheet.columnCount;
    if (sheet.rows.isEmpty || columns == 0) {
      return const Center(child: Text('Lembar ini kosong.'));
    }
    final width = _numberWidth + columns * _cellWidth;

    Widget cell(String text, {bool header = false}) => Container(
      width: _cellWidth,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: header ? scheme.surfaceContainerHigh : null,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant, width: 0.5),
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Tooltip(
        message: text.length > 24 ? text : '',
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: ListView.builder(
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
                          cell(c < row.length ? row[c] : '', header: index == 0),
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
            child: Text(
              'Hanya ${TableData.maxRows} baris pertama yang ditampilkan. '
              'Buka dengan aplikasi lain untuk melihat semuanya.',
              style: style,
            ),
          ),
      ],
    );
  }
}
