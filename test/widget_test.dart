import 'package:acsys360/domain/entities/document.dart';
import 'package:acsys360/domain/entities/file_node.dart';
import 'package:acsys360/domain/repositories/workspace_repository.dart';
import 'package:acsys360/main.dart';
import 'package:acsys360/presentation/state/editor_controller.dart';
import 'package:flutter/material.dart';
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
    expect(find.text('src'), findsOneWidget);
    expect(find.text('main.arb'), findsNothing);

    await tester.tap(find.text('src'));
    await tester.pumpAndSettle();
    expect(find.text('main.arb'), findsOneWidget);

    await tester.tap(find.text('main.arb'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.activeDocument?.text, 'برنامج اختبار {}.');
  });

  testWidgets('toggles the editor theme', (tester) async {
    final controller = EditorController(
      repository: FakeWorkspaceRepository(),
      rootPath: '.',
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pump();
    expect(find.byTooltip('الوضع الداكن'), findsOneWidget);

    await tester.tap(find.byTooltip('الوضع الداكن'));
    await tester.pump();
    expect(find.byTooltip('الوضع الفاتح'), findsOneWidget);
  });
}
