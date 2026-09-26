import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../domain/entities/editor_diagnostic.dart';
import '../../../../../../shared/themes/app_theme.dart';
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

class _EditorScrollBehavior extends ScrollBehavior {
  const _EditorScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class _LineNumberedEditorState extends State<LineNumberedEditor> {
  final editorScrollController = ScrollController();
  final gutterScrollController = ScrollController();
  late int lineCount;
  late TextSelection lastSelection;
  Offset? _lastPrimaryPointer;

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
    final incomingSelection = widget.controller.selection;
    final pointer = _lastPrimaryPointer;
    if (pointer != null && incomingSelection.isCollapsed) {
      _normalizePointerAtLineBoundary(pointer, selection: incomingSelection);
    }
    final selection = widget.controller.selection;
    if (selection != lastSelection) {
      lastSelection = selection;
      widget.onSelectionChanged?.call(selection);
    }
  }

  void _rememberPrimaryPointer(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton != 0) {
      _lastPrimaryPointer = event.position;
    }
  }

  void _handleEditorTap() {
    widget.onTap?.call();
  }

  void _handlePrimaryPointerUp(PointerUpEvent event) {
    _schedulePointerNormalization(event.position);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastPrimaryPointer = null;
    });
  }

  void _schedulePointerNormalization(Offset globalPosition) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _normalizePointerAtLineBoundary(globalPosition);
    });
  }

  void _normalizePointerAtLineBoundary(
    Offset globalPosition, {
    TextSelection? selection,
  }) {
    final editable = _findRenderEditable(context.findRenderObject());
    if (editable == null || !editable.attached) return;
    // A non-collapsed selection is normally a word selection (double-click)
    // or a deliberate drag. Never rewrite it as a line-boundary selection.
    // This keeps Flutter's native word-selection behavior intact.
    final current = selection ?? widget.controller.selection;
    if (!current.isCollapsed) return;

    final text = widget.controller.text;
    final local = editable.globalToLocal(globalPosition);
    var lineStart = 0;
    var lineEnd = text.indexOf('\n');
    if (lineEnd == -1) lineEnd = text.length;
    var bestDistance = double.infinity;
    var scanStart = 0;
    while (true) {
      final scanEnd = text.indexOf('\n', scanStart);
      final candidateEnd = scanEnd == -1 ? text.length : scanEnd;
      final caret = editable.getLocalRectForCaret(
        TextPosition(offset: scanStart),
      );
      final distance = (caret.center.dy - local.dy).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        lineStart = scanStart;
        lineEnd = candidateEnd;
      }
      if (scanEnd == -1) break;
      scanStart = scanEnd + 1;
      if (scanStart > text.length) break;
    }

    var left = double.infinity;
    var right = double.negativeInfinity;
    for (var offset = lineStart; offset <= lineEnd; offset++) {
      final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
      left = left < caret.left ? left : caret.left;
      right = right > caret.left ? right : caret.left;
    }
    if (!left.isFinite || !right.isFinite) return;

    const tolerance = 4.0;
    final target = local.dx < left - tolerance
        ? lineEnd
        : local.dx > right + tolerance
        ? lineStart
        : null;
    if (target == null) return;

    _lastPrimaryPointer = null;
    widget.controller.selection = TextSelection.collapsed(offset: target);
  }

  RenderEditable? _findRenderEditable(RenderObject? root) {
    if (root == null) return null;
    if (root is RenderEditable) return root;
    RenderEditable? result;
    root.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
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
    final editorBody = Padding(
      padding: const EdgeInsets.only(left: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .55),
          ),
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
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _syncGutter,
                child: Focus(
                  onKeyEvent: widget.onKeyEvent,
                  child: ScrollConfiguration(
                    behavior: const _EditorScrollBehavior(),
                    child: Listener(
                      onPointerDown: _rememberPrimaryPointer,
                      onPointerUp: _handlePrimaryPointerUp,
                      child: TextField(
                        key: const ValueKey('code-editor-field'),
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        scrollController: editorScrollController,
                        onChanged: widget.onChanged,
                        onTap: _handleEditorTap,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        // One RTL paragraph base for Arabic and mixed content;
                        // margin correction is based only on caret geometry.
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
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
              ),
            ),
            SizedBox(
              key: const ValueKey('code-gutter'),
              width: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .42),
                  border: Border(
                    left: BorderSide(color: colors.outlineVariant),
                  ),
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
                      onTap:
                          diagnostic == null || widget.onDiagnosticTap == null
                          ? null
                          : () => widget.onDiagnosticTap!(diagnostic),
                      child: Row(
                        children: [
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
                          if (diagnostic != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 3),
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
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbVisibility: const WidgetStatePropertyAll(true),
          trackVisibility: const WidgetStatePropertyAll(false),
          thickness: const WidgetStatePropertyAll(6),
          radius: Radius.zero,
          mainAxisMargin: 0,
          crossAxisMargin: 0,
        ),
        child: Scrollbar(
          controller: editorScrollController,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.left,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.vertical,
          child: editorBody,
        ),
      ),
    );
  }
}
