import 'package:acsys360/features/editor/domain/entities/compilation_result.dart';
import 'package:acsys360/features/editor/domain/entities/document.dart';
import 'package:acsys360/features/editor/domain/entities/file_node.dart';
import 'package:acsys360/features/editor/domain/repositories/program_runner.dart';
import 'package:acsys360/features/editor/domain/repositories/workspace_repository.dart';
import 'package:acsys360/features/editor/presentation/controllers/editor_controller.dart';
import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkflowRepository repository;
  late WorkflowCompiler compiler;
  late WorkflowRunner runner;
  late EditorController controller;

  setUp(() {
    repository = WorkflowRepository();
    compiler = WorkflowCompiler();
    runner = WorkflowRunner();
    controller = EditorController(
      repository: repository,
      compiler: compiler,
      assistant: compiler,
      artifactRunner: runner,
      rootPath: '/workspace',
    );
  });

  test(
    'refreshes, changes root, opens, creates, and creates folders',
    () async {
      await controller.refreshFiles();
      expect(controller.files, contains('/workspace/main.arb'));
      await controller.open('/workspace/main.arb');
      await controller.create('new.arb');
      await controller.createFolder('src');
      expect(controller.workspace.documents, hasLength(2));
      expect(repository.createdDirectories, contains('/workspace/src'));
      await controller.changeRoot('/other');
      expect(controller.workspace.rootPath, '/other');
      expect(controller.activeDocument, isNull);
    },
  );

  test('supports search navigation, replacement, undo, and redo', () async {
    await controller.open('/workspace/main.arb');
    controller.search('س');
    expect(controller.searchMatches, hasLength(2));
    expect(controller.currentMatch?.offset, 0);
    controller.nextMatch();
    expect(controller.currentMatch?.offset, greaterThan(0));
    controller.previousMatch();
    controller.firstMatch();
    expect(controller.replaceCurrent('س', 'ص'), 1);
    expect(controller.activeDocument?.text, startsWith('ص'));
    expect(controller.replaceAll('س', 'ع'), 1);
    controller.undo();
    controller.redo();
    expect(controller.activeDocument?.text, contains('ع'));
  });

  test(
    'moves and renames selected workspace paths and deletes documents',
    () async {
      await controller.open('/workspace/main.arb');
      controller.selectExplorerPath('/workspace/main.arb', isDirectory: false);
      controller.cut('/workspace/main.arb');
      await controller.paste('/workspace/src');
      expect(controller.activeDocument?.path, '/workspace/src/main.arb');
      controller.selectExplorerPath(
        '/workspace/src/main.arb',
        isDirectory: false,
      );
      await controller.rename('/workspace/src/main.arb', 'renamed.arb');
      expect(controller.activeDocument?.path, '/workspace/src/renamed.arb');
      await controller.delete('/workspace/src');
      expect(controller.activeDocument, isNull);
    },
  );

  test('saves, saves as, closes tabs, and reports repository errors', () async {
    await controller.open('/workspace/main.arb');
    controller.edit(const TextEdit(offset: 0, before: 'س', after: 'ص'));
    await controller.save();
    expect(controller.activeDocument?.isDirty, isFalse);
    await controller.saveAs('/workspace/copy.arb');
    expect(controller.activeDocument?.path, '/workspace/copy.arb');
    await controller.saveAll();
    expect(controller.closeTab(0), isTrue);
    expect(controller.closeTab(-1), isFalse);
    controller.reportError(StateError('expected'));
    expect(controller.error, isA<StateError>());
  });

  test(
    'compiles, analyzes, completes, helps, and runs native output',
    () async {
      await controller.open('/workspace/main.arb');
      await controller.compile();
      expect(controller.compilation?.success, isTrue);
      await controller.analyze();
      await controller.complete(0);
      expect(controller.currentCompletion?.label, 'برنامج');
      controller.nextCompletion();
      controller.previousCompletion();
      await controller.help(0);
      expect(controller.assistance?.help?.keyword, 'برنامج');
      controller.clearAssist();
      await controller.buildNative();
      expect(controller.compilation?.artifacts, isNotEmpty);
      await controller.runNative(onOutput: (_) {});
      expect(controller.compilation?.executionOutput, ['native output']);
    },
  );

  test(
    'returns safe no-op values without active documents or search matches',
    () async {
      expect(controller.closeTab(0), isFalse);
      controller.search('x');
      controller.firstMatch();
      controller.previousMatch();
      controller.nextMatch();
      expect(controller.replaceCurrent('x', 'y'), 0);
      expect(controller.replaceAll('x', 'y'), 0);
      await controller.saveAs('/workspace/noop.arb');
      await controller.runNative().catchError((_) {});
      await controller.complete(0);
      await controller.help(0);
      expect(controller.currentCompletion, isNull);
    },
  );
}

class WorkflowRepository implements WorkspaceRepository {
  final createdDirectories = <String>[];
  final written = <Document>[];
  final documents = <String, Document>{
    '/workspace/main.arb': const Document(
      path: '/workspace/main.arb',
      text: 'س = 1;\nس = 2;',
    ),
  };

  @override
  Future<List<String>> listFiles(String rootPath) async => [
    for (final path in documents.keys.where(
      (path) => path.startsWith(rootPath),
    ))
      path,
  ];

  @override
  Future<List<FileNode>> listTree(String rootPath) async => [
    FileNode(path: '$rootPath/main.arb', name: 'main.arb', isDirectory: false),
  ];

  @override
  Future<Document> read(String path) async =>
      documents[path] ?? Document(path: path, text: '');

  @override
  Future<Document> create(String rootPath, String name) async {
    final document = Document(path: '$rootPath/$name', text: '');
    documents[document.path] = document;
    return document;
  }

  @override
  Future<String> createDirectory(String rootPath, String name) async {
    final path = '$rootPath/$name';
    createdDirectories.add(path);
    return path;
  }

  @override
  Future<void> write(Document document) async {
    written.add(document);
    documents[document.path] = document;
  }

  @override
  Future<void> delete(String path) async {
    documents.removeWhere((key, _) => key == path || key.startsWith('$path/'));
  }

  @override
  Future<void> move(String sourcePath, String targetDirectory) async {
    final document = documents.remove(sourcePath);
    if (document != null) {
      final target = '$targetDirectory/${sourcePath.split('/').last}';
      documents[target] = Document(
        path: target,
        text: document.text,
        savedText: document.savedText,
      );
    }
  }

  @override
  Future<void> rename(String path, String newName) async {
    final document = documents.remove(path);
    if (document != null) {
      final target = '${path.substring(0, path.lastIndexOf('/'))}/$newName';
      documents[target] = Document(
        path: target,
        text: document.text,
        savedText: document.savedText,
      );
    }
  }
}

class WorkflowCompiler implements CompilerRepository, AssistRepository {
  @override
  Future<CompilationResult> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
    String target = 'none',
    String? artifactDirectory,
    CompilationMode? mode,
    Map<String, String> inputValues = const {},
    bool execute = true,
    bool interactive = false,
    InputRequestHandler? onInputRequest,
  }) async => CompilationResult(
    success: true,
    artifacts: target == 'dart-native' ? const ['/tmp/native'] : const [],
    executionOutput: execute ? const ['compiled'] : const [],
  );

  @override
  Future<AssistResponse> complete({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
    List<String> symbols = const [],
  }) async => const AssistResponse(
    action: AssistAction.completion,
    items: [
      AssistCompletionItem(
        label: 'برنامج',
        insertText: 'برنامج',
        kind: 'keyword',
        detail: 'declaration',
      ),
    ],
  );

  @override
  Future<AssistResponse> help({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
  }) async => const AssistResponse(
    action: AssistAction.help,
    help: AssistHelp(
      keyword: 'برنامج',
      title: 'برنامج',
      description: 'وحدة',
      syntax: 'برنامج ...',
    ),
  );
}

class WorkflowRunner implements ProgramRunner {
  @override
  Future<List<String>> run(
    String executable, {
    InputRequestHandler? onInputRequest,
    NativeOutputHandler? onOutput,
  }) async {
    onOutput?.call('native output');
    return const ['native output'];
  }
}
