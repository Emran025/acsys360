import 'package:acsys360/domain/entities/document.dart';
import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:acsys360/domain/entities/compilation_result.dart';
import 'package:acsys360/domain/entities/editor_diagnostic.dart';
import 'package:acsys360/domain/entities/source_token.dart';
import 'package:acsys360/domain/entities/file_node.dart';
import 'package:acsys360/domain/repositories/workspace_repository.dart';
import 'package:acsys360/main.dart';
import 'package:acsys360/presentation/state/editor_controller.dart';
import 'package:acsys360/presentation/widgets/arabic_code_controller.dart';
import 'package:acsys360/presentation/widgets/code_minimap.dart';
import 'package:acsys360/presentation/widgets/line_numbered_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  final document = const Document(path: 'main.arb', text: 'برنامج اختبار {}.');
  String? lastCreateRoot;
  String? lastCreateDirectoryRoot;

  @override
  Future<List<String>> listFiles(String rootPath) async => [document.path];

  @override
  Future<List<FileNode>> listTree(String rootPath) async => [
    const FileNode(
      path: 'src',
      name: 'src',
      isDirectory: true,
      children: [
        FileNode(path: 'src/main.arb', name: 'main.arb', isDirectory: false),
      ],
    ),
  ];

  @override
  Future<Document> read(String path) async => document;

  @override
  Future<Document> create(String rootPath, String name) async {
    lastCreateRoot = rootPath;
    return Document(path: '$rootPath/$name', text: '');
  }

  @override
  Future<String> createDirectory(String rootPath, String name) async {
    lastCreateDirectoryRoot = rootPath;
    return '$rootPath/$name';
  }

  @override
  Future<void> write(Document document) async {}

  @override
  Future<void> delete(String path) async {}

  @override
  Future<void> move(String sourcePath, String targetDirectory) async {}

  @override
  Future<void> rename(String path, String newName) async {}
}

void main() {
  testWidgets('starts with no folder and shows the welcome workspace', (
    tester,
  ) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '',
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();

    expect(find.text('No Folder Opened'), findsOneWidget);
    expect(find.text('Open Editors'), findsOneWidget);
    expect(find.text('فتح مجلد'), findsAtLeastNWidgets(1));
    expect(find.text('ملف جديد'), findsOneWidget);
    expect(find.text('فتح ملف'), findsAtLeastNWidgets(1));
    expect(find.text('مستكشف المشروع'), findsNothing);
    expect(find.text('Welcome'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders execution output on separate lines', (tester) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    await controller.open('main.arb');
    controller.compilation = const CompilationResult(
      success: true,
      payload: {
        'executionOutput': ['الأول', 'الثاني'],
      },
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    final executionStage = find.widgetWithText(TextButton, 'التنفيذ');
    await tester.ensureVisible(executionStage);
    await tester.tap(executionStage);
    await tester.pump();

    expect(find.text('الأول\nالثاني'), findsOneWidget);
    expect(find.text(r'الأول\nالثاني'), findsNothing);
  });

  testWidgets('uses Arabic direction and right-aligns code', (tester) async {
    final textController = TextEditingController(text: 'برنامج اختبار {}.');
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 800,
            height: 400,
            child: LineNumberedEditor(controller: textController),
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.textDirection, TextDirection.rtl);
    expect(textField.textAlign, TextAlign.right);
    expect(
      tester.getCenter(find.bySemanticsLabel('خريطة مصغرة للكود')).dx,
      lessThan(
        tester.getCenter(find.byKey(const ValueKey('code-editor-field'))).dx,
      ),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('code-gutter'))).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('code-editor-field'))).dx,
      ),
    );
  });

  testWidgets('moves Arabic caret with logical text positions', (tester) async {
    final textController = TextEditingController(text: 'اطبع("السلام")');
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 800,
            height: 400,
            child: LineNumberedEditor(controller: textController),
          ),
        ),
      ),
    );

    final state = tester.state<EditableTextState>(find.byType(EditableText));
    final render = state.renderEditable;
    textController.selection = TextSelection.collapsed(
      offset: textController.text.length,
    );
    await tester.pump();
    final endX = render
        .getLocalRectForCaret(textController.selection.extent)
        .left;
    textController.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    final startX = render
        .getLocalRectForCaret(textController.selection.extent)
        .left;

    expect(endX, lessThan(startX));
  });

  testWidgets('opens an Arabic source document', (tester) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    expect(find.text('مستكشف المشروع'), findsOneWidget);
    expect(find.text('src'), findsOneWidget);

    expect(find.text('main.arb'), findsNothing);

    await tester.tap(find.text('src'));
    await tester.pumpAndSettle();
    expect(find.text('main.arb'), findsOneWidget);

    await tester.tap(find.text('main.arb'));
    await tester.pump();
    expect(find.byType(LineNumberedEditor), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(controller.activeDocument?.text, 'برنامج اختبار {}.');
    expect(
      find.byKey(const ValueKey('arabic-file-icon')),
      findsAtLeastNWidgets(2),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textDirection, TextDirection.rtl);
  });

  testWidgets('renders a navigable code minimap', (tester) async {
    final controller = ArabicCodeController(
      text: List.generate(80, (index) => 'اطبع($index)؛').join('\n'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            height: 180,
            child: LineNumberedEditor(controller: controller),
          ),
        ),
      ),
    );

    final minimap = find.bySemanticsLabel('خريطة مصغرة للكود');
    final editor = find.byType(TextField);
    expect(minimap, findsOneWidget);
    expect(tester.getCenter(minimap).dx, lessThan(tester.getCenter(editor).dx));
    await tester.tap(minimap, warnIfMissed: false);
    await tester.pump();
  });

  testWidgets('renders miniature token strokes in the minimap', (tester) async {
    final controller = ArabicCodeController(
      text: 'برنامج سعيد {\n  اطبع("السلام")؛\n  س = 42؛',
    );
    addTearDown(controller.dispose);

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 180,
            height: 240,
            child: CodeMinimap(
              controller: controller,
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );

    final painter = tester.renderObject<RenderCustomPaint>(
      find.byKey(const ValueKey('minimap-code-painter')),
    );
    expect(painter.painter, isNotNull);
    expect(painter.size.width, greaterThan(0));
    expect(painter.size.height, greaterThan(0));
  });

  testWidgets('jumps to a distant line from the minimap', (tester) async {
    final sourceController = TextEditingController(
      text: List.generate(80, (index) => 'السطر $index').join('\n'),
    );
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 220,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SizedBox(
                    height: 1900,
                    child: Text(sourceController.text),
                  ),
                ),
              ),
              SizedBox(
                width: 118,
                height: 100,
                child: CodeMinimap(
                  controller: sourceController,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final minimap = find.byType(CodeMinimap);
    await tester.tap(minimap);
    await tester.pump();

    expect(scrollController.offset, greaterThan(0));
    scrollController.dispose();
    sourceController.dispose();
  });

  testWidgets('configures theme colors and collapsible panels', (tester) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    expect(find.byTooltip('الوضع الداكن'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byKey(const ValueKey('workspace-new-file')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-new-folder')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-open-file')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-open-folder')), findsOneWidget);
    expect(find.byKey(const ValueKey('topbar-toggle')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collapse-نتائج الترجمة')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('topbar-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('topbar-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('collapse-نتائج الترجمة')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collapse-نتائج الترجمة')),
      findsOneWidget,
    );
  });

  test('creates files and folders inside the requested directory', () async {
    final repository = FakeWorkspaceRepository();
    final controller = EditorController(repository: repository, rootPath: '.');

    await controller.create('child.arb', rootPath: 'src');
    await controller.createFolder('nested', rootPath: 'src');

    expect(repository.lastCreateRoot, 'src');
    expect(repository.lastCreateDirectoryRoot, 'src');
  });

  test('navigates and replaces the current search match', () async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    await controller.open('main.arb');
    controller.edit(
      const TextEdit(
        offset: 0,
        before: 'برنامج اختبار {}.',
        after: 'اكتب اكتب',
      ),
    );

    controller.search('اكتب');
    expect(controller.currentMatch?.offset, 0);
    controller.nextMatch();
    expect(controller.currentMatch?.offset, 5);

    expect(controller.replaceCurrent('اكتب', 'نفذ'), 1);
    expect(controller.activeDocument?.text, 'اكتب نفذ');
    expect(controller.currentMatch?.offset, 0);
  });

  test('cycles through inline completion items', () {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    controller.assistance = const AssistResponse(
      action: AssistAction.completion,
      items: [
        AssistCompletionItem(
          label: 'برنامج',
          insertText: 'برنامج',
          kind: 'keyword',
          detail: 'كلمة محجوزة',
        ),
        AssistCompletionItem(
          label: 'برنامج_آخر',
          insertText: 'برنامج_آخر',
          kind: 'symbol',
          detail: 'رمز',
        ),
      ],
    );

    expect(controller.currentCompletion?.label, 'برنامج');
    controller.nextCompletion();
    expect(controller.currentCompletion?.label, 'برنامج_آخر');
    controller.previousCompletion();
    expect(controller.currentCompletion?.label, 'برنامج');
  });

  testWidgets('renders ghost completion without changing source text', (
    tester,
  ) async {
    final controller = ArabicCodeController(text: 'بر');
    controller.setGhostText('نامج', 2);
    late TextSpan span;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(color: Colors.white),
              withComposing: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(controller.text, 'بر');
    expect(span.toPlainText(), 'برنامج');
  });

  testWidgets('typing remains editable while ghost completion is visible', (
    tester,
  ) async {
    final controller = ArabicCodeController(text: 'بر');
    controller.setGhostText('نامج', 2);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            height: 180,
            child: LineNumberedEditor(controller: controller),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'برنامج');
    expect(controller.text, 'برنامج');
  });

  testWidgets('typing a different character dismisses ghost text once', (
    tester,
  ) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    await controller.open('main.arb');
    controller.edit(
      const TextEdit(offset: 0, before: 'برنامج اختبار {}.', after: 'بر'),
    );
    controller.assistance = const AssistResponse(
      action: AssistAction.completion,
      prefix: 'بر',
      replaceStart: 0,
      replaceLength: 2,
      items: [
        AssistCompletionItem(
          label: 'برنامج',
          insertText: 'برنامج',
          kind: 'keyword',
          detail: 'كلمة محجوزة',
        ),
      ],
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'بز');
    await tester.pump();

    expect(controller.activeDocument?.text, 'بز');
  });

  testWidgets('inserts an indented line without moving the cursor to EOF', (
    tester,
  ) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    await controller.open('main.arb');
    controller.edit(
      const TextEdit(
        offset: 0,
        before: 'برنامج اختبار {}.',
        after: 'برنامج اختبار {',
      ),
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    final field = find.byType(TextField);
    await tester.tap(field);
    final textFieldController = tester.widget<TextField>(field).controller!;
    textFieldController.selection = TextSelection.collapsed(
      offset: textFieldController.text.length,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.activeDocument?.text, 'برنامج اختبار {\n  ');
    expect(
      tester.widget<TextField>(field).controller?.selection.extentOffset,
      controller.activeDocument?.text.length,
    );
  });

  testWidgets('inserts a new line safely at offset zero', (tester) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    await controller.open('main.arb');

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    final field = find.byType(TextField);
    await tester.tap(field);
    final textFieldController = tester.widget<TextField>(field).controller!;
    textFieldController.selection = const TextSelection.collapsed(offset: 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.activeDocument?.text, '\nبرنامج اختبار {}.');
    expect(textFieldController.selection.extentOffset, 1);
  });

  testWidgets('normalizes a blank-area tap to the end of its line', (
    tester,
  ) async {
    final textController = TextEditingController(text: 'سعيد\nاطبع');
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 800,
            height: 240,
            child: LineNumberedEditor(controller: textController),
          ),
        ),
      ),
    );

    textController.selection = const TextSelection.collapsed(
      offset: 5,
      affinity: TextAffinity.upstream,
    );
    await tester.pump();

    expect(textController.selection.extentOffset, 4);
    expect(textController.selection.affinity, TextAffinity.downstream);
  });

  testWidgets('moves arrows by visual direction in the Arabic editor', (
    tester,
  ) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    await controller.open('main.arb');
    controller.edit(
      const TextEdit(
        offset: 0,
        before: 'برنامج اختبار {}.',
        after: 'سعيد\nاطبع',
      ),
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    final field = find.byType(TextField);
    await tester.tap(field);
    final textFieldController = tester.widget<TextField>(field).controller!;
    textFieldController.selection = const TextSelection.collapsed(offset: 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(textFieldController.selection.extentOffset, 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(textFieldController.selection.extentOffset, 4);
  });

  testWidgets('toggles line comments through the editor shortcut', (
    tester,
  ) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    await controller.open('main.arb');

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    final field = find.byType(TextField);
    await tester.tap(field);
    final textFieldController = tester.widget<TextField>(field).controller!;
    textFieldController.selection = const TextSelection.collapsed(offset: 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(controller.activeDocument?.text, '// برنامج اختبار {}.');
  });

  testWidgets('changes global text scale once and resets it', (tester) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );
    await controller.open('main.arb');

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    final scaffold = find.byType(Scaffold);
    double scale() =>
        MediaQuery.of(tester.element(scaffold)).textScaler.scale(1);

    expect(scale(), 1.0);
    await tester.tap(find.byType(TextField));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(scale(), closeTo(1.1, 0.001));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(scale(), 1.0);
  });

  testWidgets('shows a diagnostic lamp in the editor gutter', (tester) async {
    final controller = ArabicCodeController(text: 'برنامج');
    controller.setDiagnostics([
      const EditorDiagnostic(
        severity: EditorDiagnosticSeverity.error,
        phase: 'lexer',
        code: 'L001',
        message: 'رمز غير معروف',
        sourcePath: 'main.arb',
        offset: 0,
        length: 1,
        line: 1,
        column: 1,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            height: 180,
            child: LineNumberedEditor(
              controller: controller,
              diagnostics: controller.diagnostics,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
  });

  testWidgets('keeps code input RTL inside the RTL editor shell', (
    tester,
  ) async {
    final controller = ArabicCodeController(text: 'س = 1؛');

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            child: SizedBox(
              height: 180,
              child: LineNumberedEditor(controller: controller, fontScale: 1.5),
            ),
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textDirection, TextDirection.rtl);
    expect(field.textAlign, TextAlign.right);
    expect(field.style?.fontSize, 15);
  });

  testWidgets('highlights compiler-backed lexical categories', (tester) async {
    final controller = ArabicCodeController(
      text: 'برنامج صحيح صح 12 1.5 "نص" + // تعليق',
    );
    late TextSpan span;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(color: Colors.white),
              withComposing: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final colors = {
      for (final child in span.children!.whereType<TextSpan>())
        if (child.style?.color != null) child.style!.color,
    };
    expect(colors.length, greaterThanOrEqualTo(5));
  });

  testWidgets('semantic roles refine highlighting and diagnostics win', (
    tester,
  ) async {
    final controller = ArabicCodeController(text: 'س = 1; ص');
    controller.setSemanticRoles(const {'س': SourceTokenRole.constant});
    controller.setDiagnostics([
      const EditorDiagnostic(
        severity: EditorDiagnosticSeverity.error,
        phase: 'lexer',
        code: 'L001',
        message: 'رمز غير معروف',
        sourcePath: 'main.arb',
        offset: 7,
        length: 1,
        line: 1,
        column: 8,
      ),
    ]);
    late TextSpan span;
    late ColorScheme scheme;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(color: Colors.white),
              withComposing: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final constantSpan = span.children!.whereType<TextSpan>().firstWhere(
      (child) => child.text == 'س',
    );
    final diagnosticSpan = span.children!.whereType<TextSpan>().firstWhere(
      (child) => child.text == 'ص',
    );
    expect(constantSpan.style?.color, scheme.secondary);
    expect(diagnosticSpan.style?.decoration, TextDecoration.underline);
    expect(diagnosticSpan.style?.decorationStyle, TextDecorationStyle.wavy);
  });
}
