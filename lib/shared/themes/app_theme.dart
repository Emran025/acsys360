import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brandOrange = Color(0xFFFF9500);
  static const brandBlack = Color(0xFF0B0B0B);
  static Color syntaxDeclaration(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFFFFC857),
        light: const Color(0xFF875F00),
      );
  static Color syntaxControlFlow(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFFFF7AB2),
        light: const Color(0xFFA1265A),
      );
  static Color syntaxBuiltin(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFF63C5DA),
        light: const Color(0xFF006D77),
      );
  static Color syntaxType(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFFB39DDB),
        light: const Color(0xFF5E3A8A),
      );
  static Color syntaxModifier(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFFF2A65A),
        light: const Color(0xFF9A4F00),
      );
  static Color syntaxNumber(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFF9CDCFE),
        light: const Color(0xFF005A9C),
      );
  static Color syntaxString(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFFCE9178),
        light: const Color(0xFF9C3D1F),
      );
  static Color syntaxBoolean(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFF569CD6),
        light: const Color(0xFF124E96),
      );
  static Color syntaxOperator(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFFD4D4D4),
        light: const Color(0xFF424242),
      );
  static Color syntaxPunctuation(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFF9B9B9B),
        light: const Color(0xFF707070),
      );
  static Color syntaxIdentifier(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFFD4D4D4),
        light: const Color(0xFF303030),
      );
  static Color syntaxComment(ColorScheme colors) => _syntaxColor(
        colors,
        dark: const Color(0xFF6A9955),
        light: const Color(0xFF3F7A3F),
      );

  static Color _syntaxColor(
    ColorScheme colors, {
    required Color dark,
    required Color light,
  }) => colors.brightness == Brightness.dark ? dark : light;
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
