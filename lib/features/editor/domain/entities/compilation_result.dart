import 'package:compiler_contracts/compiler_contracts.dart';

class CompilationResult {
  final bool success;
  final List<Diagnostic> diagnostics;
  final List<ProtocolToken> tokens;
  final Map<String, Object?>? syntaxTree;
  final List<SymbolRecord> symbols;
  final List<String> threeAddressCode;
  final String assembly;
  final List<String> executionOutput;
  final List<String> artifacts;
  final Map<String, Object?>? intermediateRepresentation;

  const CompilationResult({
    required this.success,
    this.diagnostics = const [],
    this.tokens = const [],
    this.syntaxTree,
    this.symbols = const [],
    this.threeAddressCode = const [],
    this.assembly = '',
    this.executionOutput = const [],
    this.artifacts = const [],
    this.intermediateRepresentation,
  });

  factory CompilationResult.fromProtocol(CompilationResponse response) =>
      CompilationResult(
        success: response.success,
        diagnostics: response.diagnostics,
        tokens: response.tokens,
        syntaxTree: response.syntaxTree,
        symbols: response.symbols,
        threeAddressCode: response.threeAddressCode,
        assembly: response.assembly,
        executionOutput: response.executionOutput,
        artifacts: response.artifacts,
        intermediateRepresentation: response.intermediateRepresentation,
      );

  CompilationResult copyWith({List<String>? executionOutput}) =>
      CompilationResult(
        success: success,
        diagnostics: diagnostics,
        tokens: tokens,
        syntaxTree: syntaxTree,
        symbols: symbols,
        threeAddressCode: threeAddressCode,
        assembly: assembly,
        executionOutput: executionOutput ?? this.executionOutput,
        artifacts: artifacts,
        intermediateRepresentation: intermediateRepresentation,
      );
}
