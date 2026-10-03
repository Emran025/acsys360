import 'package:acsys360/features/editor/domain/entities/compilation_result.dart';
import 'package:acsys360/features/editor/domain/entities/document.dart';
import 'package:acsys360/features/editor/domain/entities/file_node.dart';
import 'package:acsys360/features/editor/domain/repositories/workspace_repository.dart';
import 'package:acsys360/features/editor/presentation/controllers/editor_controller.dart';
import 'package:acsys360/features/editor/presentation/ui/widgets/diagnostics_panel_widget.dart';
import 'package:acsys360/features/editor/presentation/ui/widgets/workspace_explorer.dart';
import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'diagnostics panel renders empty, error, inputs, and all stages',
    (tester) async {
      final controller = EditorController(
        repository: EmptyRepository(),
        rootPath: '/workspace',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 590,
              child: DiagnosticsPanelWidget(controller: controller),
            ),
          ),
        ),
      );
      expect(find.text('لا توجد نتيجة ترجمة'), findsOneWidget);

      controller.reportError(StateError('فشل متعمد'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 590,
              child: DiagnosticsPanelWidget(controller: controller),
            ),
          ),
        ),
      );
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.textContaining('فشل متعمد'), findsOneWidget);

      controller.error = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 590,
              child: DiagnosticsPanelWidget(
                controller: controller,
                inputNames: const ['الاسم'],
                onSubmitInputs: (_) {},
                onCancelInputs: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('الاسم'), findsOneWidget);

      controller.compilation = const CompilationResult(
        success: true,
        diagnostics: [
          Diagnostic(
            severity: DiagnosticSeverity.warning,
            phase: 'syntax',
            code: 'S001',
            message: 'تنبيه',
          ),
        ],
        tokens: [
          ProtocolToken(
            kind: 'keyword',
            lexeme: 'برنامج',
            span: SourceSpan(
              sourcePath: 'main.arb',
              offset: 0,
              line: 1,
              column: 1,
              length: 6,
            ),
          ),
        ],
        syntaxTree: {
          'kind': 'program',
          'children': ['main'],
        },
        symbols: [
          SymbolRecord(
            name: 'س',
            kind: 'variable',
            type: 'صحيح',
            span: SourceSpan(
              sourcePath: 'main.arb',
              offset: 0,
              line: 1,
              column: 1,
              length: 1,
            ),
          ),
        ],
        threeAddressCode: ['س = 1'],
        assembly: 'mov rax, 1',
        executionOutput: ['1'],
        artifacts: ['/tmp/main', '/tmp/main.asm'],
        intermediateRepresentation: {'unit': 'main', 'blocks': []},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 590,
              child: DiagnosticsPanelWidget(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final label in ['Tokens', 'Syntax Tree', 'Symbol Table', '3AC']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Assembly'));
      await tester.tap(find.text('Assembly'));
      await tester.pump();
      expect(find.text('mov rax, 1'), findsOneWidget);
    },
  );

  testWidgets('workspace explorer renders loading, empty and tree callbacks', (
    tester,
  ) async {
    var refreshes = 0;
    var opened = 0;
    var selected = 0;
    Future<void> noop() async {}
    Widget buildExplorer({
      required bool loading,
      List<FileNode> nodes = const [],
    }) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 590,
          child: WorkspaceExplorer(
            rootPath: '/workspace',
            nodes: nodes,
            isLoading: loading,
            hasCutPath: true,
            selectedPath: null,
            selectedDirectoryPath: null,
            onSelect: (_, {required isDirectory}) => selected++,
            onChooseFolder: noop,
            onOpenFile: noop,
            onRefresh: () async => refreshes++,
            onNewFile: (_) async {},
            onNewFolder: (_) async {},
            onOpen: (_) async => opened++,
            onDelete: (_) async {},
            onRename: (_) async {},
            onCut: (_) {},
            onPaste: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(buildExplorer(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(buildExplorer(loading: false));
    expect(find.text('المجلد فارغ'), findsOneWidget);
    await tester.tap(find.byTooltip('تحديث الملفات'));
    expect(refreshes, 1);

    await tester.pumpWidget(
      buildExplorer(
        loading: false,
        nodes: const [
          FileNode(
            path: '/workspace/main.arb',
            name: 'main.arb',
            isDirectory: false,
          ),
          FileNode(
            path: '/workspace/src',
            name: 'src',
            isDirectory: true,
            children: [
              FileNode(
                path: '/workspace/src/lib.arb',
                name: 'lib.arb',
                isDirectory: false,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('main.arb'));
    await tester.pump();
    expect(opened, 1);
    expect(selected, greaterThan(0));
    await tester.tap(find.text('src'));
    await tester.pumpAndSettle();
    expect(find.text('lib.arb'), findsOneWidget);
  });
}

class EmptyRepository implements WorkspaceRepository {
  @override
  Future<List<String>> listFiles(String rootPath) async => const [];
  @override
  Future<List<FileNode>> listTree(String rootPath) async => const [];
  @override
  Future<Document> read(String path) async => Document(path: path, text: '');
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
