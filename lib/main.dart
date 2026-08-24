import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/repositories/local_workspace_repository.dart';
import 'data/repositories/process_compiler_repository.dart';
import 'domain/entities/document.dart';
import 'domain/entities/file_node.dart';
import 'presentation/state/editor_controller.dart';
import 'presentation/widgets/find_replace_bar.dart';

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
  final findController = TextEditingController();
  final replaceController = TextEditingController();
  String? boundPath;
  bool showFindReplace = false;

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
    findController.dispose();
    replaceController.dispose();
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

  Future<void> _newFile() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ملف جديد'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم الملف'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await widget.controller.create(name.trim());
    }
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['arb'],
    );
    final path = file?.path;
    if (path != null && mounted) {
      await widget.controller.open(path);
    }
  }

  Future<void> _pickWorkspace() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'اختر مجلد المشروع',
    );
    if (path != null && mounted) {
      await widget.controller.changeRoot(path);
    }
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
      if (discard != true) {
        return;
      }
    }
    widget.controller.closeTab(index, discard: document.isDirty);
  }

  void _toggleFindReplace() {
    setState(() => showFindReplace = !showFindReplace);
    if (showFindReplace) {
      findController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: findController.text.length,
      );
    }
  }

  void _search(String value) {
    widget.controller.search(value);
  }

  void _replaceAll() {
    final count = widget.controller.replaceAll(
      findController.text,
      replaceController.text,
    );
    if (!mounted || count == 0) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('تم استبدال $count تطابقات')));
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
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyS, control: true): SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true): UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, meta: true): RedoIntent(),
        SingleActivator(LogicalKeyboardKey.f5): CompileIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true): FindIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true): FindIntent(),
      },
      child: Actions(
        actions: {
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) => controller.save(),
          ),
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) => controller.undo(),
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) => controller.redo(),
          ),
          CompileIntent: CallbackAction<CompileIntent>(
            onInvoke: (_) => controller.compile(),
          ),
          FindIntent: CallbackAction<FindIntent>(
            onInvoke: (_) => _toggleFindReplace(),
          ),
        },
        child: Directionality(
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
                  onPressed: _newFile,
                  icon: const Icon(Icons.note_add),
                  tooltip: 'ملف جديد',
                ),
                IconButton(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.description),
                  tooltip: 'فتح ملف',
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
                  onPressed: controller.saveAll,
                  icon: const Icon(Icons.save_as),
                  tooltip: 'حفظ الكل',
                ),
                IconButton(
                  onPressed: _toggleFindReplace,
                  icon: const Icon(Icons.search),
                  tooltip: 'بحث واستبدال',
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
                      if (showFindReplace)
                        FindReplaceBar(
                          findController: findController,
                          replaceController: replaceController,
                          matches: controller.searchMatches.length,
                          onSearch: _search,
                          onReplaceAll: _replaceAll,
                          onClose: _toggleFindReplace,
                        ),
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
                      const Divider(height: 1),
                      _StatusBar(controller: controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class CompileIntent extends Intent {
  const CompileIntent();
}

class FindIntent extends Intent {
  const FindIntent();
}

class _Explorer extends StatelessWidget {
  final EditorController controller;
  const _Explorer({required this.controller});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(8),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text('المشروع', style: Theme.of(context).textTheme.titleMedium),
      ),
      const SizedBox(height: 4),
      for (final node in controller.tree)
        _TreeNode(node: node, onOpen: controller.open),
      if (controller.tree.isEmpty)
        const Padding(
          padding: EdgeInsets.all(4),
          child: Text('لا توجد ملفات .arb'),
        ),
    ],
  );
}

class _TreeNode extends StatelessWidget {
  final FileNode node;
  final Future<void> Function(String path) onOpen;
  const _TreeNode({required this.node, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (!node.isDirectory) {
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        leading: const Icon(Icons.description_outlined, size: 18),
        title: Text(node.name, overflow: TextOverflow.ellipsis),
        onTap: () => onOpen(node.path),
      );
    }
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(left: 16),
      leading: const Icon(Icons.folder_outlined, size: 18),
      title: Text(node.name, overflow: TextOverflow.ellipsis),
      children: [
        for (final child in node.children)
          _TreeNode(node: child, onOpen: onOpen),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  final EditorController controller;
  const _StatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final dirty = controller.workspace.documents
        .where((document) => document.isDirty)
        .length;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.workspace.rootPath,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('تعديلات غير محفوظة: $dirty'),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
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
