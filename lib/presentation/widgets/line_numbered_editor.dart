import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LineNumberedEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const LineNumberedEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onTap,
  });

  @override
  State<LineNumberedEditor> createState() => _LineNumberedEditorState();
}

class _LineNumberedEditorState extends State<LineNumberedEditor> {
  final editorScrollController = ScrollController();
  final gutterScrollController = ScrollController();
  late int lineCount;

  @override
  void initState() {
    super.initState();
    lineCount = _lineCount(widget.controller.text);
    widget.controller.addListener(_updateLineCount);
  }

  @override
  void didUpdateWidget(covariant LineNumberedEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateLineCount);
      widget.controller.addListener(_updateLineCount);
      _updateLineCount();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLineCount);
    editorScrollController.dispose();
    gutterScrollController.dispose();
    super.dispose();
  }

  void _updateLineCount() {
    final next = _lineCount(widget.controller.text);
    if (next != lineCount && mounted) setState(() => lineCount = next);
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .42),
                border: Border(left: BorderSide(color: colors.outlineVariant)),
              ),
              child: ListView.builder(
                controller: gutterScrollController,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                itemExtent: 24,
                itemCount: lineCount,
                itemBuilder: (context, index) => Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 2,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _syncGutter,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                scrollController: editorScrollController,
                onChanged: widget.onChanged,
                onTap: widget.onTap,
                expands: true,
                maxLines: null,
                minLines: null,
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
        ],
      ),
    );
  }
}
