import 'dart:convert';
import 'dart:io';

import 'package:compiler_contracts/compiler_contracts.dart';

import '../lib/arabic_compiler.dart' hide Diagnostic;

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 && arguments.single == '--assist') {
    await _runAssist();
    return;
  }
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

Future<void> _runAssist() async {
  final payload = await stdin.transform(utf8.decoder).join();
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      throw const FormatException('يجب أن يكون طلب assist كائن JSON');
    }
    final request = AssistRequest.fromJson(Map<String, dynamic>.from(decoded));
    final assist = const LanguageAssist();
    if (request.action == AssistAction.completion) {
      final result = assist.complete(
        request.sourceText,
        request.offset,
        symbols: request.symbols,
      );
      await _writeAssistResponse(
        AssistResponse(
          action: AssistAction.completion,
          expected: result.expected,
          prefix: result.prefix,
          replaceStart: result.replaceStart,
          replaceLength: result.replaceLength,
          items: [
            for (final item in result.items)
              AssistCompletionItem(
                label: item.label,
                insertText: item.insertText,
                kind: item.kind,
                detail: item.detail,
              ),
          ],
        ),
      );
    } else {
      final help = assist.helpFor(request.sourceText, request.offset);
      await _writeAssistResponse(
        AssistResponse(
          action: AssistAction.help,
          help: help == null
              ? null
              : AssistHelp(
                  keyword: help.keyword,
                  title: help.title,
                  description: help.description,
                  syntax: help.syntax,
                ),
        ),
      );
    }
    exitCode = 0;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  }
}

Future<void> _writeAssistResponse(AssistResponse response) async {
  stdout.writeln(jsonEncode(response.toJson()));
  await stdout.flush();
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
  final assembly = <String>[];
  final executionOutput = <String>[];
  final artifacts = <String>[];
  final trees = <Map<String, Object?>>[];
  final intermediateRepresentations = <Map<String, Object?>>[];
  final sources = <String, String>{};

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
    sources[sourcePath] = inlineSource ?? await file.readAsString();
  }

  final project = ProjectCompiler().compile(sources);
  for (final fileResult in project.files) {
    final sourcePath = fileResult.sourcePath;
    final result = fileResult.result;
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
    if (result.intermediateRepresentation != null) {
      intermediateRepresentations.add({
        'sourcePath': sourcePath,
        'ir': result.intermediateRepresentation!.toJson(),
      });
    }
    for (final symbol in result.semantic?.symbols.values ?? const <Symbol>[]) {
      symbols.add(
        SymbolRecord(
          name: symbol.name,
          kind: symbol.kind,
          type: symbol.type,
          span: _span(sourcePath, symbol.position, symbol.name.length),
        ),
      );
    }
    tac.addAll(result.threeAddressCode);
    if (result.assembly.isNotEmpty) {
      assembly.add('; source: $sourcePath\n${result.assembly}');
      executionOutput.addAll(result.executionOutput);
    }
  }
  if (request.target != 'none' && request.target != 'dart-native') {
    diagnostics.add(
      Diagnostic(
        severity: DiagnosticSeverity.error,
        phase: 'backend',
        code: 'B001',
        message: 'الهدف التنفيذي غير مدعوم: ${request.target}',
        span: SourceSpan(
          sourcePath: request.entryPath ?? paths.first,
          offset: 0,
          line: 1,
          column: 1,
          length: 0,
        ),
      ),
    );
  }
  if (request.target == 'dart-native' && diagnostics.isEmpty) {
    if (paths.length != 1 || project.files.length != 1) {
      diagnostics.add(
        Diagnostic(
          severity: DiagnosticSeverity.error,
          phase: 'backend',
          code: 'B002',
          message: 'هدف dart-native يحتاج ملف دخول واحدًا؛ لم يُنشأ artifact',
          span: SourceSpan(
            sourcePath: request.entryPath ?? paths.first,
            offset: 0,
            line: 1,
            column: 1,
            length: 0,
          ),
        ),
      );
    } else {
      final fileResult = project.files.single;
      final program = fileResult.result.program;
      if (program == null || !fileResult.result.success) {
        diagnostics.add(
          Diagnostic(
            severity: DiagnosticSeverity.error,
            phase: 'backend',
            code: 'B003',
            message: 'لا يمكن بناء artifact من مصدر غير صالح',
            span: SourceSpan(
              sourcePath: fileResult.sourcePath,
              offset: 0,
              line: 1,
              column: 1,
              length: 0,
            ),
          ),
        );
      } else {
        final outputDirectory =
            request.artifactDirectory ??
            '${request.rootPath}${Platform.pathSeparator}.arabic360${Platform.pathSeparator}build';
        final artifact = await const DartNativeArtifactBuilder().build(
          program,
          outputDirectory: outputDirectory,
          dartExecutable: _resolveDartExecutable(),
        );
        if (artifact.success) {
          artifacts.add(artifact.executablePath!);
        } else {
          diagnostics.add(
            Diagnostic(
              severity: DiagnosticSeverity.error,
              phase: 'backend',
              code: 'B004',
              message: artifact.diagnostics.join('\n'),
              span: SourceSpan(
                sourcePath: fileResult.sourcePath,
                offset: 0,
                line: 1,
                column: 1,
                length: 0,
              ),
            ),
          );
        }
      }
    }
  }
  diagnostics.addAll(
    project.projectDiagnostics.map(
      (item) => Diagnostic(
        severity: DiagnosticSeverity.error,
        phase: item.diagnostic.phase,
        code: 'M002',
        message: item.diagnostic.message,
        span: _span(item.sourcePath, item.diagnostic.position, 1),
      ),
    ),
  );

  final syntaxTree = paths.length == 1
      ? (trees.isEmpty ? null : trees.single['tree'] as Map<String, Object?>?)
      : <String, Object?>{'kind': 'project', 'files': trees};
  final intermediateRepresentation = paths.length == 1
      ? (intermediateRepresentations.isEmpty
            ? null
            : intermediateRepresentations.single['ir'] as Map<String, Object?>?)
      : <String, Object?>{
          'kind': 'project',
          'files': intermediateRepresentations,
        };
  return CompilationResponse(
    success: sources.length == paths.length && diagnostics.isEmpty,
    diagnostics: diagnostics,
    tokens: tokens,
    syntaxTree: syntaxTree,
    symbols: symbols,
    threeAddressCode: tac,
    assembly: assembly.join('\n'),
    executionOutput: executionOutput,
    artifacts: artifacts,
    intermediateRepresentation: intermediateRepresentation,
  );
}

String _resolveDartExecutable() {
  final configured = Platform.environment['DART_EXECUTABLE']?.trim();
  if (configured != null && configured.isNotEmpty) return configured;
  final dartName = Platform.isWindows ? 'dart.exe' : 'dart';
  final bundled = File(
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin${Platform.pathSeparator}$dartName',
  );
  if (bundled.existsSync()) return bundled.path;
  final executableName = Platform.resolvedExecutable
      .split(Platform.pathSeparator)
      .last;
  if (executableName == 'dart' || executableName == 'dart.exe') {
    return Platform.resolvedExecutable;
  }
  return dartName;
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
