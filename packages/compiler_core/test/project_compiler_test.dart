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

  test('does not leak variables between project files', () {
    final result = const ProjectCompiler().compile({
      'main.arb': '''برنامج رئيسي {
س = 3;
}.''',
      'lib.arb': '''برنامج مكتبة {
متغير س: صحيح;
}.''',
    });

    expect(result.success, isFalse);
    expect(result.diagnosticsFor('main.arb'), isNotEmpty);
    expect(
      result.diagnosticsFor('main.arb').single.message,
      contains('غير معرف'),
    );
  });

  test('resolves a procedure exported by another project file', () {
    final result = const ProjectCompiler().compile({
      'main.arb': '''برنامج رئيسي {
متغير س: صحيح;
س = 3;
اطبع_قيمة(س);
}.''',
      'lib.arb': '''برنامج مكتبة {
اجراء اطبع_قيمة(بالقيمة قيمة: صحيح)؛ {
اطبع(قيمة);
};
}.''',
    });

    expect(result.success, isTrue);
    expect(result.projectDiagnostics, isEmpty);
    expect(result.diagnosticsFor('main.arb'), isEmpty);
  });
}

String _program(String name) =>
    '''برنامج اختبار {
  متغير $name: صحيح;
  $name = 1;
  اطبع($name);
}.''';
