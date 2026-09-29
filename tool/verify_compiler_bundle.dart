import 'dart:async';
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
  final environment = <String, String>{...Platform.environment};
  if (native && Platform.isWindows) {
    final bundleRoot = File(executable).absolute.parent.parent.path;
    final toolchainDirectory = Directory(
      '$bundleRoot${Platform.pathSeparator}toolchain${Platform.pathSeparator}windows${Platform.pathSeparator}bin',
    ).absolute.path;
    environment['ACSYS360_TOOLCHAIN_DIR'] = toolchainDirectory;
    environment['ACSYS360_TOOLCHAIN_ONLY'] = '1';
    final pathKey = environment.containsKey('Path') ? 'Path' : 'PATH';
    final systemRoot = environment['SystemRoot'] ?? r'C:\Windows';
    environment[pathKey] = [
      toolchainDirectory,
      '$systemRoot${Platform.pathSeparator}System32',
      systemRoot,
    ].join(';');
  }
  final request = {
    'protocolVersion': '0.5.0',
    'rootPath': Directory.current.path,
    'sourcePaths': ['smoke.arb'],
    'sourceTexts': {'smoke.arb': 'برنامج اختبار؛ { اطبع(2)؛ }.'},
    'mode': 'project',
    if (native) 'execute': false,
    if (native) ...{
      'target': 'dart-native',
      'artifactDirectory': artifactDirectory.path,
    },
  };
  try {
    final process = await Process.start(
      executable,
      const ['--protocol'],
      workingDirectory: Directory.current.path,
      environment: environment,
      includeParentEnvironment: false,
    );
    process.stdin.writeln(jsonEncode(request));
    await process.stdin.close();
    final outputFuture = process.stdout.transform(utf8.decoder).join();
    final errorOutputFuture = process.stderr.transform(utf8.decoder).join();
    final exitCodeFuture = process.exitCode;
    late final String output;
    late final String errorOutput;
    late final int result;
    try {
      await Future.wait<Object>([
        outputFuture,
        errorOutputFuture,
        exitCodeFuture,
      ]).timeout(const Duration(seconds: 90));
      output = await outputFuture;
      errorOutput = await errorOutputFuture;
      result = await exitCodeFuture;
    } on TimeoutException {
      process.kill(ProcessSignal.sigterm);
      stderr.writeln(
        'Bundled compiler smoke test timed out after 90 seconds; '
        'native toolchain execution was terminated.',
      );
      exitCode = 124;
      return;
    }
    if (result != 0) {
      stderr.writeln('Bundled compiler exited with code $result.');
      if (output.isNotEmpty) stderr.writeln('stdout: $output');
      if (errorOutput.isNotEmpty) stderr.writeln('stderr: $errorOutput');
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
      stderr.writeln('Bundled compiler response: $output');
      if (response is Map && response['diagnostics'] is List) {
        stderr.writeln('Compiler diagnostics: ${response['diagnostics']}');
      }
      stderr.writeln(
        native
            ? 'Bundled compiler native smoke test failed; GCC/NASM may be missing.'
            : 'Bundled compiler returned an unsuccessful protocol response.',
      );
      exitCode = 1;
      return;
    }
    if (native) {
      if (artifacts.any((artifact) => artifact is! String)) {
        stderr.writeln('Compiler returned a non-string artifact path.');
        exitCode = 1;
        return;
      }
      final artifactPaths = artifacts.cast<String>();
      for (final artifact in artifactPaths) {
        if (!File(artifact).existsSync()) {
          stderr.writeln('Compiler reported a missing artifact: $artifact');
          exitCode = 1;
          return;
        }
      }
      final executablePath = artifactPaths.last;
      final nativeProcess = await Process.start(
        executablePath,
        const [],
        workingDirectory: artifactDirectory.path,
        environment: environment,
        includeParentEnvironment: false,
        runInShell: false,
      );
      final nativeStdout = nativeProcess.stdout.transform(utf8.decoder).join();
      final nativeStderr = nativeProcess.stderr.transform(utf8.decoder).join();
      final nativeExitCode = nativeProcess.exitCode;
      try {
        await Future.wait<Object>([
          nativeStdout,
          nativeStderr,
          nativeExitCode,
        ]).timeout(const Duration(seconds: 30));
      } on TimeoutException {
        nativeProcess.kill(ProcessSignal.sigterm);
        stderr.writeln('Generated native artifact timed out after 30 seconds.');
        exitCode = 124;
        return;
      }
      final output = (await nativeStdout).replaceAll('\r\n', '\n').trim();
      final errorOutput = await nativeStderr;
      final result = await nativeExitCode;
      if (result != 0 || output != '2') {
        stderr.writeln(
          'Generated native artifact failed: exit=$result, '
          'stdout=$output, stderr=$errorOutput',
        );
        exitCode = 1;
        return;
      }
    }
    stdout.writeln(
      'Bundled compiler ${native ? 'native build-and-run ' : ''}smoke test passed: $executable',
    );
  } finally {
    if (artifactDirectory.existsSync()) {
      artifactDirectory.deleteSync(recursive: true);
    }
  }
}
