import 'dart:io';

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

  Workspace workspace;
  List<String> files = const [];
  List<FileNode> tree = const [];
  Object? error;
  CompilationResult? compilation;
  AssistResponse? assistance;
  List<SearchMatch> searchMatches = const [];
  int currentMatchIndex = -1;
  List<EditorDiagnostic> diagnostics = const [];
  String? cutPath;
  String? selectedExplorerPath;
  String? selectedDirectoryPath;

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
    workspace = Workspace(rootPath: rootPath);
    files = const [];
    tree = const [];
    compilation = null;
    diagnostics = const [];
    assistance = null;
    selectedExplorerPath = null;
    selectedDirectoryPath = null;
    await refreshFiles();
  }

  Future<void> refreshFiles() async {
    try {
      tree = await repository.listTree(workspace.rootPath);
      files = _flattenFiles(tree);
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  void selectTab(int index) {
    workspace = workspace.select(index);
    searchMatches = const [];
    assistance = null;
    notifyListeners();
  }

  bool closeTab(int index, {bool discard = false}) {
    if (index < 0 || index >= workspace.documents.length) return false;
    final document = workspace.documents[index];
    if (document.isDirty && !discard) return false;
    workspace = workspace.close(index);
    notifyListeners();
    return true;
  }

  Future<void> create(String name, {String? rootPath}) async {
    try {
      final document = await repository.create(
        rootPath ?? workspace.rootPath,
        name,
      );
      workspace = workspace.open(document);
      await refreshFiles();
      error = null;
    } catch (exception) {
      error = exception;
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> createFolder(String name, {String? rootPath}) async {
    try {
      await repository.createDirectory(rootPath ?? workspace.rootPath, name);
      await refreshFiles();
      error = null;
    } catch (exception) {
      error = exception;
      notifyListeners();
    }
    notifyListeners();
  }

  List<String> _flattenFiles(List<FileNode> nodes) => [
    for (final node in nodes)
      if (node.isDirectory) ..._flattenFiles(node.children) else node.path,
  ];

  Future<void> open(String path) async {
    try {
      workspace = await openDocument(workspace, path);
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  Future<void> save() async {
    try {
      formatActive();
      workspace = await saveDocument(workspace);
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  Future<void> saveAs(String path) async {
    final active = workspace.activeDocument;
    if (active == null) return;
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
      workspace = workspace.open(document);
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  void formatActive() {
    final active = workspace.activeDocument;
    if (active == null) return;
    final formatted = formatArabicSource(active.text);
    if (formatted == active.text) return;
    edit(TextEdit(offset: 0, before: active.text, after: formatted));
  }

  Future<void> delete(String path) async {
    try {
      await repository.delete(path);
      final separator = Platform.pathSeparator;
      final indexes = [
        for (var index = workspace.documents.length - 1; index >= 0; index--)
          if (workspace.documents[index].path == path ||
              workspace.documents[index].path.startsWith('$path$separator'))
            index,
      ];
      for (final index in indexes) {
        workspace = workspace.close(index);
      }
      if (selectedExplorerPath == path ||
          selectedExplorerPath?.startsWith('$path$separator') == true) {
        selectedExplorerPath = null;
        selectedDirectoryPath = null;
      }
      await refreshFiles();
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

  String _parentDirectory(String path) {
    final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
    if (separatorIndex <= 0) return workspace.rootPath;
    return path.substring(0, separatorIndex);
  }

  Future<void> paste(String targetDirectory) async {
    final sourcePath = cutPath;
    if (sourcePath == null) return;
    try {
      final targetName = sourcePath.split(Platform.pathSeparator).last;
      final targetPath = _joinPath(targetDirectory, targetName);
      await repository.move(sourcePath, targetDirectory);
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
      await refreshFiles();
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  Future<void> rename(String path, String newName) async {
    try {
      final targetPath = _joinPath(_parentDirectory(path), newName);
      await repository.rename(path, newName);
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
      await refreshFiles();
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  String _joinPath(String directory, String name) {
    final separator = Platform.pathSeparator;
    return '$directory${directory.endsWith(separator) ? '' : separator}$name';
  }

  String _relocatePath(String path, String source, String target) {
    final separator = Platform.pathSeparator;
    if (path == source) return target;
    if (path.startsWith('$source$separator')) {
      return '$target${path.substring(source.length)}';
    }
    return path;
  }

  String? _relocateOptionalPath(String? path, String source, String target) =>
      path == null ? null : _relocatePath(path, source, target);

  Future<void> saveAll() async {
    try {
      for (final document in workspace.documents) {
        await repository.write(document);
      }
      workspace = workspace.copyWith(
        documents: [
          for (final document in workspace.documents) document.markSaved(),
        ],
      );
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
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
    workspace = applyEdit(workspace, change);
    searchMatches = const [];
    diagnostics = const [];
    assistance = null;
    notifyListeners();
  }

  Future<void> analyze() => compile();

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
    final service = languageServer;
    final active = workspace.activeDocument;
    if (service == null || active == null) return;
    try {
      assistance = await service.complete(
        rootPath: workspace.rootPath,
        sourcePath: active.path,
        sourceText: active.text,
        offset: offset,
        symbols: _knownSymbols(),
      );
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  void clearAssist() {
    if (assistance == null) return;
    assistance = null;
    notifyListeners();
  }

  Future<void> help(int offset) async {
    final service = languageServer;
    final active = workspace.activeDocument;
    if (service == null || active == null) return;
    try {
      assistance = await service.help(
        rootPath: workspace.rootPath,
        sourcePath: active.path,
        sourceText: active.text,
        offset: offset,
      );
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
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
    workspace = undoEdit(workspace);
    notifyListeners();
  }

  void redo() {
    workspace = redoEdit(workspace);
    notifyListeners();
  }

  Future<void> compile() async {
    final service = languageServer;
    final active = workspace.activeDocument;
    if (service == null || active == null) return;
    try {
      final analysis = await service.analyze(
        rootPath: workspace.rootPath,
        sourcePath: active.path,
        documents: workspace.documents,
      );
      compilation = analysis.compilation;
      diagnostics = analysis.diagnostics;
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }
}
