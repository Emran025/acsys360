import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EditorTopBar extends StatelessWidget {
  final String rootPath;
  final String? activePath;
  final bool isDark;
  final bool expanded;
  final AppAccent accent;
  final ValueChanged<AppAccent> onSelectAccent;
  final VoidCallback onChooseFolder;
  final VoidCallback onSave;
  final VoidCallback onSaveAll;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onFind;
  final VoidCallback onComplete;
  final VoidCallback onHelp;
  final VoidCallback onCompile;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleExpanded;

  const EditorTopBar({
    super.key,
    required this.rootPath,
    required this.activePath,
    required this.isDark,
    required this.expanded,
    required this.accent,
    required this.onSelectAccent,
    required this.onChooseFolder,
    required this.onSave,
    required this.onSaveAll,
    required this.onUndo,
    required this.onRedo,
    required this.onFind,
    required this.onComplete,
    required this.onHelp,
    required this.onCompile,
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
        height: expanded ? 68 : 44,
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: expanded ? 10 : 4,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: expanded
            ? Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BrandBlock(
                            activeName: _activeName,
                            rootPath: rootPath,
                          ),
                          const SizedBox(width: 24),
                          _ToolbarGroup(
                            label: 'تحرير',
                            children: [
                              _ToolbarButton(
                                tooltip: 'تراجع Ctrl+Z',
                                icon: Icons.undo_rounded,
                                onPressed: onUndo,
                              ),
                              _ToolbarButton(
                                tooltip: 'إعادة Ctrl+Y',
                                icon: Icons.redo_rounded,
                                onPressed: onRedo,
                              ),
                              _ToolbarButton(
                                tooltip: 'بحث واستبدال Ctrl+F',
                                icon: Icons.search_rounded,
                                onPressed: onFind,
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          _ToolbarGroup(
                            label: 'لغة',
                            children: [
                              _ToolbarButton(
                                tooltip: 'إكمال Ctrl+Space',
                                icon: Icons.auto_awesome_rounded,
                                onPressed: onComplete,
                              ),
                              _ToolbarButton(
                                tooltip: 'مساعدة F1',
                                icon: Icons.help_outline_rounded,
                                onPressed: onHelp,
                              ),
                              _ToolbarButton(
                                tooltip: 'ترجمة F5',
                                icon: Icons.play_arrow_rounded,
                                filled: true,
                                onPressed: onCompile,
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          _ToolbarGroup(
                            label: 'ملف',
                            children: [
                              _ToolbarButton(
                                tooltip: 'حفظ Ctrl+S',
                                icon: Icons.save_outlined,
                                onPressed: onSave,
                              ),
                              _ToolbarButton(
                                tooltip: 'حفظ الكل',
                                icon: Icons.save_as_outlined,
                                onPressed: onSaveAll,
                              ),
                              _ToolbarButton(
                                tooltip: 'اختيار مجلد المشروع',
                                icon: Icons.folder_open_outlined,
                                onPressed: onChooseFolder,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _AccentPicker(accent: accent, onSelected: onSelectAccent),
                  _ToolbarButton(
                    tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    onPressed: onToggleTheme,
                  ),
                  IconButton(
                    onPressed: onToggleExpanded,
                    tooltip: 'طي الشريط العلوي',
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                ],
              )
            : Row(
                children: [
                  _BrandBlock(activeName: _activeName, rootPath: rootPath),
                  const Spacer(),
                  IconButton(
                    onPressed: onToggleExpanded,
                    tooltip: 'توسيع الشريط العلوي',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  final String activeName;
  final String rootPath;

  const _BrandBlock({required this.activeName, required this.rootPath});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.translate_rounded, color: colors.onPrimary),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'محرر العربية',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(activeName, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    rootPath,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolbarGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _ToolbarGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(width: 4),
      ...children,
    ],
  );
}

class _ToolbarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  const _ToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 19),
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    ),
  );
}

class _AccentPicker extends StatelessWidget {
  final AppAccent accent;
  final ValueChanged<AppAccent> onSelected;

  const _AccentPicker({required this.accent, required this.onSelected});

  @override
  Widget build(BuildContext context) => PopupMenuButton<AppAccent>(
    tooltip: 'ألوان الثيم',
    initialValue: accent,
    onSelected: onSelected,
    itemBuilder: (context) => [
      for (final option in AppAccent.values)
        PopupMenuItem(
          value: option,
          child: Row(
            children: [
              CircleAvatar(radius: 8, backgroundColor: option.color),
              const SizedBox(width: 10),
              Text(option.label),
              if (option == accent) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        ),
    ],
    child: Icon(Icons.palette_outlined, color: accent.color, size: 22),
  );
}
