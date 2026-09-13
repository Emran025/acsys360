import 'dart:io';

import '../repositories_impl/process_compiler_repository_impl.dart';

ProcessCompilerRepository createCompilerRepository() {
  final compilerName = Platform.isWindows ? 'arabicc.exe' : 'arabicc';
  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  final roots = <String>[];

  void addRoot(String path) {
    if (!roots.contains(path)) roots.add(path);
  }

  var current = Directory.current;
  for (var level = 0; level < 8; level++) {
    addRoot(current.path);
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }

  current = Directory(executableDirectory);
  for (var level = 0; level < 5; level++) {
    addRoot(current.path);
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }

  final candidates = <String>[
    for (final root in roots) ...[
      [root, 'compiler', compilerName].join(Platform.pathSeparator),
      [
        root,
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
        'compiler',
        compilerName,
      ].join(Platform.pathSeparator),
      [
        root,
        'build',
        'windows',
        'x64',
        'runner',
        'Debug',
        'compiler',
        compilerName,
      ].join(Platform.pathSeparator),
      [
        root,
        'packages',
        'compiler_c',
        'build',
        'Release',
        compilerName,
      ].join(Platform.pathSeparator),
      [
        root,
        'packages',
        'compiler_c',
        'build',
        compilerName,
      ].join(Platform.pathSeparator),
    ],
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return ProcessCompilerRepository(
        executable: candidate,
        arguments: const ['--protocol'],
        processWorkingDirectory: roots.first,
      );
    }
  }

  return ProcessCompilerRepository(
    executable: compilerName,
    arguments: const ['--protocol'],
    processWorkingDirectory: roots.first,
  );
}
