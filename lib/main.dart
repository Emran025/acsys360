import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/repositories/local_workspace_repository.dart';
import 'data/repositories/process_compiler_repository.dart';
import 'domain/entities/compilation_result.dart';
import 'domain/entities/document.dart';
import 'domain/entities/editor_diagnostic.dart';
import 'presentation/state/editor_controller.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/widgets/editor_dialogs.dart';
import 'presentation/widgets/collapsible_panel.dart';
import 'presentation/widgets/editor_top_bar.dart';
import 'presentation/widgets/find_replace_bar.dart';
import 'presentation/widgets/arabic_code_controller.dart';
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
        rootPath: '',
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
  final textController = ArabicCodeController();
  final editorFocusNode = FocusNode();
  final findController = TextEditingController();
  final replaceController = TextEditingController();
  String? boundPath;
  bool showFindReplace = false;
  bool isRefreshing = false;
  bool topBarExpanded = true;
  bool resultsExpanded = true;
  EditorDiagnostic? visibleDiagnostic;
  Timer? analysisTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncDocument);
    widget.controller.refreshFiles();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncDocument);
    analysisTimer?.cancel();
    textController.dispose();
    editorFocusNode.dispose();
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
    if (document == null) {
      textController.setDiagnostics(const []);
      textController.clearGhostText();
      visibleDiagnostic = null;
      boundPath = null;
      return;
    }
    final pathChanged = document.path != boundPath;
    if (pathChanged || textController.text != document.text) {
      boundPath = document.path;
      textController.value = TextEditingValue(text: document.text);
    }
    textController.setDiagnostics(widget.controller.diagnostics);
    _syncGhostCompletion();
    if (visibleDiagnostic != null &&
        !widget.controller.diagnostics.contains(visibleDiagnostic)) {
      visibleDiagnostic = null;
    }
    if (pathChanged) _scheduleAnalysis();
  }

  void _scheduleAnalysis() {
    analysisTimer?.cancel();
    if (widget.controller.activeDocument == null) return;
    analysisTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      await widget.controller.analyze();
      if (!mounted || !_shouldSuggest) {
        widget.controller.clearAssist();
        return;
      }
      await widget.controller.complete(_cursorOffset);
    });
  }

  bool get _shouldSuggest {
    final offset = _cursorOffset;
    if (offset == 0 || offset > textController.text.length) return false;
    final character = textController.text.substring(offset - 1, offset);
    return RegExp(r'[ء-يA-Za-z_]').hasMatch(character);
  }

  void _showDiagnosticLamp(EditorDiagnostic diagnostic) {
    if (!mounted) return;
    setState(() => visibleDiagnostic = diagnostic);
  }

  void _hideTransientUi() {
    if (visibleDiagnostic != null) {
      setState(() => visibleDiagnostic = null);
    }
  }

  void _syncGhostCompletion() {
    final response = widget.controller.assistance;
    final item = widget.controller.currentCompletion;
    final expectedOffset = response == null
        ? -1
        : response.replaceStart + response.replaceLength;
    if (response == null ||
        response.help != null ||
        item == null ||
        _cursorOffset != expectedOffset) {
      textController.clearGhostText();
      return;
    }
    final prefix = response.prefix;
    final ghost = item.insertText.startsWith(prefix)
        ? item.insertText.substring(prefix.length)
        : item.insertText;
    textController.setGhostText(ghost, _cursorOffset);
  }

  void _acceptCompletion() {
    final item = widget.controller.currentCompletion;
    if (item != null) _applyCompletion(item);
  }

  KeyEventResult _handleEditorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final hardware = HardwareKeyboard.instance;
    final hasCompletion = widget.controller.currentCompletion != null;
    if (key == LogicalKeyboardKey.tab) {
      if (hardware.isShiftPressed) {
        _outdent();
      } else if (hasCompletion) {
        _acceptCompletion();
      } else {
        _indent();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && hasCompletion) {
      widget.controller.nextCompletion();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && hasCompletion) {
      widget.controller.previousCompletion();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape &&
        (hasCompletion || widget.controller.assistance != null)) {
      widget.controller.clearAssist();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyD &&
        (hardware.isControlPressed || hardware.isMetaPressed)) {
      _duplicateLine();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
    final edit = TextEdit(
      offset: start,
      before: document.text.substring(start, end),
      after: item.insertText,
    );
    widget.controller.edit(edit);
    final text =
        widget.controller.activeDocument?.text ??
        document.text.replaceRange(start, end, item.insertText);
    textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: start + item.insertText.length,
      ),
    );
    widget.controller.clearAssist();
  }

  void _onSelectionChanged(TextSelection selection) {
    _hideTransientUi();
    final response = widget.controller.assistance;
    final expectedOffset = response == null
        ? -1
        : response.replaceStart + response.replaceLength;
    if (response?.help != null ||
        (response != null && _cursorOffset != expectedOffset)) {
      widget.controller.clearAssist();
      return;
    }
    _syncGhostCompletion();
  }

  void _insertTextAtSelection(String value) {
    final selection = textController.selection;
    if (!selection.isValid) return;
    final start = selection.start;
    final end = selection.end;
    final oldText = textController.text;
    final beforeText = oldText.substring(0, start);
    final replacedText = oldText.substring(start, end);
    final nextText = '$beforeText$value${oldText.substring(end)}';
    textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    widget.controller.edit(
      TextEdit(offset: start, before: replacedText, after: value),
    );
  }

  void _indent() => _insertTextAtSelection('  ');

  void _outdent() {
    final selection = textController.selection;
    if (!selection.isValid || selection.start < 2) return;
    final startOfLine =
        textController.text.lastIndexOf('\n', selection.start - 1) + 1;
    final removeStart = selection.start - 2;
    if (removeStart >= startOfLine &&
        textController.text.substring(removeStart, selection.start) == '  ') {
      _insertTextAtSelectionAt(removeStart, selection.start, '');
    }
  }

  void _insertTextAtSelectionAt(int start, int end, String value) {
    final oldText = textController.text;
    final nextText = oldText.replaceRange(start, end, value);
    textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    widget.controller.edit(
      TextEdit(
        offset: start,
        before: oldText.substring(start, end),
        after: value,
      ),
    );
  }

  void _duplicateLine() {
    final selection = textController.selection;
    if (!selection.isValid) return;
    final oldText = textController.text;
    final lineStart = oldText.lastIndexOf('\n', selection.start - 1) + 1;
    final lineEndIndex = oldText.indexOf('\n', selection.end);
    final lineEnd = lineEndIndex == -1 ? oldText.length : lineEndIndex;
    final line = oldText.substring(lineStart, lineEnd);
    final insertAt = lineEndIndex == -1 ? lineEnd : lineEnd + 1;
    final insertion = lineEndIndex == -1 ? '\n$line' : '$line\n';
    final nextText = oldText.replaceRange(insertAt, insertAt, insertion);
    final nextSelection = selection.start >= insertAt
        ? selection.start + insertion.length
        : selection.start;
    textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextSelection),
    );
    widget.controller.edit(
      TextEdit(offset: insertAt, before: '', after: insertion),
    );
  }

  Future<void> _newFileFromWelcome() async {
    if (widget.controller.workspace.rootPath.trim().isEmpty) {
      await _pickWorkspace();
      if (widget.controller.workspace.rootPath.trim().isEmpty) return;
    }
    await _newFileAt(widget.controller.workspace.rootPath);
  }

  Future<void> _newFileAt(String rootPath) async {
    final name = await showNewFileDialog(context);
    if (name != null && mounted) {
      await widget.controller.create(name, rootPath: rootPath);
    }
  }

  Future<void> _newFolderAt(String rootPath) async {
    final name = await showNewFolderDialog(context);
    if (name != null && mounted) {
      await widget.controller.createFolder(name, rootPath: rootPath);
    }
  }

  Future<void> _openFile() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'فتح ملف عربي',
      type: FileType.custom,
      allowedExtensions: [
        LocalWorkspaceRepository.sourceExtension.substring(1),
      ],
    );
    final path = files.isEmpty ? null : files.first.path;
    if (path != null && mounted) await widget.controller.open(path);
  }

  Future<void> _deletePath(String path) async {
    if (!await confirmDeleteDialog(context, path: path) || !mounted) return;
    await widget.controller.delete(path);
  }

  Future<void> _renamePath(String path) async {
    final currentName = path.split(Platform.pathSeparator).last;
    final newName = await showRenameDialog(context, currentName: currentName);
    if (newName != null && mounted) {
      await widget.controller.rename(path, newName);
    }
  }

  Future<void> _saveAs() async {
    final active = widget.controller.activeDocument;
    if (active == null) return;
    final currentName = active.path.split(Platform.pathSeparator).last;
    final selected = await FilePicker.saveFile(
      dialogTitle: 'حفظ الملف باسم',
      fileName: currentName,
      bytes: Uint8List.fromList(utf8.encode(active.text)),
      type: FileType.custom,
      allowedExtensions: [
        LocalWorkspaceRepository.sourceExtension.substring(1),
      ],
    );
    final path = selected?.toFilePath();
    if (path == null || !mounted) return;
    final normalized =
        path.toLowerCase().endsWith(LocalWorkspaceRepository.sourceExtension)
        ? path
        : '$path${LocalWorkspaceRepository.sourceExtension}';
    await widget.controller.saveAs(normalized);
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
    _selectCurrentMatch();
  }

  void _selectCurrentMatch() {
    final match = widget.controller.currentMatch;
    if (match == null) return;
    textController.selection = TextSelection(
      baseOffset: match.offset,
      extentOffset: match.offset + match.length,
    );
    editorFocusNode.requestFocus();
  }

  void _firstMatch() {
    widget.controller.firstMatch();
    _selectCurrentMatch();
  }

  void _previousMatch() {
    widget.controller.previousMatch();
    _selectCurrentMatch();
  }

  void _nextMatch() {
    widget.controller.nextMatch();
    _selectCurrentMatch();
  }

  void _replaceCurrent() {
    final count = widget.controller.replaceCurrent(
      findController.text,
      replaceController.text,
    );
    if (count > 0) _selectCurrentMatch();
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

  Future<void> _showEditorMenu(Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      items: const [
        PopupMenuItem(value: 'format', child: Text('تنسيق المستند')),
        PopupMenuItem(value: 'save', child: Text('حفظ Ctrl+S')),
        PopupMenuItem(value: 'saveAs', child: Text('حفظ باسم Ctrl+Shift+S')),
      ],
    );
    if (!mounted) return;
    if (action == 'format') widget.controller.formatActive();
    if (action == 'save') await widget.controller.save();
    if (action == 'saveAs') await _saveAs();
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
    _scheduleAnalysis();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final active = controller.activeDocument;
    final hasWorkspace = controller.workspace.rootPath.trim().isNotEmpty;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
            SaveAsIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
            SaveAsIntent(),
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
          SaveAsIntent: CallbackAction<SaveAsIntent>(
            onInvoke: (_) => _saveAs(),
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
                  onToggleTheme: widget.onToggleTheme ?? () {},
                  onToggleExpanded: () =>
                      setState(() => topBarExpanded = !topBarExpanded),
                ),
                Expanded(
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      SizedBox(
                        width: 300,
                        child: hasWorkspace
                            ? Directionality(
                                textDirection: TextDirection.rtl,
                                child: WorkspaceExplorer(
                                  rootPath: controller.workspace.rootPath,
                                  nodes: controller.tree,
                                  isLoading: isRefreshing,
                                  hasCutPath: controller.hasCutPath,
                                  selectedPath: controller.selectedExplorerPath,
                                  selectedDirectoryPath:
                                      controller.selectedDirectoryPath,
                                  onSelect: controller.selectExplorerPath,
                                  onChooseFolder: _pickWorkspace,
                                  onOpenFile: _openFile,
                                  onRefresh: _refreshFiles,
                                  onNewFile: _newFileAt,
                                  onNewFolder: _newFolderAt,
                                  onOpen: controller.open,
                                  onDelete: _deletePath,
                                  onRename: _renamePath,
                                  onCut: controller.cut,
                                  onPaste: controller.paste,
                                ),
                              )
                            : _NoFolderExplorer(
                                controller: controller,
                                onChooseFolder: _pickWorkspace,
                                onOpenFile: _openFile,
                              ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(
                            children: [
                              _Tabs(
                                controller: controller,
                                onClose: _closeTab,
                                showWelcome: !hasWorkspace,
                              ),
                              if (hasWorkspace)
                                _Breadcrumb(
                                  rootPath: controller.workspace.rootPath,
                                  activePath: active?.path,
                                ),
                              if (showFindReplace)
                                FindReplaceBar(
                                  findController: findController,
                                  replaceController: replaceController,
                                  matches: controller.searchMatches.length,
                                  currentMatch: controller.currentMatchIndex,
                                  onSearch: _search,
                                  onFirst: _firstMatch,
                                  onPrevious: _previousMatch,
                                  onNext: _nextMatch,
                                  onReplaceCurrent: _replaceCurrent,
                                  onReplaceAll: _replaceAll,
                                  onClose: _toggleFindReplace,
                                ),
                              Expanded(
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onSecondaryTapUp: (details) =>
                                          _showEditorMenu(
                                            details.globalPosition,
                                          ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: active == null
                                            ? _WelcomeEditor(
                                                hasWorkspace: hasWorkspace,
                                                onNewFile: _newFileFromWelcome,
                                                onOpenFile: _openFile,
                                                onOpenFolder: _pickWorkspace,
                                              )
                                            : LineNumberedEditor(
                                                controller: textController,
                                                focusNode: editorFocusNode,
                                                diagnostics:
                                                    controller.diagnostics,
                                                onChanged: _onTextChanged,
                                                onSelectionChanged:
                                                    _onSelectionChanged,
                                                onTap: _hideTransientUi,
                                                onDiagnosticTap:
                                                    _showDiagnosticLamp,
                                                onKeyEvent: _handleEditorKey,
                                              ),
                                      ),
                                    ),
                                    if (visibleDiagnostic != null)
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        width: 340,
                                        child: _DiagnosticPopover(
                                          diagnostic: visibleDiagnostic!,
                                          onApply: (action) {
                                            widget.controller.applyCodeAction(
                                              action,
                                            );
                                            _hideTransientUi();
                                          },
                                          onClose: _hideTransientUi,
                                        ),
                                      ),
                                    if (controller.assistance?.help != null)
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        width: 340,
                                        child: _HelpPopover(
                                          help: controller.assistance!.help!,
                                          onClose: controller.clearAssist,
                                        ),
                                      ),
                                  ],
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
                                child: _DiagnosticsPanel(
                                  controller: controller,
                                ),
                              ),
                              _StatusBar(controller: controller),
                            ],
                          ),
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

class SaveAsIntent extends Intent {
  const SaveAsIntent();
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

class _WelcomeEditor extends StatelessWidget {
  final bool hasWorkspace;
  final Future<void> Function() onNewFile;
  final Future<void> Function() onOpenFile;
  final Future<void> Function() onOpenFolder;

  const _WelcomeEditor({
    required this.hasWorkspace,
    required this.onNewFile,
    required this.onOpenFile,
    required this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.code_rounded, size: 52, color: colors.primary),
              const SizedBox(height: 14),
              Text(
                'Arabic360',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasWorkspace
                    ? 'اختر ملفًا من مستكشف المشروع للبدء'
                    : 'لم يتم فتح مجلد بعد',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 22),
              if (!hasWorkspace)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _WelcomeAction(
                      icon: Icons.note_add_outlined,
                      label: 'ملف جديد',
                      onPressed: onNewFile,
                    ),
                    _WelcomeAction(
                      icon: Icons.file_open_outlined,
                      label: 'فتح ملف',
                      onPressed: onOpenFile,
                    ),
                    _WelcomeAction(
                      icon: Icons.folder_open_outlined,
                      label: 'فتح مجلد',
                      onPressed: onOpenFolder,
                    ),
                  ],
                )
              else
                Text(
                  'تصفح شجرة المشروع من مستكشف الملفات لفتح ملف .arb',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _WelcomeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );
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

class _DiagnosticsPanel extends StatefulWidget {
  final EditorController controller;
  const _DiagnosticsPanel({required this.controller});

  @override
  State<_DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<_DiagnosticsPanel> {
  var _stage = 0;

  static const _stages = [
    'الأخطاء',
    'Tokens',
    'Syntax Tree',
    'Symbol Table',
    'Semantic',
    '3AC',
    'Assembly',
    'التنفيذ',
  ];

  @override
  Widget build(BuildContext context) {
    final result = widget.controller.compilation;
    if (result == null) return const Center(child: Text('لا توجد نتيجة ترجمة'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (var index = 0; index < _stages.length; index++)
                TextButton(
                  onPressed: () => setState(() => _stage = index),
                  style: TextButton.styleFrom(
                    foregroundColor: index == _stage
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: Text(_stages[index]),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _stageBody(result)),
      ],
    );
  }

  Widget _stageBody(CompilationResult result) => switch (_stage) {
    0 => _diagnostics(result),
    1 => _selectable(_prettyJson(result.tokens)),
    2 => _selectable(
      result.syntaxTree == null
          ? 'لا توجد شجرة تحليل'
          : _prettyJson(result.syntaxTree),
    ),
    3 => _selectable(_prettyJson(result.symbols)),
    4 => _selectable(
      _prettyJson(
        result.diagnostics
            .where((item) => item is Map && item['phase'] == 'semantic')
            .toList(),
      ),
    ),
    5 => _selectable(result.threeAddressCode.join('\n')),
    6 => _selectable(
      result.assembly.isEmpty ? 'لا يوجد مخرج Assembly' : result.assembly,
    ),
    7 => _selectable(
      result.executionOutput.isEmpty
          ? 'لا يوجد خرج تنفيذ'
          : result.executionOutput.join('\n'),
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _diagnostics(CompilationResult result) {
    if (result.diagnostics.isEmpty) {
      return Center(
        child: Text(
          result.success ? 'تمت الترجمة والتنفيذ بنجاح' : 'فشلت الترجمة',
        ),
      );
    }
    return _selectable(
      result.diagnostics
          .map((diagnostic) {
            if (diagnostic is Map) {
              return '${diagnostic['phase'] ?? 'compiler'}: ${diagnostic['message'] ?? diagnostic}';
            }
            return '$diagnostic';
          })
          .join('\n'),
    );
  }

  Widget _selectable(String value) => SingleChildScrollView(
    padding: const EdgeInsets.all(8),
    child: SelectableText(
      value.isEmpty ? 'لا توجد بيانات لهذه المرحلة' : value,
    ),
  );
}

String _prettyJson(Object? value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return '$value';
  }
}

class _Tabs extends StatefulWidget {
  final EditorController controller;
  final Future<void> Function(int index) onClose;
  final bool showWelcome;
  const _Tabs({
    required this.controller,
    required this.onClose,
    this.showWelcome = false,
  });

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
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
      height: 38,
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          _TabScrollButton(
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
                  return _WelcomeTab();
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
                        Icon(
                          _tabFileIcon(document.path),
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
          _TabScrollButton(
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

class _TabScrollButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _TabScrollButton({
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

IconData _tabFileIcon(String path) {
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

class _WelcomeTab extends StatelessWidget {
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

class _NoFolderExplorer extends StatelessWidget {
  final EditorController controller;
  final Future<void> Function() onChooseFolder;
  final Future<void> Function() onOpenFile;

  const _NoFolderExplorer({
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
          _NoFolderSectionTitle(
            icon: Icons.keyboard_arrow_down_rounded,
            title: 'Open Editors',
          ),
          if (controller.workspace.documents.isEmpty)
            const _OpenEditorRow()
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
                  _tabFileIcon(controller.workspace.documents[index].path),
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
          const _NoFolderSectionTitle(
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

class _NoFolderSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _NoFolderSectionTitle({required this.icon, required this.title});

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

class _OpenEditorRow extends StatelessWidget {
  const _OpenEditorRow();

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    visualDensity: VisualDensity.compact,
    contentPadding: const EdgeInsetsDirectional.only(start: 10, end: 8),
    leading: const Icon(Icons.home_outlined, size: 17),
    title: const Text('Welcome'),
  );
}

class _Breadcrumb extends StatelessWidget {
  final String rootPath;
  final String? activePath;

  const _Breadcrumb({required this.rootPath, required this.activePath});

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
    return SizedBox(
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
              _BreadcrumbItem(
                icon: Icons.folder_open_outlined,
                label: root.split(Platform.pathSeparator).last,
              ),
              for (final segment in segments) ...[
                const Icon(Icons.chevron_right_rounded, size: 15),
                _BreadcrumbItem(
                  icon: segment == segments.last
                      ? _tabFileIcon(segment)
                      : Icons.folder_outlined,
                  label: segment,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BreadcrumbItem({required this.icon, required this.label});

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

class _DiagnosticPopover extends StatelessWidget {
  final EditorDiagnostic diagnostic;
  final ValueChanged<EditorCodeAction> onApply;
  final VoidCallback onClose;

  const _DiagnosticPopover({
    required this.diagnostic,
    required this.onApply,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = diagnostic.severity == EditorDiagnosticSeverity.error
        ? colors.error
        : colors.secondary;
    return Material(
      color: colors.surfaceContainerHighest,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: accent, width: 3),
            top: BorderSide(color: colors.outlineVariant),
            bottom: BorderSide(color: colors.outlineVariant),
            left: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: accent, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${diagnostic.code} · ${diagnostic.phase}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 17),
                  tooltip: 'إغلاق التشخيص',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              diagnostic.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'السطر ${diagnostic.line}، العمود ${diagnostic.column}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (diagnostic.actions.isNotEmpty) ...[
              const Divider(height: 12),
              for (final action in diagnostic.actions)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => onApply(action),
                    style: TextButton.styleFrom(
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(action.title),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HelpPopover extends StatelessWidget {
  final AssistHelp help;
  final VoidCallback onClose;

  const _HelpPopover({required this.help, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: colors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${help.keyword} · ${help.title}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 17),
                  tooltip: 'إغلاق المساعدة',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
            Text(help.description),
            const SizedBox(height: 4),
            Text(
              'الصيغة: ${help.syntax}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
