import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _timeout = Duration(seconds: 10);

Never fail(String message) => throw StateError(message);

void check(bool condition, String message) {
  if (!condition) fail(message);
}

class RunResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const RunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

Future<RunResult> runProcess(
  String executable,
  List<String> arguments, {
  String? input,
}) async {
  final process = await Process.start(executable, arguments).timeout(_timeout);
  try {
    if (input != null) {
      process.stdin.write(input);
      await process.stdin.close();
    } else {
      await process.stdin.close();
    }
    final values = await Future.wait<Object?>([
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.transform(utf8.decoder).join(),
      process.exitCode,
    ]).timeout(_timeout);
    return RunResult(
      stdout: values[0]! as String,
      stderr: values[1]! as String,
      exitCode: values[2]! as int,
    );
  } on Object {
    process.kill();
    rethrow;
  }
}

Future<Map<String, dynamic>> compile(
  String executable,
  Map<String, dynamic> request,
) async {
  final result = await runProcess(
    executable,
    const ['--protocol'],
    input: '${jsonEncode(request)}\n',
  );
  check(
    result.stdout.trim().isNotEmpty,
    'compiler returned no response: ${result.stderr}',
  );
  return Map<String, dynamic>.from(jsonDecode(result.stdout));
}

Map<String, dynamic> requestFor(
  String source, {
  bool execute = true,
  String? target,
  String? artifactDirectory,
}) => {
  'protocolVersion': '0.5.0',
  'rootPath': '/stability',
  'sourcePaths': ['/stability/main.arb'],
  'sourceTexts': {'/stability/main.arb': source},
  'mode': 'project',
  'entryPath': '/stability/main.arb',
  'execute': execute,
  ...?target == null ? null : {'target': target},
  ...?artifactDirectory == null ? null : {'artifactDirectory': artifactDirectory},
};

String canonical(Map<String, dynamic> response) => jsonEncode(response);

Future<void> main(List<String> args) async {
  check(args.length == 1, 'usage: dart stability.dart <arabicc>');
  final executable = args.single;

  const validSource = 'برنامج ثبات؛ { اطبع(1 + 2)؛ اطبع("ثابت")؛ }.';
  final validRequest = requestFor(validSource);
  String? validBaseline;
  for (var iteration = 0; iteration < 20; iteration++) {
    final response = await compile(executable, validRequest);
    check(response['success'] == true, 'valid iteration $iteration failed');
    check(
      _sameList(response['executionOutput'], ['3', 'ثابت']),
      'valid output changed at iteration $iteration',
    );
    final encoded = canonical(response);
    validBaseline ??= encoded;
    check(encoded == validBaseline, 'valid response is not deterministic');
  }

  const syntaxRequest = {
    'protocolVersion': '0.5.0',
    'rootPath': '/stability',
    'sourcePaths': ['/stability/main.arb'],
    'sourceTexts': {
      '/stability/main.arb': 'برنامج خطأ؛ { اطبع(؛ }.',
    },
    'mode': 'project',
    'entryPath': '/stability/main.arb',
  };
  final syntaxBaseline = canonical(await compile(executable, syntaxRequest));
  for (var iteration = 0; iteration < 10; iteration++) {
    final response = await compile(executable, syntaxRequest);
    check(response['success'] == false, 'syntax error unexpectedly succeeded');
    check(
      canonical(response) == syntaxBaseline,
      'syntax response is not deterministic',
    );
  }

  const semanticRequest = {
    'protocolVersion': '0.5.0',
    'rootPath': '/stability',
    'sourcePaths': ['/stability/main.arb'],
    'sourceTexts': {
      '/stability/main.arb':
          'برنامج خطأ دلالي؛ متغير رقم: صحيح؛ متغير نص: خيط_رمزي؛ '
          '{ رقم = نص؛ }.',
    },
    'mode': 'project',
    'entryPath': '/stability/main.arb',
  };
  final semanticBaseline = canonical(await compile(executable, semanticRequest));
  for (var iteration = 0; iteration < 10; iteration++) {
    final response = await compile(executable, semanticRequest);
    check(response['success'] == false, 'semantic error unexpectedly succeeded');
    check(
      canonical(response) == semanticBaseline,
      'semantic response is not deterministic',
    );
  }

  const malformedPayload = '{"protocolVersion":"0.5.0","sourceTexts":';
  String? malformedBaseline;
  for (var iteration = 0; iteration < 10; iteration++) {
    final result = await runProcess(
      executable,
      const ['--protocol'],
      input: '$malformedPayload\n',
    );
    check(result.stdout.trim().isNotEmpty, 'malformed request returned nothing');
    final response = Map<String, dynamic>.from(jsonDecode(result.stdout));
    check(response['success'] == false, 'malformed request unexpectedly succeeded');
    final encoded = canonical(response);
    malformedBaseline ??= encoded;
    check(encoded == malformedBaseline, 'malformed response is not deterministic');
  }

  for (var iteration = 0; iteration < 4; iteration++) {
    final directory = await Directory.systemTemp.createTemp(
      'arabicc-stability-artifact-',
    );
    final marker = File('${directory.path}/shell-injection-marker');
    final artifactDirectory = Directory(
      '${directory.path}/artifact-\$(touch ${marker.path})',
    );
    try {
      await artifactDirectory.create(recursive: true);
      final response = await compile(
        executable,
        requestFor(
          'برنامج artifact؛ { اطبع(7)؛ }.',
          target: 'dart-native',
          artifactDirectory: artifactDirectory.path,
        ),
      );
      check(response['success'] == true, 'artifact iteration $iteration failed');
      check(!await marker.exists(), 'artifact path executed shell syntax');
      final artifacts = response['artifacts'];
      check(artifacts is List && artifacts.length >= 2, 'artifacts are missing');
      for (final artifact in artifacts) {
        check(artifact is String && await File(artifact).exists(),
            'artifact does not exist: $artifact');
      }
      final executablePath = (artifacts as List).last as String;
      final execution = await runProcess(executablePath, const []);
      check(
        execution.exitCode == 0,
        'artifact iteration $iteration failed: ${execution.stderr}',
      );
    } finally {
      await directory.delete(recursive: true);
    }
  }

  stdout.writeln(
    'compiler stability tests passed: deterministic protocol, recovery, and artifacts',
  );
}

bool _sameList(Object? actual, List<String> expected) =>
    actual is List &&
    actual.length == expected.length &&
    List.generate(actual.length, (index) => actual[index] == expected[index])
        .every((value) => value);
