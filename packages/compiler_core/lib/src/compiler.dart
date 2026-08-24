import 'ast/ast.dart';
import 'codegen/three_address.dart';
import 'lexer/lexer.dart';
import 'model/token.dart';
import 'parser/parser.dart';
import 'semantic/semantic.dart';

class CompilationResult {
  final List<Token> tokens;
  final ProgramNode? program;
  final SemanticResult? semantic;
  final List<String> threeAddressCode;
  final List<Diagnostic> diagnostics;

  const CompilationResult(
    this.tokens,
    this.program,
    this.semantic,
    this.threeAddressCode,
    this.diagnostics,
  );

  bool get success => diagnostics.isEmpty && program != null;

  Map<String, Object?> toJson() => {
    'success': success,
    'tokens': tokens.map((token) => token.toJson()).toList(),
    'syntaxTree': program?.toJson(),
    'symbolTable': semantic?.toJson()['symbols'],
    'threeAddressCode': threeAddressCode,
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
    return CompilationResult(
      lexical.tokens,
      parsed.program,
      semantic,
      tac,
      diagnostics,
    );
  }
}
