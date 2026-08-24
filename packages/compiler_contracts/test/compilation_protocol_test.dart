import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:test/test.dart';

void main() {
  const span = SourceSpan(
    sourcePath: 'src/main.arb',
    offset: 12,
    line: 2,
    column: 4,
    length: 6,
  );

  test('round-trips a multi-file compilation request', () {
    const request = CompilationRequest(
      rootPath: '/workspace/project',
      sourcePaths: [
        '/workspace/project/main.arb',
        '/workspace/project/lib.arb',
      ],
      sourceTexts: {
        '/workspace/project/main.arb': 'برنامج رئيسي {}.',
        '/workspace/project/lib.arb': 'برنامج مساعد {}.',
      },
      mode: CompilationMode.project,
      entryPath: '/workspace/project/main.arb',
    );

    final decoded = CompilationRequest.fromJson(
      Map<String, dynamic>.from(request.toJson()),
    );

    expect(decoded.rootPath, request.rootPath);
    expect(decoded.sourcePaths, request.sourcePaths);
    expect(decoded.sourceTexts, request.sourceTexts);
    expect(decoded.mode, CompilationMode.project);
    expect(decoded.entryPath, request.entryPath);
  });

  test('round-trips response stages and typed diagnostics', () {
    const response = CompilationResponse(
      success: false,
      diagnostics: [
        Diagnostic(
          severity: DiagnosticSeverity.error,
          phase: 'parser',
          code: 'E100',
          message: 'تعليمة غير مكتملة',
          span: span,
        ),
      ],
      tokens: [ProtocolToken(kind: 'keyword', lexeme: 'برنامج', span: span)],
      syntaxTree: {'kind': 'program'},
      symbols: [
        SymbolRecord(name: 'س', kind: 'variable', type: 'صحيح', span: span),
      ],
      threeAddressCode: ['س := 1'],
      assembly: 'MOV R0, 1',
      artifacts: ['build/program.exe'],
    );

    final json = Map<String, dynamic>.from(response.toJson());
    final decoded = CompilationResponse.fromJson(json);

    expect(decoded.success, isFalse);
    expect(decoded.diagnostics.single.span?.sourcePath, 'src/main.arb');
    expect(decoded.diagnostics.single.code, 'E100');
    expect(decoded.tokens.single.lexeme, 'برنامج');
    expect(decoded.symbols.single.type, 'صحيح');
    expect(decoded.threeAddressCode, ['س := 1']);
    expect(decoded.artifacts, ['build/program.exe']);
  });

  test('rejects unsupported protocol versions', () {
    expect(
      () => CompilationRequest.fromJson({
        'protocolVersion': '9.9.9',
        'rootPath': '/workspace/project',
        'sourcePaths': ['/workspace/project/main.arb'],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an empty source list', () {
    expect(
      () => CompilationRequest.fromJson({
        'protocolVersion': protocolVersion,
        'rootPath': '/workspace/project',
        'sourcePaths': [],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
