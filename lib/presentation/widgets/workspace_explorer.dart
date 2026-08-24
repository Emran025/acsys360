import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/file_node.dart';
import 'arabic_file_icon.dart';

enum _WorkspaceAction { open, cut, delete, paste, newFile, newFolder, rename }

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
  final Future<void> Function(String path) onRename;
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
    required this.onRename,
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
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 2),
            child: Row(
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  color: colors.primary,
                  size: 19,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'مستكشف المشروع',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ExplorerIcon(
                  key: const ValueKey('workspace-refresh'),
                  icon: Icons.refresh_rounded,
                  tooltip: 'تحديث الملفات',
                  onPressed: isLoading ? null : onRefresh,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  tooltip: 'فتح ملف',
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onChooseFolder,
              onSecondaryTapUp: (details) =>
                  _showRootMenu(context, details.globalPosition),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _rootName.isEmpty ? 'اختر مجلدًا' : _rootName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded, size: 18),
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
                            padding: const EdgeInsets.fromLTRB(4, 3, 4, 12),
                            children: [
                              for (final node in nodes)
                                _WorkspaceTreeNode(
                                  node: node,
                                  hasCutPath: hasCutPath,
                                  selectedPath: selectedPath,
                                  onSelect: onSelect,
                                  onOpen: onOpen,
                                  onDelete: onDelete,
                                  onRename: onRename,
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
            child: Text('لصق هنا'),
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
  final Future<void> Function()? onPressed;

  const _ExplorerIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 30),
    ),
  );
}

class _EmptyExplorer extends StatelessWidget {
  const _EmptyExplorer();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        'المجلد فارغ',
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
  final Future<void> Function(String path) onRename;
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
    required this.onRename,
    required this.onCut,
    required this.onPaste,
    required this.onNewFile,
    required this.onNewFolder,
  });

  @override
  Widget build(BuildContext context) {
    if (!node.isDirectory) return _buildFile(context);
    return _buildDirectory(context);
  }

  Widget _buildFile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onSecondaryTapUp: (details) {
        onSelect(node.path, isDirectory: false);
        _showFileMenu(context, details.globalPosition);
      },
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 8),
          selected: node.path == selectedPath,
          selectedTileColor: colors.primaryContainer.withValues(alpha: .38),
          leading: _fileLeading(colors),
          title: Text(
            node.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: node.path == selectedPath ? colors.primary : null,
            ),
          ),
          onTap: () {
            onSelect(node.path, isDirectory: false);
            onOpen(node.path);
          },
        ),
      ),
    );
  }

  Widget _buildDirectory(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onSecondaryTapUp: (details) {
        onSelect(node.path, isDirectory: true);
        _showDirectoryMenu(context, details.globalPosition);
      },
      child: Container(
        decoration: BoxDecoration(
          color: node.path == selectedPath
              ? colors.primaryContainer.withValues(alpha: .38)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            initiallyExpanded: false,
            onExpansionChanged: (_) => onSelect(node.path, isDirectory: true),
            tilePadding: const EdgeInsetsDirectional.only(start: 2, end: 4),
            childrenPadding: const EdgeInsetsDirectional.only(start: 16),
            visualDensity: VisualDensity.compact,
            leading: Icon(
              Icons.folder_outlined,
              size: 18,
              color: node.path == selectedPath
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
            title: Text(
              node.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: node.path == selectedPath ? colors.primary : null,
              ),
            ),
            children: [
              for (final child in node.children)
                _WorkspaceTreeNode(
                  node: child,
                  hasCutPath: hasCutPath,
                  selectedPath: selectedPath,
                  onSelect: onSelect,
                  onOpen: onOpen,
                  onDelete: onDelete,
                  onRename: onRename,
                  onCut: onCut,
                  onPaste: onPaste,
                  onNewFile: onNewFile,
                  onNewFolder: onNewFolder,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileLeading(ColorScheme colors) => ArabicFileIcon(
    path: node.name,
    fallback: _fileIcon,
    size: 17,
    color: node.path == selectedPath ? colors.primary : colors.onSurfaceVariant,
  );

  IconData get _fileIcon {
    final extension = node.name.toLowerCase().split('.').last;
    return switch (extension) {
      'arb' || 'json' || 'yaml' || 'yml' => Icons.data_object_rounded,
      'dart' || 'js' || 'ts' || 'tsx' || 'jsx' => Icons.code_rounded,
      'css' || 'scss' || 'html' => Icons.language_rounded,
      'md' || 'txt' => Icons.article_outlined,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' => Icons.image_outlined,
      'php' ||
      'py' ||
      'java' ||
      'c' ||
      'cpp' => Icons.integration_instructions_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  Future<void> _showFileMenu(BuildContext context, Offset position) async {
    final action = await _showMenu(
      context,
      position,
      items: const [
        PopupMenuItem(value: _WorkspaceAction.open, child: Text('فتح')),
        PopupMenuItem(value: _WorkspaceAction.cut, child: Text('قص')),
        PopupMenuItem(
          value: _WorkspaceAction.rename,
          child: Text('إعادة تسمية'),
        ),
        PopupMenuItem(value: _WorkspaceAction.delete, child: Text('حذف')),
      ],
    );
    if (action == _WorkspaceAction.open) await onOpen(node.path);
    if (action == _WorkspaceAction.cut) onCut(node.path);
    if (action == _WorkspaceAction.rename) await onRename(node.path);
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
            child: Text('لصق هنا'),
          ),
        const PopupMenuItem(
          value: _WorkspaceAction.newFile,
          child: Text('ملف جديد هنا'),
        ),
        const PopupMenuItem(
          value: _WorkspaceAction.newFolder,
          child: Text('مجلد جديد هنا'),
        ),
        const PopupMenuItem(value: _WorkspaceAction.cut, child: Text('قص')),
        const PopupMenuItem(
          value: _WorkspaceAction.rename,
          child: Text('إعادة تسمية'),
        ),
        const PopupMenuItem(value: _WorkspaceAction.delete, child: Text('حذف')),
      ],
    );
    if (action == _WorkspaceAction.paste) await onPaste(node.path);
    if (action == _WorkspaceAction.newFile) await onNewFile(node.path);
    if (action == _WorkspaceAction.newFolder) await onNewFolder(node.path);
    if (action == _WorkspaceAction.cut) onCut(node.path);
    if (action == _WorkspaceAction.rename) await onRename(node.path);
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
