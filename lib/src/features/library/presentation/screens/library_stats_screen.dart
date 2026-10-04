import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/library_stats.dart';
import '../controllers/library_controllers.dart';

/// Bentuk sebuah library dalam angka.
///
/// Bukan daftar isi — itu tugas panel di sebelahnya — melainkan jawaban atas
/// pertanyaan yang tidak bisa dijawab daftar: tahun mana yang menumpuk, jenis
/// apa yang mendominasi, siapa yang paling sering muncul, dan berapa banyak
/// yang PDF-nya belum pernah ada. Yang terakhir itu yang paling sering
/// berguna, dan paling sering mengejutkan.
class LibraryStatsScreen extends ConsumerWidget {
  const LibraryStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(libraryStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik library')),
      body: stats.isEmpty
          ? const Center(child: Text('Belum ada item untuk dihitung.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                _Summary(stats: stats),
                const SizedBox(height: 20),
                _Section(
                  title: 'Per tahun terbit',
                  note: stats.withoutYear == 0
                      ? null
                      : '${stats.withoutYear} item tanpa tahun tidak ikut dihitung di sini.',
                  tallies: stats.byYear,
                ),
                _Section(
                  title: 'Per jenis',
                  tallies: <StatTally>[
                    for (final t in stats.byType)
                      (label: LibraryStats.labelForType(t.label), count: t.count),
                  ],
                ),
                _Section(title: 'Pengarang tersering', tallies: stats.topCreators),
                if (stats.topTags.isNotEmpty)
                  _Section(title: 'Tag tersering', tallies: stats.topTags),
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final span = stats.earliestYear == null || stats.latestYear == null
        ? null
        : '${stats.earliestYear}–${stats.latestYear}';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _Tile(label: 'Item', value: '${stats.itemCount}'),
        _Tile(
          label: 'Berkasnya ada',
          value: '${stats.withFile}',
          note: '${stats.filePercent}%',
          // Yang paling pantas diperhatikan: library yang separuhnya tanpa
          // berkas adalah daftar bacaan, bukan perpustakaan.
          tint: stats.filePercent < 50 ? scheme.error : null,
        ),
        _Tile(
          label: 'Ada anotasi',
          value: '${stats.withAnnotations}',
          note: '${stats.annotationTotal} anotasi',
        ),
        if (span != null) _Tile(label: 'Rentang tahun', value: span),
        if (stats.untitledCount > 0)
          _Tile(label: 'Tanpa judul', value: '${stats.untitledCount}', tint: scheme.error),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.note, this.tint});

  final String label;
  final String value;
  final String? note;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: tint)),
          if (note != null)
            Text(
              note!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: tint ?? scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// Satu bagian berisi batang-batang sederhana.
///
/// Digambar dari `FractionallySizedBox`, bukan dari pustaka grafik: yang
/// dibutuhkan hanya perbandingan panjang, dan menambah satu dependensi untuk
/// itu bukan harga yang pantas dibayar aplikasi yang harus terasa ringan.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tallies, this.note});

  final String title;
  final List<StatTally> tallies;
  final String? note;

  @override
  Widget build(BuildContext context) {
    if (tallies.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final biggest = tallies.map((t) => t.count).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(note!, style: Theme.of(context).textTheme.labelSmall),
          ),
        const SizedBox(height: 8),
        for (final tally in tallies)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 150,
                  child: Text(
                    tally.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: biggest == 0 ? 0 : tally.count / biggest,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${tally.count}',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
