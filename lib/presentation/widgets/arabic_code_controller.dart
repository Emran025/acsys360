import 'package:flutter/material.dart';

import '../../domain/entities/editor_diagnostic.dart';
import '../theme/app_theme.dart';

class ArabicCodeController extends TextEditingController {
  static final _tokenPattern = RegExp(
    r'"(?:\\.|[^"\\])*"|[0-9]+|[ء-ي]+|[A-Za-z_][A-Za-z0-9_]*',
  );
  static const _keywords = {
    'برنامج',
    'دالة',
    'متغير',
    'اذا',
    'وإلا',
    'طالما',
    'لكل',
    'ارجع',
    'اطبع',
    'صحيح',
    'خطأ',
    'نص',
    'عدد',
  };

  List<EditorDiagnostic> diagnostics = const [];

  ArabicCodeController({super.text});

  void setDiagnostics(List<EditorDiagnostic> next) {
    diagnostics = List.unmodifiable(next);
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final colors = Theme.of(context).colorScheme;
    final tokens = _tokenPattern.allMatches(text).toList();
    final boundaries = <int>{0, text.length};
    for (final token in tokens) {
      boundaries.add(token.start);
      boundaries.add(token.end);
    }
    for (final diagnostic in diagnostics) {
      final start = diagnostic.offset.clamp(0, text.length);
      final end = (diagnostic.offset + diagnostic.length).clamp(
        start,
        text.length,
      );
      boundaries.add(start);
      boundaries.add(end);
    }
    final sorted = boundaries.toList()..sort();
    final children = <TextSpan>[];
    for (var index = 0; index < sorted.length - 1; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (start == end) continue;
      final segment = text.substring(start, end);
      final token = _tokenAt(tokens, start, end);
      final diagnostic = _diagnosticAt(start, end);
      final tokenColor = token == null ? null : _tokenColor(token, colors);
      final diagnosticColor = diagnostic == null
          ? null
          : diagnostic.severity == EditorDiagnosticSeverity.error
          ? colors.error
          : diagnostic.severity == EditorDiagnosticSeverity.warning
          ? colors.secondary
          : colors.primary;
      children.add(
        TextSpan(
          text: segment,
          style: baseStyle.copyWith(
            color: diagnosticColor ?? tokenColor,
            decoration: diagnostic == null ? null : TextDecoration.underline,
            decorationColor: diagnosticColor,
            decorationStyle: diagnostic == null
                ? null
                : TextDecorationStyle.wavy,
          ),
        ),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }

  Match? _tokenAt(List<Match> tokens, int start, int end) {
    for (final token in tokens) {
      if (token.start <= start && end <= token.end) return token;
    }
    return null;
  }

  EditorDiagnostic? _diagnosticAt(int start, int end) {
    for (final diagnostic in diagnostics) {
      final diagnosticEnd = diagnostic.offset + diagnostic.length;
      if (diagnostic.length == 0 &&
          start <= diagnostic.offset &&
          diagnostic.offset <= end) {
        return diagnostic;
      }
      if (start < diagnosticEnd && end > diagnostic.offset) return diagnostic;
    }
    return null;
  }

  Color? _tokenColor(Match token, ColorScheme colors) {
    final value = token.group(0)!;
    if (value.startsWith('"')) return colors.tertiary;
    if (int.tryParse(value) != null) return colors.secondary;
    return _keywords.contains(value) ? AppTheme.brandOrange : null;
  }
}
