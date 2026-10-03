import 'dart:io';

import 'package:acsys360/features/editor/data/repositories_impl/process_compiler_repository_impl.dart';
import 'package:acsys360/features/editor/domain/entities/document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('acsys360-process-');
  });

  tearDown(() => directory.delete(recursive: true));

  test('returns a process diagnostic when source path is empty', () async {
    final result = await const ProcessCompilerRepository(
      executable: 'unused',
    ).compile(rootPath: directory.path, sourcePath: '', documents: const []);
    expect(result.success, isFalse);
    expect(result.diagnostics.single.code, 'P004');
  });

  test(
    'maps valid compile and assist responses from an isolated process',
    () async {
      final compileScript = await _script('''#!/bin/sh
cat >/dev/null
printf '%s' '{"protocolVersion":"0.5.0","success":true,"diagnostics":[],"tokens":[],"syntaxTree":null,"symbolTable":[],"threeAddressCode":[],"assembly":"","executionOutput":[],"artifacts":[],"intermediateRepresentation":null}'
''');
      final repository = ProcessCompilerRepository(
        executable: compileScript.path,
        processWorkingDirectory: directory.path,
      );
      final result = await repository.compile(
        rootPath: directory.path,
        sourcePath: '${directory.path}/main.arb',
        documents: [
          Document(path: '${directory.path}/main.arb', text: 'س = 1;'),
        ],
      );
      expect(result.success, isTrue);

      final assistScript = await _script('''#!/bin/sh
cat >/dev/null
if [ "\$1" = "--assist" ]; then
  printf '%s' '{"protocolVersion":"0.5.0","success":true,"requestType":"assist","action":"completion","expected":"","prefix":"","replaceStart":0,"replaceLength":0,"items":[],"help":null}'
else
  printf '%s' '{}'
fi
''');
      final assistRepository = ProcessCompilerRepository(
        executable: assistScript.path,
        processWorkingDirectory: directory.path,
      );
      final completion = await assistRepository.complete(
        rootPath: directory.path,
        sourcePath: 'main.arb',
        sourceText: 'س',
        offset: 1,
      );
      expect(completion.items, isEmpty);
    },
  );

  test(
    'converts malformed compiler output and startup errors to failures',
    () async {
      final invalid = await _script('''#!/bin/sh
cat >/dev/null
printf '%s' 'not-json'
''');
      final result =
          await ProcessCompilerRepository(
            executable: invalid.path,
            processWorkingDirectory: directory.path,
          ).compile(
            rootPath: directory.path,
            sourcePath: 'main.arb',
            documents: const [Document(path: 'main.arb', text: 'س')],
          );
      expect(result.success, isFalse);
      expect(result.diagnostics.single.code, 'P004');

      final missing =
          await ProcessCompilerRepository(
            executable: '${directory.path}/missing',
          ).compile(
            rootPath: directory.path,
            sourcePath: 'main.arb',
            documents: const [Document(path: 'main.arb', text: 'س')],
          );
      expect(missing.success, isFalse);
      expect(missing.diagnostics.single.code, 'P004');
    },
  );
}

Future<File> _script(String body) async {
  final directory = await Directory.systemTemp.createTemp('acsys360-script-');
  final file = File('${directory.path}/compiler.sh');
  await file.writeAsString(body);
  await Process.run('chmod', ['+x', file.path]);
  return file;
}
