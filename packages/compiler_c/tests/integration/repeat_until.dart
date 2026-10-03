import 'dart:convert';
import 'dart:io';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<Map<String, dynamic>> compile(String executable, String source) async {
  final process = await Process.start(executable, const ['--protocol']);
  process.stdin.writeln(
    jsonEncode({
      'protocolVersion': '0.5.0',
      'rootPath': '.',
      'sourcePaths': ['repeat_until.arb'],
      'sourceTexts': {'repeat_until.arb': source},
      'mode': 'active',
      'entryPath': 'repeat_until.arb',
      'execute': true,
    }),
  );
  await process.stdin.close();
  final stdout = (await process.stdout.transform(utf8.decoder).join()).trim();
  final stderr = await process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;
  check(stdout.isNotEmpty, 'compiler returned no response: $stderr');
  check(exitCode == 0, 'compiler exited with $exitCode: $stderr');
  return jsonDecode(stdout) as Map<String, dynamic>;
}

Future<void> main(List<String> args) async {
  check(args.length == 1, 'usage: dart repeat_until.dart <arabicc>');

  const source = '''
برنامج اختبار_اعد_حتى؛
متغير س, j: صحيح؛
{
  س = 0؛
  أعد س = س + 1 حتى(س == 3)؛
  أعد {
    س = س + 1؛
    س = س + 1؛
  } حتى(س => 7)؛
  j = 1؛
  طالما(j < 4)؛{
    استمر j = j + 1؛
    اطبع(j)؛
  }؛
  أعد حتى(صح)؛
  اطبع(س، "اكتمل")؛
}.
''';
  final response = await compile(args.single, source);
  check(
    response['success'] == true,
    'repeat-until program should compile: ${response['diagnostics']}',
  );
  check(
    (response['executionOutput'] as List).join('\n') == '2\n3\n4\n7\nاكتمل',
    'unexpected repeat-until output: ${response['executionOutput']}',
  );
}
