import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/library_controllers.dart';
import '../../domain/duplicate_finder.dart';
import '../../domain/entities/zotero_item.dart';

/// Memperlihatkan item yang tampaknya karya yang sama, masuk lebih dari sekali.
///
/// Layar ini **tidak menghapus apa pun**. Library Zotero adalah pekerjaan
/// bertahun-tahun yang dijaga byte-for-byte oleh plugin sinkronisasi, dan
/// menggabungkan dua item berarti salah satunya hilang. Yang pantas dilakukan
/// aplikasi ini adalah menunjukkan mana yang mencurigakan, berdampingan,
/// beserta alasannya — keputusannya milik yang punya library.
class DuplicateScreen extends ConsumerWidget {
  const DuplicateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dibaca dari provider, bukan dihitung di sini: pencariannya 65 milidetik
    // pada library 1.741 item, dan membangun ulang layar tidak boleh
    // membayarnya lagi.
    final groups = ref.watch(duplicateGroupsProvider);
    final itemCount = ref.watch(libraryItemCountProvider);
    final scheme = Theme.of(context).colorScheme;

    final copies = groups.fold<int>(0, (sum, g) => sum + g.items.length);
    final risky = groups.where((g) => g.annotationsOnMoreThanOne).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kemungkinan duplikat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                groups.isEmpty
                    ? '$itemCount item diperiksa, tidak ada yang mencurigakan.'
                    : '${groups.length} kelompok · $copies salinan '
                          'dari $itemCount item'
                          '${risky == 0 ? '' : ' · $risky perlu hati-hati'}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ),
      ),
      body: groups.isEmpty
          ? const _Empty()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: groups.length + 1,
              itemBuilder: (context, i) {
                if (i == groups.length) return const _Footer();
                return _GroupCard(group: groups[i], scheme: scheme);
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.verified_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('Tidak ada yang tampak ganda.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Dicocokkan lewat DOI, lalu ISBN, lalu judul bersama tahun dan '
            'nama pengarang pertama.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
    child: Text(
      'Tidak ada yang dihapus dari sini. Penggabungan dikerjakan di Zotero, '
      'tempat riwayat dan lampirannya ikut dipindahkan — daftar ini gunanya '
      'menunjukkan mana yang perlu dilihat.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, required this.scheme});

  final DuplicateGroup group;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = group.items.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Chip(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  label: Text(
                    group.strongest.label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${group.items.length} salinan',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                if (group.annotationsOnMoreThanOne)
                  Tooltip(
                    message:
                        'Anotasi ada di lebih dari satu salinan — '
                        'menggabungkan bisa menghilangkan sebagiannya.',
                    child: Icon(Icons.warning_amber_outlined, size: 18, color: scheme.error),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(first.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final item in group.items) _CopyRow(item: item, isKeeper: item == first),
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends ConsumerWidget {
  const _CopyRow({required this.item, required this.isKeeper});

  final ZoteroItem item;

  /// Salinan yang paling pantas dipertahankan: paling banyak anotasinya, lalu
  /// yang punya berkas, lalu yang metadatanya paling lengkap.
  final bool isKeeper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final facts = <String>[
      if (item.year.isNotEmpty) item.year,
      if (item.annotationCount > 0) '${item.annotationCount} anotasi',
      if (item.hasReadableFile) 'ada berkas',
      if (item.collectionPaths.isNotEmpty) item.collectionPaths.join(' · '),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        // Membuka berarti memilihnya di daftar utama; panel detail sudah tahu
        // cara menampilkan seluruh medannya, dan itu yang dibutuhkan untuk
        // memutuskan mana yang dipertahankan.
        ref.read(selectedItemKeyProvider.notifier).select(item.key);
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              isKeeper ? Icons.star : Icons.star_border,
              size: 15,
              color: isKeeper ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.creatorLabel.isEmpty ? item.key : item.creatorLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (facts.isNotEmpty)
                    Text(
                      facts.join(' · '),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(item.key, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
