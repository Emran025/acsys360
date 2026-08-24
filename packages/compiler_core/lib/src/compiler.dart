import 'ast/ast.dart';
import 'codegen/assembly.dart';
import 'codegen/three_address.dart';
import 'lexer/lexer.dart';
import 'runtime/interpreter.dart';
import 'model/token.dart';
import 'parser/parser.dart';
import 'semantic/semantic.dart';

class CompilationResult {
  final List<Token> tokens;
  final ProgramNode? program;
  final SemanticResult? semantic;
  final List<String> threeAddressCode;
  final List<Diagnostic> diagnostics;
  final String assembly;
  final List<String> executionOutput;

  const CompilationResult(
    this.tokens,
    this.program,
    this.semantic,
    this.threeAddressCode,
    this.diagnostics, {
    this.assembly = '',
    this.executionOutput = const [],
  });

  bool get success => diagnostics.isEmpty && program != null;

  Map<String, Object?> toJson() => {
    'success': success,
    'tokens': tokens.map((token) => token.toJson()).toList(),
    'syntaxTree': program?.toJson(),
    'symbolTable': semantic?.toJson()['symbols'],
    'threeAddressCode': threeAddressCode,
    'assembly': assembly,
    'executionOutput': executionOutput,
    'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
  };
}

class Compiler {
  const Compiler();

  CompilationResult compile(String source) {
    final lexical = Lexer(source).scan();
    final parsed = Parser(lexical.tokens).parse();
    if (parsed.program == null) {
      return CompilationResult(lexical.tokens, null, null, const [], [
        ...lexical.diagnostics,
        ...parsed.diagnostics,
      ]);
    }
    final semantic = SemanticAnalyzer().analyze(parsed.program!);
    final diagnostics = [
      ...lexical.diagnostics,
      ...parsed.diagnostics,
      ...semantic.diagnostics,
    ];
    final tac = diagnostics.isEmpty
        ? ThreeAddressGenerator().generate(parsed.program!)
        : const <String>[];
    final assembly = diagnostics.isEmpty
        ? const AssemblyGenerator().generate(tac)
        : '';
    final executionResult = diagnostics.isEmpty
        ? const Interpreter().execute(parsed.program!)
        : const ExecutionResult();
    final allDiagnostics = [
      ...diagnostics,
      ...executionResult.diagnostics.map(
        (message) => Diagnostic('execution', message, parsed.program!.position),
      ),
    ];
    return CompilationResult(
      lexical.tokens,
      parsed.program,
      semantic,
      tac,
      allDiagnostics,
      assembly: assembly,
      executionOutput: executionResult.output,
    );
  }
}
