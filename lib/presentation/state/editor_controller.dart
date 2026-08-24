import 'package:flutter/foundation.dart';

import '../../domain/entities/document.dart';
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

  Workspace workspace;
  List<String> files = const [];
  Object? error;

  EditorController({required this.repository, required String rootPath})
    : workspace = Workspace(rootPath: rootPath),
      openDocument = OpenDocument(repository),
      saveDocument = SaveDocument(repository),
      applyEdit = const ApplyEdit(),
      undoEdit = const UndoEdit(),
      redoEdit = const RedoEdit();

  Document? get activeDocument => workspace.activeDocument;

  Future<void> refreshFiles() async {
    try {
      files = await repository.listFiles(workspace.rootPath);
      error = null;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

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
}
