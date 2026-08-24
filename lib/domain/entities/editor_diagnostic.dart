enum EditorDiagnosticSeverity { info, warning, error }

class EditorCodeAction {
  final String title;
  final int offset;
  final int length;
  final String replacement;

  const EditorCodeAction({
    required this.title,
    required this.offset,
    required this.length,
    required this.replacement,
  });
}

class EditorDiagnostic {
  final EditorDiagnosticSeverity severity;
  final String phase;
  final String code;
  final String message;
  final String? sourcePath;
  final int offset;
  final int length;
  final int line;
  final int column;
  final List<EditorCodeAction> actions;

  const EditorDiagnostic({
    required this.severity,
    required this.phase,
    required this.code,
    required this.message,
    required this.sourcePath,
    required this.offset,
    required this.length,
    required this.line,
    required this.column,
    this.actions = const [],
  });

  bool containsOffset(int value) =>
      value >= offset && value <= offset + (length == 0 ? 1 : length);

  EditorDiagnostic copyWith({List<EditorCodeAction>? actions}) =>
      EditorDiagnostic(
        severity: severity,
        phase: phase,
        code: code,
        message: message,
        sourcePath: sourcePath,
        offset: offset,
        length: length,
        line: line,
        column: column,
        actions: actions ?? this.actions,
      );

  factory EditorDiagnostic.fromJson(Map<String, dynamic> json) {
    final rawSpan = json['span'];
    final span = rawSpan is Map
        ? Map<String, dynamic>.from(rawSpan)
        : const <String, dynamic>{};
    final severity = switch (json['severity']) {
      'warning' => EditorDiagnosticSeverity.warning,
      'info' => EditorDiagnosticSeverity.info,
      _ => EditorDiagnosticSeverity.error,
    };
    return EditorDiagnostic(
      severity: severity,
      phase: json['phase'] as String? ?? 'compiler',
      code: json['code'] as String? ?? 'C001',
      message: json['message'] as String? ?? 'خطأ غير معروف',
      sourcePath: span['sourcePath'] as String?,
      offset: _asInt(span['offset']),
      length: _asInt(span['length']),
      line: _asInt(span['line'], fallback: 1),
      column: _asInt(span['column'], fallback: 1),
    );
  }

  static int _asInt(Object? value, {int fallback = 0}) =>
      value is int && value >= 0 ? value : fallback;
}
