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

enum SourceTokenGroup { declaration, controlFlow, builtin, type, modifier }

enum SourceTokenRole { variable, constant, type, procedure, parameter }

class SourceToken {
  final SourceTokenKind kind;
  final String lexeme;
  final int start;
  final int end;
  final SourceTokenRole? role;
  final SourceTokenGroup? group;

  const SourceToken({
    required this.kind,
    required this.lexeme,
    required this.start,
    required this.end,
    this.role,
    this.group,
  });
}
