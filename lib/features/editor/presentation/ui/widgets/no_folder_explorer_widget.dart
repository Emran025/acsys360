import 'dart:io';
import 'package:flutter/material.dart';

import '../../controllers/editor_controller.dart';
import 'editor_tabs_widget.dart';

class NoFolderExplorerWidget extends StatelessWidget {
  final EditorController controller;
  final Future<void> Function() onChooseFolder;
  final Future<void> Function() onOpenFile;

  const NoFolderExplorerWidget({
    super.key,
    required this.controller,
    required this.onChooseFolder,
    required this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
            child: Row(
              children: [
                Text(
                  'Explorer',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'فتح ملف',
                  onPressed: onOpenFile,
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  style: IconButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const NoFolderSectionTitleWidget(
            icon: Icons.keyboard_arrow_down_rounded,
            title: 'Open Editors',
          ),
          if (controller.workspace.documents.isEmpty)
            const OpenEditorRowWidget()
          else
            for (
              var index = 0;
              index < controller.workspace.documents.length;
              index++
            )
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 10,
                  end: 8,
                ),
                leading: Icon(
                  tabFileIcon(controller.workspace.documents[index].path),
                  size: 17,
                ),
                title: Text(
                  controller.workspace.documents[index].path
                      .split(Platform.pathSeparator)
                      .last,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => controller.selectTab(index),
              ),
          const Divider(height: 1),
          const NoFolderSectionTitleWidget(
            icon: Icons.keyboard_arrow_down_rounded,
            title: 'No Folder Opened',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'لم يتم فتح مجلد بعد.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onChooseFolder,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: const Text('فتح مجلد'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'فتح مجلد سيعرض شجرة المشروع هنا، بينما تبقى الملفات المفتوحة مستقلة عن Workspace.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoFolderSectionTitleWidget extends StatelessWidget {
  final IconData icon;
  final String title;

  const NoFolderSectionTitleWidget({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 4),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class OpenEditorRowWidget extends StatelessWidget {
  const OpenEditorRowWidget({super.key});

  @override
  Widget build(BuildContext context) => const ListTile(
    dense: true,
    visualDensity: VisualDensity.compact,
    contentPadding: EdgeInsetsDirectional.only(start: 10, end: 8),
    leading: Icon(Icons.home_outlined, size: 17),
    title: Text('Welcome'),
  );
}
