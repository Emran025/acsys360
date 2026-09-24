import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/repositories/workspace_repository.dart';

typedef NativeOutputHandler = void Function(String line);

class NativeArtifactRunner {
  const NativeArtifactRunner();

  Future<List<String>> run(
    String executable, {
    InputRequestHandler? onInputRequest,
    NativeOutputHandler? onOutput,
  }) async {
    final executableFile = File(executable).absolute;
    if (!executableFile.existsSync()) {
      throw StateError(
        'ملف executable الناتج غير موجود: ${executableFile.path}',
      );
    }
    final process = await Process.start(
      executableFile.path,
      const [],
      workingDirectory: executableFile.parent.path,
      environment: _runtimeEnvironment(),
    );
    final output = <String>[];
    final stderr = StringBuffer();
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .listen(stderr.write);

    try {
      await for (final line
          in process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final request = _inputRequest(line);
        if (request != null) {
          if (onInputRequest == null) {
            process.kill();
            throw StateError(
              'البرنامج الهدف طلب إدخالًا ولا توجد نافذة تنفيذ متصلة',
            );
          }
          final value = await onInputRequest(request);
          if (value == null) {
            process.kill();
            throw StateError('أُلغي إدخال البرنامج الهدف');
          }
          process.stdin.writeln(value);
          await process.stdin.flush();
        } else {
          output.add(line);
          onOutput?.call(line);
        }
      }
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        final details = stderr.toString().trim();
        throw ProcessException(
          executable,
          const [],
          details.isEmpty ? 'فشل تنفيذ البرنامج الهدف' : details,
          exitCode,
        );
      }
      return output;
    } finally {
      await stderrSubscription.cancel();
      await process.stdin.close();
    }
  }

  InputRequest? _inputRequest(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map && decoded['requestType'] == 'input') {
        final name = decoded['name'];
        final type = decoded['type'];
        if (name is String && name.isNotEmpty) {
          return InputRequest(
            name: name,
            type: type is String && type.isNotEmpty ? type : 'غير معروف',
          );
        }
      }
    } on FormatException {
      // Normal program output is not JSON and is returned to the execution tab.
    }
    return null;
  }

  Map<String, String> _runtimeEnvironment() {
    final environment = Map<String, String>.from(Platform.environment);
    if (Platform.isWindows) {
      final paths = [
        r'C:\msys64\ucrt64\bin',
        r'C:\msys64\mingw64\bin',
        environment['Path'] ?? '',
      ];
      environment['Path'] = paths.where((path) => path.isNotEmpty).join(';');
    }
    return environment;
  }
}
