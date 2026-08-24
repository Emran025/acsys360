import 'dart:io';

import 'package:compiler_core/arabic_compiler.dart';
import 'package:test/test.dart';

void main() {
  test(
    'matches interpreter for literals, constants, and typed values',
    () async {
      await _expectNativeParity('''
برنامج تعريفات؛ {
ثابت نسبة = 2.5;
متغير قيمة: حقيقي;
متغير متاح: منطقي;
متغير رمز: حرفي;
متغير اسم: خيط_رمزي;
قيمة = نسبة * 2;
متاح = صح;
رمز = ‘س’؛
اسم = "لغة عربية";
اطبع(قيمة, متاح, رمز, اسم);
}.
''');
    },
  );

  test('matches interpreter for typed input and arithmetic', () async {
    await _expectNativeParity(
      '''
برنامج ادخال؛ {
متغير س: صحيح;
اقرا(س);
اطبع(س * 2);
}.
''',
      input: const ['7'],
    );
  });

  test(
    'matches interpreter for if, repeat, and repeat-until control flow',
    () async {
      await _expectNativeParity('''
برنامج تحكم؛ {
متغير س: صحيح;
س = 0;
اذا(س == 0) فان { س = 1; } والا { س = 99; };
كرر(س = 1 الى 5 اضف 2) {
اطبع(س);
}
كرر(س = 1 الى 3) {
س = س + 1;
}
اعد {
س = س + 1;
} حتى(س => 5)
اطبع(س);
}.
''');
    },
  );

  test(
    'matches interpreter for reference procedures and compound values',
    () async {
      await _expectNativeParity('''
برنامج مركب؛ {
نوع درجات = قائمة[3] من صحيح;
نوع طالب = سجل { درجات: درجات; اسم: خيط_رمزي; };
متغير الطالب: طالب;
متغير س: صحيح;
اجراء زد(بالمرجع قيمة: صحيح); {
قيمة = قيمة + 1;
};
الطالب.درجات[0] = 10;
الطالب.درجات[1] = 20;
الطالب.اسم = "سارة";
س = الطالب.درجات[0] + الطالب.درجات[1];
زد(س);
اطبع(الطالب.اسم, س);
}.
''');
    },
  );

  test(
    'builds a native artifact with executable metadata verification',
    () async {
      final program = _parse('''
برنامج اختبار؛ {
اطبع(2 + 3);
}.
''');
      final directory = await Directory.systemTemp.createTemp(
        'arabic360-native-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final result = await const DartNativeArtifactBuilder().build(
        program,
        outputDirectory: directory.path,
        dartExecutable: Platform.resolvedExecutable,
      );

      expect(result.success, isTrue, reason: result.diagnostics.join('\n'));
      expect(result.verified, isTrue);
      final process = await Process.run(result.executablePath!, []);
      expect(
        process.exitCode,
        0,
        reason: '${process.stdout}\n${process.stderr}',
      );
      expect(process.stdout.toString().trim(), '5');
    },
  );
}

Future<void> _expectNativeParity(
  String source, {
  List<String> input = const [],
}) async {
  final program = _parse(source);
  final interpreted = const Interpreter().execute(program, input: input);
  expect(
    interpreted.success,
    isTrue,
    reason: interpreted.diagnostics.join('\n'),
  );

  final directory = await Directory.systemTemp.createTemp(
    'arabic360-native-parity-',
  );
  addTearDown(() => directory.delete(recursive: true));
  final native = await const DartNativeArtifactBuilder().build(
    program,
    outputDirectory: directory.path,
    dartExecutable: Platform.resolvedExecutable,
  );
  expect(native.success, isTrue, reason: native.diagnostics.join('\n'));

  final process = await Process.start(native.executablePath!, []);
  if (input.isNotEmpty) {
    process.stdin.write('${input.join('\n')}\n');
  }
  await process.stdin.close();
  final stdout = await process.stdout
      .transform(SystemEncoding().decoder)
      .join();
  final stderr = await process.stderr
      .transform(SystemEncoding().decoder)
      .join();
  final exitCode = await process.exitCode;
  expect(exitCode, 0, reason: '$stdout\n$stderr');
  expect(stdout.trim(), interpreted.output.join('\n'));
}

ProgramNode _parse(String source) {
  final lexical = Lexer(source).scan();
  expect(
    lexical.diagnostics,
    isEmpty,
    reason: lexical.diagnostics.map((item) => item.message).join('\n'),
  );
  final parsed = Parser(lexical.tokens).parse();
  expect(
    parsed.diagnostics,
    isEmpty,
    reason: parsed.diagnostics.map((item) => item.message).join('\n'),
  );
  return parsed.program!;
}
