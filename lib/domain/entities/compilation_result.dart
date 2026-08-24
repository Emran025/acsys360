class CompilationResult {
  final bool success;
  final Map<String, dynamic> payload;

  const CompilationResult({required this.success, required this.payload});

  List<dynamic> get diagnostics =>
      payload['diagnostics'] as List<dynamic>? ?? const [];
  List<dynamic> get tokens => payload['tokens'] as List<dynamic>? ?? const [];
  List<dynamic> get threeAddressCode =>
      payload['threeAddressCode'] as List<dynamic>? ?? const [];
  String get assembly => payload['assembly'] as String? ?? '';
  List<dynamic> get executionOutput =>
      payload['executionOutput'] as List<dynamic>? ?? const [];
  List<String> get artifacts =>
      (payload['artifacts'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false);
  List<dynamic> get symbols =>
      payload['symbolTable'] as List<dynamic>? ?? const [];
  Map<String, dynamic>? get syntaxTree =>
      payload['syntaxTree'] as Map<String, dynamic>?;
}
