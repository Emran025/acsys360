import '../entities/document.dart';
import '../entities/workspace.dart';
import '../repositories/workspace_repository.dart';

class OpenDocument {
  final WorkspaceRepository repository;
  const OpenDocument(this.repository);

  Future<Workspace> call(Workspace workspace, String path) async =>
      workspace.open(await repository.read(path));
}

class SaveDocument {
  final WorkspaceRepository repository;
  const SaveDocument(this.repository);

  Future<Workspace> call(Workspace workspace) async {
    final document = workspace.activeDocument;
    if (document == null) return workspace;
    await repository.write(document);
    return workspace.replaceActive(document.markSaved());
  }
}

class ApplyEdit {
  const ApplyEdit();

  Workspace call(Workspace workspace, TextEdit edit) {
    final document = workspace.activeDocument;
    return document == null
        ? workspace
        : workspace.replaceActive(document.edit(edit));
  }
}

class UndoEdit {
  const UndoEdit();

  Workspace call(Workspace workspace) {
    final document = workspace.activeDocument;
    return document == null
        ? workspace
        : workspace.replaceActive(document.undo());
  }
}

class RedoEdit {
  const RedoEdit();

  Workspace call(Workspace workspace) {
    final document = workspace.activeDocument;
    return document == null
        ? workspace
        : workspace.replaceActive(document.redo());
  }
}
