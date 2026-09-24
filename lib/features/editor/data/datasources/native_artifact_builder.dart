import 'dart:io';

class NativeArtifactBuilder {
  const NativeArtifactBuilder();

  Future<String> build({
    required String assembly,
    required String outputDirectory,
    required String baseName,
  }) async {
    final directory = Directory(outputDirectory);
    await directory.create(recursive: true);
    final stem = _safeStem(baseName);
    final assemblyPath = _join(outputDirectory, '$stem.asm');
    final objectPath = _join(
      outputDirectory,
      Platform.isWindows ? '$stem.obj' : '$stem.o',
    );
    final executablePath = _join(
      outputDirectory,
      Platform.isWindows ? '$stem.exe' : stem,
    );
    await File(assemblyPath).writeAsString(assembly);

    final format = Platform.isWindows
        ? 'win64'
        : Platform.isMacOS
        ? 'macho64'
        : 'elf64';
    await _run('nasm', ['-f', format, assemblyPath, '-o', objectPath]);

    final linkerArguments = <String>[objectPath, '-o', executablePath];
    if (!Platform.isWindows && !Platform.isMacOS) {
      linkerArguments.insert(0, '-no-pie');
    }
    await _run('gcc', linkerArguments);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', executablePath]);
    }
    return executablePath;
  }

  Future<void> _run(String executable, List<String> arguments) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      final output = '${result.stdout}\n${result.stderr}'.trim();
      throw ProcessException(
        executable,
        arguments,
        output.isEmpty ? 'فشل بناء artifact التنفيذي' : output,
        result.exitCode,
      );
    }
  }

  String _safeStem(String value) {
    final fileName = value.split(RegExp(r'[\\/]')).last;
    final stem = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final safe = stem.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safe.isEmpty ? 'program' : safe;
  }

  String _join(String directory, String name) =>
      '$directory${Platform.pathSeparator}$name';
}
