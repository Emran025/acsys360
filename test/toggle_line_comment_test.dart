import 'package:acsys360/domain/usecases/toggle_line_comment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const toggle = ToggleLineComment();

  test('comments selected lines while preserving indentation', () {
    const source = 'برنامج اختبار {\n  س = 1;\n  ص = 2;\n}.';
    final result = toggle.apply(
      source,
      source.indexOf('س'),
      source.indexOf('}') - 1,
    );

    expect(result.after, '  // س = 1;\n  // ص = 2;');
    expect(result.before, '  س = 1;\n  ص = 2;');
    expect(
      result.selectionBase,
      result.offset + result.before.indexOf('س') + 3,
    );
    expect(result.selectionExtent, greaterThan(result.selectionBase));
  });

  test('uncomments a fully commented selection', () {
    const source = '// س = 1;\n// ص = 2;';
    final result = toggle.apply(source, 0, source.length);

    expect(result.after, 'س = 1;\nص = 2;');
    expect(result.selectionBase, 0);
    expect(result.selectionExtent, result.after.length);
  });

  test('preserves reverse selection direction', () {
    const source = 'س = 1;\nص = 2;';
    final result = toggle.apply(source, source.length, 0);

    expect(result.selectionBase, result.after.length);
    expect(result.selectionExtent, 0);
  });

  test('blank lines do not prevent commenting or decide uncomment mode', () {
    const source = '  س = 1;\n\n  ص = 2;';
    final result = toggle.apply(source, 0, source.length);

    expect(result.after, '  // س = 1;\n\n  // ص = 2;');
  });
}
