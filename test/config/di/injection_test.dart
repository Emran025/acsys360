import 'package:acsys360/config/di/injection.dart';
import 'package:acsys360/features/editor/data/datasources/file_picker_document_service.dart';
import 'package:acsys360/features/editor/presentation/controllers/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composition root wires the editor controller and file service', () {
    final controller = ServiceLocator.createEditorController(
      rootPath: '/workspace',
    );
    expect(controller, isA<EditorController>());
    expect(controller.workspace.rootPath, '/workspace');
    expect(
      ServiceLocator.createDocumentFileService(),
      isA<FilePickerDocumentService>(),
    );
  });
}
