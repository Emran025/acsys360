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
    final externalProcedures = <String, ProcedureDeclaration>{};
    final externalTypes = <String, TypeSpec>{};
    for (final file in initialFiles) {
      for (final symbol
          in file.result.semantic?.symbols.values ?? const <Symbol>[]) {
        if (symbol.kind == 'procedure' || symbol.kind == 'type') {
          externalSymbols.putIfAbsent(symbol.name, () => symbol);
        }
      }
      for (final declaration in file.result.program?.declarations ?? const []) {
        if (declaration is ProcedureDeclaration) {
          externalProcedures.putIfAbsent(declaration.name, () => declaration);
        } else if (declaration is TypeDeclaration) {
          externalTypes.putIfAbsent(declaration.name, () => declaration.type);
        }
      }
    }
    final files = [
      for (final entry in sources.entries)
        ProjectFileResult(
          sourcePath: entry.key,
          result: compiler.compile(
            entry.value,
            externalSymbols: externalSymbols.values,
            externalProcedures: externalProcedures.values,
            externalTypes: externalTypes,
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
}
