import 'package:compiler_contracts/compiler_contracts.dart';

import '../entities/compilation_result.dart';
import '../entities/document.dart';
import '../entities/editor_diagnostic.dart';
import '../repositories/workspace_repository.dart';
import 'arabic_language_service.dart';

class LanguageAnalysis {
  final CompilationResult compilation;
  final List<EditorDiagnostic> diagnostics;

  const LanguageAnalysis({
    required this.compilation,
    required this.diagnostics,
  });
}

class EditorLanguageServer {
  final CompilerRepository compiler;
  final AssistRepository assistant;
  final ArabicLanguageService diagnosticsService;

  const EditorLanguageServer({
    required this.compiler,
    required this.assistant,
    this.diagnosticsService = const ArabicLanguageService(),
  });

  Future<LanguageAnalysis> analyze({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
  }) async {
    final response = await compiler.compile(
      rootPath: rootPath,
      sourcePath: sourcePath,
      documents: documents,
    );
    final compilation = CompilationResult(
      success: response['success'] == true,
      payload: response,
    );
    final active = documents.firstWhere(
      (document) => document.path == sourcePath,
      orElse: () => Document(path: sourcePath, text: ''),
    );
    final rawDiagnostics = response['diagnostics'];
    final diagnostics = diagnosticsService
        .enrichDiagnostics(
          rawDiagnostics is List ? rawDiagnostics : const [],
          active.text,
        )
        .where(
          (diagnostic) =>
              diagnostic.sourcePath == null ||
              diagnostic.sourcePath == sourcePath,
        )
        .toList();
    return LanguageAnalysis(compilation: compilation, diagnostics: diagnostics);
  }

  Future<AssistResponse> complete({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
    List<String> symbols = const [],
  }) => assistant.complete(
    rootPath: rootPath,
    sourcePath: sourcePath,
    sourceText: sourceText,
    offset: offset,
    symbols: symbols,
  );

  Future<AssistResponse> help({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
  }) => assistant.help(
    rootPath: rootPath,
    sourcePath: sourcePath,
    sourceText: sourceText,
    offset: offset,
  );
}
