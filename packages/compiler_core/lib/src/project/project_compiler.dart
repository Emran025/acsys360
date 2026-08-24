import '../ast/ast.dart';
import '../compiler.dart';
import '../model/token.dart';
import '../semantic/semantic.dart';

class ProjectFileResult {
  final String sourcePath;
  final CompilationResult result;

  const ProjectFileResult({required this.sourcePath, required this.result});
}

class ProjectDiagnostic {
  final String sourcePath;
  final Diagnostic diagnostic;

  const ProjectDiagnostic({required this.sourcePath, required this.diagnostic});
}

class ProjectCompilationResult {
  final List<ProjectFileResult> files;
  final List<ProjectDiagnostic> projectDiagnostics;

  const ProjectCompilationResult({
    required this.files,
    this.projectDiagnostics = const [],
  });

  bool get success =>
      files.isNotEmpty &&
      files.every((file) => file.result.success) &&
      projectDiagnostics.isEmpty;

  List<Diagnostic> diagnosticsFor(String sourcePath) => [
    for (final file in files)
      if (file.sourcePath == sourcePath) ...file.result.diagnostics,
    for (final item in projectDiagnostics)
      if (item.sourcePath == sourcePath) item.diagnostic,
  ];
}

class ProjectCompiler {
  final Compiler compiler;

  const ProjectCompiler({this.compiler = const Compiler()});

  ProjectCompilationResult compile(Map<String, String> sources) {
    final initialFiles = [
      for (final entry in sources.entries)
        ProjectFileResult(
          sourcePath: entry.key,
          result: compiler.compile(entry.value),
        ),
    ];
    final externalSymbols = <String, Symbol>{};
    for (final file in initialFiles) {
      for (final symbol
          in file.result.semantic?.symbols.values ?? const <Symbol>[]) {
        if (symbol.kind == 'procedure' || symbol.kind == 'type') {
          externalSymbols.putIfAbsent(symbol.name, () => symbol);
        }
      }
    }
    final externalProcedures = externalSymbols.values
        .where((symbol) => symbol.kind == 'procedure')
        .map((symbol) => symbol.name)
        .toSet();
    final files = [
      for (final entry in sources.entries)
        ProjectFileResult(
          sourcePath: entry.key,
          result: compiler.compile(
            entry.value,
            externalSymbols: externalSymbols.values,
            execute:
                sources.length == 1 ||
                !_containsExternalCall(
                  initialFiles
                      .firstWhere((file) => file.sourcePath == entry.key)
                      .result
                      .program,
                  externalProcedures,
                ),
          ),
        ),
    ];
    final projectDiagnostics = <ProjectDiagnostic>[];
    final declarations = <String, ProjectFileResult>{};
    for (final file in files) {
      for (final symbol
          in file.result.semantic?.symbols.values ?? const <Symbol>[]) {
        final previous = declarations[symbol.name];
        if (previous != null && previous.sourcePath != file.sourcePath) {
          projectDiagnostics.add(
            ProjectDiagnostic(
              sourcePath: file.sourcePath,
              diagnostic: Diagnostic(
                'semantic',
                'الرمز "${symbol.name}" معرف في أكثر من ملف',
                symbol.position,
              ),
            ),
          );
        } else {
          declarations[symbol.name] = file;
        }
      }
    }
    return ProjectCompilationResult(
      files: files,
      projectDiagnostics: projectDiagnostics,
    );
  }

  bool _containsExternalCall(
    ProgramNode? program,
    Set<String> externalProcedures,
  ) {
    if (program == null || externalProcedures.isEmpty) return false;
    return _containsExternalCallInNodes(program.statements, externalProcedures);
  }

  bool _containsExternalCallInNodes(
    Iterable<AstNode> nodes,
    Set<String> externalProcedures,
  ) {
    for (final node in nodes) {
      if (node is CallStatement && externalProcedures.contains(node.name)) {
        return true;
      }
      if (node is IfStatement &&
          (_containsExternalCallInNodes(node.thenBranch, externalProcedures) ||
              _containsExternalCallInNodes(
                node.elseBranch,
                externalProcedures,
              ))) {
        return true;
      }
      if (node is WhileStatement &&
          _containsExternalCallInNodes(node.body, externalProcedures)) {
        return true;
      }
      if (node is RepeatStatement &&
          _containsExternalCallInNodes(node.body, externalProcedures)) {
        return true;
      }
      if (node is RepeatUntilStatement &&
          _containsExternalCallInNodes(node.body, externalProcedures)) {
        return true;
      }
    }
    return false;
  }
}
