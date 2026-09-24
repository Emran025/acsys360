import 'dart:io';
import 'package:flutter/material.dart';

import '../../controllers/editor_controller.dart';
import 'arabic_file_icon.dart';

class EditorTabsWidget extends StatefulWidget {
  final EditorController controller;
  final Future<void> Function(int index) onClose;
  final bool showWelcome;

  const EditorTabsWidget({
    super.key,
    required this.controller,
    required this.onClose,
    this.showWelcome = false,
  });

  @override
  State<EditorTabsWidget> createState() => _EditorTabsWidgetState();
}

class _EditorTabsWidgetState extends State<EditorTabsWidget> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documents = widget.controller.workspace.documents;
    final welcomeOffset = widget.showWelcome ? 1 : 0;
    return SizedBox(
      height: 28,
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          TabScrollButtonWidget(
            icon: Icons.chevron_left_rounded,
            tooltip: 'تمرير التبويبات يسارًا',
            onPressed: () => _scrollBy(220),
          ),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: documents.length + welcomeOffset,
              separatorBuilder: (_, _) => const SizedBox(width: 1),
              itemBuilder: (context, index) {
                if (widget.showWelcome && index == 0) {
                  return const WelcomeTabWidget();
                }
                final documentIndex = index - welcomeOffset;
                final document = documents[documentIndex];
                final active =
                    document.path == widget.controller.activeDocument?.path;
                final name = document.path.split(Platform.pathSeparator).last;
                return InkWell(
                  onTap: () => widget.controller.selectTab(documentIndex),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 118,
                      maxWidth: 220,
                    ),
                    padding: const EdgeInsetsDirectional.only(
                      start: 10,
                      end: 4,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : null,
                      border: Border(
                        bottom: BorderSide(
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        ArabicFileIcon(
                          path: document.path,
                          fallback: tabFileIcon(document.path),
                          size: 16,
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '$name${document.isDirty ? ' *' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: active ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'إغلاق الملف',
                          onPressed: () => widget.onClose(documentIndex),
                          icon: const Icon(Icons.close_rounded, size: 15),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
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
                );
              },
            ),
          ),
          TabScrollButtonWidget(
            icon: Icons.chevron_right_rounded,
            tooltip: 'تمرير التبويبات يمينًا',
            onPressed: () => _scrollBy(-220),
          ),
        ],
      ),
    );
  }

  void _scrollBy(double amount) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + amount).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }
}

class TabScrollButtonWidget extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const TabScrollButtonWidget({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    style: IconButton.styleFrom(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );
}

IconData tabFileIcon(String path) {
  final extension = path.split('.').length > 1
      ? path.split('.').last.toLowerCase()
      : '';
  return switch (extension) {
    'arb' => Icons.code_rounded,
    'dart' ||
    'js' ||
    'ts' ||
    'php' ||
    'py' ||
    'java' ||
    'cs' => Icons.integration_instructions_outlined,
    'json' || 'yaml' || 'yml' || 'xml' => Icons.data_object_rounded,
    'md' || 'txt' => Icons.description_outlined,
    'png' || 'jpg' || 'jpeg' || 'svg' => Icons.image_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}

class WelcomeTabWidget extends StatelessWidget {
  const WelcomeTabWidget({super.key});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 118),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: Border(
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        Icon(
          Icons.home_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 7),
        const Text('Welcome'),
        const SizedBox(width: 8),
        const Icon(Icons.close_rounded, size: 15),
      ],
    ),
  );
}
