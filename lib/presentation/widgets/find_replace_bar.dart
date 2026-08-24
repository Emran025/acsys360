import 'package:flutter/material.dart';

class FindReplaceBar extends StatelessWidget {
  final TextEditingController findController;
  final TextEditingController replaceController;
  final int matches;
  final ValueChanged<String> onSearch;
  final VoidCallback onReplaceAll;
  final VoidCallback onClose;

  const FindReplaceBar({
    super.key,
    required this.findController,
    required this.replaceController,
    required this.matches,
    required this.onSearch,
    required this.onReplaceAll,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 8,
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
                suffixText: '$matches',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: replaceController,
              decoration: const InputDecoration(
                labelText: 'استبدال بـ',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          FilledButton.tonal(
            onPressed: matches == 0 ? null : onReplaceAll,
            child: const Text('استبدال الكل'),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'إغلاق البحث',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}
