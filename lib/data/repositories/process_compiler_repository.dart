import 'dart:convert';
import 'dart:io';

import 'package:compiler_contracts/compiler_contracts.dart';

import '../../domain/entities/document.dart';
import '../../domain/repositories/workspace_repository.dart';

typedef CompilerProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

class ProcessCompilerRepository implements CompilerRepository {
  final String executable;
  final List<String> arguments;
  final CompilationMode mode;
  final String? processWorkingDirectory;
  final CompilerProcessStarter startProcess;

  const ProcessCompilerRepository({
    required this.executable,
    this.arguments = const ['--protocol'],
    this.mode = CompilationMode.project,
    this.processWorkingDirectory,
    this.startProcess = Process.start,
  });

  @override
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
  }) async {
    if (sourcePath.isEmpty) {
      return _processFailure('لا يوجد ملف للترجمة', -1);
    }

    final sourcePaths = <String>{
      for (final document in documents) document.path,
      sourcePath,
    }.toList();
    final sourceTexts = <String, String>{
      for (final document in documents) document.path: document.text,
    };
    final request = CompilationRequest(
      rootPath: rootPath,
      sourcePaths: sourcePaths,
      sourceTexts: sourceTexts,
      mode: mode,
      entryPath: sourcePath,
    );

    try {
      final process = await startProcess(
        executable,
        arguments,
        workingDirectory: processWorkingDirectory ?? rootPath,
      );
      process.stdin.writeln(jsonEncode(request.toJson()));
      await process.stdin.close();
      final output = await process.stdout.transform(utf8.decoder).join();
      final errorOutput = await process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      if (output.trim().isEmpty) {
        return _processFailure(errorOutput, exitCode);
      }
      final decoded = jsonDecode(output);
      if (decoded is! Map) {
        return _processFailure('استجابة المترجم ليست كائن JSON', exitCode);
      }
      final response = CompilationResponse.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return Map<String, dynamic>.from(response.toJson());
    } on FormatException catch (error) {
      return _processFailure(error.message, -1);
    } on Object catch (error) {
      return _processFailure(error.toString(), -1);
    }
  }

  Map<String, dynamic> _processFailure(String message, int exitCode) => {
    'protocolVersion': protocolVersion,
    'success': false,
    'diagnostics': [
      {
        'severity': 'error',
        'phase': 'process',
        'code': exitCode == -1 ? 'P004' : 'P005',
        'message': message.isEmpty ? 'فشل تشغيل المترجم' : message,
        'span': null,
      },
    ],
    'tokens': const [],
    'syntaxTree': null,
    'symbolTable': const [],
    'threeAddressCode': const [],
    'assembly': '',
    'artifacts': const [],
  };
}
