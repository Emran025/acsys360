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
    final runtime = File('${app.path}${Platform.pathSeparator}vcruntime140.dll')
      ..writeAsStringSync('fake runtime');

    final expectedToolchain =
        '${app.path}${Platform.pathSeparator}toolchain${Platform.pathSeparator}windows${Platform.pathSeparator}bin';
    final resolvedCompiler = File(
      '${app.path}${Platform.pathSeparator}compiler${Platform.pathSeparator}arabicc.exe',
    );
    if (resolvedCompiler.path != compiler.path ||
        !gcc.existsSync() ||
        !nasm.existsSync() ||
        !runtime.existsSync() ||
        expectedToolchain != bin.path) {
      throw StateError('Installed Windows bundle topology mismatch');
    }

    final iss = File('tool/packaging/acsys360-windows.iss').readAsStringSync();
    if (!iss.contains('Source: "{#SourceDir}\\*"') ||
        !iss.contains('recursesubdirs')) {
      throw StateError('Inno Setup does not recursively install toolchain');
    }
    final release = File('.github/workflows/release.yml').readAsStringSync();
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    if (!ci.contains('windows-build:') ||
        !ci.contains('Export MSYS2 toolchain for CTest') ||
        !ci.contains("steps.setup_msys2.outputs['msys2-location']") ||
        !ci.contains('GITHUB_PATH') ||
        !ci.contains(r'"/DOutputDir=$outputDir"') ||
        !ci.contains(
          r'Join-Path $outputDir "acsys360-windows-$version-setup-x64.exe"',
        ) ||
        !ci.contains('test_windows_installer.ps1') ||
        !ci.contains('bundle_windows_toolchain.ps1') ||
        !ci.contains('bundle_windows_vc_runtime.ps1') ||
        !release.contains('Export MSYS2 toolchain for CTest') ||
        !release.contains("steps.setup_msys2.outputs['msys2-location']") ||
        !release.contains('GITHUB_PATH') ||
        !release.contains('ctest --test-dir build -C Release') ||
        !release.contains('bundle_windows_toolchain.ps1') ||
        !release.contains('bundle_windows_vc_runtime.ps1') ||
        !release.contains('test_windows_installer.ps1') ||
        !release.contains('verify_compiler_bundle.dart --executable') ||
        !release.contains('--native')) {
      throw StateError('Windows release does not test compiler artifacts');
    }
    final cmake = File('packages/compiler_c/CMakeLists.txt').readAsStringSync();
    if (!cmake.contains('if(UNIX)') ||
        !cmake.contains('tests/native_3ac_smoke.sh')) {
      throw StateError('CMake registers a shell-only test on Windows');
    }
    final runtimeBundler = File(
      'tool/bundle_windows_vc_runtime.ps1',
    ).readAsStringSync();
    if (!runtimeBundler.contains('vcruntime140.dll') ||
        !runtimeBundler.contains('msvcp140.dll') ||
        !runtimeBundler.contains('compilerDirectory')) {
      throw StateError('Windows bundle does not include Visual C++ runtime');
    }
    final toolchainBundler = File(
      'tool/bundle_windows_toolchain.ps1',
    ).readAsStringSync();
    if (!toolchainBundler.contains('gcc.exe') ||
        !toolchainBundler.contains('nasm.exe') ||
        !toolchainBundler.contains('libkernel32.a')) {
      throw StateError('Windows bundle toolchain validation is incomplete');
    }
    stdout.writeln('[OK] Windows install topology simulation passed:');
    stdout.writeln('     compiler=${resolvedCompiler.path}');
    stdout.writeln('     ACSYS360_TOOLCHAIN_DIR=$expectedToolchain');
    stdout.writeln('     gcc=${gcc.path}');
    stdout.writeln('     nasm=${nasm.path}');
    stdout.writeln('     VC runtime=${runtime.path}');
  } finally {
    root.deleteSync(recursive: true);
  }
}
