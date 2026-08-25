import 'package:acsys360/domain/entities/editor_diagnostic.dart';
import 'package:acsys360/domain/usecases/arabic_language_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enriches parser diagnostics with a safe insertion fix', () {
    const service = ArabicLanguageService();
    final diagnostics = service.enrichDiagnostics([
      {
        'severity': 'error',
        'phase': 'syntax',
        'code': 'S001',
        'message': 'متوقع ";"',
        'span': {
          'sourcePath': '/tmp/main.arb',
          'offset': 12,
          'line': 1,
          'column': 13,
          'length': 1,
        },
      },
    ], 'برنامج اختبار');

    expect(diagnostics.single.line, 1);
    expect(diagnostics.single.actions.single.replacement, ';');
    expect(diagnostics.single.actions.single.offset, 12);
  });

  test('uses half-open offsets for diagnostics', () {
    const diagnostic = EditorDiagnostic(
      severity: EditorDiagnosticSeverity.error,
      phase: 'syntax',
      code: 'S001',
      message: 'خطأ',
      sourcePath: 'main.arb',
      offset: 4,
      length: 1,
      line: 1,
      column: 5,
    );

    expect(diagnostic.containsOffset(4), isTrue);
    expect(diagnostic.containsOffset(5), isFalse);
  });
}
