import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/compilation_result.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/file_node.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../../domain/usecases/find_replace.dart';
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
    assistance = null;
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

  Future<void> create(String name) async {
    try {
      final document = await repository.create(workspace.rootPath, name);
      workspace = workspace.open(document);
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
      workspace = await saveDocument(workspace);
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

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
    notifyListeners();
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
    return result.count;
  }

  void edit(TextEdit change) {
    workspace = applyEdit(workspace, change);
    searchMatches = const [];
    assistance = null;
    notifyListeners();
  }

  Future<void> complete(int offset) async {
    final service = assistant;
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
    final service = assistant;
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
    final service = compiler;
    if (service == null) return;
    final active = workspace.activeDocument;
    if (active == null) return;
    final response = await service.compile(
      rootPath: workspace.rootPath,
      sourcePath: active.path,
      documents: workspace.documents,
    );
    compilation = CompilationResult(
      success: response['success'] == true,
      payload: response,
    );
    notifyListeners();
  }
}
