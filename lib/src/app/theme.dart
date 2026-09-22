import 'package:flutter/material.dart';

import '../core/utils/layout_size.dart';

/// ReadPaper uses a calm, paper-like surface so the PDF stays the focus.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF2F6FB0);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Compact suits a mouse; fingers need the standard spacing to hit
      // anything reliably on a tablet.
      visualDensity: isTouchPlatform ? VisualDensity.standard : VisualDensity.compact,
      scaffoldBackgroundColor: scheme.surface,
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      listTileTheme: ListTileThemeData(
        dense: !isTouchPlatform,
        horizontalTitleGap: 8,
        minLeadingWidth: 20,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// Page background behind the rendered PDF.
  static Color readerBackground(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? const Color(0xFF15171A) : const Color(0xFFE7E9EC);
}
