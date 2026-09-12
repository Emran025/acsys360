import 'dart:async';
import 'dart:io';

import 'package:acsys360/features/editor/data/repositories_impl/process_compiler_repository_impl.dart';
import 'package:acsys360/features/editor/domain/entities/document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'communicates with the compiled C arabicc binary over protocol',
    () async {
      final cExecutable =
          '${Directory.current.path}/packages/compiler_c/build/arabicc.exe';
      if (!File(cExecutable).existsSync()) return;

      final repository = ProcessCompilerRepository(
        executable: cExecutable,
        arguments: const ['--protocol'],
        processWorkingDirectory: Directory.current.path,
      );

      final response = await repository.compile(
        rootPath: Directory.current.path,
        sourcePath: '${Directory.current.path}/main.arb',
        documents: [
          Document(
            path: '${Directory.current.path}/main.arb',
            text: 'برنامج اختبار {}.',
          ),
        ],
      );

      expect(response['protocolVersion'], '0.5.0');
      expect(response['success'], isTrue);
      expect(response['diagnostics'], isEmpty);
    },
  );

  test(
    'compiles a program through the C binary protocol (multi-statement)',
    () async {
      final cExecutable =
          '${Directory.current.path}/packages/compiler_c/build/arabicc.exe';
      if (!File(cExecutable).existsSync()) return;

      final repository = ProcessCompilerRepository(
        executable: cExecutable,
        arguments: const ['--protocol'],
        processWorkingDirectory: Directory.current.path,
      );

      final response = await repository.compile(
        rootPath: Directory.current.path,
        sourcePath: '${Directory.current.path}/main.arb',
        documents: [
          Document(
            path: '${Directory.current.path}/main.arb',
            text: _validProgram('س', '42'),
          ),
        ],
      );

      expect(response['protocolVersion'], '0.5.0');
      expect(response['success'], isTrue);
      expect(response['intermediateRepresentation'], isA<Map>());
    },
  );

  test(
    'returns a process diagnostic when compiler startup times out',
    () async {
      final pending = Completer<Process>();
      final repository = ProcessCompilerRepository(
        executable: 'arabicc',
        processTimeout: const Duration(milliseconds: 1),
        startProcess: (executable, arguments, {workingDirectory}) =>
            pending.future,
      );

      final response = await repository.compile(
        rootPath: '/workspace',
        sourcePath: '/workspace/main.arb',
        documents: const [Document(path: '/workspace/main.arb', text: 'س')],
      );

      expect(response['success'], isFalse);
      final diagnostic = (response['diagnostics'] as List).single as Map;
      expect(diagnostic['phase'], 'process');
      expect(diagnostic['code'], 'P005');
      expect(diagnostic['message'], contains('حد الانتظار'));
    },
  );
}

String _validProgram(String name, String value) =>
    '''برنامج اختبار {
  متغير $name: صحيح;
  $name = $value;
  اطبع($name);
}.''';
