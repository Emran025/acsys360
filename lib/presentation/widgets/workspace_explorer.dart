import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/file_node.dart';

enum _WorkspaceAction { open, cut, delete, paste, newFile, newFolder }

class WorkspaceExplorer extends StatelessWidget {
  final String rootPath;
  final List<FileNode> nodes;
  final bool isLoading;
  final bool hasCutPath;
  final String? selectedPath;
  final String? selectedDirectoryPath;
  final void Function(String path, {required bool isDirectory}) onSelect;
  final Future<void> Function() onChooseFolder;
  final Future<void> Function() onOpenFile;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String rootPath) onNewFile;
  final Future<void> Function(String rootPath) onNewFolder;
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
    required this.selectedPath,
    required this.selectedDirectoryPath,
    required this.onSelect,
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _ExplorerIcon(
                  key: const ValueKey('workspace-new-file'),
                  icon: Icons.note_add_outlined,
                  tooltip: 'ملف عربي جديد داخل المجلد المحدد',
                  onPressed: () => onNewFile(selectedDirectoryPath ?? rootPath),
                ),
                _ExplorerIcon(
                  key: const ValueKey('workspace-new-folder'),
                  icon: Icons.create_new_folder_outlined,
                  tooltip: 'مجلد جديد داخل المجلد المحدد',
                  onPressed: () =>
                      onNewFolder(selectedDirectoryPath ?? rootPath),
                ),
                _ExplorerIcon(
                  key: const ValueKey('workspace-open-file'),
                  icon: Icons.file_open_outlined,
                  tooltip: 'فتح ملف عربي',
                  onPressed: onOpenFile,
                ),
                _ExplorerIcon(
                  key: const ValueKey('workspace-open-folder'),
                  icon: Icons.drive_folder_upload_outlined,
                  tooltip: 'فتح مجلد Workspace',
                  onPressed: onChooseFolder,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onChooseFolder,
              onSecondaryTapUp: (details) =>
                  _showRootMenu(context, details.globalPosition),
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
                    onSecondaryTapUp: (details) =>
                        _showRootMenu(context, details.globalPosition),
                    child: nodes.isEmpty
                        ? const _EmptyExplorer()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                            children: [
                              for (final node in nodes)
                                _WorkspaceTreeNode(
                                  node: node,
                                  hasCutPath: hasCutPath,
                                  selectedPath: selectedPath,
                                  onSelect: onSelect,
                                  onOpen: onOpen,
                                  onDelete: onDelete,
                                  onCut: onCut,
                                  onPaste: onPaste,
                                  onNewFile: onNewFile,
                                  onNewFolder: onNewFolder,
                                ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRootMenu(BuildContext context, Offset position) async {
    final action = await _showMenu(
      context,
      position,
      items: [
        if (hasCutPath)
          const PopupMenuItem(
            value: _WorkspaceAction.paste,
            child: Text('لصق الملف هنا'),
          ),
        const PopupMenuItem(
          value: _WorkspaceAction.newFile,
          child: Text('ملف عربي جديد'),
        ),
        const PopupMenuItem(
          value: _WorkspaceAction.newFolder,
          child: Text('مجلد جديد'),
        ),
        const PopupMenuItem(
          value: _WorkspaceAction.open,
          child: Text('اختيار مجلد Workspace'),
        ),
      ],
    );
    if (action == _WorkspaceAction.paste) await onPaste(rootPath);
    if (action == _WorkspaceAction.newFile) await onNewFile(rootPath);
    if (action == _WorkspaceAction.newFolder) await onNewFolder(rootPath);
    if (action == _WorkspaceAction.open) await onChooseFolder();
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

class _ExplorerIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;

  const _ExplorerIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 19)),
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
  final String? selectedPath;
  final void Function(String path, {required bool isDirectory}) onSelect;
  final Future<void> Function(String path) onOpen;
  final Future<void> Function(String path) onDelete;
  final void Function(String path) onCut;
  final Future<void> Function(String targetDirectory) onPaste;
  final Future<void> Function(String rootPath) onNewFile;
  final Future<void> Function(String rootPath) onNewFolder;

  const _WorkspaceTreeNode({
    required this.node,
    required this.hasCutPath,
    required this.selectedPath,
    required this.onSelect,
    required this.onOpen,
    required this.onDelete,
    required this.onCut,
    required this.onPaste,
    required this.onNewFile,
    required this.onNewFolder,
  });

  @override
  Widget build(BuildContext context) {
    if (!node.isDirectory) {
      final colors = Theme.of(context).colorScheme;
      return GestureDetector(
        onSecondaryTapUp: (details) {
          onSelect(node.path, isDirectory: false);
          _showFileMenu(context, details.globalPosition);
        },
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          selected: node.path == selectedPath,
          selectedTileColor: colors.primaryContainer.withValues(alpha: .36),
          leading: const Icon(Icons.code_rounded, size: 18),
          title: Text(node.name, overflow: TextOverflow.ellipsis),
          onTap: () {
            onSelect(node.path, isDirectory: false);
            onOpen(node.path);
          },
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onSecondaryTapUp: (details) {
        onSelect(node.path, isDirectory: true);
        _showDirectoryMenu(context, details.globalPosition);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: node.path == selectedPath
              ? colors.primaryContainer.withValues(alpha: .36)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (_) => onSelect(node.path, isDirectory: true),
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: const EdgeInsetsDirectional.only(start: 14),
          leading: const Icon(Icons.folder_outlined, size: 19),
          title: Text(node.name, overflow: TextOverflow.ellipsis),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: Row(
                children: [
                  _TreeAction(
                    tooltip: 'ملف جديد داخل ${node.name}',
                    icon: Icons.note_add_outlined,
                    onPressed: () => onNewFile(node.path),
                  ),
                  _TreeAction(
                    tooltip: 'مجلد جديد داخل ${node.name}',
                    icon: Icons.create_new_folder_outlined,
                    onPressed: () => onNewFolder(node.path),
                  ),
                ],
              ),
            ),
            for (final child in node.children)
              _WorkspaceTreeNode(
                node: child,
                hasCutPath: hasCutPath,
                selectedPath: selectedPath,
                onSelect: onSelect,
                onOpen: onOpen,
                onDelete: onDelete,
                onCut: onCut,
                onPaste: onPaste,
                onNewFile: onNewFile,
                onNewFolder: onNewFolder,
              ),
          ],
        ),
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
        const PopupMenuItem(
          value: _WorkspaceAction.newFile,
          child: Text('ملف جديد هنا'),
        ),
        const PopupMenuItem(
          value: _WorkspaceAction.newFolder,
          child: Text('مجلد جديد هنا'),
        ),
        const PopupMenuItem(value: _WorkspaceAction.delete, child: Text('حذف')),
      ],
    );
    if (action == _WorkspaceAction.paste) await onPaste(node.path);
    if (action == _WorkspaceAction.newFile) await onNewFile(node.path);
    if (action == _WorkspaceAction.newFolder) await onNewFolder(node.path);
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

class _TreeAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;

  const _TreeAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 17)),
  );
}
