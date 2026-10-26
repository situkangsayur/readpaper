import 'package:flutter/material.dart';

import '../../core/l10n.dart';

/// Membuka laci pohon koleksi dari bawah daftar.
///
/// Di tablet tegak dan ponsel, pohon koleksi — jalan ke paper, catatan, dan
/// koleksi lain — hanya bisa dibuka lewat tombol menu di pojok kiri atas.
/// Saat layar dibagikan lewat Google Meet, gelembung Meet justru menutupi
/// pojok itu. Tombol ini memberi jalan kedua di tepi bawah.
///
/// Tidak tampil apa-apa bila layarnya tidak punya laci (desktop, tablet
/// mendatar: pohonnya sudah terlihat).
class TreeDrawerButton extends StatelessWidget {
  const TreeDrawerButton({super.key});

  /// Ada laci yang bisa dibuka dari [context].
  static bool available(BuildContext context) => Scaffold.maybeOf(context)?.hasDrawer ?? false;

  @override
  Widget build(BuildContext context) {
    if (!available(context)) return const SizedBox.shrink();
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: () => Scaffold.of(context).openDrawer(),
      icon: const Icon(Icons.account_tree_outlined, size: 16),
      label: Text(context.l10n.libraryOpenTree),
    );
  }
}
