import 'dart:convert';
import 'dart:io';

import '../../domain/entities/compilation_result.dart';
import '../../domain/entities/document.dart';
import '../../domain/repositories/workspace_repository.dart';

class ProcessCompilerRepository implements CompilerRepository {
  final String executable;
  final List<String> arguments;

  const ProcessCompilerRepository({
    required this.executable,
    this.arguments = const [],
  });

  @override
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
  }) async {
    final active = sourcePath;
    if (active.isEmpty) {
      return const CompilationResult(
        success: false,
        payload: {'diagnostics': [], 'message': 'لا يوجد ملف للترجمة'},
      ).payload;
    }

    final process = await Process.run(executable, [
      ...arguments,
      active,
    ], workingDirectory: rootPath);
    final output = process.stdout.toString().trim();
    if (output.isEmpty) {
      return CompilationResult(
        success: false,
        payload: {
          'diagnostics': [
            {'phase': 'process', 'message': process.stderr.toString().trim()},
          ],
        },
      ).payload;
    }
    return jsonDecode(output) as Map<String, dynamic>;
  }
}
