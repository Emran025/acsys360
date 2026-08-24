import 'dart:io';

import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/repositories/local_workspace_repository.dart';
import 'data/repositories/process_compiler_repository.dart';
import 'domain/entities/document.dart';
import 'presentation/state/editor_controller.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/widgets/editor_dialogs.dart';
import 'presentation/widgets/collapsible_panel.dart';
import 'presentation/widgets/editor_top_bar.dart';
import 'presentation/widgets/find_replace_bar.dart';
import 'presentation/widgets/line_numbered_editor.dart';
import 'presentation/widgets/workspace_explorer.dart';

void main() {
  final repository = LocalWorkspaceRepository();
  final compiler = _createCompilerRepository();
  runApp(
    ArabicEditorApp(
      controller: EditorController(
        repository: repository,
        compiler: compiler,
        assistant: compiler,
        rootPath: Directory.current.path,
      ),
    ),
  );
}

ProcessCompilerRepository _createCompilerRepository() {
  final compilerName = Platform.isWindows ? 'arabicc.exe' : 'arabicc';
  final bundledPath = [
    File(Platform.resolvedExecutable).parent.path,
    'compiler',
    compilerName,
  ].join(Platform.pathSeparator);
  if (File(bundledPath).existsSync()) {
    return ProcessCompilerRepository(
      executable: bundledPath,
      arguments: const ['--protocol'],
      processWorkingDirectory: File(Platform.resolvedExecutable).parent.path,
    );
  }
  return ProcessCompilerRepository(
    executable: 'dart',
    arguments: const [
      'run',
      'packages/compiler_core/bin/arabicc.dart',
      '--protocol',
    ],
    processWorkingDirectory: Directory.current.path,
  );
}

class ArabicEditorApp extends StatefulWidget {
  final EditorController controller;

  const ArabicEditorApp({super.key, required this.controller});

  @override
  State<ArabicEditorApp> createState() => _ArabicEditorAppState();
}

class _ArabicEditorAppState extends State<ArabicEditorApp> {
  ThemeMode themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      themeMode = themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'محرر اللغة العربية',
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: EditorShell(
        controller: widget.controller,
        onToggleTheme: _toggleTheme,
        isDark: themeMode == ThemeMode.dark,
      ),
    ),
  );
}

class EditorShell extends StatefulWidget {
  final EditorController controller;
  final VoidCallback? onToggleTheme;
  final bool isDark;

  const EditorShell({
    super.key,
    required this.controller,
    this.onToggleTheme,
    this.isDark = false,
  });

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  final textController = TextEditingController();
  final findController = TextEditingController();
  final replaceController = TextEditingController();
  String? boundPath;
  bool showFindReplace = false;
  bool isRefreshing = false;
  bool topBarExpanded = true;
  bool resultsExpanded = true;

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

  Future<void> _refreshFiles() async {
    if (isRefreshing) return;
    setState(() => isRefreshing = true);
    try {
      await widget.controller.refreshFiles();
    } finally {
      if (mounted) setState(() => isRefreshing = false);
    }
  }

  void _syncDocument() {
    final document = widget.controller.activeDocument;
    if (document == null) return;
    if (document.path != boundPath || textController.text != document.text) {
      boundPath = document.path;
      textController.value = TextEditingValue(text: document.text);
    }
  }

  int get _cursorOffset {
    final offset = textController.selection.baseOffset;
    return offset < 0 ? textController.text.length : offset;
  }

  void _applyCompletion(AssistCompletionItem item) {
    final response = widget.controller.assistance;
    final document = widget.controller.activeDocument;
    if (response == null || document == null) return;
    final start = response.replaceStart.clamp(0, document.text.length).toInt();
    final end = (start + response.replaceLength)
        .clamp(start, document.text.length)
        .toInt();
    final text = document.text.replaceRange(start, end, item.insertText);
    textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: start + item.insertText.length,
      ),
    );
    widget.controller.edit(
      TextEdit(
        offset: start,
        before: document.text.substring(start, end),
        after: item.insertText,
      ),
    );
    widget.controller.clearAssist();
  }

  Future<void> _newFile() async {
    final name = await showNewFileDialog(context);
    if (name != null && mounted) await widget.controller.create(name);
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
    if (document.isDirty &&
        !await confirmDiscardDialog(context, path: document.path)) {
      return;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم استبدال $count تطابقات')));
  }

  void _onTextChanged(String value) {
    final document = widget.controller.activeDocument;
    if (document == null || value == document.text) return;
    final before = document.text;
    var start = 0;
    while (start < before.length &&
        start < value.length &&
        before.codeUnitAt(start) == value.codeUnitAt(start)) {
      start++;
    }
    var beforeEnd = before.length;
    var valueEnd = value.length;
    while (beforeEnd > start &&
        valueEnd > start &&
        before.codeUnitAt(beforeEnd - 1) == value.codeUnitAt(valueEnd - 1)) {
      beforeEnd--;
      valueEnd--;
    }
    widget.controller.edit(
      TextEdit(
        offset: start,
        before: before.substring(start, beforeEnd),
        after: value.substring(start, valueEnd),
      ),
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
        SingleActivator(LogicalKeyboardKey.space, control: true):
            CompletionIntent(),
        SingleActivator(LogicalKeyboardKey.space, meta: true):
            CompletionIntent(),
        SingleActivator(LogicalKeyboardKey.f1): HelpIntent(),
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
          CompletionIntent: CallbackAction<CompletionIntent>(
            onInvoke: (_) => controller.complete(_cursorOffset),
          ),
          HelpIntent: CallbackAction<HelpIntent>(
            onInvoke: (_) => controller.help(_cursorOffset),
          ),
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                EditorTopBar(
                  rootPath: controller.workspace.rootPath,
                  activePath: active?.path,
                  isDark: widget.isDark,
                  expanded: topBarExpanded,
                  onChooseFolder: _pickWorkspace,
                  onSave: controller.save,
                  onSaveAll: controller.saveAll,
                  onFind: _toggleFindReplace,
                  onComplete: () => controller.complete(_cursorOffset),
                  onHelp: () => controller.help(_cursorOffset),
                  onCompile: controller.compile,
                  onToggleTheme: widget.onToggleTheme ?? () {},
                  onToggleExpanded: () =>
                      setState(() => topBarExpanded = !topBarExpanded),
                ),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: WorkspaceExplorer(
                          rootPath: controller.workspace.rootPath,
                          nodes: controller.tree,
                          isLoading: isRefreshing,
                          onChooseFolder: _pickWorkspace,
                          onRefresh: _refreshFiles,
                          onNewFile: _newFile,
                          onOpen: controller.open,
                        ),
                      ),
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
                            if (controller.assistance != null)
                              _AssistPanel(
                                response: controller.assistance!,
                                onSelect: _applyCompletion,
                                onClose: controller.clearAssist,
                              ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: active == null
                                    ? const _EmptyEditor()
                                    : LineNumberedEditor(
                                        controller: textController,
                                        onChanged: _onTextChanged,
                                      ),
                              ),
                            ),
                            CollapsiblePanel(
                              title: 'نتائج الترجمة',
                              icon: Icons.terminal_rounded,
                              expanded: resultsExpanded,
                              expandedHeight: 160,
                              onToggle: () => setState(
                                () => resultsExpanded = !resultsExpanded,
                              ),
                              child: _DiagnosticsPanel(controller: controller),
                            ),
                            _StatusBar(controller: controller),
                          ],
                        ),
                      ),
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

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code_off_rounded, size: 48, color: colors.primary),
          const SizedBox(height: 14),
          Text(
            'اختر ملفًا من مستكشف المشروع',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'ابدأ باختيار مجلد Workspace ثم افتح ملف .arb',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
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

class _AssistPanel extends StatelessWidget {
  final AssistResponse response;
  final ValueChanged<AssistCompletionItem> onSelect;
  final VoidCallback onClose;

  const _AssistPanel({
    required this.response,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final help = response.help;
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: help != null
          ? ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text('${help.keyword} — ${help.title}'),
              subtitle: Text('${help.description}\nالصيغة: ${help.syntax}'),
              trailing: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                tooltip: 'إغلاق المساعدة',
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: response.items.length,
                    itemBuilder: (context, index) {
                      final item = response.items[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          item.kind == 'symbol'
                              ? Icons.data_object
                              : Icons.code,
                        ),
                        title: Text(item.label),
                        subtitle: Text(item.detail),
                        onTap: () => onSelect(item),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المتوقع: ${response.expected}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        Text('البادئة: ${response.prefix}'),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                          tooltip: 'إغلاق الاقتراحات',
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

class CompletionIntent extends Intent {
  const CompletionIntent();
}

class HelpIntent extends Intent {
  const HelpIntent();
}
