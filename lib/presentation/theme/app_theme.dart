import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brandOrange = Color(0xFFFF9500);
  static const brandBlack = Color(0xFF0B0B0B);
  static const lightSurface = Color(0xFFF5F2ED);
  static const darkSurface = Color(0xFF141414);
  static const fontFamily = 'Cairo';

  static ThemeData light() =>
      _theme(brightness: Brightness.light, surface: lightSurface);

  static ThemeData dark() =>
      _theme(brightness: Brightness.dark, surface: darkSurface);

  static ThemeData _theme({
    required Brightness brightness,
    required Color surface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandOrange,
      brightness: brightness,
      surface: surface,
    ).copyWith(primary: brandOrange, onPrimary: brandBlack);
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
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
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
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
