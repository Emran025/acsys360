import 'package:flutter/material.dart';

class EditorTopBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onExecute;

  const EditorTopBar({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onExecute,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 3, 8, 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: const _CompactIdentity(),
            ),
            Tooltip(
              message: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
              child: IconButton(
                onPressed: onToggleTheme,
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 19,
                ),
              ),
            ),
            Tooltip(
              message: 'تنفيذ (F5)',
              child: IconButton(
                key: const ValueKey('topbar-execute'),
                onPressed: onExecute,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIdentity extends StatelessWidget {
  const _CompactIdentity();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      'محرر العربية',
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}