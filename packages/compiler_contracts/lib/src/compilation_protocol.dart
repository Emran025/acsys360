const protocolVersion = '0.5.0';

enum CompilationMode { active, project }

extension CompilationModeJson on CompilationMode {
  String get value => name;

  static CompilationMode parse(Object? value) {
    return CompilationMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => throw FormatException('وضع ترجمة غير معروف: $value'),
    );
  }
}

enum DiagnosticSeverity { info, warning, error }

enum AssistAction { completion, help }

extension AssistActionJson on AssistAction {
  String get value => name;

  static AssistAction parse(Object? value) {
    return AssistAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => throw FormatException('عملية مساعدة غير معروفة: $value'),
    );
  }
}

extension DiagnosticSeverityJson on DiagnosticSeverity {
  String get value => name;

  static DiagnosticSeverity parse(Object? value) {
    return DiagnosticSeverity.values.firstWhere(
      (severity) => severity.value == value,
      orElse: () => throw FormatException('شدة تشخيص غير معروفة: $value'),
    );
  }
}

class SourceSpan {
  final String sourcePath;
  final int offset;
  final int line;
  final int column;
  final int length;

  const SourceSpan({
    required this.sourcePath,
    required this.offset,
    required this.line,
    required this.column,
    required this.length,
  });

  Map<String, Object> toJson() => {
    'sourcePath': sourcePath,
    'offset': offset,
    'line': line,
    'column': column,
    'length': length,
  };

  factory SourceSpan.fromJson(Map<String, dynamic> json) => SourceSpan(
    sourcePath: _requiredString(json, 'sourcePath'),
    offset: _requiredNonNegativeInt(json, 'offset'),
    line: _requiredPositiveInt(json, 'line'),
    column: _requiredPositiveInt(json, 'column'),
    length: _requiredNonNegativeInt(json, 'length'),
  );
}

class Diagnostic {
  final DiagnosticSeverity severity;
  final String phase;
  final String code;
  final String message;
  final SourceSpan? span;

  const Diagnostic({
    required this.severity,
    required this.phase,
    required this.code,
    required this.message,
    this.span,
  });

  Map<String, Object?> toJson() => {
    'severity': severity.value,
    'phase': phase,
    'code': code,
    'message': message,
    'span': span?.toJson(),
  };

  factory Diagnostic.fromJson(Map<String, dynamic> json) => Diagnostic(
    severity: DiagnosticSeverityJson.parse(json['severity']),
    phase: _requiredString(json, 'phase'),
    code: _requiredString(json, 'code'),
    message: _requiredString(json, 'message'),
    span: _optionalSpan(json['span']),
  );
}

class ProtocolToken {
  final String kind;
  final String lexeme;
  final SourceSpan span;

  const ProtocolToken({
    required this.kind,
    required this.lexeme,
    required this.span,
  });

  Map<String, Object> toJson() => {
    'kind': kind,
    'lexeme': lexeme,
    'span': span.toJson(),
  };

  factory ProtocolToken.fromJson(Map<String, dynamic> json) => ProtocolToken(
    kind: _requiredString(json, 'kind'),
    lexeme: _requiredString(json, 'lexeme'),
    span: SourceSpan.fromJson(_requiredMap(json, 'span')),
  );
}

class SymbolRecord {
  final String name;
  final String kind;
  final String type;
  final SourceSpan span;

  const SymbolRecord({
    required this.name,
    required this.kind,
    required this.type,
    required this.span,
  });

  Map<String, Object> toJson() => {
    'name': name,
    'kind': kind,
    'type': type,
    'span': span.toJson(),
  };

  factory SymbolRecord.fromJson(Map<String, dynamic> json) => SymbolRecord(
    name: _requiredString(json, 'name'),
    kind: _requiredString(json, 'kind'),
    type: _requiredString(json, 'type'),
    span: SourceSpan.fromJson(_requiredMap(json, 'span')),
  );
}

class CompilationRequest {
  final String rootPath;
  final List<String> sourcePaths;
  final Map<String, String> sourceTexts;
  final CompilationMode mode;
  final String? entryPath;
  final String target;
  final String? artifactDirectory;

  const CompilationRequest({
    required this.rootPath,
    required this.sourcePaths,
    this.sourceTexts = const {},
    this.mode = CompilationMode.project,
    this.entryPath,
    this.target = 'none',
    this.artifactDirectory,
  });

  Map<String, Object?> toJson() => {
    'protocolVersion': protocolVersion,
    'rootPath': rootPath,
    'sourcePaths': sourcePaths,
    'sourceTexts': sourceTexts,
    'mode': mode.value,
    'entryPath': entryPath,
    'target': target,
    'artifactDirectory': artifactDirectory,
  };

  factory CompilationRequest.fromJson(Map<String, dynamic> json) {
    _checkProtocolVersion(json);
    final sourcePaths = _requiredStringList(json, 'sourcePaths');
    final sourceTexts = _optionalStringMap(json['sourceTexts']);
    if (sourcePaths.isEmpty) {
      throw const FormatException('يجب تمرير ملف مصدر واحد على الأقل');
    }
    return CompilationRequest(
      rootPath: _requiredString(json, 'rootPath'),
      sourcePaths: sourcePaths,
      sourceTexts: sourceTexts,
      mode: CompilationModeJson.parse(json['mode'] ?? 'project'),
      entryPath: _optionalString(json['entryPath']),
      target: _optionalString(json['target']) ?? 'none',
      artifactDirectory: _optionalString(json['artifactDirectory']),
    );
  }
}

class CompilationResponse {
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

  const CompilationResponse({
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

  Map<String, Object?> toJson() => {
    'protocolVersion': protocolVersion,
    'success': success,
    'diagnostics': [for (final diagnostic in diagnostics) diagnostic.toJson()],
    'tokens': [for (final token in tokens) token.toJson()],
    'syntaxTree': syntaxTree,
    'symbolTable': [for (final symbol in symbols) symbol.toJson()],
    'threeAddressCode': threeAddressCode,
    'assembly': assembly,
    'executionOutput': executionOutput,
    'artifacts': artifacts,
    'intermediateRepresentation': intermediateRepresentation,
  };

  factory CompilationResponse.fromJson(Map<String, dynamic> json) {
    _checkProtocolVersion(json);
    return CompilationResponse(
      success: _requiredBool(json, 'success'),
      diagnostics: _requiredMapList(
        json,
        'diagnostics',
      ).map(Diagnostic.fromJson).toList(),
      tokens: _requiredMapList(
        json,
        'tokens',
      ).map(ProtocolToken.fromJson).toList(),
      syntaxTree: _optionalMap(json['syntaxTree']),
      symbols: _requiredMapList(
        json,
        'symbolTable',
      ).map(SymbolRecord.fromJson).toList(),
      threeAddressCode: _requiredStringList(json, 'threeAddressCode'),
      assembly: _requiredString(json, 'assembly'),
      executionOutput: _requiredStringList(json, 'executionOutput'),
      artifacts: _requiredStringList(json, 'artifacts'),
      intermediateRepresentation: _optionalMap(
        json['intermediateRepresentation'],
      ),
    );
  }
}

class AssistRequest {
  final String sourcePath;
  final String sourceText;
  final int offset;
  final AssistAction action;
  final List<String> symbols;

  const AssistRequest({
    required this.sourcePath,
    required this.sourceText,
    required this.offset,
    required this.action,
    this.symbols = const [],
  });

  Map<String, Object> toJson() => {
    'protocolVersion': protocolVersion,
    'requestType': 'assist',
    'sourcePath': sourcePath,
    'sourceText': sourceText,
    'offset': offset,
    'action': action.value,
    'symbols': symbols,
  };

  factory AssistRequest.fromJson(Map<String, dynamic> json) {
    _checkProtocolVersion(json);
    if (json['requestType'] != 'assist') {
      throw const FormatException('نوع الطلب ليس assist');
    }
    return AssistRequest(
      sourcePath: _requiredString(json, 'sourcePath'),
      sourceText: _requiredString(json, 'sourceText'),
      offset: _requiredNonNegativeInt(json, 'offset'),
      action: AssistActionJson.parse(json['action']),
      symbols: _optionalStringList(json['symbols']),
    );
  }
}

class AssistCompletionItem {
  final String label;
  final String insertText;
  final String kind;
  final String detail;

  const AssistCompletionItem({
    required this.label,
    required this.insertText,
    required this.kind,
    required this.detail,
  });

  Map<String, Object> toJson() => {
    'label': label,
    'insertText': insertText,
    'kind': kind,
    'detail': detail,
  };

  factory AssistCompletionItem.fromJson(Map<String, dynamic> json) =>
      AssistCompletionItem(
        label: _requiredString(json, 'label'),
        insertText: _requiredString(json, 'insertText'),
        kind: _requiredString(json, 'kind'),
        detail: _requiredString(json, 'detail'),
      );
}

class AssistHelp {
  final String keyword;
  final String title;
  final String description;
  final String syntax;

  const AssistHelp({
    required this.keyword,
    required this.title,
    required this.description,
    required this.syntax,
  });

  Map<String, Object> toJson() => {
    'keyword': keyword,
    'title': title,
    'description': description,
    'syntax': syntax,
  };

  factory AssistHelp.fromJson(Map<String, dynamic> json) => AssistHelp(
    keyword: _requiredString(json, 'keyword'),
    title: _requiredString(json, 'title'),
    description: _requiredString(json, 'description'),
    syntax: _requiredString(json, 'syntax'),
  );
}

class AssistResponse {
  final AssistAction action;
  final String expected;
  final String prefix;
  final int replaceStart;
  final int replaceLength;
  final List<AssistCompletionItem> items;
  final AssistHelp? help;

  const AssistResponse({
    required this.action,
    this.expected = '',
    this.prefix = '',
    this.replaceStart = 0,
    this.replaceLength = 0,
    this.items = const [],
    this.help,
  });

  Map<String, Object?> toJson() => {
    'protocolVersion': protocolVersion,
    'success': true,
    'requestType': 'assist',
    'action': action.value,
    'expected': expected,
    'prefix': prefix,
    'replaceStart': replaceStart,
    'replaceLength': replaceLength,
    'items': [for (final item in items) item.toJson()],
    'help': help?.toJson(),
  };

  factory AssistResponse.fromJson(Map<String, dynamic> json) {
    _checkProtocolVersion(json);
    if (json['requestType'] != 'assist') {
      throw const FormatException('نوع الاستجابة ليس assist');
    }
    return AssistResponse(
      action: AssistActionJson.parse(json['action']),
      expected: _requiredString(json, 'expected'),
      prefix: _requiredString(json, 'prefix'),
      replaceStart: _requiredNonNegativeInt(json, 'replaceStart'),
      replaceLength: _requiredNonNegativeInt(json, 'replaceLength'),
      items: _requiredMapList(
        json,
        'items',
      ).map(AssistCompletionItem.fromJson).toList(),
      help: json['help'] == null
          ? null
          : AssistHelp.fromJson(_requiredMap(json, 'help')),
    );
  }
}

void _checkProtocolVersion(Map<String, dynamic> json) {
  if (json['protocolVersion'] != protocolVersion) {
    throw FormatException(
      'إصدار بروتوكول غير مدعوم: ${json['protocolVersion']}',
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('الحقل $key يجب أن يكون نصًا');
}

String? _optionalString(Object? value) => value == null
    ? null
    : value is String
    ? value
    : throw const FormatException('الحقل الاختياري يجب أن يكون نصًا');

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('الحقل $key يجب أن يكون منطقيًا');
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = _requiredNonNegativeInt(json, key);
  if (value > 0) return value;
  throw FormatException('الحقل $key يجب أن يكون موجبًا');
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int && value >= 0) return value;
  throw FormatException('الحقل $key يجب أن يكون عددًا غير سالب');
}

List<String> _optionalStringList(Object? value) {
  if (value == null) return const [];
  if (value is List && value.every((item) => item is String)) {
    return [for (final item in value) item as String];
  }
  throw const FormatException('الحقل الاختياري يجب أن يكون قائمة نصوص');
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.every((item) => item is String)) {
    return [for (final item in value) item as String];
  }
  throw FormatException('الحقل $key يجب أن يكون قائمة نصوص');
}

Map<String, String> _optionalStringMap(Object? value) {
  if (value == null) return const {};
  if (value is Map &&
      value.keys.every((key) => key is String) &&
      value.values.every((item) => item is String)) {
    return {
      for (final entry in value.entries)
        entry.key as String: entry.value as String,
    };
  }
  throw const FormatException('الحقل sourceTexts يجب أن يكون خريطة نصوص');
}

List<Map<String, dynamic>> _requiredMapList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is List && value.every((item) => item is Map)) {
    return [for (final item in value) Map<String, dynamic>.from(item as Map)];
  }
  throw FormatException('الحقل $key يجب أن يكون قائمة كائنات');
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('الحقل $key يجب أن يكون كائنًا');
}

Map<String, Object?>? _optionalMap(Object? value) {
  if (value == null) return null;
  if (value is Map) return Map<String, Object?>.from(value);
  throw const FormatException('الشجرة النحوية يجب أن تكون كائنًا');
}

SourceSpan? _optionalSpan(Object? value) => value == null
    ? null
    : SourceSpan.fromJson(Map<String, dynamic>.from(value as Map));
