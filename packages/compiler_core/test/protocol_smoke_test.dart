import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('CLI accepts a multi-file request over stdin/stdout', () async {
    final root = await Directory.systemTemp.createTemp('arabicc-protocol-');
    addTearDown(() => root.delete(recursive: true));
    final request = jsonEncode({
      'protocolVersion': '0.5.0',
      'rootPath': root.path,
      'sourcePaths': ['main.arb', 'lib.arb'],
      'sourceTexts': {
        'main.arb': _validProgram('س', '2'),
        'lib.arb': _validProgram('ص', '4'),
      },
      'mode': 'project',
    });
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/arabicc.dart',
      '--protocol',
    ], workingDirectory: Directory.current.path);
    process.stdin.writeln(request);
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;

    expect(exitCode, 0, reason: stderr);
    final response = jsonDecode(stdout) as Map<String, dynamic>;
    expect(response['protocolVersion'], '0.5.0');
    expect(response['success'], isTrue);
    expect((response['syntaxTree'] as Map)['kind'], 'project');
    expect((response['tokens'] as List), isNotEmpty);
    expect((response['threeAddressCode'] as List), isNotEmpty);
    final intermediateRepresentation =
        response['intermediateRepresentation'] as Map<String, dynamic>;
    expect(intermediateRepresentation['kind'], 'project');
    expect(intermediateRepresentation['files'], isNotEmpty);
  });

  test('CLI resolves project procedures across source files', () async {
    final root = await Directory.systemTemp.createTemp('arabicc-project-');
    addTearDown(() => root.delete(recursive: true));
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/arabicc.dart',
      '--protocol',
    ], workingDirectory: Directory.current.path);
    process.stdin.writeln(
      jsonEncode({
        'protocolVersion': '0.5.0',
        'rootPath': root.path,
        'sourcePaths': ['main.arb', 'lib.arb'],
        'sourceTexts': {
          'main.arb': '''برنامج رئيسي {
متغير س: صحيح;
س = 3;
اطبع_قيمة(س);
}.''',
          'lib.arb': '''برنامج مكتبة {
اجراء اطبع_قيمة(بالقيمة قيمة: صحيح)؛ {
اطبع(قيمة);
};
}.''',
        },
        'mode': 'project',
      }),
    );
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;

    expect(exitCode, 0, reason: stderr);
    final response = jsonDecode(stdout) as Map<String, dynamic>;
    expect(response['success'], isTrue);
    expect(response['diagnostics'], isEmpty);
    expect(response['executionOutput'], ['3']);
    final intermediateRepresentation =
        response['intermediateRepresentation'] as Map<String, dynamic>;
    expect(intermediateRepresentation['kind'], 'project');
    expect(intermediateRepresentation['files'], isNotEmpty);
  });

  test('CLI builds a dart-native artifact when requested', () async {
    final root = await Directory.systemTemp.createTemp('arabicc-artifact-');
    addTearDown(() => root.delete(recursive: true));
    final artifactDirectory = Directory(
      '${root.path}${Platform.pathSeparator}build',
    );
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/arabicc.dart', '--protocol'],
      workingDirectory: Directory.current.path,
      environment: {
        ...Platform.environment,
        'DART_EXECUTABLE': Platform.resolvedExecutable,
      },
    );
    process.stdin.writeln(
      jsonEncode({
        'protocolVersion': '0.5.0',
        'rootPath': root.path,
        'sourcePaths': ['main.arb'],
        'sourceTexts': {
          'main.arb': '''برنامج رئيسي {
متغير س: صحيح;
س = 2 + 3;
اطبع(س);
}.''',
        },
        'mode': 'active',
        'entryPath': 'main.arb',
        'target': 'dart-native',
        'artifactDirectory': artifactDirectory.path,
      }),
    );
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;

    expect(exitCode, 0, reason: stderr);
    final response = jsonDecode(stdout) as Map<String, dynamic>;
    expect(response['success'], isTrue);
    final artifacts = response['artifacts'] as List;
    expect(artifacts, hasLength(1));
    expect(File(artifacts.single as String).existsSync(), isTrue);
    final artifactProcess = await Process.run(artifacts.single as String, []);
    expect(artifactProcess.exitCode, 0);
    expect(artifactProcess.stdout.toString().trim(), '5');
  });

  test('CLI returns a protocol diagnostic for malformed JSON', () async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/arabicc.dart',
      '--protocol',
    ], workingDirectory: Directory.current.path);
    process.stdin.writeln('{not-json');
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    await process.stderr.drain();
    final exitCode = await process.exitCode;

    expect(exitCode, 64);
    final response = jsonDecode(stdout) as Map<String, dynamic>;
    expect(response['success'], isFalse);
    expect((response['diagnostics'] as List).single['phase'], 'protocol');
  });

  test('CLI returns Arabic completion suggestions', () async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/arabicc.dart',
      '--assist',
    ], workingDirectory: Directory.current.path);
    process.stdin.writeln(
      jsonEncode({
        'protocolVersion': '0.5.0',
        'requestType': 'assist',
        'sourcePath': 'main.arb',
        'sourceText': 'مت',
        'offset': 2,
        'action': 'completion',
      }),
    );
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    await process.stderr.drain();
    final exitCode = await process.exitCode;

    expect(exitCode, 0);
    final response = jsonDecode(stdout) as Map<String, dynamic>;
    expect(response['requestType'], 'assist');
    expect(response['action'], 'completion');
    expect(
      (response['items'] as List).map((item) => (item as Map)['label']),
      contains('متغير'),
    );
  });

  test('CLI returns contextual Arabic help', () async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/arabicc.dart',
      '--assist',
    ], workingDirectory: Directory.current.path);
    process.stdin.writeln(
      jsonEncode({
        'protocolVersion': '0.5.0',
        'requestType': 'assist',
        'sourcePath': 'main.arb',
        'sourceText': 'برنامج ',
        'offset': 8,
        'action': 'help',
      }),
    );
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    await process.stderr.drain();
    final exitCode = await process.exitCode;

    expect(exitCode, 0);
    final response = jsonDecode(stdout) as Map<String, dynamic>;
    expect(response['action'], 'help');
    expect((response['help'] as Map)['keyword'], 'برنامج');
  });
}

String _validProgram(String name, String value) =>
    '''برنامج اختبار {
  متغير $name: صحيح;
  $name = $value;
  اطبع($name);
}.''';
