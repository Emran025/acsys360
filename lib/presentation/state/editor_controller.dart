import 'package:flutter/foundation.dart';

import '../../domain/entities/compilation_result.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/file_node.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../../domain/usecases/workspace_actions.dart';

class EditorController extends ChangeNotifier {
  final WorkspaceRepository repository;
  final OpenDocument openDocument;
  final SaveDocument saveDocument;
  final ApplyEdit applyEdit;
  final UndoEdit undoEdit;
  final RedoEdit redoEdit;
  final CompilerRepository? compiler;

  Workspace workspace;
  List<String> files = const [];
  List<FileNode> tree = const [];
  Object? error;
  CompilationResult? compilation;

  EditorController({
    required this.repository,
    required String rootPath,
    this.compiler,
  }) : workspace = Workspace(rootPath: rootPath),
       openDocument = OpenDocument(repository),
       saveDocument = SaveDocument(repository),
       applyEdit = const ApplyEdit(),
       undoEdit = const UndoEdit(),
       redoEdit = const RedoEdit();

  Document? get activeDocument => workspace.activeDocument;

  Future<void> changeRoot(String rootPath) async {
    workspace = Workspace(rootPath: rootPath);
    files = const [];
    tree = const [];
    compilation = null;
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

  void edit(TextEdit change) {
    workspace = applyEdit(workspace, change);
    notifyListeners();
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
