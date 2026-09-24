import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/repositories/workspace_repository.dart';

class NativeArtifactRunner {
  const NativeArtifactRunner();

  Future<List<String>> run(
    String executable, {
    InputRequestHandler? onInputRequest,
  }) async {
    final process = await Process.start(executable, const []);
    final output = <String>[];
    final stderr = StringBuffer();
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .listen(stderr.write);

    try {
      await for (final line in process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final request = _inputRequest(line);
        if (request != null) {
          if (onInputRequest == null) {
            process.kill();
            throw StateError('البرنامج الهدف طلب إدخالًا ولا توجد نافذة تنفيذ متصلة');
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

  String? _inputRequest(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map && decoded['requestType'] == 'input') {
        final name = decoded['name'];
        return name is String && name.isNotEmpty ? name : 'input';
      }
    } on FormatException {
      // Normal program output is not JSON and is returned to the execution tab.
    }
    return null;
  }
}
