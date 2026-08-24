import '../entities/editor_diagnostic.dart';

class ArabicLanguageService {
  const ArabicLanguageService();

  List<EditorDiagnostic> enrichDiagnostics(
    List<dynamic> rawDiagnostics,
    String source,
  ) => [
    for (final raw in rawDiagnostics)
      if (raw is Map)
        _enrich(
          EditorDiagnostic.fromJson(Map<String, dynamic>.from(raw)),
          source,
        ),
  ];

  EditorDiagnostic _enrich(EditorDiagnostic diagnostic, String source) =>
      diagnostic.copyWith(actions: _actionsFor(diagnostic, source));

  List<EditorCodeAction> _actionsFor(
    EditorDiagnostic diagnostic,
    String source,
  ) {
    final message = diagnostic.message;
    if (diagnostic.code == 'L001' && message.contains('رمز غير معروف')) {
      return [
        EditorCodeAction(
          title: 'حذف الرمز غير المعروف',
          offset: diagnostic.offset,
          length: diagnostic.length == 0 ? 1 : diagnostic.length,
          replacement: '',
        ),
      ];
    }
    if (diagnostic.code == 'L001' && message.contains('سلسلة نصية')) {
      return [
        const EditorCodeAction(
          title: 'إغلاق السلسلة النصية',
          offset: 0,
          length: 0,
          replacement: '"',
        ),
      ].map((action) {
        final lineEnd = source.indexOf('\n', diagnostic.offset);
        return EditorCodeAction(
          title: action.title,
          offset: lineEnd < 0 ? source.length : lineEnd,
          length: 0,
          replacement: action.replacement,
        );
      }).toList();
    }
    final expected = RegExp(r'متوقع "([^"]+)"').firstMatch(message);
    if (diagnostic.code == 'S001' && expected != null) {
      return [
        EditorCodeAction(
          title: 'إدراج «${expected.group(1)}»',
          offset: diagnostic.offset,
          length: 0,
          replacement: expected.group(1)!,
        ),
      ];
    }
    return const [];
  }
}
