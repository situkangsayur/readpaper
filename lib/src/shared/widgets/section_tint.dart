import 'package:flutter/material.dart';

/// Warna latar tipis per bagian panel kiri: library paper, catatan, dan folder
/// kerja "readpaper". Ketiganya bertumpuk dalam satu kolom dengan baris yang
/// tampak sama; tanpa warna, batas antarbagian hanya garis tipis dan mata
/// harus membaca judulnya untuk tahu sedang di bagian mana.
class SectionTint {
  const SectionTint._();

  static Color library(ColorScheme scheme) => scheme.primary.withValues(alpha: 0.07);

  static Color notes(ColorScheme scheme) => scheme.tertiary.withValues(alpha: 0.16);

  static Color files(ColorScheme scheme) => scheme.secondary.withValues(alpha: 0.18);
}
