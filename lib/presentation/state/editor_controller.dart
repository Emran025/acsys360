import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/compilation_result.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/editor_diagnostic.dart';
import '../../domain/entities/file_node.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../../domain/usecases/find_replace.dart';
import '../../domain/usecases/editor_language_server.dart';
import '../../domain/usecases/format_arabic_source.dart';
import '../../domain/usecases/workspace_actions.dart';
import '../../domain/services/workspace_path_service.dart';

/// مصدر حالة المحرر: workspace والوثائق والنتائج، بينما تبقى الملفات والمترجم خلف عقود repositories.
class EditorController extends ChangeNotifier {
  final WorkspaceRepository repository;
  final OpenDocument openDocument;
  final SaveDocument saveDocument;
  final ApplyEdit applyEdit;
  final UndoEdit undoEdit;
  final RedoEdit redoEdit;
  final FindText findText;
  final ReplaceAllText replaceAllText;
  final CompilerRepository? compiler;
  final AssistRepository? assistant;
  final WorkspacePathService pathService;

  Workspace workspace;
  List<String> files = const [];
  List<FileNode> tree = const [];
  Object? error;
  CompilationResult? compilation;
  AssistResponse? assistance;
  int assistanceIndex = 0;
  List<SearchMatch> searchMatches = const [];
  int currentMatchIndex = -1;
  List<EditorDiagnostic> diagnostics = const [];
  String? cutPath;
  String? selectedExplorerPath;
  String? selectedDirectoryPath;
  int _stateVersion = 0;

  EditorLanguageServer? get languageServer {
    final compilerService = compiler;
    final assistantService = assistant;
    if (compilerService == null || assistantService == null) return null;
    return EditorLanguageServer(
      compiler: compilerService,
      assistant: assistantService,
    );
  }

  EditorController({
    required this.repository,
    required String rootPath,
    this.compiler,
    this.assistant,
    this.pathService = const DefaultWorkspacePathService(),
  }) : workspace = Workspace(rootPath: rootPath),
       openDocument = OpenDocument(repository),
       saveDocument = SaveDocument(repository),
       applyEdit = const ApplyEdit(),
       undoEdit = const UndoEdit(),
       redoEdit = const RedoEdit(),
       findText = const FindText(),
       replaceAllText = const ReplaceAllText();

  Document? get activeDocument => workspace.activeDocument;

  Future<void> changeRoot(String rootPath) async {
    _stateVersion++;
    workspace = Workspace(rootPath: rootPath);
    files = const [];
    tree = const [];
    compilation = null;
    diagnostics = const [];
    assistance = null;
    selectedExplorerPath = null;
    selectedDirectoryPath = null;
    notifyListeners();
    await refreshFiles();
  }

  Future<void> refreshFiles({bool notify = true}) async {
    final version = _stateVersion;
    final rootPath = workspace.rootPath;
    if (rootPath.trim().isEmpty) {
      tree = const [];
      files = const [];
      error = null;
      return;
    }
    try {
      final nextTree = await repository.listTree(rootPath);
      if (version != _stateVersion) return;
      tree = nextTree;
      files = _flattenFiles(nextTree);
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (notify && version == _stateVersion) notifyListeners();
  }

  void selectTab(int index) {
    _stateVersion++;
    workspace = workspace.select(index);
    searchMatches = const [];
    assistance = null;
    assistanceIndex = 0;
    notifyListeners();
  }

  bool closeTab(int index, {bool discard = false}) {
    if (index < 0 || index >= workspace.documents.length) return false;
    final document = workspace.documents[index];
    if (document.isDirty && !discard) return false;
    _stateVersion++;
    workspace = workspace.close(index);
    notifyListeners();
    return true;
  }

  Future<void> create(String name, {String? rootPath}) async {
    final version = ++_stateVersion;
    final targetRoot = rootPath ?? workspace.rootPath;
    try {
      final document = await repository.create(targetRoot, name);
      if (version != _stateVersion) return;
      workspace = workspace.open(document);
      await refreshFiles(notify: false);
      if (version == _stateVersion) error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  Future<void> createFolder(String name, {String? rootPath}) async {
    final version = ++_stateVersion;
    final targetRoot = rootPath ?? workspace.rootPath;
    try {
      await repository.createDirectory(targetRoot, name);
      if (version != _stateVersion) return;
      await refreshFiles(notify: false);
      if (version == _stateVersion) error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  List<String> _flattenFiles(List<FileNode> nodes) => [
    for (final node in nodes)
      if (node.isDirectory) ..._flattenFiles(node.children) else node.path,
  ];

  Future<void> open(String path) async {
    final version = ++_stateVersion;
    try {
      final nextWorkspace = await openDocument(workspace, path);
      if (version != _stateVersion) return;
      workspace = nextWorkspace;
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  Future<void> save() async {
    formatActive();
    final version = _stateVersion;
    final snapshot = workspace;
    try {
      final savedWorkspace = await saveDocument(snapshot);
      if (version != _stateVersion) return;
      workspace = savedWorkspace;
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  Future<void> saveAs(String path) async {
    final active = workspace.activeDocument;
    if (active == null) return;
    final version = _stateVersion;
    try {
      final formatted = formatArabicSource(active.text);
      final document = Document(
        path: path,
        text: formatted,
        savedText: formatted,
        undoStack: active.undoStack,
        redoStack: active.redoStack,
      );
      await repository.write(document);
      if (version != _stateVersion) return;
      workspace = workspace.open(document);
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  void formatActive() {
    final active = workspace.activeDocument;
    if (active == null) return;
    final formatted = formatArabicSource(active.text);
    if (formatted == active.text) return;
    edit(TextEdit(offset: 0, before: active.text, after: formatted));
  }

  Future<void> delete(String path) async {
    _stateVersion++;
    try {
      await repository.delete(path);
      final indexes = [
        for (var index = workspace.documents.length - 1; index >= 0; index--)
          if (pathService.isSameOrDescendant(
            workspace.documents[index].path,
            path,
          ))
            index,
      ];
      for (final index in indexes) {
        workspace = workspace.close(index);
      }
      if (selectedExplorerPath == path ||
          (selectedExplorerPath != null &&
              pathService.isSameOrDescendant(selectedExplorerPath!, path))) {
        selectedExplorerPath = null;
        selectedDirectoryPath = null;
      }
      await refreshFiles(notify: false);
      error = null;
    } catch (exception) {
      error = exception;
      notifyListeners();
    }
    notifyListeners();
  }

  void cut(String path) {
    cutPath = path;
    notifyListeners();
  }

  bool get hasCutPath => cutPath != null;

  void selectExplorerPath(String path, {required bool isDirectory}) {
    selectedExplorerPath = path;
    selectedDirectoryPath = isDirectory ? path : _parentDirectory(path);
    notifyListeners();
  }

  String _parentDirectory(String path) =>
      pathService.parentOf(path, fallback: workspace.rootPath);

  Future<void> paste(String targetDirectory) async {
    final version = ++_stateVersion;
    final sourcePath = cutPath;
    if (sourcePath == null) return;
    try {
      final targetName = pathService.baseName(sourcePath);
      final targetPath = pathService.join(targetDirectory, targetName);
      await repository.move(sourcePath, targetDirectory);
      if (version != _stateVersion) return;
      final movedDocuments = [
        for (final document in workspace.documents)
          Document(
            path: _relocatePath(document.path, sourcePath, targetPath),
            text: document.text,
            savedText: document.savedText,
            undoStack: document.undoStack,
            redoStack: document.redoStack,
          ),
      ];
      workspace = workspace.copyWith(documents: movedDocuments);
      selectedExplorerPath = _relocateOptionalPath(
        selectedExplorerPath,
        sourcePath,
        targetPath,
      );
      selectedDirectoryPath = selectedExplorerPath == null
          ? targetDirectory
          : _parentDirectory(selectedExplorerPath!);
      cutPath = null;
      await refreshFiles(notify: false);
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  Future<void> rename(String path, String newName) async {
    final version = ++_stateVersion;
    try {
      final targetPath = _joinPath(_parentDirectory(path), newName);
      await repository.rename(path, newName);
      if (version != _stateVersion) return;
      workspace = workspace.copyWith(
        documents: [
          for (final document in workspace.documents)
            Document(
              path: _relocatePath(document.path, path, targetPath),
              text: document.text,
              savedText: document.savedText,
              undoStack: document.undoStack,
              redoStack: document.redoStack,
            ),
        ],
      );
      selectedExplorerPath = _relocateOptionalPath(
        selectedExplorerPath,
        path,
        targetPath,
      );
      selectedDirectoryPath = selectedExplorerPath == null
          ? workspace.rootPath
          : _parentDirectory(selectedExplorerPath!);
      await refreshFiles(notify: false);
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  String _joinPath(String directory, String name) =>
      pathService.join(directory, name);

  String _relocatePath(String path, String source, String target) =>
      pathService.relocate(path, source: source, target: target);

  String? _relocateOptionalPath(String? path, String source, String target) =>
      path == null ? null : _relocatePath(path, source, target);

  Future<void> saveAll() async {
    final version = _stateVersion;
    final snapshot = workspace;
    try {
      for (final document in snapshot.documents) {
        await repository.write(document);
      }
      if (version != _stateVersion) return;
      workspace = snapshot.copyWith(
        documents: [
          for (final document in snapshot.documents) document.markSaved(),
        ],
      );
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  void search(String query, {bool caseSensitive = true}) {
    final active = workspace.activeDocument;
    searchMatches = active == null
        ? const []
        : findText(active.text, query, caseSensitive: caseSensitive);
    currentMatchIndex = searchMatches.isEmpty ? -1 : 0;
    notifyListeners();
  }

  SearchMatch? get currentMatch =>
      currentMatchIndex >= 0 && currentMatchIndex < searchMatches.length
      ? searchMatches[currentMatchIndex]
      : null;

  void firstMatch() {
    if (searchMatches.isEmpty) return;
    currentMatchIndex = 0;
    notifyListeners();
  }

  void previousMatch() {
    if (searchMatches.isEmpty) return;
    currentMatchIndex =
        (currentMatchIndex - 1 + searchMatches.length) % searchMatches.length;
    notifyListeners();
  }

  void nextMatch() {
    if (searchMatches.isEmpty) return;
    currentMatchIndex = (currentMatchIndex + 1) % searchMatches.length;
    notifyListeners();
  }

  int replaceCurrent(String query, String replacement) {
    final active = workspace.activeDocument;
    final match = currentMatch;
    if (active == null || match == null) return 0;
    edit(
      TextEdit(
        offset: match.offset,
        before: active.text.substring(
          match.offset,
          match.offset + match.length,
        ),
        after: replacement,
      ),
    );
    search(query);
    return 1;
  }

  int replaceAll(
    String query,
    String replacement, {
    bool caseSensitive = true,
  }) {
    final active = workspace.activeDocument;
    if (active == null) return 0;
    final result = replaceAllText(
      active.text,
      query,
      replacement,
      caseSensitive: caseSensitive,
    );
    if (result.count == 0) return 0;
    edit(TextEdit(offset: 0, before: active.text, after: result.text));
    searchMatches = const [];
    currentMatchIndex = -1;
    return result.count;
  }

  void edit(TextEdit change) {
    _stateVersion++;
    workspace = applyEdit(workspace, change);
    searchMatches = const [];
    diagnostics = const [];
    assistance = null;
    assistanceIndex = 0;
    notifyListeners();
  }

  AssistCompletionItem? get currentCompletion {
    final items = assistance?.items ?? const <AssistCompletionItem>[];
    if (items.isEmpty || assistanceIndex >= items.length) return null;
    return items[assistanceIndex];
  }

  void nextCompletion() {
    final items = assistance?.items ?? const <AssistCompletionItem>[];
    if (items.isEmpty) return;
    assistanceIndex = (assistanceIndex + 1) % items.length;
    notifyListeners();
  }

  void previousCompletion() {
    final items = assistance?.items ?? const <AssistCompletionItem>[];
    if (items.isEmpty) return;
    assistanceIndex = (assistanceIndex - 1 + items.length) % items.length;
    notifyListeners();
  }

  Future<void> analyze() => compile();

  Future<void> buildNative() async {
    final version = _stateVersion;
    final service = languageServer;
    final active = workspace.activeDocument;
    final root = workspace.rootPath.trim();
    if (service == null || active == null || root.isEmpty) return;
    try {
      final artifactDirectory = pathService.join(
        pathService.join(root, '.arabic360'),
        'build',
      );
      final analysis = await service.analyze(
        rootPath: root,
        sourcePath: active.path,
        documents: workspace.documents,
        target: 'dart-native',
        artifactDirectory: artifactDirectory,
        mode: CompilationMode.active,
      );
      if (version != _stateVersion) return;
      compilation = analysis.compilation;
      diagnostics = analysis.diagnostics;
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  EditorDiagnostic? diagnosticAt(int offset) {
    for (final diagnostic in diagnostics) {
      if (diagnostic.containsOffset(offset)) return diagnostic;
    }
    return null;
  }

  void applyCodeAction(EditorCodeAction action) {
    final document = activeDocument;
    if (document == null) return;
    final offset = action.offset.clamp(0, document.text.length).toInt();
    final end = (offset + action.length)
        .clamp(offset, document.text.length)
        .toInt();
    edit(
      TextEdit(
        offset: offset,
        before: document.text.substring(offset, end),
        after: action.replacement,
      ),
    );
  }

  Future<void> complete(int offset) async {
    final version = _stateVersion;
    final service = languageServer;
    final active = workspace.activeDocument;
    if (service == null || active == null) return;
    try {
      final result = await service.complete(
        rootPath: workspace.rootPath,
        sourcePath: active.path,
        sourceText: active.text,
        offset: offset,
        symbols: _knownSymbols(),
      );
      if (version != _stateVersion) return;
      assistance = result;
      assistanceIndex = 0;
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  void clearAssist() {
    if (assistance == null && assistanceIndex == 0) return;
    assistance = null;
    assistanceIndex = 0;
    notifyListeners();
  }

  Future<void> help(int offset) async {
    final version = _stateVersion;
    final service = languageServer;
    final active = workspace.activeDocument;
    if (service == null || active == null) return;
    try {
      final result = await service.help(
        rootPath: workspace.rootPath,
        sourcePath: active.path,
        sourceText: active.text,
        offset: offset,
      );
      if (version != _stateVersion) return;
      assistance = result;
      assistanceIndex = 0;
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }

  List<String> _knownSymbols() {
    final table = compilation?.payload['symbolTable'];
    if (table is! List) return const [];
    return [
      for (final item in table)
        if (item is Map && item['name'] is String) item['name'] as String,
    ];
  }

  void undo() {
    _stateVersion++;
    workspace = undoEdit(workspace);
    _clearDerivedState();
    notifyListeners();
  }

  void redo() {
    _stateVersion++;
    workspace = redoEdit(workspace);
    _clearDerivedState();
    notifyListeners();
  }

  void _clearDerivedState() {
    searchMatches = const [];
    currentMatchIndex = -1;
    diagnostics = const [];
    assistance = null;
    assistanceIndex = 0;
  }

  Future<void> compile() async {
    final version = _stateVersion;
    final service = languageServer;
    final active = workspace.activeDocument;
    if (service == null || active == null) return;
    try {
      final analysis = await service.analyze(
        rootPath: workspace.rootPath,
        sourcePath: active.path,
        documents: workspace.documents,
      );
      if (version != _stateVersion) return;
      compilation = analysis.compilation;
      diagnostics = analysis.diagnostics;
      error = null;
    } catch (exception) {
      if (version == _stateVersion) error = exception;
    }
    if (version == _stateVersion) notifyListeners();
  }
}
