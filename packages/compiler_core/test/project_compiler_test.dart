import 'package:compiler_core/arabic_compiler.dart';
import 'package:test/test.dart';

void main() {
  test('reports duplicate variable declarations across project files', () {
    final result = const ProjectCompiler().compile({
      'main.arb': _program('س'),
      'lib.arb': _program('س'),
    });

    expect(result.success, isFalse);
    expect(
      result.projectDiagnostics.single.diagnostic.message,
      contains('معرف في أكثر من ملف'),
    );
    expect(result.diagnosticsFor('lib.arb'), hasLength(1));
  });

  test('keeps independent files successful', () {
    final result = const ProjectCompiler().compile({
      'main.arb': _program('س'),
      'lib.arb': _program('ص'),
    });

    expect(result.success, isTrue);
    expect(result.projectDiagnostics, isEmpty);
  });
}

String _program(String name) =>
    '''برنامج اختبار {
  متغير $name: صحيح;
  $name = 1;
  اطبع($name);
}.''';
