import 'dart:convert';
import 'dart:io';

import 'package:compiler_contracts/compiler_contracts.dart';

import '../lib/arabic_compiler.dart' hide Diagnostic;

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 && arguments.single != '--protocol') {
    await _runLegacy(arguments.single);
    return;
  }
  if (arguments.length > 1 ||
      (arguments.length == 1 && arguments.single != '--protocol')) {
    stderr.writeln('الاستخدام: arabicc <source-file> أو arabicc --protocol');
    exitCode = 64;
    return;
  }
  await _runProtocol();
}

Future<void> _runLegacy(String sourcePath) async {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    stderr.writeln('الملف غير موجود: ${file.path}');
    exitCode = 66;
    return;
  }
  final result = Compiler().compile(await file.readAsString());
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
  exitCode = result.success ? 0 : 1;
}

Future<void> _runProtocol() async {
  final payload = await stdin.transform(utf8.decoder).join();
  if (payload.trim().isEmpty) {
    await _writeResponse(_failure('protocol', 'P001', 'لم يصل طلب JSON'));
    exitCode = 64;
    return;
  }

  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      throw const FormatException('يجب أن يكون الطلب كائن JSON');
    }
    final request = CompilationRequest.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    final response = await _compileRequest(request);
    await _writeResponse(response);
    exitCode = response.success ? 0 : 1;
  } on FormatException catch (error) {
    await _writeResponse(_failure('protocol', 'P002', error.message));
    exitCode = 64;
  } on Object catch (error) {
    await _writeResponse(_failure('protocol', 'P003', error.toString()));
    exitCode = 70;
  }
}

Future<CompilationResponse> _compileRequest(CompilationRequest request) async {
  final paths =
      request.mode == CompilationMode.active && request.entryPath != null
      ? [request.entryPath!]
      : request.sourcePaths;
  final diagnostics = <Diagnostic>[];
  final tokens = <ProtocolToken>[];
  final symbols = <SymbolRecord>[];
  final tac = <String>[];
  final trees = <Map<String, Object?>>[];
  var compiledFiles = 0;

  for (final sourcePath in paths) {
    final file = _resolveFile(request.rootPath, sourcePath);
    final inlineSource = request.sourceTexts[sourcePath];
    if (inlineSource == null && !file.existsSync()) {
      diagnostics.add(
        Diagnostic(
          severity: DiagnosticSeverity.error,
          phase: 'io',
          code: 'IO001',
          message: 'الملف غير موجود: ${file.path}',
          span: SourceSpan(
            sourcePath: sourcePath,
            offset: 0,
            line: 1,
            column: 1,
            length: 0,
          ),
        ),
      );
      continue;
    }

    final source = inlineSource ?? await file.readAsString();
    final result = Compiler().compile(source);
    compiledFiles++;
    tokens.addAll(
      result.tokens.map(
        (token) => ProtocolToken(
          kind: token.kind.name,
          lexeme: token.lexeme,
          span: _span(sourcePath, token.position, token.lexeme.length),
        ),
      ),
    );
    diagnostics.addAll(
      result.diagnostics.map(
        (diagnostic) => Diagnostic(
          severity: DiagnosticSeverity.error,
          phase: diagnostic.phase,
          code: _diagnosticCode(diagnostic.phase),
          message: diagnostic.message,
          span: _span(sourcePath, diagnostic.position, 1),
        ),
      ),
    );
    if (result.program != null) {
      trees.add({'sourcePath': sourcePath, 'tree': result.program!.toJson()});
    }
    for (final symbol in result.semantic?.symbols.values ?? const <Symbol>[]) {
      symbols.add(
        SymbolRecord(
          name: symbol.name,
          kind: 'variable',
          type: symbol.type,
          span: _span(sourcePath, symbol.position, symbol.name.length),
        ),
      );
    }
    tac.addAll(result.threeAddressCode);
  }

  final syntaxTree = paths.length == 1
      ? (trees.isEmpty ? null : trees.single['tree'] as Map<String, Object?>?)
      : <String, Object?>{'kind': 'project', 'files': trees};
  return CompilationResponse(
    success: compiledFiles == paths.length && diagnostics.isEmpty,
    diagnostics: diagnostics,
    tokens: tokens,
    syntaxTree: syntaxTree,
    symbols: symbols,
    threeAddressCode: tac,
    artifacts: const [],
  );
}

File _resolveFile(String rootPath, String sourcePath) {
  final candidate = File(sourcePath);
  if (candidate.isAbsolute) return candidate;
  return File(
    '${Directory(rootPath).path}${Platform.pathSeparator}$sourcePath',
  );
}

SourceSpan _span(String sourcePath, SourcePosition position, int length) =>
    SourceSpan(
      sourcePath: sourcePath,
      offset: position.offset,
      line: position.line,
      column: position.column,
      length: length,
    );

String _diagnosticCode(String phase) => switch (phase) {
  'lexical' => 'L001',
  'syntax' => 'S001',
  'semantic' => 'M001',
  _ => 'C001',
};

CompilationResponse _failure(String phase, String code, String message) =>
    CompilationResponse(
      success: false,
      diagnostics: [
        Diagnostic(
          severity: DiagnosticSeverity.error,
          phase: phase,
          code: code,
          message: message,
        ),
      ],
    );

Future<void> _writeResponse(CompilationResponse response) async {
  stdout.writeln(jsonEncode(response.toJson()));
  await stdout.flush();
}
