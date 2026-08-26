import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/editor_diagnostic.dart';
import '../theme/app_theme.dart';

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
        onTapDown: (details) => _jumpTo(details.localPosition.dy, lines.length),
        onVerticalDragStart: (details) =>
            _jumpTo(details.localPosition.dy, lines.length),
        onVerticalDragUpdate: (details) =>
            _jumpTo(details.localPosition.dy, lines.length),
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
    );
  }

  void _jumpTo(double y, int lineCount) {
    if (!widget.scrollController.hasClients || lineCount < 1) return;
    final height = context.size?.height ?? 0;
    if (height <= 0) return;
    final line = ((y / height) * lineCount)
        .floor()
        .clamp(0, lineCount - 1)
        .toInt();
    final position = widget.scrollController.position;
    final target =
        (line * _MinimapPainter.lineHeight - position.viewportDimension * .35)
            .clamp(0.0, position.maxScrollExtent)
            .toDouble();
    widget.scrollController.jumpTo(target);
  }
}

class _MinimapSection {
  final int line;
  final String label;
  const _MinimapSection({required this.line, required this.label});
}

class _MiniToken {
  final String text;
  const _MiniToken(this.text);
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
      r'^(برنامج|اجراء|نوع|ثابت|متغير)\b(.*)',
    ).firstMatch(trimmed);
    if (match == null) continue;
    final label = '${match.group(1)}${match.group(2)?.trim() ?? ''}'.trim();
    sections.add(_MinimapSection(line: index, label: label));
  }
  return sections;
}

class _MinimapPainter extends CustomPainter {
  static const lineHeight = 24.0;
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
    final lineScale = size.height / lineCount;
    final currentLine = _lineAtOffset(selection.extentOffset);
    final viewport = _viewport(size, lineCount);

    final currentPaint = Paint()..color = colors.primary.withValues(alpha: .12);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        currentLine * lineScale,
        size.width,
        math.max(2.0, lineScale).toDouble(),
      ),
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
    final text = sourceLine.trimRight();
    if (text.isEmpty) return;

    final indent = sourceLine.length - sourceLine.trimLeft().length;
    final tokens = _miniTokens(text);
    final gap = math.min(1.0, lineScale * .12).toDouble();
    final indentWidth = math.min(size.width * .18, indent * 1.2).toDouble();
    final widths = tokens
        .map((token) => math.max(3.0, token.text.length * .95 * fontScale))
        .toList();
    final rawWidth =
        widths.fold<double>(indentWidth, (sum, width) => sum + width) +
        math.max(0, tokens.length - 1) * gap;
    final available = math.max(6.0, size.width - 8).toDouble();
    final compression = rawWidth > available ? available / rawWidth : 1.0;
    final barHeight = math.max(1.5, math.min(4.0, lineScale * .42)).toDouble();
    final y = index * lineScale + math.max(0.0, (lineScale - barHeight) / 2);
    var x = size.width - 4;

    // The first logical token is anchored at the right, matching Arabic lines.
    for (var tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
      final width = widths[tokenIndex] * compression;
      x -= width;
      canvas.drawRect(
        Rect.fromLTWH(x, y, width, barHeight),
        Paint()
          ..color = _tokenColor(tokens[tokenIndex].text).withValues(alpha: .86),
      );
      x -= gap * compression;
    }
  }

  List<_MiniToken> _miniTokens(String text) {
    final matches = RegExp(
      r'//.*|"(?:\\.|[^"\\])*"|\d+(?:\.\d+)?|[A-Za-zء-ي_][A-Za-z0-9ء-ي_]*|[^\s]',
    ).allMatches(text);
    return [for (final match in matches) _MiniToken(match.group(0) ?? '')];
  }

  Color _tokenColor(String token) {
    if (token.startsWith('//')) return colors.onSurfaceVariant;
    if (token.startsWith('"')) return colors.secondary;
    if (RegExp(r'^\d').hasMatch(token)) return colors.error;
    if (RegExp(
      r'^(برنامج|اجراء|نوع|ثابت|متغير|اذا|والا|طالما|كرر|اعد)$',
    ).hasMatch(token)) {
      return colors.primary;
    }
    if (RegExp(r'^(صحيح|حقيقي|منطقي|حرفي|خيط)$').hasMatch(token)) {
      return colors.tertiary;
    }
    if (RegExp(r'^[{}()\[\];،؛,.+*/=<>:-]$').hasMatch(token)) {
      return colors.outline;
    }
    return colors.onSurfaceVariant;
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
        .max(size.height, lineCount * lineHeight)
        .toDouble();
    final viewportHeight =
        (position.viewportDimension / contentHeight * size.height)
            .clamp(8.0, size.height)
            .toDouble();
    final available = math.max(0.0, size.height - viewportHeight).toDouble();
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
