import 'package:acsys360/features/editor/domain/entities/editor_diagnostic.dart';
import 'package:acsys360/features/editor/domain/usecases/arabic_language_service.dart';
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

  test('suggests the closest declared name for an unknown identifier', () {
    const service = ArabicLanguageService();
    const source = 'متغير العدد: صحيح؛ العد = 1؛';
    final offset = source.indexOf('العد');
    final diagnostics = service.enrichDiagnostics([
      {
        'severity': 'error',
        'phase': 'semantic',
        'code': 'SEM001',
        'message': 'رمز غير معرف: العد',
        'span': {
          'offset': offset,
          'line': 1,
          'column': offset + 1,
          'length': 'العد'.length,
        },
      },
    ], source, symbolNames: const ['العدد']);

    expect(diagnostics.single.actions, hasLength(1));
    expect(diagnostics.single.actions.single.replacement, 'العدد');
    expect(diagnostics.single.actions.single.offset, offset);
    expect(diagnostics.single.actions.single.length, 'العد'.length);
  });

  test('offers insertion at EOF without selecting the previous character', () {
    const service = ArabicLanguageService();
    const source = 'برنامج نهاية؛ { }';
    final diagnostics = service.enrichDiagnostics([
      {
        'severity': 'error',
        'phase': 'syntax',
        'code': 'S001',
        'message': 'متوقع "." قبل نهاية المصدر',
        'span': {
          'offset': source.length,
          'line': 1,
          'column': source.length + 1,
          'length': 0,
        },
      },
    ], source);

    expect(diagnostics.single.actions.single.offset, source.length);
    expect(diagnostics.single.actions.single.length, 0);
    expect(diagnostics.single.actions.single.replacement, '.');
  });
}
