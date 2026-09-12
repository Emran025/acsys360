import 'package:flutter/material.dart';

import '../../../domain/entities/editor_diagnostic.dart';

class DiagnosticPopoverWidget extends StatelessWidget {
  final EditorDiagnostic diagnostic;
  final ValueChanged<EditorCodeAction> onApply;
  final VoidCallback onClose;

  const DiagnosticPopoverWidget({
    super.key,
    required this.diagnostic,
    required this.onApply,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = diagnostic.severity == EditorDiagnosticSeverity.error
        ? colors.error
        : colors.secondary;
    return Material(
      color: colors.surfaceContainerHighest,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: accent, width: 3),
            top: BorderSide(color: colors.outlineVariant),
            bottom: BorderSide(color: colors.outlineVariant),
            left: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: accent, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${diagnostic.code} · ${diagnostic.phase}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 17),
                  tooltip: 'إغلاق التشخيص',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              diagnostic.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'السطر ${diagnostic.line}، العمود ${diagnostic.column}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (diagnostic.actions.isNotEmpty) ...[
              const Divider(height: 12),
              for (final action in diagnostic.actions)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => onApply(action),
                    style: TextButton.styleFrom(
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(action.title),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
