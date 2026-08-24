import 'dart:io';

import 'package:flutter/material.dart';

class EditorTopBar extends StatelessWidget {
  final String rootPath;
  final String? activePath;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleExpanded;

  const EditorTopBar({
    super.key,
    required this.rootPath,
    required this.activePath,
    required this.isDark,
    required this.expanded,
    required this.onToggleTheme,
    required this.onToggleExpanded,
  });

  String get _activeName => activePath == null
      ? 'لا يوجد ملف نشط'
      : activePath!.split(Platform.pathSeparator).last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: expanded ? 58 : 42,
        padding: EdgeInsetsDirectional.fromSTEB(16, expanded ? 8 : 3, 8, 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: expanded
                  ? _ExpandedIdentity(
                      activeName: _activeName,
                      rootPath: rootPath,
                    )
                  : const _CompactIdentity(),
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
              message: expanded ? 'طي الشريط العلوي' : 'توسيع الشريط العلوي',
              child: IconButton(
                key: const ValueKey('topbar-toggle'),
                onPressed: onToggleExpanded,
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
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

class _ExpandedIdentity extends StatelessWidget {
  final String activeName;
  final String rootPath;

  const _ExpandedIdentity({required this.activeName, required this.rootPath});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'محرر العربية',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 16),
        Text(activeName, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            rootPath,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
