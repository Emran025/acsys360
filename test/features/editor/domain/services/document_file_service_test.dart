import 'package:acsys360/features/editor/domain/services/document_file_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unavailable file service is safe in headless environments', () async {
    const service = UnavailableDocumentFileService();
    expect(await service.pickSourceFile(), isNull);
    expect(await service.pickWorkspace(), isNull);
    expect(
      await service.saveSourceFile(fileName: 'main.arb', text: 'س = 1;'),
      isNull,
    );
    expect(service.baseName('/tmp/main.arb'), 'main.arb');
  });
}
