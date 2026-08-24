import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/editor_diagnostic.dart';
import '../theme/app_theme.dart';

class CodeMinimap extends StatefulWidget {
  final TextEditingController controller;
  final ScrollController scrollController;
  final List<EditorDiagnostic> diagnostics;

  const CodeMinimap({
    super.key,
    required this.controller,
    required this.scrollController,
    this.diagnostics = const [],
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
            painter: _MinimapPainter(
              lines: lines,
              sections: sections,
              diagnostics: widget.diagnostics,
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
  final ScrollPosition? scrollPosition;
  final ColorScheme colors;

  const _MinimapPainter({
    required this.lines,
    required this.sections,
    required this.diagnostics,
    required this.selection,
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
    final text = lines[index].trimRight();
    if (text.isEmpty) return;
    final indent = lines[index].length - lines[index].trimLeft().length;
    final width = math
        .min(size.width - 8, math.max(5.0, (text.length * .9) + indent * .8))
        .toDouble();
    final y = index * lineScale + math.max(0.0, (lineScale - 2) / 2).toDouble();
    final paint = Paint()..color = _lineColor(text).withValues(alpha: .82);
    canvas.drawRect(Rect.fromLTWH(5 + indent * .35, y, width, 2), paint);
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

  Color _lineColor(String text) {
    if (text.startsWith('//')) return colors.onSurfaceVariant;
    if (RegExp(
      r'^(برنامج|اجراء|نوع|ثابت|متغير|اذا|والا|طالما|كرر|اعد)\b',
    ).hasMatch(text)) {
      return colors.primary;
    }
    if (RegExp(r'^(صحيح|حقيقي|منطقي|حرفي|خيط)').hasMatch(text)) {
      return colors.tertiary;
    }
    if (RegExp(r'\"|‘|’').hasMatch(text)) return colors.secondary;
    if (RegExp(r'\d').hasMatch(text)) return colors.error;
    return colors.onSurfaceVariant;
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
