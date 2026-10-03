import 'dart:convert';
import 'dart:io';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main(List<String> args) async {
  check(args.length == 1, 'usage: dart record_array_regression.dart <arabicc>');
  const source = '''برنامج مصفوفة_سجل؛
نوع درجات = قائمة[3] من صحيح؛
نوع طالب = سجل { درجات: درجات؛ اسم: خيط_رمزي؛ }؛
متغير الطالب: طالب؛
{
الطالب.درجات[0] = 10؛
الطالب.درجات[1] = 20؛
الطالب.درجات[2] = 30؛
الطالب.اسم = "سارة"؛
اطبع(الطالب.اسم, الطالب.درجات[1])؛
}.''';
  final request = {
    'protocolVersion': '0.5.0',
    'rootPath': Directory.current.path,
    'sourcePaths': ['main.arb'],
    'sourceTexts': {'main.arb': source},
    'mode': 'project',
    'entryPath': 'main.arb',
    'execute': true,
  };
  final process = await Process.start(args.single, ['--protocol']);
  process.stdin.writeln(jsonEncode(request));
  await process.stdin.close();
  final stdout = (await process.stdout.transform(utf8.decoder).join()).trim();
  final stderr = await process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;
  check(stdout.isNotEmpty, 'compiler returned no response: $stderr');
  final response = jsonDecode(stdout) as Map<String, dynamic>;
  check(exitCode == 0, 'compiler exited with $exitCode: $stderr');
  check(response['success'] == true, 'diagnostics: ${response['diagnostics']}');
  check(
    _sameList(response['executionOutput'], ['سارة', '20']),
    'expected [سارة, 20], got ${response['executionOutput']}',
  );
  final tac = (response['threeAddressCode'] as List).cast<String>();
  check(tac.contains('الطالب.اسم = "سارة"'), 'record field was lost in 3AC: $tac');
  check(tac.contains('PRINT الطالب.درجات[1]'), 'array access was lost in 3AC: $tac');
}

bool _sameList(Object? actual, List<String> expected) =>
    actual is List &&
    actual.length == expected.length &&
    List.generate(actual.length, (index) => actual[index] == expected[index])
        .every((value) => value);
