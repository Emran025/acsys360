import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter/material.dart';

class CompletionPopoverWidget extends StatelessWidget {
  final List<AssistCompletionItem> items;
  final int selectedIndex;
  final ValueChanged<AssistCompletionItem> onSelect;
  final VoidCallback onClose;

  const CompletionPopoverWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 12,
                end: 4,
                top: 4,
                bottom: 4,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اقتراحات الإكمال',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 17),
                    tooltip: 'إغلاق الاقتراحات',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: items.length > 5 ? 240 : items.length * 48,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = index == selectedIndex;
                  return Material(
                    color: selected
                        ? colors.primaryContainer.withValues(alpha: .55)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelect(item),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          12,
                          6,
                          12,
                          6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.kind == 'symbol'
                                  ? Icons.data_object_rounded
                                  : Icons.code_rounded,
                              size: 17,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  if (item.detail.isNotEmpty)
                                    Text(
                                      item.detail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
