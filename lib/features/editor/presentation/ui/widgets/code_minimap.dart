import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../domain/entities/editor_diagnostic.dart';
import '../../../domain/entities/source_token.dart';
import '../../../domain/usecases/arabic_syntax_highlighter.dart';
import '../../../../../../shared/themes/app_theme.dart';

class CodeMinimap extends StatefulWidget {
  final TextEditingController controller;
  final ScrollController scrollController;
  final List<EditorDiagnostic> diagnostics;
  final double fontScale;

  const CodeMinimap({
    super.key,
    required this.controller,
    required this.scrollController,
    this.diagnostics = const [],
    this.fontScale = 1.0,
  });

  @override
  State<CodeMinimap> createState() => _CodeMinimapState();
}

class _CodeMinimapState extends State<CodeMinimap> {
  bool _draggingViewport = false;
  double _dragStartGlobalY = 0;
  double _dragStartScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.scrollController.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant CodeMinimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_refresh);
      widget.scrollController.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.scrollController.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lines = widget.controller.text.split('\n');
    final sections = _sections(lines);
    return Semantics(
      label: 'خريطة مصغرة للكود',
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          if (!_viewportRect(lines.length).contains(details.localPosition)) {
            _jumpTo(details.localPosition.dy, lines.length);
          }
        },
        onVerticalDragStart: (details) {
          final viewport = _viewportRect(lines.length);
          _draggingViewport = viewport.contains(details.localPosition);
          _dragStartGlobalY = details.globalPosition.dy;
          _dragStartScrollOffset = widget.scrollController.hasClients
              ? widget.scrollController.offset
              : 0;
          if (!_draggingViewport) {
            _jumpTo(details.localPosition.dy, lines.length);
          }
        },
        onVerticalDragUpdate: (details) {
          if (_draggingViewport) {
            _dragViewport(details.globalPosition.dy - _dragStartGlobalY);
          } else {
            _jumpTo(details.localPosition.dy, lines.length);
          }
        },
        onVerticalDragEnd: (_) => _draggingViewport = false,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _scrollBy(event.scrollDelta.dy);
              }
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .34),
                border: Border(right: BorderSide(color: colors.outlineVariant)),
              ),
              child: CustomPaint(
                key: const ValueKey('minimap-code-painter'),
                painter: _MinimapPainter(
                  lines: lines,
                  sections: sections,
                  diagnostics: widget.diagnostics,
                  fontScale: widget.fontScale,
                  selection: widget.controller.selection,
                  scrollPosition: widget.scrollController.hasClients
                      ? widget.scrollController.position
                      : null,
                  colors: colors,
                ),
                size: Size.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect _viewportRect(int lineCount) {
    final size = context.size;
    if (size == null || size.height <= 0) return Rect.zero;
    final position = widget.scrollController.hasClients
        ? widget.scrollController.position
        : null;
    if (position == null || !position.hasContentDimensions) return Rect.zero;
    final contentHeight = math.min(
      size.height,
      lineCount * _MinimapPainter.lineHeight,
    );
    final minimumViewportHeight = math.min(8.0, contentHeight).toDouble();
    final viewportHeight =
        (position.viewportDimension / contentHeight * contentHeight)
            .clamp(minimumViewportHeight, contentHeight)
            .toDouble();
    final available = math.max(0.0, contentHeight - viewportHeight).toDouble();
    final top = position.maxScrollExtent == 0
        ? 0.0
        : position.pixels / position.maxScrollExtent * available;
    return Rect.fromLTWH(0, top, size.width, viewportHeight);
  }

  void _jumpTo(double y, int lineCount) {
    if (!widget.scrollController.hasClients || lineCount < 1) return;
    final height = context.size?.height ?? 0;
    if (height <= 0) return;
    final position = widget.scrollController.position;
    final contentHeight = math.min(
      height,
      lineCount * _MinimapPainter.lineHeight,
    );
    final target = (y / height * contentHeight - position.viewportDimension / 2)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() > 0.5) {
      widget.scrollController.jumpTo(target);
    }
  }

  void _dragViewport(double deltaY) {
    if (!widget.scrollController.hasClients) return;
    final size = context.size;
    if (size == null || size.height <= 0) return;
    final viewport = _viewportRect(widget.controller.text.split('\n').length);
    final available = math.max(1.0, size.height - viewport.height);
    final delta =
        deltaY / available * widget.scrollController.position.maxScrollExtent;
    final target = (_dragStartScrollOffset + delta)
        .clamp(0.0, widget.scrollController.position.maxScrollExtent)
        .toDouble();
    widget.scrollController.jumpTo(target);
  }

  void _scrollBy(double delta) {
    if (!widget.scrollController.hasClients ||
        !widget.scrollController.position.hasContentDimensions) {
      return;
    }
    final position = widget.scrollController.position;
    final target = (position.pixels + delta)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() > 0.5) {
      widget.scrollController.jumpTo(target);
    }
  }
}

class _MinimapSection {
  final int line;
  final String label;
  const _MinimapSection({required this.line, required this.label});
}

List<_MinimapSection> _sections(List<String> lines) {
  final sections = <_MinimapSection>[];
  for (var index = 0; index < lines.length; index++) {
    final trimmed = lines[index].trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('//')) {
      final label = trimmed.substring(2).trim();
      if (label.startsWith('#region') || label.startsWith('قسم')) {
        sections.add(
          _MinimapSection(
            line: index,
            label: label.replaceFirst(RegExp(r'^#region\s*'), '').trim(),
          ),
        );
      }
      continue;
    }
    final match = RegExp(
      r'^(برنامج|اجراء|إجراء|نوع|ثابت|متغير)\b(.*)',
    ).firstMatch(trimmed);
    if (match == null) continue;
    final label = '${match.group(1)}${match.group(2)?.trim() ?? ''}'.trim();
    sections.add(_MinimapSection(line: index, label: label));
  }
  return sections;
}

class _MinimapPainter extends CustomPainter {
  static const lineHeight = 7.0;
  static const _highlighter = ArabicSyntaxHighlighter();
  final List<String> lines;
  final List<_MinimapSection> sections;
  final List<EditorDiagnostic> diagnostics;
  final TextSelection selection;
  final double fontScale;
  final ScrollPosition? scrollPosition;
  final ColorScheme colors;

  const _MinimapPainter({
    required this.lines,
    required this.sections,
    required this.diagnostics,
    required this.selection,
    required this.fontScale,
    required this.scrollPosition,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineCount = math.max(lines.length, 1).toInt();
    final lineScale = lineHeight;
    final currentLine = _lineAtOffset(selection.extentOffset);
    final viewport = _viewport(size, lineCount);

    final currentPaint = Paint()..color = colors.primary.withValues(alpha: .12);
    canvas.drawRect(
      Rect.fromLTWH(0, currentLine * lineScale, size.width, lineScale),
      currentPaint,
    );

    for (var index = 0; index < lines.length; index++) {
      _paintLine(canvas, size, index, lineScale);
    }
    for (final section in sections) {
      _paintSection(canvas, size, section, lineScale);
    }
    for (final diagnostic in diagnostics) {
      final line = (diagnostic.line - 1).clamp(0, lineCount - 1).toInt();
      final paint = Paint()
        ..color = diagnostic.severity == EditorDiagnosticSeverity.error
            ? colors.error
            : colors.secondary;
      canvas.drawRect(
        Rect.fromLTWH(
          1,
          line * lineScale,
          3,
          math.max(2.0, lineScale).toDouble(),
        ),
        paint,
      );
    }
    if (viewport != null) {
      final viewportPaint = Paint()
        ..color = colors.primary.withValues(alpha: .18)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = colors.primary.withValues(alpha: .72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRect(viewport, viewportPaint);
      canvas.drawRect(viewport, borderPaint);
    }
  }

  void _paintLine(Canvas canvas, Size size, int index, double lineScale) {
    final sourceLine = lines[index];
    if (sourceLine.trim().isEmpty) return;

    final fontSize = math.min(5.5, lineScale * .8).toDouble();
    final painter = TextPainter(
      text: _lineSpan(sourceLine, fontSize),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(8.0, size.width - 8));

    final y =
        index * lineScale + math.max(0.0, (lineScale - painter.height) / 2);
    painter.paint(canvas, Offset(size.width - 4 - painter.width, y));
  }

  TextSpan _lineSpan(String sourceLine, double fontSize) {
    final matches = RegExp(
      r'//.*|"(?:\\.|[^"\\])*"|\d+(?:\.\d+)?|[A-Za-zء-ي_][A-Za-z0-9ء-ي_]*|[^\s]',
    ).allMatches(sourceLine);
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(
          TextSpan(
            text: sourceLine.substring(cursor, match.start),
            style: _miniTextStyle(fontSize, colors.onSurfaceVariant),
          ),
        );
      }
      final token = match.group(0) ?? '';
      children.add(
        TextSpan(
          text: token,
          style: _miniTextStyle(fontSize, _tokenColor(token)),
        ),
      );
      cursor = match.end;
    }
    if (cursor < sourceLine.length) {
      children.add(
        TextSpan(
          text: sourceLine.substring(cursor),
          style: _miniTextStyle(fontSize, colors.onSurfaceVariant),
        ),
      );
    }
    return TextSpan(children: children);
  }

  TextStyle _miniTextStyle(double fontSize, Color color) {
    return TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: fontSize,
      height: 1,
      color: color.withValues(alpha: .9),
    );
  }

  Color _tokenColor(String token) {
    final parsed = _highlighter.tokenize(token);
    if (parsed.isEmpty) return AppTheme.syntaxIdentifier(colors);
    final sourceToken = parsed.first;
    if (sourceToken.group != null) {
      return switch (sourceToken.group!) {
        SourceTokenGroup.declaration => AppTheme.syntaxDeclaration(colors),
        SourceTokenGroup.controlFlow => AppTheme.syntaxControlFlow(colors),
        SourceTokenGroup.builtin => AppTheme.syntaxBuiltin(colors),
        SourceTokenGroup.type => AppTheme.syntaxType(colors),
        SourceTokenGroup.modifier => AppTheme.syntaxModifier(colors),
      };
    }
    return switch (sourceToken.kind) {
      SourceTokenKind.comment => AppTheme.syntaxComment(colors),
      SourceTokenKind.string || SourceTokenKind.character => AppTheme.syntaxString(colors),
      SourceTokenKind.integer || SourceTokenKind.real => AppTheme.syntaxNumber(colors),
      SourceTokenKind.boolean => AppTheme.syntaxBoolean(colors),
      SourceTokenKind.operator => AppTheme.syntaxOperator(colors),
      SourceTokenKind.punctuation => AppTheme.syntaxPunctuation(colors),
      SourceTokenKind.keyword => AppTheme.syntaxDeclaration(colors),
      SourceTokenKind.identifier => AppTheme.syntaxIdentifier(colors),
    };
  }

  void _paintSection(
    Canvas canvas,
    Size size,
    _MinimapSection section,
    double lineScale,
  ) {
    final y = section.line * lineScale;
    final markerPaint = Paint()..color = colors.primary.withValues(alpha: .9);
    canvas.drawRect(Rect.fromLTWH(3, y, size.width - 6, 2), markerPaint);
    final painter = TextPainter(
      text: TextSpan(
        text: section.label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 7,
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 10);
    painter.paint(canvas, Offset(5, y + 3));
  }

  Rect? _viewport(Size size, int lineCount) {
    final position = scrollPosition;
    if (position == null || !position.hasContentDimensions) return null;
    final contentHeight = math
        .min(size.height, lineCount * lineHeight)
        .toDouble();
    final minimumViewportHeight = math.min(8.0, contentHeight).toDouble();
    final viewportHeight =
        (position.viewportDimension / contentHeight * contentHeight)
            .clamp(minimumViewportHeight, contentHeight)
            .toDouble();
    final available = math.max(0.0, contentHeight - viewportHeight).toDouble();
    final top = position.maxScrollExtent == 0
        ? 0.0
        : position.pixels / position.maxScrollExtent * available;
    return Rect.fromLTWH(0, top, size.width, viewportHeight);
  }

  int _lineAtOffset(int offset) {
    if (offset <= 0) return 0;
    var remaining = offset;
    for (var index = 0; index < lines.length; index++) {
      if (remaining <= lines[index].length) return index;
      remaining -= lines[index].length + 1;
    }
    return math.max(0, lines.length - 1);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}
