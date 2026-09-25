import 'package:flutter/material.dart';

class CollapsiblePanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final double expandedHeight;
  final VoidCallback onToggle;
  final ValueChanged<double>? onResize;
  final Widget child;

  const CollapsiblePanel({
    super.key,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.expandedHeight,
    required this.onToggle,
    this.onResize,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: expanded ? expandedHeight : 41,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: 40,
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          key: ValueKey('collapse-$title'),
                          onPressed: onToggle,
                          tooltip: expanded ? 'طي اللوحة' : 'توسيع اللوحة',
                          icon: Icon(
                            expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (expanded) Expanded(child: child),
            ],
          ),
          if (expanded && onResize != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 6,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) =>
                      onResize!(details.delta.dy),
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 2,
                      decoration: BoxDecoration(
                        color: colors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
