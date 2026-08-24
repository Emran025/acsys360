import 'package:flutter/material.dart';

import '../../domain/entities/editor_diagnostic.dart';
import '../theme/app_theme.dart';

class ArabicCodeController extends TextEditingController {
  static final _tokenPattern = RegExp(
    r'//[^\r\n]*|"(?:\\.|[^"\\])*"|[‘’][^‘’]*[‘’]|[0-9]+(?:\.[0-9]+)?|[ء-يً-ٟۑ-ے]+(?:_[ء-يً-ٟۑ-ے]+)*|[A-Za-z_][A-Za-z0-9_]*|==|!=|=<|=>|&&|\|\||[+\-*\/%\\^!<>=]|[{}()[\],.:;]',
  );
  static const _keywords = {
    'برنامج',
    'ثابت',
    'نوع',
    'متغير',
    'اجراء',
    'بالقيمة',
    'بالمرجع',
    'اطبع',
    'اقرا',
    'اذا',
    'فان',
    'والا',
    'كرر',
    'طالما',
    'استمر',
    'اعد',
    'حتى',
  };
  static const _types = {
    'صحيح',
    'حقيقي',
    'منطقي',
    'حرفي',
    'خيط_رمزي',
    'قائمة',
    'سجل',
  };
  static const _booleans = {'صح', 'خطأ'};
  static const _operators = {
    '+',
    '-',
    '*',
    '/',
    '%',
    r'\',
    '^',
    '&&',
    '||',
    '!',
    '=',
    '==',
    '!=',
    '=<',
    '=>',
    '<',
    '>',
  };
  static const _punctuation = {
    '{',
    '}',
    '(',
    ')',
    '[',
    ']',
    ';',
    ',',
    '.',
    ':',
  };

  List<EditorDiagnostic> diagnostics = const [];
  String ghostText = '';
  int ghostOffset = -1;

  ArabicCodeController({super.text});

  void setDiagnostics(List<EditorDiagnostic> next) {
    diagnostics = List.unmodifiable(next);
    notifyListeners();
  }

  void setGhostText(String value, int offset) {
    if (ghostText == value && ghostOffset == offset) return;
    ghostText = value;
    ghostOffset = value.isEmpty ? -1 : offset.clamp(0, text.length);
    notifyListeners();
  }

  void clearGhostText() => setGhostText('', -1);

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
    if (ghostText.isNotEmpty &&
        ghostOffset >= 0 &&
        ghostOffset <= text.length) {
      boundaries.add(ghostOffset);
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
    if (ghostOffset == 0 && ghostText.isNotEmpty) {
      children.add(
        TextSpan(
          text: ghostText,
          style: baseStyle.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: .52),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
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
      if (end == ghostOffset && ghostText.isNotEmpty) {
        children.add(
          TextSpan(
            text: ghostText,
            style: baseStyle.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: .52),
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
    }
    if (sorted.length == 1 && ghostOffset != 0 && ghostText.isNotEmpty) {
      children.add(
        TextSpan(
          text: ghostText,
          style: baseStyle.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: .52),
            fontStyle: FontStyle.italic,
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
    if (value.startsWith('//')) return colors.onSurfaceVariant;
    if (value.startsWith('"') ||
        value.startsWith('‘') ||
        value.startsWith('’')) {
      return colors.tertiary;
    }
    if (RegExp(r'^\d').hasMatch(value)) return colors.secondary;
    if (_booleans.contains(value)) return colors.primary;
    if (_types.contains(value)) return colors.tertiary;
    if (_keywords.contains(value)) return AppTheme.brandOrange;
    if (_operators.contains(value)) return colors.error;
    if (_punctuation.contains(value)) return colors.outline;
    return null;
  }
}
