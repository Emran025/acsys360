import 'package:flutter/material.dart';

import '../../domain/entities/editor_diagnostic.dart';
import '../theme/app_theme.dart';
import 'code_minimap.dart';

class LineNumberedEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final List<EditorDiagnostic> diagnostics;
  final ValueChanged<String>? onChanged;
  final ValueChanged<TextSelection>? onSelectionChanged;
  final VoidCallback? onTap;
  final ValueChanged<EditorDiagnostic>? onDiagnosticTap;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final double fontScale;

  const LineNumberedEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.diagnostics = const [],
    this.onChanged,
    this.onSelectionChanged,
    this.onTap,
    this.onDiagnosticTap,
    this.onKeyEvent,
    this.fontScale = 1.0,
  });

  @override
  State<LineNumberedEditor> createState() => _LineNumberedEditorState();
}

class _LineNumberedEditorState extends State<LineNumberedEditor> {
  final editorScrollController = ScrollController();
  final gutterScrollController = ScrollController();
  late int lineCount;
  late TextSelection lastSelection;

  @override
  void initState() {
    super.initState();
    lineCount = _lineCount(widget.controller.text);
    lastSelection = widget.controller.selection;
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant LineNumberedEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _handleControllerChange();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    editorScrollController.dispose();
    gutterScrollController.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final next = _lineCount(widget.controller.text);
    if (next != lineCount && mounted) setState(() => lineCount = next);
    final selection = widget.controller.selection;
    if (selection != lastSelection) {
      lastSelection = selection;
      widget.onSelectionChanged?.call(selection);
    }
  }

  int _lineCount(String text) =>
      text.isEmpty ? 1 : '\n'.allMatches(text).length + 1;

  bool _syncGutter(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification ||
        !gutterScrollController.hasClients) {
      return false;
    }
    final offset = notification.metrics.pixels.clamp(
      0.0,
      gutterScrollController.position.maxScrollExtent,
    );
    gutterScrollController.jumpTo(offset);
    return false;
  }

  EditorDiagnostic? _diagnosticForLine(int line) {
    for (final diagnostic in widget.diagnostics) {
      if (diagnostic.line == line) return diagnostic;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final editorStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 15,
      height: 1.6,
      color: colors.onSurface,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 118,
            child: CodeMinimap(
              controller: widget.controller,
              scrollController: editorScrollController,
              diagnostics: widget.diagnostics,
              fontScale: widget.fontScale,
            ),
          ),
          SizedBox(
            width: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .42),
                border: Border(right: BorderSide(color: colors.outlineVariant)),
              ),
              child: ListView.builder(
                controller: gutterScrollController,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                itemExtent: 24 * widget.fontScale,
                itemCount: lineCount,
                itemBuilder: (context, index) {
                  final diagnostic = _diagnosticForLine(index + 1);
                  return InkWell(
                    onTap: diagnostic == null || widget.onDiagnosticTap == null
                        ? null
                        : () => widget.onDiagnosticTap!(diagnostic),
                    child: Row(
                      children: [
                        if (diagnostic != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 3),
                            child: Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 14,
                              color:
                                  diagnostic.severity ==
                                      EditorDiagnosticSeverity.error
                                  ? colors.error
                                  : colors.secondary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            '${index + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 2,
                              color: diagnostic == null
                                  ? colors.onSurfaceVariant
                                  : colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _syncGutter,
              child: Focus(
                onKeyEvent: widget.onKeyEvent,
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  scrollController: editorScrollController,
                  onChanged: widget.onChanged,
                  onTap: widget.onTap,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  cursorColor: colors.primary,
                  style: editorStyle,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.fromLTRB(18, 14, 18, 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
