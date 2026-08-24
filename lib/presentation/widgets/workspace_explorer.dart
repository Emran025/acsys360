import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/file_node.dart';

enum _WorkspaceAction { open, cut, delete, paste }

class WorkspaceExplorer extends StatelessWidget {
  final String rootPath;
  final List<FileNode> nodes;
  final bool isLoading;
  final bool hasCutPath;
  final Future<void> Function() onChooseFolder;
  final Future<void> Function() onOpenFile;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onNewFile;
  final Future<void> Function() onNewFolder;
  final Future<void> Function(String path) onOpen;
  final Future<void> Function(String path) onDelete;
  final void Function(String path) onCut;
  final Future<void> Function(String targetDirectory) onPaste;

  const WorkspaceExplorer({
    super.key,
    required this.rootPath,
    required this.nodes,
    required this.isLoading,
    required this.hasCutPath,
    required this.onChooseFolder,
    required this.onOpenFile,
    required this.onRefresh,
    required this.onNewFile,
    required this.onNewFolder,
    required this.onOpen,
    required this.onDelete,
    required this.onCut,
    required this.onPaste,
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
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
            child: Row(
              children: [
                Icon(Icons.folder_copy_outlined, color: colors.primary),
                const SizedBox(width: 8),
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
            child: Row(
              children: [
                _ExplorerAction(
                  key: const ValueKey('workspace-new-file'),
                  icon: Icons.note_add_outlined,
                  label: 'ملف',
                  tooltip: 'إنشاء ملف عربي',
                  onPressed: onNewFile,
                ),
                _ExplorerAction(
                  key: const ValueKey('workspace-new-folder'),
                  icon: Icons.create_new_folder_outlined,
                  label: 'مجلد',
                  tooltip: 'إنشاء مجلد',
                  onPressed: onNewFolder,
                ),
                _ExplorerAction(
                  key: const ValueKey('workspace-open-file'),
                  icon: Icons.file_open_outlined,
                  label: 'فتح',
                  tooltip: 'فتح ملف عربي',
                  onPressed: onOpenFile,
                ),
                const Spacer(),
                IconButton(
                  onPressed: onChooseFolder,
                  tooltip: 'اختيار مجلد Workspace',
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onChooseFolder,
              onSecondaryTapUp: (details) => _showMenu(
                context,
                details.globalPosition,
                targetDirectory: rootPath,
                includePaste: hasCutPath,
              ),
              child: Ink(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_open_rounded, color: colors.primary),
                    const SizedBox(width: 8),
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
          const Divider(height: 1),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapUp: (details) => _showMenu(
                      context,
                      details.globalPosition,
                      targetDirectory: rootPath,
                      includePaste: hasCutPath,
                    ),
                    child: nodes.isEmpty
                        ? const _EmptyExplorer()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                            children: [
                              for (final node in nodes)
                                _WorkspaceTreeNode(
                                  node: node,
                                  hasCutPath: hasCutPath,
                                  onOpen: onOpen,
                                  onDelete: onDelete,
                                  onCut: onCut,
                                  onPaste: onPaste,
                                ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    Offset globalPosition, {
    required String targetDirectory,
    required bool includePaste,
  }) async {
    final action = await showMenu<_WorkspaceAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        MediaQuery.of(context).size.width - globalPosition.dx,
        MediaQuery.of(context).size.height - globalPosition.dy,
      ),
      items: [
        if (includePaste)
          const PopupMenuItem(
            value: _WorkspaceAction.paste,
            child: Text('لصق الملف هنا'),
          ),
        const PopupMenuItem(
          value: _WorkspaceAction.open,
          child: Text('اختيار مجلد Workspace'),
        ),
      ],
    );
    if (action == _WorkspaceAction.paste) await onPaste(targetDirectory);
    if (action == _WorkspaceAction.open) await onChooseFolder();
  }
}

class _ExplorerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Future<void> Function() onPressed;

  const _ExplorerAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
    ),
  );
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
  final bool hasCutPath;
  final Future<void> Function(String path) onOpen;
  final Future<void> Function(String path) onDelete;
  final void Function(String path) onCut;
  final Future<void> Function(String targetDirectory) onPaste;

  const _WorkspaceTreeNode({
    required this.node,
    required this.hasCutPath,
    required this.onOpen,
    required this.onDelete,
    required this.onCut,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    if (!node.isDirectory) {
      return GestureDetector(
        onSecondaryTapUp: (details) =>
            _showFileMenu(context, details.globalPosition),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.code_rounded, size: 18),
          title: Text(node.name, overflow: TextOverflow.ellipsis),
          onTap: () => onOpen(node.path),
        ),
      );
    }
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showDirectoryMenu(context, details.globalPosition),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsetsDirectional.only(start: 14),
        leading: const Icon(Icons.folder_outlined, size: 19),
        title: Text(node.name, overflow: TextOverflow.ellipsis),
        children: [
          for (final child in node.children)
            _WorkspaceTreeNode(
              node: child,
              hasCutPath: hasCutPath,
              onOpen: onOpen,
              onDelete: onDelete,
              onCut: onCut,
              onPaste: onPaste,
            ),
        ],
      ),
    );
  }

  Future<void> _showFileMenu(BuildContext context, Offset position) async {
    final action = await _showMenu(
      context,
      position,
      items: const [
        PopupMenuItem(value: _WorkspaceAction.open, child: Text('فتح')),
        PopupMenuItem(value: _WorkspaceAction.cut, child: Text('قص')),
        PopupMenuItem(value: _WorkspaceAction.delete, child: Text('حذف')),
      ],
    );
    if (action == _WorkspaceAction.open) await onOpen(node.path);
    if (action == _WorkspaceAction.cut) onCut(node.path);
    if (action == _WorkspaceAction.delete) await onDelete(node.path);
  }

  Future<void> _showDirectoryMenu(BuildContext context, Offset position) async {
    final action = await _showMenu(
      context,
      position,
      items: [
        if (hasCutPath)
          const PopupMenuItem(
            value: _WorkspaceAction.paste,
            child: Text('لصق الملف هنا'),
          ),
        const PopupMenuItem(value: _WorkspaceAction.delete, child: Text('حذف')),
      ],
    );
    if (action == _WorkspaceAction.paste) await onPaste(node.path);
    if (action == _WorkspaceAction.delete) await onDelete(node.path);
  }

  Future<_WorkspaceAction?> _showMenu(
    BuildContext context,
    Offset position, {
    required List<PopupMenuEntry<_WorkspaceAction>> items,
  }) => showMenu<_WorkspaceAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      MediaQuery.of(context).size.width - position.dx,
      MediaQuery.of(context).size.height - position.dy,
    ),
    items: items,
  );
}
