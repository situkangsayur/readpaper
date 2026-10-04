import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../domain/markdown_doc.dart';
import 'mermaid_view.dart';

/// Menampilkan dokumen Markdown yang sudah dibaca.
///
/// Blok `mermaid` digambar sebagai diagram; blok kode lain tetap kode.
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    required this.doc,
    this.baseDir,
    this.onEditBlock,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 48),
    super.key,
  });

  final MarkdownDoc doc;

  /// Folder acuan untuk gambar berjalur relatif.
  final String? baseDir;

  /// Diketuk untuk menyunting satu blok; menerima baris awal blok itu.
  ///
  /// Inilah yang membuat diagram "bisa disunting" dan bukan hanya dilihat:
  /// ketukan di pratinjau membawa kursor ke sumbernya.
  final void Function(MdBlock block)? onEditBlock;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (doc.blocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Dokumen masih kosong.', style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    return ListView.builder(
      padding: padding,
      itemCount: doc.blocks.length,
      itemBuilder: (context, i) => _block(context, doc.blocks[i]),
    );
  }

  Widget _block(BuildContext context, MdBlock block) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    switch (block) {
      case MdHeading():
        final style = switch (block.level) {
          1 => text.headlineSmall,
          2 => text.titleLarge,
          3 => text.titleMedium,
          4 => text.titleSmall,
          _ => text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        };
        return Padding(
          padding: EdgeInsets.only(top: block.level <= 2 ? 20 : 14, bottom: 6),
          child: _spans(context, block.spans, style),
        );

      case MdParagraph():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: _spans(context, block.spans, text.bodyMedium),
        );

      case MdList():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < block.items.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: 4 + block.items[i].depth * 18.0, bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 26,
                        child: block.items[i].checked != null
                            ? Icon(
                                block.items[i].checked!
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank,
                                size: 16,
                                color: scheme.primary,
                              )
                            : Text(
                                block.ordered ? '${i + 1}.' : '•',
                                style: text.bodyMedium?.copyWith(color: scheme.primary),
                              ),
                      ),
                      Expanded(child: _spans(context, block.items[i].spans, text.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        );

      case MdQuote():
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: scheme.primary, width: 3)),
            color: scheme.surfaceContainerLow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final line in block.lines)
                _spans(context, line, text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ],
          ),
        );

      case MdCode():
        if (block.isMermaid) {
          return MermaidView(
            source: block.text,
            onEdit: onEditBlock == null ? null : () => onEditBlock!(block),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            onTap: onEditBlock == null ? null : () => onEditBlock!(block),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (block.language.isNotEmpty)
                    Text(block.language, style: text.labelSmall?.copyWith(color: scheme.outline)),
                  SelectableText(
                    block.text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        );

      case MdRule():
        return const Divider(height: 24);

      case MdTable():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 48,
              columns: <DataColumn>[
                for (final cell in block.header)
                  DataColumn(label: Text(cell, style: text.labelMedium)),
              ],
              rows: <DataRow>[
                for (final row in block.rows)
                  DataRow(
                    cells: <DataCell>[
                      for (var i = 0; i < block.header.length; i++)
                        DataCell(
                          _spans(
                            context,
                            MarkdownDoc.parseInline(i < row.length ? row[i] : ''),
                            text.bodySmall,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );

      case MdImage():
        final path = block.path;
        final file = p.isAbsolute(path) || baseDir == null
            ? File(path)
            : File(p.join(baseDir!, path));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (file.existsSync())
                Image.file(file, fit: BoxFit.contain)
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.image_not_supported_outlined, size: 18, color: scheme.outline),
                      const SizedBox(width: 8),
                      // Gambar yang tidak ada disebutkan jalurnya: itu satu-satunya
                      // keterangan yang berguna untuk memperbaikinya.
                      Expanded(child: Text(path, style: text.labelSmall)),
                    ],
                  ),
                ),
              if (block.alt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(block.alt, style: text.labelSmall),
                ),
            ],
          ),
        );
    }
  }

  Widget _spans(BuildContext context, List<MdSpan> spans, TextStyle? base) {
    final scheme = Theme.of(context).colorScheme;
    return SelectableText.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          for (final span in spans)
            TextSpan(
              text: span.text,
              style: (base ?? const TextStyle()).copyWith(
                fontWeight: span.bold ? FontWeight.w700 : null,
                fontStyle: span.italic ? FontStyle.italic : null,
                decoration: span.strike
                    ? TextDecoration.lineThrough
                    : (span.link != null ? TextDecoration.underline : null),
                fontFamily: span.code ? 'monospace' : null,
                backgroundColor: span.code ? scheme.surfaceContainerHighest : null,
                color: span.link != null ? scheme.primary : null,
              ),
              recognizer: span.link == null
                  ? null
                  : (TapGestureRecognizer()..onTap = () => _openLink(span.link!)),
            ),
        ],
      ),
    );
  }

  Future<void> _openLink(String target) async {
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    // Tautan berkas dibiarkan: membukanya di peramban tidak menolong siapa pun.
    if (!uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
