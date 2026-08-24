import 'dart:convert';
import 'dart:io';

import '../lib/arabic_compiler.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('الاستخدام: arabicc <source-file>');
    exitCode = 64;
    return;
  }

  final file = File(arguments.single);
  if (!file.existsSync()) {
    stderr.writeln('الملف غير موجود: ${file.path}');
    exitCode = 66;
    return;
  }

  final result = Compiler().compile(file.readAsStringSync());
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
  exitCode = result.success ? 0 : 1;
}
