import 'dart:io';

import '../repositories_impl/process_compiler_repository_impl.dart';

ProcessCompilerRepository createCompilerRepository() {
  final compilerName = Platform.isWindows ? 'arabicc.exe' : 'arabicc';
  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  String join(List<String> parts) => parts.join(Platform.pathSeparator);

  final toolchainDirectory = join([
    executableDirectory,
    'toolchain',
    Platform.isWindows ? 'windows' : (Platform.isMacOS ? 'macos' : 'linux'),
    'bin',
  ]);
  final toolchainEnvironment = {
    'ACSYS360_TOOLCHAIN_DIR': toolchainDirectory,
    'PATH': [
      toolchainDirectory,
      Platform.environment['PATH'] ?? '',
    ].join(Platform.isWindows ? ';' : ':'),
  };
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
  for (var level = 0; level < 8; level++) {
    addRoot(current.path);
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }

  // Search all source-tree compiler locations before any bundled Release copy.
  // A stale bundled executable must never shadow the freshly built compiler.
  final developmentCandidates = <String>[
    for (final root in roots) ...[
      join([root, 'packages', 'compiler_c', 'build', 'Release', compilerName]),
      join([root, 'packages', 'compiler_c', 'build', compilerName]),
    ],
  ];
  final bundledCandidates = <String>[
    for (final root in roots) ...[
      join([root, 'compiler', compilerName]),
      join([
        root,
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
        'compiler',
        compilerName,
      ]),
      join([
        root,
        'build',
        'windows',
        'x64',
        'runner',
        'Debug',
        'compiler',
        compilerName,
      ]),
    ],
  ];

  for (final candidate in [...developmentCandidates, ...bundledCandidates]) {
    if (File(candidate).existsSync()) {
      return ProcessCompilerRepository(
        executable: candidate,
        arguments: const ['--protocol'],
        processWorkingDirectory: roots.first,
        environment: toolchainEnvironment,
      );
    }
  }

  return ProcessCompilerRepository(
    executable: compilerName,
    arguments: const ['--protocol'],
    processWorkingDirectory: roots.first,
    environment: toolchainEnvironment,
  );
}
