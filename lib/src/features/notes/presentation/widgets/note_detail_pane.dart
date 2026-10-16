import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/utils/layout_size.dart';
import '../../domain/note_entities.dart';
import '../controllers/notes_controller.dart';
import 'note_list_pane.dart';

/// Panel kanan saat yang dipilih ada di bawah akar catatan — padanan panel
/// keterangan paper di My Library.
///
/// Dulu mengetuk catatan langsung membukanya, dan tidak ada tempat untuk
/// melihat atau menambah apa pun tentang catatan itu selain judulnya. Di sini
/// keterangannya tampil, bisa diubah, dan berkasnya dibuka dengan satu tombol.
class NoteDetailPane extends ConsumerWidget {
  const NoteDetailPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(selectedNoteKeyProvider);
    final index = ref.watch(notesControllerProvider).value ?? NotesIndex.empty;
    final note = key == null ? null : index.items.firstWhereOrNull((n) => n.key == key);
    if (note == null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.notesPickNote)),
      );
    }

    final theme = Theme.of(context);
    final file = File(p.join(index.directory, note.file));
    final size = file.existsSync() ? humanFileSize(file.lengthSync()) : null;
    final collections = <String>[
      for (final k in note.collectionKeys)
        ?index.collections.firstWhereOrNull((c) => c.key == k)?.name,
    ];

    return ListView(
      key: ValueKey<String>(note.key),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (LayoutSize.of(context).isCompact)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: context.l10n.notesBackToList,
                onPressed: () => ref.read(selectedNoteKeyProvider.notifier).select(null),
              ),
            Expanded(child: SelectableText(note.title, style: theme.textTheme.titleLarge)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Icon(noteIcon(note)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(p.basename(note.file), maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (size != null) Text(size, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(context.l10n.notesOpen),
                  onPressed: () => openNote(context, ref, note, index),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                context.l10n.notesDetails.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_note, size: 18),
              label: Text(
                note.hasDetails ? context.l10n.notesEditDetails : context.l10n.notesAddDetails,
              ),
              onPressed: () => editNoteDetails(context, ref, note),
            ),
          ],
        ),
        if (!note.hasDetails)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              context.l10n.notesNoDetails,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        if (note.authors.isNotEmpty) _Row(context.l10n.notesFieldAuthors, note.authors.join('; ')),
        if (note.date.isNotEmpty) _Row(context.l10n.notesFieldDate, note.date),
        if (note.tags.isNotEmpty)
          _Row(
            context.l10n.notesFieldTags,
            '',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final tag in note.tags)
                  Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        if (note.source.isNotEmpty)
          _Row(
            context.l10n.notesFieldSource,
            note.source,
            link: Uri.tryParse(note.source)?.hasScheme ?? false,
          ),
        if (note.description.isNotEmpty) _Row(context.l10n.notesFieldDescription, note.description),
        const SizedBox(height: 8),
        if (collections.isNotEmpty)
          _Row(context.l10n.notesFieldCollections, collections.join(' · ')),
        _Row(context.l10n.notesFieldAdded, noteTimestamp(note.dateAdded)),
        _Row(context.l10n.notesFieldModified, noteTimestamp(note.dateModified)),
        _Row(context.l10n.notesFieldFile, note.file),
        const SizedBox(height: 20),
        const Divider(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.more_horiz, size: 18),
            label: Text(context.l10n.notesMoreActions),
            onPressed: () => showNoteMenu(context, ref, note),
          ),
        ),
      ],
    );
  }
}

/// Ikon jenis berkas catatan, sama dengan yang di daftar.
IconData noteIcon(NoteItem note) => note.isNotebook
    ? Icons.auto_stories_outlined
    : switch (note.extension) {
        '.pdf' => Icons.picture_as_pdf_outlined,
        '.md' || '.txt' => Icons.notes_outlined,
        '.png' || '.jpg' || '.jpeg' || '.webp' => Icons.image_outlined,
        '.pptx' || '.ppt' || '.odp' => Icons.slideshow_outlined,
        '.docx' || '.doc' || '.odt' => Icons.description_outlined,
        '.xlsx' || '.xls' || '.csv' || '.ods' => Icons.table_chart_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.child, this.link = false});

  final String label;
  final String value;
  final Widget? child;
  final bool link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child:
                child ??
                (link
                    ? InkWell(
                        onTap: () =>
                            launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication),
                        child: Text(
                          value,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    : SelectableText(value, style: theme.textTheme.bodySmall)),
          ),
        ],
      ),
    );
  }
}

/// Formulir judul dan keterangan sebuah catatan.
Future<void> editNoteDetails(BuildContext context, WidgetRef ref, NoteItem note) async {
  final saved = await showDialog<_Details>(
    context: context,
    builder: (_) => _DetailsDialog(note: note),
  );
  if (saved == null) return;
  await ref
      .read(notesControllerProvider.notifier)
      .updateDetails(
        itemKey: note.key,
        title: saved.title,
        authors: saved.authors,
        date: saved.date,
        tags: saved.tags,
        source: saved.source,
        description: saved.description,
      );
}

typedef _Details = ({
  String title,
  List<String> authors,
  String date,
  List<String> tags,
  String source,
  String description,
});

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({required this.note});

  final NoteItem note;

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _authors = TextEditingController(text: widget.note.authors.join('\n'));
  late final _date = TextEditingController(text: widget.note.date);
  late final _tags = TextEditingController(text: widget.note.tags.join(', '));
  late final _source = TextEditingController(text: widget.note.source);
  late final _description = TextEditingController(text: widget.note.description);

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _title,
      _authors,
      _date,
      _tags,
      _source,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    Navigator.of(context).pop<_Details>((
      title: _title.text,
      // Penulis per baris, bukan per koma: "Bishop, C. M." satu orang.
      authors: _authors.text.split('\n'),
      date: _date.text,
      tags: _tags.text.split(RegExp('[,;\n]')),
      source: _source.text,
      description: _description.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    InputDecoration field(String label, [String? hint]) =>
        InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());
    return AlertDialog(
      title: Text(l10n.notesEditDetails),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _title,
                autofocus: true,
                decoration: field(l10n.notesTitleField),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _authors,
                minLines: 1,
                maxLines: 4,
                decoration: field(l10n.notesFieldAuthors, l10n.notesFieldAuthorsHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _date,
                decoration: field(l10n.notesFieldDate, l10n.notesFieldDateHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: field(l10n.notesFieldTags, l10n.notesFieldTagsHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _source,
                keyboardType: TextInputType.url,
                decoration: field(l10n.notesFieldSource, l10n.notesFieldSourceHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 6,
                decoration: field(l10n.notesFieldDescription),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.notesCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.notesSave)),
      ],
    );
  }
}
