enum SourceTokenKind {
  identifier,
  keyword,
  integer,
  real,
  string,
  character,
  boolean,
  operator,
  punctuation,
  comment,
}

enum SourceTokenRole { variable, constant, type, procedure, parameter }

class SourceToken {
  final SourceTokenKind kind;
  final String lexeme;
  final int start;
  final int end;
  final SourceTokenRole? role;

  const SourceToken({
    required this.kind,
    required this.lexeme,
    required this.start,
    required this.end,
    this.role,
  });
}
