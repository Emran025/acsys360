import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final executableIndex = arguments.indexOf('--executable');
  if (executableIndex == -1 || executableIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Usage: dart run tool/verify_compiler_bundle.dart --executable <path>',
    );
    exitCode = 64;
    return;
  }

  final executable = arguments[executableIndex + 1];
  final native = arguments.contains('--native');
  final artifactDirectory = Directory.current.createTempSync(
    'acsys360-bundle-smoke-',
  );
  final request = {
    'protocolVersion': '0.5.0',
    'rootPath': Directory.current.path,
    'sourcePaths': ['smoke.arb'],
    'sourceTexts': {'smoke.arb': 'برنامج اختبار؛ { اطبع(2)؛ }.'},
    'mode': 'project',
    if (native) ...{
      'target': 'dart-native',
      'artifactDirectory': artifactDirectory.path,
    },
  };
  try {
    final process = await Process.start(executable, const [
      '--protocol',
    ], workingDirectory: Directory.current.path);
    process.stdin.writeln(jsonEncode(request));
    await process.stdin.close();
    final output = await process.stdout.transform(utf8.decoder).join();
    final errorOutput = await process.stderr.transform(utf8.decoder).join();
    final result = await process.exitCode;
    if (result != 0) {
      stderr.writeln(errorOutput);
      exitCode = result;
      return;
    }

    final response = jsonDecode(output);
    final artifacts = response is Map ? response['artifacts'] : null;
    if (response is! Map ||
        response['protocolVersion'] != '0.5.0' ||
        response['success'] != true ||
        response['executionOutput'] is! List ||
        artifacts is! List ||
        response['intermediateRepresentation'] is! Map ||
        (native && artifacts.isEmpty)) {
      stderr.writeln(
        native
            ? 'Bundled compiler native smoke test failed; GCC/NASM may be missing.'
            : 'Bundled compiler returned an unsuccessful protocol response.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'Bundled compiler ${native ? 'native ' : ''}smoke test passed: $executable',
    );
  } finally {
    if (artifactDirectory.existsSync()) {
      artifactDirectory.deleteSync(recursive: true);
    }
  }
}
