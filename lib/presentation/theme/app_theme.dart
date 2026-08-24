import 'package:flutter/material.dart';

enum AppAccent {
  ocean('أزرق بحري', Color(0xFF355C7D)),
  emerald('زمردي', Color(0xFF247A68)),
  violet('بنفسجي', Color(0xFF6C4BA5)),
  amber('كهرماني', Color(0xFF9A6415));

  final String label;
  final Color color;

  const AppAccent(this.label, this.color);
}

abstract final class AppTheme {
  static const fontFamily = 'Cairo';

  static ThemeData light({AppAccent accent = AppAccent.ocean}) => _theme(
    brightness: Brightness.light,
    seed: accent.color,
    surface: const Color(0xFFF7F9FC),
  );

  static ThemeData dark({AppAccent accent = AppAccent.ocean}) => _theme(
    brightness: Brightness.dark,
    seed: accent.color,
    surface: const Color(0xFF111820),
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color seed,
    required Color surface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
    );
    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: surface,
      visualDensity: VisualDensity.standard,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 4),
    );
  }
}
