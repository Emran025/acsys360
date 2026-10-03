import 'package:acsys360/features/editor/domain/entities/document.dart';
import 'package:acsys360/features/editor/domain/entities/file_node.dart';
import 'package:acsys360/features/editor/domain/entities/workspace.dart';
import 'package:acsys360/features/editor/domain/repositories/workspace_repository.dart';
import 'package:acsys360/features/editor/domain/usecases/workspace_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens documents and does not duplicate an existing path', () async {
    final repository = FakeRepository();
    final workspace = const Workspace(rootPath: '/workspace');
    final opened = await OpenDocument(repository)(
      workspace,
      '/workspace/main.arb',
    );
    final selected = await OpenDocument(repository)(
      opened,
      '/workspace/main.arb',
    );
    expect(opened.documents, hasLength(1));
    expect(selected.documents, hasLength(1));
    expect(selected.activeIndex, 0);
  });

  test(
    'save marks the active document clean and leaves empty workspace unchanged',
    () async {
      final repository = FakeRepository();
      const empty = Workspace(rootPath: '/workspace');
      expect(await SaveDocument(repository)(empty), same(empty));
      final workspace = empty
          .open(const Document(path: 'main.arb', text: 'x'))
          .replaceActive(
            const Document(path: 'main.arb', text: 'y', savedText: 'x'),
          );
      final saved = await SaveDocument(repository)(workspace);
      expect(repository.written.single.isDirty, isTrue);
      expect(saved.activeDocument?.isDirty, isFalse);
    },
  );

  test('edit undo and redo are no-ops without an active document', () {
    const workspace = Workspace(rootPath: '/workspace');
    const edit = TextEdit(offset: 0, before: '', after: 'س');
    expect(const ApplyEdit().call(workspace, edit), same(workspace));
    expect(const UndoEdit().call(workspace), same(workspace));
    expect(const RedoEdit().call(workspace), same(workspace));
  });
}

class FakeRepository implements WorkspaceRepository {
  final written = <Document>[];
  @override
  Future<List<String>> listFiles(String rootPath) async => const [];
  @override
  Future<List<FileNode>> listTree(String rootPath) async => const [];
  @override
  Future<Document> read(String path) async => Document(path: path, text: 'x');
  @override
  Future<Document> create(String rootPath, String name) async =>
      Document(path: '$rootPath/$name', text: '');
  @override
  Future<String> createDirectory(String rootPath, String name) async =>
      '$rootPath/$name';
  @override
  Future<void> write(Document document) async => written.add(document);
  @override
  Future<void> delete(String path) async {}
  @override
  Future<void> move(String sourcePath, String targetDirectory) async {}
  @override
  Future<void> rename(String path, String newName) async {}
}
