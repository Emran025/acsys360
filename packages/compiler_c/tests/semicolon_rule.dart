import 'dart:convert';
import 'dart:io';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<Map<String, dynamic>> compileSource(
  String executable,
  String source, {
  String target = 'none',
}) async {
  final request = {
    'protocolVersion': '0.5.0',
    'rootPath': '/workspace',
    'sourcePaths': ['/workspace/main.arb'],
    'sourceTexts': {'/workspace/main.arb': source},
    'mode': 'active',
    'entryPath': '/workspace/main.arb',
    'target': target,
  };
  final process = await Process.start(executable, ['--protocol']);
  process.stdin.writeln(jsonEncode(request));
  await process.stdin.close();
  final stdout = (await process.stdout.transform(utf8.decoder).join()).trim();
  final stderr = await process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;
  check(stdout.isNotEmpty, 'compiler returned no response: $stderr');
  check(
    exitCode == 0 || exitCode == 1,
    'unexpected compiler exit code $exitCode: $stderr',
  );
  return jsonDecode(stdout) as Map<String, dynamic>;
}

Future<void> main(List<String> args) async {
  check(args.length == 1, 'usage: dart semicolon_rule.dart <arabicc>');
  final valid = await compileSource(
    args.single,
    'برنامج اختبار؛ { اطبع(1)؛ }.',
  );
  const elseIfSource =
      'برنامج شروط؛ متغير س: صحيح؛ { س = 8؛ إذا(س < 0) فان اطبع("سالب")؛ وإلا إذا(س > 5) فان اطبع("كبير")؛ وإلا اطبع("صغير")؛ }.';
  final elseIf = await compileSource(args.single, elseIfSource);
  final nativeElseIf = await compileSource(
    args.single,
    elseIfSource,
    target: 'dart-native',
  );
  final invalid = await compileSource(
    args.single,
    'برنامج اختبار؛ { اطبع(1) }.',
  );

  check(valid['success'] == true, 'valid semicolon program should compile');
  check(elseIf['success'] == true, 'else-if chain should compile');
  check(
    nativeElseIf['success'] == true,
    'else-if chain should compile in the native backend',
  );
  check(
    (nativeElseIf['assembly'] as String).contains('if_else'),
    'native backend should emit conditional labels',
  );
  check(invalid['success'] == false, 'missing semicolon should fail');
  check(
    (invalid['diagnostics'] as List).isNotEmpty,
    'missing semicolon should produce a diagnostic',
  );
}
