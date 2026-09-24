import 'dart:convert';
import 'dart:io';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main(List<String> args) async {
  check(args.length == 1, 'usage: dart composite_types.dart <arabicc>');
  final path = File(Platform.script.toFilePath()).parent.parent.parent.parent
      .uri
      .resolve('examples/manual/02_composite_types.arb')
      .toFilePath();
  final source = await File(path).readAsString();
  final request = {
    'protocolVersion': '0.5.0',
    'rootPath': Directory(path).parent.path,
    'sourcePaths': [path],
    'sourceTexts': {path: source},
    'mode': 'project',
    'entryPath': path,
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
  check(exitCode == 0, 'composite program exited with $exitCode');
  check(response['success'] == true,
      'composite program diagnostics: ${response['diagnostics']}');
  check(_sameList(response['executionOutput'], ['10', 'علي', '20', 'صح']),
      'composite execution output changed: ${response['executionOutput']}');
}

bool _sameList(Object? actual, List<String> expected) =>
    actual is List && actual.length == expected.length &&
    List.generate(actual.length, (index) => actual[index] == expected[index])
        .every((value) => value);
