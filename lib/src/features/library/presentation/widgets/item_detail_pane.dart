import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/formatting.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../reader/presentation/screens/reader_screen.dart';
import '../../../workspace/presentation/controllers/workspace_controller.dart';
import '../../domain/entities/zotero_annotation.dart';
import '../../domain/entities/zotero_item.dart';
import '../controllers/library_controllers.dart';
import 'item_list_pane.dart' show itemTypeIcon;

/// The right pane: metadata, attachments, notes and the annotation list of the
/// selected item.
class ItemDetailPane extends ConsumerWidget {
  const ItemDetailPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(selectedItemProvider);
    if (item == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Pilih satu paper untuk melihat detailnya.'),
        ),
      );
    }

    final library = ref.watch(workspaceControllerProvider).library;
    final repository = ref.watch(libraryRepositoryProvider);

    return FutureBuilder<ItemDetail>(
      key: ValueKey<String>(item.key),
      future: repository.loadItem(item.filePath),
      builder: (context, snapshot) {
        final annotations = snapshot.data?.annotations ?? const <ZoteroAnnotation>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            _Title(item: item),
            const SizedBox(height: 16),
            _AttachmentSection(item: item, libraryDir: library?.directoryPath),
            const SizedBox(height: 20),
            _MetadataSection(item: item),
            if (item.abstractNote.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              _SectionTitle('Abstrak'),
              const SizedBox(height: 6),
              SelectableText(item.abstractNote, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (annotations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              _SectionTitle('Anotasi (${annotations.length})'),
              const SizedBox(height: 6),
              for (final annotation in annotations) _AnnotationRow(annotation: annotation),
            ],
            if (item.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              _SectionTitle('Catatan (${item.notes.length})'),
              const SizedBox(height: 6),
              for (final note in item.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SelectableText(
                    note.plainText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Title extends ConsumerWidget {
  const _Title({required this.item});

  final ZoteroItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (MediaQuery.sizeOf(context).width < 1000)
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali ke daftar',
          onPressed: () => ref.read(selectedItemKeyProvider.notifier).select(null),
        ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(item.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(itemTypeIcon(item.itemType), size: 14),
                const SizedBox(width: 6),
                Text(item.itemType, style: Theme.of(context).textTheme.labelSmall),
                if (item.year.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 12),
                  Text('· ${item.year}', style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _AttachmentSection extends ConsumerWidget {
  const _AttachmentSection({required this.item, required this.libraryDir});

  final ZoteroItem item;
  final String? libraryDir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.attachments.isEmpty) {
      return Text('Tidak ada lampiran.', style: Theme.of(context).textTheme.bodySmall);
    }
    final repository = ref.watch(libraryRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final attachment in item.attachments)
          _AttachmentCard(
            item: item,
            attachment: attachment,
            file: libraryDir == null
                ? null
                : repository.resolveAttachment(
                    libraryDir: libraryDir!,
                    attachment: attachment,
                  ),
          ),
      ],
    );
  }
}

class _AttachmentCard extends ConsumerWidget {
  const _AttachmentCard({required this.item, required this.attachment, required this.file});

  final ZoteroItem item;
  final ZoteroAttachment attachment;
  final File? file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repository = ref.watch(libraryRepositoryProvider);
    final isPointer = file != null && repository.isLfsPointer(file!);
    final canRead = file != null && !isPointer && attachment.isPdf;

    // On Android the mirror holds metadata only; a PDF is fetched when asked for.
    final lazy = ref.watch(gitBackendProvider).usesLazyAttachments;
    final libraryDir = ref.watch(workspaceControllerProvider).library?.directoryPath;
    final expected = file == null && lazy && libraryDir != null
        ? repository.attachmentLocation(libraryDir: libraryDir, attachment: attachment)
        : null;
    final busy = ref.watch(workspaceControllerProvider).isBusy;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(
          attachment.isPdf
              ? Icons.picture_as_pdf_outlined
              : attachment.isEpub
              ? Icons.menu_book_outlined
              : Icons.attach_file,
          color: canRead ? scheme.primary : scheme.outline,
        ),
        title: Text(attachment.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          <String>[
            if (attachment.sizeLabel.isNotEmpty) attachment.sizeLabel,
            if (attachment.annotationCount > 0) '${attachment.annotationCount} anotasi',
            if (file == null && expected != null) 'ada di GitHub, belum diunduh',
            if (file == null && expected == null) 'berkas belum diunduh',
            if (isPointer) 'pointer Git LFS — jalankan LFS pull',
            if (file != null && !attachment.isPdf && !isPointer) 'format belum didukung pembaca',
          ].join(' · '),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        trailing: canRead
            ? FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReaderScreen(
                      itemKey: item.key,
                      itemFilePath: item.filePath,
                      attachmentKey: attachment.key,
                      filePath: file!.path,
                      title: item.title,
                    ),
                  ),
                ),
                icon: const Icon(Icons.chrome_reader_mode_outlined, size: 18),
                label: const Text('Baca'),
              )
            : isPointer
            ? TextButton(
                onPressed: () => ref.read(workspaceControllerProvider.notifier).lfsPull(),
                child: const Text('LFS pull'),
              )
            : expected != null
            ? FilledButton.tonalIcon(
                onPressed: busy
                    ? null
                    : () => ref
                          .read(workspaceControllerProvider.notifier)
                          .downloadAttachment(expected.path),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Unduh'),
              )
            : null,
      ),
    );
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.item});

  final ZoteroItem item;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      if (item.creatorDetails.isNotEmpty)
        MapEntry<String, String>(
          'Pengarang',
          item.creatorDetails.map((c) => c.display).join('; '),
        )
      else if (item.creators.isNotEmpty)
        MapEntry<String, String>('Pengarang', item.creators.join('; ')),
      if (item.publication.isNotEmpty) MapEntry<String, String>('Publikasi', item.publication),
      if (item.date.isNotEmpty) MapEntry<String, String>('Tanggal', item.date),
      if (item.publisher.isNotEmpty) MapEntry<String, String>('Penerbit', item.publisher),
      if (item.doi.isNotEmpty) MapEntry<String, String>('DOI', item.doi),
      if (item.url.isNotEmpty) MapEntry<String, String>('URL', item.url),
      if (item.tags.isNotEmpty) MapEntry<String, String>('Tag', item.tags.join(', ')),
      if (item.collectionPaths.isNotEmpty)
        MapEntry<String, String>('Koleksi', item.collectionPaths.join(' · ')),
      if (item.dateAdded != null)
        MapEntry<String, String>('Ditambahkan', noteTimestamp(item.dateAdded!)),
      MapEntry<String, String>('Zotero key', item.key),
      for (final entry in item.extraFields.entries)
        if (entry.value is String || entry.value is num)
          MapEntry<String, String>(entry.key, '${entry.value}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle('Detail'),
        const SizedBox(height: 6),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 120,
                  child: Text(
                    row.key,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: row.key == 'DOI' || row.key == 'URL'
                      ? _LinkText(label: row.value, key: ValueKey<String>(row.value))
                      : SelectableText(
                          row.value,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final uri = label.startsWith('http') ? Uri.tryParse(label) : Uri.tryParse('https://doi.org/$label');
    return InkWell(
      onTap: uri == null ? null : () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _AnnotationRow extends StatelessWidget {
  const _AnnotationRow({required this.annotation});

  final ZoteroAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(annotation.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 32,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'hal. ${annotation.pageLabel.isEmpty ? annotation.pageNumber : annotation.pageLabel}'
                  ' · ${annotation.type.wire}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (annotation.text.isNotEmpty)
                  Text(
                    annotation.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (annotation.hasComment)
                  Text(
                    annotation.comment,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}
