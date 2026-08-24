import 'package:acsys360/domain/entities/document.dart';
import 'package:acsys360/domain/entities/file_node.dart';
import 'package:acsys360/domain/repositories/workspace_repository.dart';
import 'package:acsys360/main.dart';
import 'package:acsys360/presentation/state/editor_controller.dart';
import 'package:acsys360/presentation/widgets/line_numbered_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  final document = const Document(path: 'main.arb', text: 'برنامج اختبار {}.');

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
  Future<Document> create(String rootPath, String name) async =>
      Document(path: name, text: '');

  @override
  Future<void> write(Document document) async {}
}

void main() {
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
  });

  testWidgets('configures theme colors and collapsible panels', (tester) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    expect(find.byTooltip('الوضع الداكن'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
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
}
