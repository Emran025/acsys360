import 'dart:io';

import '../repositories_impl/process_compiler_repository_impl.dart';

ProcessCompilerRepository createCompilerRepository() {
  final compilerName = Platform.isWindows ? 'arabicc.exe' : 'arabicc';
  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  final root = Directory.current.path;
  final candidates = <String>[
    [executableDirectory, 'compiler', compilerName].join(Platform.pathSeparator),
    [root, 'build', 'windows', 'x64', 'runner', 'Release', 'compiler', compilerName].join(Platform.pathSeparator),
    [root, 'build', 'windows', 'x64', 'runner', 'Debug', 'compiler', compilerName].join(Platform.pathSeparator),
    [root, 'packages', 'compiler_c', 'build', 'Release', compilerName].join(Platform.pathSeparator),
    [root, 'packages', 'compiler_c', 'build', compilerName].join(Platform.pathSeparator),
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return ProcessCompilerRepository(
        executable: candidate,
        arguments: const ['--protocol'],
        processWorkingDirectory: root,
      );
    }
  }
  return ProcessCompilerRepository(
    executable: compilerName,
    arguments: const ['--protocol'],
    processWorkingDirectory: Directory.current.path,
  );
}
