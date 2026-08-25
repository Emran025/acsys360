import 'ast/ast.dart';
import 'codegen/assembly.dart';
import 'codegen/three_address.dart';
import 'lexer/lexer.dart';
import 'runtime/interpreter.dart';
import 'ir/typed_ir.dart';
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
  final TypedIrProgram? intermediateRepresentation;

  const CompilationResult(
    this.tokens,
    this.program,
    this.semantic,
    this.threeAddressCode,
    this.diagnostics, {
    this.assembly = '',
    this.executionOutput = const [],
    this.intermediateRepresentation,
  });

  bool get success => diagnostics.isEmpty && program != null;

  Map<String, Object?> toJson() => {
    'success': success,
    'tokens': tokens.map((token) => token.toJson()).toList(),
    'syntaxTree': program?.toJson(),
    'symbolTable': semantic?.toJson()['symbols'],
    'threeAddressCode': threeAddressCode,
    'assembly': assembly,
    'intermediateRepresentation': intermediateRepresentation?.toJson(),
    'executionOutput': executionOutput,
    'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
  };
}

/// ينسق pipeline المترجم من Lexer حتى runtime، ولا ينتج مرحلة لاحقة من مصدر غير صالح.
class Compiler {
  const Compiler();

  CompilationResult compile(
    String source, {
    Iterable<Symbol> externalSymbols = const [],
    Iterable<ProcedureDeclaration> externalProcedures = const [],
    Map<String, TypeSpec> externalTypes = const {},
    bool execute = true,
  }) {
    final lexical = Lexer(source).scan();
    final parsed = Parser(lexical.tokens).parse();
    if (parsed.program == null) {
      return CompilationResult(lexical.tokens, null, null, const [], [
        ...lexical.diagnostics,
        ...parsed.diagnostics,
      ]);
    }
    final semantic = SemanticAnalyzer().analyze(
      parsed.program!,
      externalSymbols: externalSymbols,
    );
    final diagnostics = [
      ...lexical.diagnostics,
      ...parsed.diagnostics,
      ...semantic.diagnostics,
    ];
    final tac = diagnostics.isEmpty
        ? ThreeAddressGenerator().generate(parsed.program!)
        : const <String>[];
    final ir = diagnostics.isEmpty
        ? TypedIrProgram.fromTac(
            tac,
            symbolTypes: {
              for (final symbol in semantic.symbols.values)
                symbol.name: IrType.fromName(symbol.type),
            },
          )
        : null;
    final irDiagnostics = ir == null
        ? const <Diagnostic>[]
        : [
            for (final message in ir.diagnostics)
              Diagnostic('ir', message, parsed.program!.position),
          ];
    final stageDiagnostics = [...diagnostics, ...irDiagnostics];
    final assembly = stageDiagnostics.isEmpty
        ? const AssemblyGenerator().generate(tac)
        : '';
    final executionResult = stageDiagnostics.isEmpty && execute
        ? const Interpreter().execute(
            parsed.program!,
            externalProcedures: externalProcedures,
            externalTypes: externalTypes,
          )
        : const ExecutionResult();
    final allDiagnostics = [
      ...stageDiagnostics,
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
      intermediateRepresentation: ir,
    );
  }
}
