enum TokenKind {
  identifier,
  keyword,
  integer,
  real,
  string,
  character,
  boolean,
  operator,
  punctuation,
  eof,
}

class SourcePosition {
  final int offset;
  final int line;
  final int column;

  const SourcePosition(this.offset, this.line, this.column);

  Map<String, Object> toJson() => {
    'offset': offset,
    'line': line,
    'column': column,
  };
}

class Diagnostic {
  final String phase;
  final String message;
  final SourcePosition position;

  const Diagnostic(this.phase, this.message, this.position);

  Map<String, Object> toJson() => {
    'phase': phase,
    'message': message,
    'position': position.toJson(),
  };
}

class Token {
  final TokenKind kind;
  final String lexeme;
  final SourcePosition position;

  const Token(this.kind, this.lexeme, this.position);

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'lexeme': lexeme,
    'position': position.toJson(),
  };
}
