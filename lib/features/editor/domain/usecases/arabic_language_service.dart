import '../entities/editor_diagnostic.dart';

class ArabicLanguageService {
  const ArabicLanguageService();

  List<EditorDiagnostic> enrichDiagnostics(
    List<dynamic> rawDiagnostics,
    String source, {
    Iterable<String> symbolNames = const [],
  }) => [
    for (final raw in rawDiagnostics)
      if (raw is Map)
        _enrich(
          EditorDiagnostic.fromJson(Map<String, dynamic>.from(raw)),
          source,
          symbolNames.toList(growable: false),
        ),
  ];

  EditorDiagnostic _enrich(
    EditorDiagnostic diagnostic,
    String source,
    List<String> symbolNames,
  ) => diagnostic.copyWith(
    actions: _actionsFor(diagnostic, source, symbolNames),
  );

  List<EditorCodeAction> _actionsFor(
    EditorDiagnostic diagnostic,
    String source,
    List<String> symbolNames,
  ) {
    final message = diagnostic.message;
    if (diagnostic.code == 'L001' &&
        message.contains('رمز غير معروف') &&
        diagnostic.length > 0) {
      return [
        EditorCodeAction(
          title: 'حذف الرمز غير المعروف',
          offset: _clampOffset(diagnostic.offset, source.length),
          length: _clampLength(
            diagnostic.offset,
            diagnostic.length,
            source.length,
          ),
          replacement: '',
        ),
      ];
    }
    if (diagnostic.code == 'L001' && message.contains('سلسلة نصية')) {
      return [
        EditorCodeAction(
          title: 'إغلاق السلسلة النصية',
          offset: diagnostic.offset,
          length: 0,
          replacement: '"',
        ),
      ].map((action) {
        final start = _clampOffset(diagnostic.offset, source.length);
        final lineEnd = source.indexOf('\n', start);
        return EditorCodeAction(
          title: action.title,
          offset: lineEnd < 0 ? source.length : lineEnd,
          length: 0,
          replacement: action.replacement,
        );
      }).toList();
    }
    final expected = RegExp(r'متوقع "([^"]+)"').firstMatch(message);
    if (diagnostic.phase == 'syntax' && expected != null) {
      return [
        EditorCodeAction(
          title: 'إدراج «${expected.group(1)}»',
          offset: _clampOffset(diagnostic.offset, source.length),
          length: 0,
          replacement: expected.group(1)!,
        ),
      ];
    }
    final unexpected = RegExp(r'رمز غير متوقع «([^»]+)»').firstMatch(message);
    if (diagnostic.phase == 'syntax' &&
        unexpected != null &&
        diagnostic.length > 0) {
      return [
        EditorCodeAction(
          title: 'حذف «${unexpected.group(1)}»',
          offset: _clampOffset(diagnostic.offset, source.length),
          length: _clampLength(
            diagnostic.offset,
            diagnostic.length,
            source.length,
          ),
          replacement: '',
        ),
      ];
    }
    final unknownName = RegExp(r'رمز غير معرف:\s*(.+)$').firstMatch(message);
    if (unknownName != null) {
      final name = unknownName.group(1)!.trim();
      final suggestion = _closestName(name, symbolNames);
      if (suggestion != null &&
          diagnostic.length > 0 &&
          diagnostic.offset <= source.length) {
        return [
          EditorCodeAction(
            title: 'استبدال «$name» بـ «$suggestion»',
            offset: diagnostic.offset,
            length: _clampLength(
              diagnostic.offset,
              diagnostic.length,
              source.length,
            ),
            replacement: suggestion,
          ),
        ];
      }
    }
    return const [];
  }

  String? _closestName(String name, List<String> candidates) {
    String? best;
    var bestDistance = name.runes.length + 1;
    for (final candidate in candidates.toSet()) {
      if (candidate == name) continue;
      final distance = _editDistance(
        name.runes.toList(),
        candidate.runes.toList(),
      );
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    final threshold = name.runes.length < 5 ? 1 : name.runes.length ~/ 4;
    return bestDistance <= threshold ? best : null;
  }

  int _editDistance(List<int> left, List<int> right) {
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var row = 1; row <= left.length; row++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = row;
      for (var column = 1; column <= right.length; column++) {
        final substitution =
            previous[column - 1] + (left[row - 1] == right[column - 1] ? 0 : 1);
        current[column] = [
          current[column - 1] + 1,
          previous[column] + 1,
          substitution,
        ].reduce((a, b) => a < b ? a : b);
      }
      previous = current;
    }
    return previous.last;
  }

  int _clampOffset(int offset, int sourceLength) =>
      offset.clamp(0, sourceLength).toInt();

  int _clampLength(int offset, int length, int sourceLength) => length
      .clamp(0, sourceLength - _clampOffset(offset, sourceLength))
      .toInt();
}
