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
}
