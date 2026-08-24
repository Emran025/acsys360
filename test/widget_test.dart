import 'dart:io';

import 'package:acsys360/data/repositories/local_workspace_repository.dart';
import 'package:acsys360/main.dart';
import 'package:acsys360/presentation/state/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens an Arabic source document', (tester) async {
    final directory = await Directory.systemTemp.createTemp('acsys360_test_');
    final file = File('${directory.path}/main.arb');
    await file.writeAsString('برنامج اختبار {}.');
    final controller = EditorController(
      repository: LocalWorkspaceRepository(),
      rootPath: directory.path,
    );

    await tester.pumpWidget(ArabicEditorApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('main.arb'), findsOneWidget);

    await tester.tap(find.text('main.arb'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.activeDocument?.text, 'برنامج اختبار {}.');

    await directory.delete(recursive: true);
  });
}
