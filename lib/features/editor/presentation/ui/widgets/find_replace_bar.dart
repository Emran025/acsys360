import 'package:flutter/material.dart';

class FindReplaceBar extends StatelessWidget {
  final TextEditingController findController;
  final TextEditingController replaceController;
  final int matches;
  final int currentMatch;
  final ValueChanged<String> onSearch;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onReplaceCurrent;
  final VoidCallback onReplaceAll;
  final VoidCallback onClose;

  const FindReplaceBar({
    super.key,
    required this.findController,
    required this.replaceController,
    required this.matches,
    required this.currentMatch,
    required this.onSearch,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onReplaceCurrent,
    required this.onReplaceAll,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: findController,
              autofocus: true,
              onChanged: onSearch,
              decoration: InputDecoration(
                labelText: 'بحث',
                hintText: 'النص المطلوب',
                isDense: true,
                suffixText: matches == 0 ? '0' : '${currentMatch + 1}/$matches',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: replaceController,
              decoration: InputDecoration(
                labelText: 'استبدال بـ',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          _ActionIcon(
            key: const ValueKey('find-first'),
            tooltip: 'النتيجة الأولى',
            icon: Icons.first_page_rounded,
            onPressed: matches == 0 ? null : onFirst,
          ),
          _ActionIcon(
            key: const ValueKey('find-previous'),
            tooltip: 'النتيجة السابقة',
            icon: Icons.navigate_before_rounded,
            onPressed: matches == 0 ? null : onPrevious,
          ),
          _ActionIcon(
            key: const ValueKey('find-next'),
            tooltip: 'النتيجة التالية',
            icon: Icons.navigate_next_rounded,
            onPressed: matches == 0 ? null : onNext,
          ),
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
          _ActionIcon(
            key: const ValueKey('find-close'),
            tooltip: 'إغلاق البحث',
            icon: Icons.close_rounded,
            onPressed: onClose,
          ),
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 19)),
  );
}
