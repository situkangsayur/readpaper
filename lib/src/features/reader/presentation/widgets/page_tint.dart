import 'package:flutter/material.dart';

/// How the page is tinted while reading.
///
/// Papers are white rectangles at full brightness, which is the wrong thing
/// to stare at in a dim room. These are applied as a colour filter over the
/// rendered page, so nothing about the document itself changes and the
/// annotations keep their own colours relative to it.
enum PageTint {
  none('Normal', Icons.brightness_7_outlined),
  sepia('Sepia', Icons.wb_twilight),
  dim('Redup', Icons.brightness_4_outlined),
  invert('Balik warna', Icons.invert_colors);

  const PageTint(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Null leaves the page exactly as rendered.
  ColorFilter? get filter => switch (this) {
    PageTint.none => null,
    // Warms the whites and pulls the blues down, the way paper looks under a
    // lamp rather than under a fluorescent tube.
    PageTint.sepia => const ColorFilter.matrix(<double>[
      0.905, 0.078, 0.017, 0, 0, //
      0.079, 0.874, 0.047, 0, 0, //
      0.062, 0.114, 0.674, 0, 0, //
      0, 0, 0, 1, 0, //
    ]),
    // Straight brightness, not opacity: a dark veil over the page would grey
    // the highlights too and make them hard to tell apart.
    PageTint.dim => const ColorFilter.matrix(<double>[
      0.62, 0, 0, 0, 0, //
      0, 0.62, 0, 0, 0, //
      0, 0, 0.62, 0, 0, //
      0, 0, 0, 1, 0, //
    ]),
    // A plain inversion, slightly softened so pure white does not become pure
    // black. Markers do turn into their complements — yellow reads as blue,
    // green as magenta — which is the price of inverting the whole page and
    // is why this is not the default.
    PageTint.invert => const ColorFilter.matrix(<double>[
      -0.8, -0.1, -0.1, 0, 255, //
      -0.1, -0.8, -0.1, 0, 255, //
      -0.1, -0.1, -0.8, 0, 255, //
      0, 0, 0, 1, 0, //
    ]),
  };

  /// The colour behind the page, so the surround matches the page itself.
  Color? get background => switch (this) {
    PageTint.none => null,
    PageTint.sepia => const Color(0xFFE8DCC4),
    PageTint.dim => const Color(0xFF15171A),
    PageTint.invert => const Color(0xFF0C0D0F),
  };
}
