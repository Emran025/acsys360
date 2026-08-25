import 'dart:async';
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

/// حد البنية التحتية بين محرر Flutter والمترجم التنفيذي عبر JSON فقط.
class ProcessCompilerRepository
    implements CompilerRepository, AssistRepository {
  final String executable;
  final List<String> arguments;
  final CompilationMode mode;
  final String? processWorkingDirectory;
  final CompilerProcessStarter startProcess;
  final Duration processTimeout;

  const ProcessCompilerRepository({
    required this.executable,
    this.arguments = const ['--protocol'],
    this.mode = CompilationMode.project,
    this.processWorkingDirectory,
    this.startProcess = Process.start,
    this.processTimeout = const Duration(seconds: 30),
  });

  @override
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
    String target = 'none',
    String? artifactDirectory,
    CompilationMode? mode,
  }) async {
    if (sourcePath.isEmpty) {
      return _processFailure('لا يوجد ملف للترجمة', -1);
    }

    final effectiveMode = mode ?? this.mode;
    final requestDocuments = effectiveMode == CompilationMode.active
        ? documents.where((document) => document.path == sourcePath)
        : documents;
    final sourcePaths = effectiveMode == CompilationMode.active
        ? <String>[sourcePath]
        : <String>{
            for (final document in requestDocuments) document.path,
            sourcePath,
          }.toList();
    final sourceTexts = <String, String>{
      for (final document in requestDocuments) document.path: document.text,
    };
    final request = CompilationRequest(
      rootPath: rootPath,
      sourcePaths: sourcePaths,
      sourceTexts: sourceTexts,
      mode: effectiveMode,
      entryPath: sourcePath,
      target: target,
      artifactDirectory: artifactDirectory,
    );

    try {
      final process = await startProcess(
        executable,
        arguments,
        workingDirectory: processWorkingDirectory ?? rootPath,
      ).timeout(processTimeout);
      process.stdin.writeln(jsonEncode(request.toJson()));
      await process.stdin.close();
      final completed = await _collect(process);
      final output = completed.stdout;
      final errorOutput = completed.stderr;
      final exitCode = completed.exitCode;
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
    } on TimeoutException {
      return _processFailure(
        'تجاوز المترجم حد الانتظار (${processTimeout.inSeconds} ثانية)',
        -2,
      );
    } on FormatException catch (error) {
      return _processFailure(error.message, -1);
    } on Object catch (error) {
      return _processFailure(error.toString(), -1);
    }
  }

  @override
  Future<AssistResponse> complete({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
    List<String> symbols = const [],
  }) => _assist(
    rootPath: rootPath,
    request: AssistRequest(
      sourcePath: sourcePath,
      sourceText: sourceText,
      offset: offset,
      action: AssistAction.completion,
      symbols: symbols,
    ),
  );

  @override
  Future<AssistResponse> help({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
  }) => _assist(
    rootPath: rootPath,
    request: AssistRequest(
      sourcePath: sourcePath,
      sourceText: sourceText,
      offset: offset,
      action: AssistAction.help,
    ),
  );

  Future<AssistResponse> _assist({
    required String rootPath,
    required AssistRequest request,
  }) async {
    try {
      final process = await startProcess(
        executable,
        _assistArguments,
        workingDirectory: processWorkingDirectory ?? rootPath,
      ).timeout(processTimeout);
      process.stdin.writeln(jsonEncode(request.toJson()));
      await process.stdin.close();
      final completed = await _collect(process);
      final output = completed.stdout;
      final errorOutput = completed.stderr;
      final exitCode = completed.exitCode;
      if (output.trim().isEmpty) {
        throw FormatException(
          errorOutput.isEmpty
              ? 'فشل تشغيل خدمة المساعدة ($exitCode)'
              : errorOutput,
        );
      }
      final decoded = jsonDecode(output);
      if (decoded is! Map) {
        throw const FormatException('استجابة المساعدة ليست كائن JSON');
      }
      return AssistResponse.fromJson(Map<String, dynamic>.from(decoded));
    } on TimeoutException {
      throw FormatException(
        'تجاوزت خدمة المساعدة حد الانتظار (${processTimeout.inSeconds} ثانية)',
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('تعذر تشغيل خدمة المساعدة: $error');
    }
  }

  Future<_ProcessResult> _collect(Process process) async {
    try {
      final result = await Future.wait<Object?>([
        process.stdout.transform(utf8.decoder).join(),
        process.stderr.transform(utf8.decoder).join(),
        process.exitCode,
      ]).timeout(processTimeout);
      return _ProcessResult(
        stdout: result[0]! as String,
        stderr: result[1]! as String,
        exitCode: result[2]! as int,
      );
    } on TimeoutException {
      process.kill();
      rethrow;
    }
  }

  List<String> get _assistArguments {
    final protocolIndex = arguments.lastIndexOf('--protocol');
    if (protocolIndex == -1) return const ['--assist'];
    return [
      for (var index = 0; index < arguments.length; index++)
        index == protocolIndex ? '--assist' : arguments[index],
    ];
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
    'executionOutput': const [],
    'artifacts': const [],
  };
}

class _ProcessResult {
  final String stdout;
  final String stderr;
  final int exitCode;

  const _ProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
}
