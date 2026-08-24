import 'dart:convert';
import 'dart:io';

import '../../domain/entities/compilation_result.dart';
import '../../domain/entities/document.dart';
import '../../domain/repositories/workspace_repository.dart';

class ProcessCompilerRepository implements CompilerRepository {
  final String executable;
  const ProcessCompilerRepository({required this.executable});

  @override
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required List<Document> documents,
  }) async {
    final process = await Process.run(executable, [rootPath]);
    if (process.stdout.toString().trim().isEmpty) {
      return CompilationResult(
        success: false,
        payload: {
          'diagnostics': [
            {'phase': 'process', 'message': process.stderr.toString().trim()},
          ],
        },
      ).payload;
    }
    return jsonDecode(process.stdout.toString()) as Map<String, dynamic>;
  }
}
