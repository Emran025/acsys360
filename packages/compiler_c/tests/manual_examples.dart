import 'dart:convert';
import 'dart:io';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<Map<String, dynamic>> compileSource(String executable, File path) async {
  final source = await path.readAsString();
  final request = {
    'protocolVersion': '0.5.0',
    'rootPath': path.parent.path,
    'sourcePaths': [path.path],
    'sourceTexts': {path.path: source},
    'mode': 'project',
    'entryPath': path.path,
  };
  final process = await Process.start(executable, ['--protocol']);
  process.stdin.writeln(jsonEncode(request));
  await process.stdin.close();
  final output = (await process.stdout.transform(utf8.decoder).join()).trim();
  final stderr = await process.stderr.transform(utf8.decoder).join();
  await process.exitCode;
  check(output.isNotEmpty, '${path.path}: $stderr');
  return jsonDecode(output) as Map<String, dynamic>;
}

Future<void> main(List<String> args) async {
  check(args.length == 1, 'usage: dart manual_examples.dart <arabicc>');
  final directory = File(Platform.script.toFilePath()).parent.parent.parent.parent
      .uri
      .resolve('examples/manual/');
  final positive = [
    '01_basics.arb',
    '02_composite_types.arb',
    '03_arithmetic.arb',
    '04_io.arb',
    '05_conditions.arb',
    '06_loops.arb',
    '07_procedures.arb',
    '10_all_rules.arb',
  ];
  final negative = ['08_syntax_error.arb', '09_semantic_error.arb'];
  for (final name in positive) {
    final path = File(directory.resolve(name).toFilePath());
    final response = await compileSource(args.single, path);
    check(response['success'] == true,
        '${path.path}: ${response['diagnostics']}');
  }
  for (final name in negative) {
    final path = File(directory.resolve(name).toFilePath());
    final response = await compileSource(args.single, path);
    check(response['success'] == false, '${path.path}: expected failure');
  }
  print('manual examples passed: ${positive.length} positive, ${negative.length} negative');
}
