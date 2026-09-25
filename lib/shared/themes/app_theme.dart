import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brandOrange = Color(0xFFFF9500);
  static const brandBlack = Color(0xFF0B0B0B);
  static const syntaxDeclaration = Color(0xFFFFC857);
  static const syntaxControlFlow = Color(0xFFFF7AB2);
  static const syntaxBuiltin = Color(0xFF63C5DA);
  static const syntaxType = Color(0xFFB39DDB);
  static const syntaxModifier = Color(0xFFF2A65A);
  static const syntaxNumber = Color(0xFF9CDCFE);
  static const syntaxString = Color(0xFFCE9178);
  static const syntaxBoolean = Color(0xFF569CD6);
  static const syntaxOperator = Color(0xFFD4D4D4);
  static const syntaxPunctuation = Color(0xFF808080);
  static const syntaxIdentifier = Color(0xFFD4D4D4);
  static const syntaxComment = Color(0xFF6A9955);
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
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
      popupMenuTheme: const PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
