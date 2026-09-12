import 'dart:io';

import '../repositories_impl/process_compiler_repository_impl.dart';

ProcessCompilerRepository createCompilerRepository() {
  final compilerName = Platform.isWindows ? 'arabicc.exe' : 'arabicc';
  final bundledPath = [
    File(Platform.resolvedExecutable).parent.path,
    'compiler',
    compilerName,
  ].join(Platform.pathSeparator);
  if (File(bundledPath).existsSync()) {
    return ProcessCompilerRepository(
      executable: bundledPath,
      arguments: const ['--protocol'],
      processWorkingDirectory: File(Platform.resolvedExecutable).parent.path,
    );
  }
  final localBuildPath = [
    Directory.current.path,
    'packages',
    'compiler_c',
    'build',
    compilerName,
  ].join(Platform.pathSeparator);
  if (File(localBuildPath).existsSync()) {
    return ProcessCompilerRepository(
      executable: localBuildPath,
      arguments: const ['--protocol'],
      processWorkingDirectory: Directory.current.path,
    );
  }
  return ProcessCompilerRepository(
    executable: compilerName,
    arguments: const ['--protocol'],
    processWorkingDirectory: Directory.current.path,
  );
}
