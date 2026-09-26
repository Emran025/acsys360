import 'package:flutter/material.dart';

import '../../../domain/entities/editor_diagnostic.dart';
import '../../../domain/entities/source_token.dart';
import '../../../domain/usecases/arabic_syntax_highlighter.dart';
import '../../../../../../shared/themes/app_theme.dart';

class ArabicCodeController extends TextEditingController {
  final ArabicSyntaxHighlighter _highlighter;
  List<EditorDiagnostic> diagnostics = const [];
  Map<String, SourceTokenRole> semanticRoles = const {};
  String ghostText = '';
  int ghostOffset = -1;

  ArabicCodeController({super.text, ArabicSyntaxHighlighter? highlighter})
    : _highlighter = highlighter ?? const ArabicSyntaxHighlighter();

  void setDiagnostics(List<EditorDiagnostic> next) {
    diagnostics = List.unmodifiable(next);
    notifyListeners();
  }

  void setSemanticRoles(Map<String, SourceTokenRole> next) {
    if (_mapsEqual(semanticRoles, next)) return;
    semanticRoles = Map.unmodifiable(next);
    notifyListeners();
  }

  bool _mapsEqual(
    Map<String, SourceTokenRole> left,
    Map<String, SourceTokenRole> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
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
    final tokens = _highlighter.tokenize(text, roles: semanticRoles);
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
      var offset = diagnostic.offset;
      var len = diagnostic.length <= 0 ? 1 : diagnostic.length;
      if (offset >= text.length && text.isNotEmpty) {
        offset = text.length - 1;
        len = 1;
      }
      final start = offset.clamp(0, text.length).toInt();
      final end = (start + len).clamp(start, text.length).toInt();
      boundaries.add(start);
      boundaries.add(end);
    }
    final sorted = boundaries.toList()..sort();
    final children = <TextSpan>[];
    if (ghostOffset == 0 && ghostText.isNotEmpty) {
      children.add(_ghostSpan(baseStyle, colors));
    }
    for (var index = 0; index < sorted.length - 1; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (start == end) continue;
      final segment = text.substring(start, end);
      final token = _tokenAt(tokens, start, end);
      final diagnostic = _diagnosticAt(start, end);
      final diagnosticColor = _diagnosticColor(diagnostic, colors);
      children.add(
        TextSpan(
          text: segment,
          style: baseStyle.copyWith(
            color:
                diagnosticColor ??
                (token == null ? null : _tokenColor(token, colors)),
            decoration: diagnostic == null ? null : TextDecoration.underline,
            decorationColor: diagnosticColor,
            decorationStyle: diagnostic == null
                ? null
                : TextDecorationStyle.wavy,
          ),
        ),
      );
      if (end == ghostOffset && ghostText.isNotEmpty) {
        children.add(_ghostSpan(baseStyle, colors));
      }
    }
    if (sorted.length == 1 && ghostOffset != 0 && ghostText.isNotEmpty) {
      children.add(_ghostSpan(baseStyle, colors));
    }
    return TextSpan(style: baseStyle, children: children);
  }

  TextSpan _ghostSpan(TextStyle baseStyle, ColorScheme colors) => TextSpan(
    text: ghostText,
    style: baseStyle.copyWith(
      color: colors.onSurfaceVariant.withValues(alpha: .52),
      fontStyle: FontStyle.italic,
    ),
  );

  SourceToken? _tokenAt(List<SourceToken> tokens, int start, int end) {
    for (final token in tokens) {
      if (token.start <= start && end <= token.end) return token;
    }
    return null;
  }

  EditorDiagnostic? _diagnosticAt(int start, int end) {
    for (final diagnostic in diagnostics) {
      var offset = diagnostic.offset;
      var len = diagnostic.length <= 0 ? 1 : diagnostic.length;
      if (offset >= text.length && text.isNotEmpty) {
        offset = text.length - 1;
        len = 1;
      }
      final diagStart = offset.clamp(0, text.length).toInt();
      final diagEnd = (diagStart + len).clamp(diagStart, text.length).toInt();
      if (start < diagEnd && end > diagStart) return diagnostic;
      if (diagStart == diagEnd && start <= diagStart && diagStart <= end) {
        return diagnostic;
      }
    }
    return null;
  }

  Color? _diagnosticColor(EditorDiagnostic? diagnostic, ColorScheme colors) {
    if (diagnostic == null) return null;
    return switch (diagnostic.severity) {
      EditorDiagnosticSeverity.error => colors.error,
      EditorDiagnosticSeverity.warning => colors.secondary,
      EditorDiagnosticSeverity.info => colors.primary,
    };
  }

  Color? _tokenColor(SourceToken token, ColorScheme colors) {
    if (token.kind == SourceTokenKind.comment) {
      return AppTheme.syntaxComment(colors);
    }
    if (token.role != null) {
      return switch (token.role!) {
        SourceTokenRole.constant => AppTheme.syntaxNumber(colors),
        SourceTokenRole.type => AppTheme.syntaxType(colors),
        SourceTokenRole.procedure => AppTheme.syntaxDeclaration(colors),
        SourceTokenRole.parameter => AppTheme.syntaxModifier(colors),
        SourceTokenRole.variable => AppTheme.syntaxIdentifier(colors),
      };
    }
    if (token.group != null) {
      return switch (token.group!) {
        SourceTokenGroup.declaration => AppTheme.syntaxDeclaration(colors),
        SourceTokenGroup.controlFlow => AppTheme.syntaxControlFlow(colors),
        SourceTokenGroup.builtin => AppTheme.syntaxBuiltin(colors),
        SourceTokenGroup.type => AppTheme.syntaxType(colors),
        SourceTokenGroup.modifier => AppTheme.syntaxModifier(colors),
      };
    }
    return switch (token.kind) {
      SourceTokenKind.keyword => AppTheme.syntaxDeclaration(colors),
      SourceTokenKind.string ||
      SourceTokenKind.character => AppTheme.syntaxString(colors),
      SourceTokenKind.integer ||
      SourceTokenKind.real => AppTheme.syntaxNumber(colors),
      SourceTokenKind.boolean => AppTheme.syntaxBoolean(colors),
      SourceTokenKind.operator => AppTheme.syntaxOperator(colors),
      SourceTokenKind.punctuation => AppTheme.syntaxPunctuation(colors),
      SourceTokenKind.identifier => AppTheme.syntaxIdentifier(colors),
      SourceTokenKind.comment => AppTheme.syntaxComment(colors),
    };
  }
}
