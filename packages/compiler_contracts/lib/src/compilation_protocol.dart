const protocolVersion = '0.1.0';

class CompilationRequest {
  final String rootPath;
  final List<String> sourcePaths;

  const CompilationRequest({required this.rootPath, required this.sourcePaths});

  Map<String, Object> toJson() => {
        'protocolVersion': protocolVersion,
        'rootPath': rootPath,
        'sourcePaths': sourcePaths,
      };

  factory CompilationRequest.fromJson(Map<String, dynamic> json) => CompilationRequest(
        rootPath: json['rootPath'] as String,
        sourcePaths: [for (final path in json['sourcePaths'] as List) path as String],
      );
}

class CompilationResponse {
  final bool success;
  final List<Map<String, Object?>> diagnostics;
  final List<Map<String, Object?>> tokens;
  final Map<String, Object?>? syntaxTree;
  final List<Map<String, Object?>> symbols;
  final List<String> threeAddressCode;
  final String assembly;
  final List<String> artifacts;

  const CompilationResponse({
    required this.success,
    this.diagnostics = const [],
    this.tokens = const [],
    this.syntaxTree,
    this.symbols = const [],
    this.threeAddressCode = const [],
    this.assembly = '',
    this.artifacts = const [],
  });

  Map<String, Object?> toJson() => {
        'protocolVersion': protocolVersion,
        'success': success,
        'diagnostics': diagnostics,
        'tokens': tokens,
        'syntaxTree': syntaxTree,
        'symbolTable': symbols,
        'threeAddressCode': threeAddressCode,
        'assembly': assembly,
        'artifacts': artifacts,
      };
}
