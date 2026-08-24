import 'dart:io';

import 'package:test/test.dart';

import 'package:compiler_core/arabic_compiler.dart';

void main() {
  test(
    'builds and runs a native artifact for a valid Arabic360 program',
    () async {
      final lexical = Lexer('''برنامج اختبار {
متغير س: صحيح;
س = 2 + 3;
اطبع(س);
}.''').scan();
      final parsed = Parser(lexical.tokens).parse();
      expect(lexical.diagnostics, isEmpty);
      expect(parsed.diagnostics, isEmpty);
      expect(parsed.program, isNotNull);

      final directory = await Directory.systemTemp.createTemp(
        'arabic360-native-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final result = await const DartNativeArtifactBuilder().build(
        parsed.program!,
        outputDirectory: directory.path,
        dartExecutable: Platform.resolvedExecutable,
      );

      expect(result.success, isTrue, reason: result.diagnostics.join('\n'));
      final process = await Process.run(result.executablePath!, []);
      expect(
        process.exitCode,
        0,
        reason: '${process.stdout}\n${process.stderr}',
      );
      expect(process.stdout.toString().trim(), '5');
    },
  );

  test('builds native control flow and procedure calls', () async {
    final lexical = Lexer('''برنامج اختبار {
اجراء اطبع_مضاعف(بالقيمة قيمة: صحيح)؛ {
اطبع(قيمة * 2);
};
متغير س: صحيح;
س = 1;
طالما(س < 4) استمر {
اطبع_مضاعف(س);
س = س + 1;
}
}.''').scan();
    final parsed = Parser(lexical.tokens).parse();
    expect(lexical.diagnostics, isEmpty);
    expect(parsed.diagnostics, isEmpty);
    expect(parsed.program, isNotNull);

    final directory = await Directory.systemTemp.createTemp(
      'arabic360-native-control-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final result = await const DartNativeArtifactBuilder().build(
      parsed.program!,
      outputDirectory: directory.path,
      dartExecutable: Platform.resolvedExecutable,
    );

    expect(result.success, isTrue, reason: result.diagnostics.join('\n'));
    final process = await Process.run(result.executablePath!, []);
    expect(process.exitCode, 0, reason: '${process.stdout}\n${process.stderr}');
    expect(process.stdout.toString().trim().split('\n'), ['2', '4', '6']);
  });
}
