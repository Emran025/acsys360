import 'dart:async';

import 'package:acsys360/domain/entities/document.dart';
import 'package:acsys360/domain/entities/file_node.dart';
import 'package:acsys360/domain/repositories/workspace_repository.dart';
import 'package:acsys360/presentation/state/editor_controller.dart';
import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ignores compile result from a document version that was edited',
    () async {
      final compiler = DeferredCompiler();
      final controller = EditorController(
        repository: MemoryWorkspaceRepository(),
        rootPath: '/workspace',
        compiler: compiler,
        assistant: const EmptyAssistant(),
      );
      await controller.open('/workspace/main.arb');

      final compileFuture = controller.compile();
      controller.edit(const TextEdit(offset: 0, before: '', after: 'س'));
      compiler.response.complete(_successResponse());
      await compileFuture;

      expect(controller.compilation, isNull);
      expect(controller.diagnostics, isEmpty);
    },
  );

  test('keeps a newer edit dirty when an older save completes', () async {
    final repository = DelayedWriteRepository();
    final controller = EditorController(
      repository: repository,
      rootPath: '/workspace',
    );
    await controller.open('/workspace/main.arb');

    final saveFuture = controller.save();
    controller.edit(const TextEdit(offset: 1, before: '', after: 'ص'));
    repository.writeCompleted.complete();
    await saveFuture;

    expect(controller.activeDocument?.text, 'سص');
    expect(controller.activeDocument?.isDirty, isTrue);
  });

  test(
    'ignores completion result from a document version that was edited',
    () async {
      final assistant = DeferredAssistant();
      final controller = EditorController(
        repository: MemoryWorkspaceRepository(),
        rootPath: '/workspace',
        compiler: const EmptyCompiler(),
        assistant: assistant,
      );
      await controller.open('/workspace/main.arb');

      final completionFuture = controller.complete(0);
      controller.edit(const TextEdit(offset: 0, before: '', after: 'س'));
      assistant.response.complete(
        const AssistResponse(
          action: AssistAction.completion,
          items: [
            AssistCompletionItem(
              label: 'برنامج',
              insertText: 'برنامج',
              kind: 'keyword',
              detail: 'اختبار',
            ),
          ],
        ),
      );
      await completionFuture;

      expect(controller.assistance, isNull);
    },
  );
}

Map<String, dynamic> _successResponse() => {
  'success': true,
  'diagnostics': const [],
};

class DeferredCompiler implements CompilerRepository {
  final response = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
    String target = 'none',
    String? artifactDirectory,
    CompilationMode? mode,
  }) => response.future;
}

class EmptyCompiler implements CompilerRepository {
  const EmptyCompiler();

  @override
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
    String target = 'none',
    String? artifactDirectory,
    CompilationMode? mode,
  }) async => _successResponse();
}

class DeferredAssistant implements AssistRepository {
  final response = Completer<AssistResponse>();

  @override
  Future<AssistResponse> complete({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
    List<String> symbols = const [],
  }) => response.future;

  @override
  Future<AssistResponse> help({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
  }) async => const AssistResponse(action: AssistAction.help);
}

class EmptyAssistant implements AssistRepository {
  const EmptyAssistant();

  @override
  Future<AssistResponse> complete({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
    List<String> symbols = const [],
  }) async => const AssistResponse(action: AssistAction.completion);

  @override
  Future<AssistResponse> help({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
  }) async => const AssistResponse(action: AssistAction.help);
}

class DelayedWriteRepository extends MemoryWorkspaceRepository {
  final writeCompleted = Completer<void>();

  @override
  Future<void> write(Document document) => writeCompleted.future;
}

class MemoryWorkspaceRepository implements WorkspaceRepository {
  @override
  Future<List<String>> listFiles(String rootPath) async => const [];

  @override
  Future<List<FileNode>> listTree(String rootPath) async => const [];

  @override
  Future<Document> read(String path) async => Document(path: path, text: 'س');

  @override
  Future<Document> create(String rootPath, String name) async =>
      Document(path: '$rootPath/$name', text: '');

  @override
  Future<String> createDirectory(String rootPath, String name) async =>
      '$rootPath/$name';

  @override
  Future<void> write(Document document) async {}

  @override
  Future<void> delete(String path) async {}

  @override
  Future<void> move(String sourcePath, String targetDirectory) async {}

  @override
  Future<void> rename(String path, String newName) async {}
}
