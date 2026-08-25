import 'package:acsys360/domain/entities/document.dart';
import 'package:acsys360/domain/repositories/workspace_repository.dart';
import 'package:acsys360/domain/usecases/editor_language_server.dart';
import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters project diagnostics to the active source path', () async {
    final service = EditorLanguageServer(
      compiler: const DiagnosticCompiler(),
      assistant: const EmptyAssistRepository(),
    );

    final analysis = await service.analyze(
      rootPath: '/workspace',
      sourcePath: '/workspace/main.arb',
      documents: const [
        Document(path: '/workspace/main.arb', text: 'س = 1;'),
        Document(path: '/workspace/lib.arb', text: 'ص = 2;'),
      ],
      mode: CompilationMode.project,
    );

    expect(analysis.diagnostics, hasLength(1));
    expect(analysis.diagnostics.single.sourcePath, '/workspace/main.arb');
    expect(analysis.diagnostics.single.offset, 0);
  });
}

class DiagnosticCompiler implements CompilerRepository {
  const DiagnosticCompiler();

  @override
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
    String target = 'none',
    String? artifactDirectory,
    CompilationMode? mode,
  }) async => {
    'success': false,
    'diagnostics': [
      {
        'severity': 'error',
        'phase': 'syntax',
        'code': 'S001',
        'message': 'خطأ في الملف النشط',
        'span': {
          'sourcePath': '/workspace/main.arb',
          'offset': 0,
          'line': 1,
          'column': 1,
          'length': 1,
        },
      },
      {
        'severity': 'error',
        'phase': 'syntax',
        'code': 'S002',
        'message': 'خطأ في ملف آخر',
        'span': {
          'sourcePath': '/workspace/lib.arb',
          'offset': 0,
          'line': 1,
          'column': 1,
          'length': 1,
        },
      },
    ],
  };
}

class EmptyAssistRepository implements AssistRepository {
  const EmptyAssistRepository();

  @override
  Future<AssistResponse> complete({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
    List<String> symbols = const [],
  }) async => const AssistResponse(action: AssistAction.completion);

  @override
  Future<AssistResponse> help({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
  }) async => const AssistResponse(action: AssistAction.help);
}
