import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FindReplaceBar extends StatelessWidget {
  final TextEditingController findController;
  final TextEditingController replaceController;
  final bool replaceExpanded;
  final int matches;
  final int currentMatch;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleReplace;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onReplaceCurrent;
  final VoidCallback onReplaceAll;
  final VoidCallback onClose;

  const FindReplaceBar({
    super.key,
    required this.findController,
    required this.replaceController,
    required this.replaceExpanded,
    required this.matches,
    required this.currentMatch,
    required this.onSearch,
    required this.onToggleReplace,
    required this.onPrevious,
    required this.onNext,
    required this.onReplaceCurrent,
    required this.onReplaceAll,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _CloseFindIntent(),
      },
      child: Actions(
        actions: {
          _CloseFindIntent: CallbackAction<_CloseFindIntent>(
            onInvoke: (_) {
              onClose();
              return null;
            },
          ),
        },
        child: Material(
          key: const ValueKey('find-replace-overlay'),
          elevation: 8,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: constraints.maxWidth,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: TextField(
                            key: const ValueKey('find-query'),
                            controller: findController,
                            autofocus: true,
                            onChanged: onSearch,
                            onSubmitted: (_) => onNext(),
                            decoration: _decoration(
                              hint: 'بحث',
                              suffix: matches == 0
                                  ? '0'
                                  : '${currentMatch + 1}/$matches',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _ActionIcon(
                        key: const ValueKey('find-previous'),
                        tooltip: 'النتيجة السابقة',
                        icon: Icons.keyboard_arrow_up_rounded,
                        onPressed: matches == 0 ? null : onPrevious,
                      ),
                      _ActionIcon(
                        key: const ValueKey('find-next'),
                        tooltip: 'النتيجة التالية',
                        icon: Icons.keyboard_arrow_down_rounded,
                        onPressed: matches == 0 ? null : onNext,
                      ),
                      _ActionIcon(
                        key: const ValueKey('find-toggle-replace'),
                        tooltip: replaceExpanded
                            ? 'إخفاء الاستبدال'
                            : 'إظهار الاستبدال',
                        icon: replaceExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        onPressed: onToggleReplace,
                      ),
                      _ActionIcon(
                        key: const ValueKey('find-close'),
                        tooltip: 'إغلاق البحث',
                        icon: Icons.close_rounded,
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  if (replaceExpanded) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: TextField(
                              key: const ValueKey('replace-query'),
                              controller: replaceController,
                              onSubmitted: (_) => onReplaceCurrent(),
                              decoration: _decoration(hint: 'استبدال'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _ActionIcon(
                          key: const ValueKey('replace-current'),
                          tooltip: 'استبدال النتيجة الحالية',
                          icon: Icons.find_replace_outlined,
                          onPressed: matches == 0 ? null : onReplaceCurrent,
                        ),
                        _ActionIcon(
                          key: const ValueKey('replace-all'),
                          tooltip: 'استبدال الكل',
                          icon: Icons.done_all_rounded,
                          onPressed: matches == 0 ? null : onReplaceAll,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  InputDecoration _decoration({required String hint, String? suffix}) =>
      InputDecoration(
        hintText: hint,
        suffixText: suffix,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
      );
}

class _CloseFindIntent extends Intent {
  const _CloseFindIntent();
}

class _ActionIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ActionIcon({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 30,
    child: Tooltip(
      message: tooltip,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 30),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    ),
  );
}
