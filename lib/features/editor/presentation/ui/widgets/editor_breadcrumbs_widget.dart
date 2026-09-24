import 'dart:io';
import 'package:flutter/material.dart';

import 'editor_tabs_widget.dart';

class EditorBreadcrumbsWidget extends StatelessWidget {
  final String rootPath;
  final String? activePath;

  const EditorBreadcrumbsWidget({
    super.key,
    required this.rootPath,
    required this.activePath,
  });

  @override
  Widget build(BuildContext context) {
    final path = activePath;
    if (path == null) return const SizedBox(height: 28);
    final root = Directory(rootPath).absolute.path;
    final absolute = File(path).absolute.path;
    final relative = absolute.startsWith('$root${Platform.pathSeparator}')
        ? absolute.substring(root.length + 1)
        : absolute;
    final segments = relative
        .split(Platform.pathSeparator)
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return const SizedBox(height: 28);
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 28,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                BreadcrumbItemWidget(
                  icon: Icons.folder_open_outlined,
                  label: root.split(Platform.pathSeparator).last,
                ),
                for (final segment in segments) ...[
                  const Icon(Icons.chevron_right_rounded, size: 15),
                  BreadcrumbItemWidget(
                    icon: segment == segments.last
                        ? tabFileIcon(segment)
                        : Icons.folder_outlined,
                    label: segment,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BreadcrumbItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;

  const BreadcrumbItemWidget({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}
