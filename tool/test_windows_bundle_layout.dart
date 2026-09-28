import 'dart:io';

void main() {
  final root = Directory.systemTemp.createTempSync('acsys360-windows-install-');
  try {
    final app = Directory('${root.path}${Platform.pathSeparator}acsys360')
      ..createSync(recursive: true);
    final compilerDirectory = Directory(
      '${app.path}${Platform.pathSeparator}compiler',
    )..createSync(recursive: true);
    final compiler = File(
      '${compilerDirectory.path}${Platform.pathSeparator}arabicc.exe',
    )..writeAsStringSync('fake compiler');
    final bin = Directory(
      '${app.path}${Platform.pathSeparator}toolchain${Platform.pathSeparator}windows${Platform.pathSeparator}bin',
    )..createSync(recursive: true);
    final gcc = File('${bin.path}${Platform.pathSeparator}gcc.exe')
      ..writeAsStringSync('fake gcc');
    final nasm = File('${bin.path}${Platform.pathSeparator}nasm.exe')
      ..writeAsStringSync('fake nasm');

    final expectedToolchain =
        '${app.path}${Platform.pathSeparator}toolchain${Platform.pathSeparator}windows${Platform.pathSeparator}bin';
    final resolvedCompiler = File(
      '${app.path}${Platform.pathSeparator}compiler${Platform.pathSeparator}arabicc.exe',
    );
    if (resolvedCompiler.path != compiler.path ||
        !gcc.existsSync() ||
        !nasm.existsSync() ||
        expectedToolchain != bin.path) {
      throw StateError('Installed Windows bundle topology mismatch');
    }

    final iss = File('tool/packaging/acsys360-windows.iss').readAsStringSync();
    if (!iss.contains('Source: "{#SourceDir}\\*"') ||
        !iss.contains('recursesubdirs')) {
      throw StateError('Inno Setup does not recursively install toolchain');
    }
    stdout.writeln('[OK] Windows install topology simulation passed:');
    stdout.writeln('     compiler=${resolvedCompiler.path}');
    stdout.writeln('     ACSYS360_TOOLCHAIN_DIR=$expectedToolchain');
    stdout.writeln('     gcc=${gcc.path}');
    stdout.writeln('     nasm=${nasm.path}');
  } finally {
    root.deleteSync(recursive: true);
  }
}
