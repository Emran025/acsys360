import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'data/repositories/local_workspace_repository.dart';
import 'data/repositories/process_compiler_repository.dart';
import 'domain/entities/document.dart';
import 'presentation/state/editor_controller.dart';

void main() {
  final repository = LocalWorkspaceRepository();
  runApp(
    ArabicEditorApp(
      controller: EditorController(
        repository: repository,
        compiler: const ProcessCompilerRepository(
          executable: 'dart',
          arguments: ['run', 'packages/compiler_core/bin/arabicc.dart'],
        ),
        rootPath: Directory.current.path,
      ),
    ),
  );
}

class ArabicEditorApp extends StatelessWidget {
  final EditorController controller;

  const ArabicEditorApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'محرر اللغة العربية',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: EditorShell(controller: controller),
    ),
  );
}

class EditorShell extends StatefulWidget {
  final EditorController controller;

  const EditorShell({super.key, required this.controller});

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  final textController = TextEditingController();
  String? boundPath;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncDocument);
    widget.controller.refreshFiles();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncDocument);
    textController.dispose();
    super.dispose();
  }

  void _syncDocument() {
    final document = widget.controller.activeDocument;
    if (document == null) return;
    if (document.path != boundPath || textController.text != document.text) {
      boundPath = document.path;
      textController.value = TextEditingValue(text: document.text);
    }
  }

  Future<void> _pickWorkspace() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'اختر مجلد المشروع',
    );
    if (path != null && mounted) await widget.controller.changeRoot(path);
  }

  Future<void> _closeTab(int index) async {
    final document = widget.controller.workspace.documents[index];
    if (document.isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تغييرات غير محفوظة'),
          content: Text(
            'هل تريد إغلاق ${document.path.split(Platform.pathSeparator).last} دون حفظ؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إغلاق دون حفظ'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    widget.controller.closeTab(index, discard: document.isDirty);
  }

  void _onTextChanged(String value) {
    final document = widget.controller.activeDocument;
    if (document == null || value == document.text) return;
    widget.controller.edit(
      TextEdit(offset: 0, before: document.text, after: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final active = controller.activeDocument;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محرر اللغة العربية'),
          actions: [
            IconButton(
              onPressed: _pickWorkspace,
              icon: const Icon(Icons.folder_open),
              tooltip: 'فتح مجلد',
            ),
            IconButton(
              onPressed: controller.refreshFiles,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
            IconButton(
              onPressed: controller.undo,
              icon: const Icon(Icons.undo),
              tooltip: 'تراجع',
            ),
            IconButton(
              onPressed: controller.redo,
              icon: const Icon(Icons.redo),
              tooltip: 'إعادة',
            ),
            IconButton(
              onPressed: controller.save,
              icon: const Icon(Icons.save),
              tooltip: 'حفظ',
            ),
            IconButton(
              onPressed: controller.compile,
              icon: const Icon(Icons.play_arrow),
              tooltip: 'ترجمة',
            ),
          ],
        ),
        body: Row(
          children: [
            SizedBox(width: 260, child: _Explorer(controller: controller)),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _Tabs(controller: controller, onClose: _closeTab),
                  Expanded(
                    child: active == null
                        ? const Center(
                            child: Text('افتح ملفًا من مستكشف المشروع'),
                          )
                        : TextField(
                            controller: textController,
                            onChanged: _onTextChanged,
                            expands: true,
                            maxLines: null,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(16),
                              border: InputBorder.none,
                            ),
                          ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 120,
                    child: _DiagnosticsPanel(controller: controller),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Explorer extends StatelessWidget {
  final EditorController controller;
  const _Explorer({required this.controller});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      Text('المشروع', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final path in controller.files)
        ListTile(
          dense: true,
          leading: const Icon(Icons.description_outlined, size: 18),
          title: Text(path.split(Platform.pathSeparator).last),
          onTap: () => controller.open(path),
        ),
      if (controller.files.isEmpty) const Text('لا توجد ملفات .arb'),
    ],
  );
}

class _DiagnosticsPanel extends StatelessWidget {
  final EditorController controller;
  const _DiagnosticsPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final result = controller.compilation;
    if (result == null) return const Center(child: Text('لا توجد نتيجة ترجمة'));
    if (result.diagnostics.isEmpty) {
      return Center(
        child: Text(result.success ? 'تمت الترجمة بنجاح' : 'فشلت الترجمة'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final diagnostic in result.diagnostics)
          Text(
            '${diagnostic['phase'] ?? 'compiler'}: ${diagnostic['message'] ?? diagnostic}',
          ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  final EditorController controller;
  final Future<void> Function(int index) onClose;
  const _Tabs({required this.controller, required this.onClose});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (
          var index = 0;
          index < controller.workspace.documents.length;
          index++
        )
          InputChip(
            label: Text(
              '${controller.workspace.documents[index].path.split(Platform.pathSeparator).last}${controller.workspace.documents[index].isDirty ? ' *' : ''}',
            ),
            selected:
                controller.workspace.documents[index].path ==
                controller.activeDocument?.path,
            onPressed: () => controller.selectTab(index),
            onDeleted: () => onClose(index),
          ),
      ],
    ),
  );
}
