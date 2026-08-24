import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/file_node.dart';

class WorkspaceExplorer extends StatelessWidget {
  final String rootPath;
  final List<FileNode> nodes;
  final bool isLoading;
  final Future<void> Function() onChooseFolder;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onNewFile;
  final Future<void> Function(String path) onOpen;

  const WorkspaceExplorer({
    super.key,
    required this.rootPath,
    required this.nodes,
    required this.isLoading,
    required this.onChooseFolder,
    required this.onRefresh,
    required this.onNewFile,
    required this.onOpen,
  });

  String get _rootName {
    final normalized = Directory(rootPath).absolute.path;
    return normalized.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 8),
            child: Row(
              children: [
                Icon(Icons.folder_copy_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'مستكشف المشروع',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث الملفات',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onChooseFolder,
              child: Ink(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_open_rounded, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _rootName.isEmpty ? 'اختر مجلدًا' : _rootName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            rootPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: OutlinedButton.icon(
              onPressed: onNewFile,
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: const Text('ملف عربي جديد'),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : nodes.isEmpty
                ? const _EmptyExplorer()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                    children: [
                      for (final node in nodes)
                        _WorkspaceTreeNode(node: node, onOpen: onOpen),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyExplorer extends StatelessWidget {
  const _EmptyExplorer();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Text(
        'لا توجد ملفات .arb داخل هذا المجلد',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}

class _WorkspaceTreeNode extends StatelessWidget {
  final FileNode node;
  final Future<void> Function(String path) onOpen;

  const _WorkspaceTreeNode({required this.node, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (!node.isDirectory) {
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: const Icon(Icons.code_rounded, size: 18),
        title: Text(node.name, overflow: TextOverflow.ellipsis),
        onTap: () => onOpen(node.path),
      );
    }
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsetsDirectional.only(start: 14),
      leading: const Icon(Icons.folder_outlined, size: 19),
      title: Text(node.name, overflow: TextOverflow.ellipsis),
      children: [
        for (final child in node.children)
          _WorkspaceTreeNode(node: child, onOpen: onOpen),
      ],
    );
  }
}
