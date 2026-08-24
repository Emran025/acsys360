import '../assist/language_catalog.dart';
import '../model/token.dart';

class LexerResult {
  final List<Token> tokens;
  final List<Diagnostic> diagnostics;

  const LexerResult(this.tokens, this.diagnostics);
}

class Lexer {
  static final keywords = LanguageCatalog.keywordSet;

  static const punctuation = {
    '{',
    '}',
    '(',
    ')',
    '[',
    ']',
    ';',
    '؛',
    ',',
    '،',
    '.',
    ':',
  };
  static const operators = {
    '+',
    '-',
    '*',
    '/',
    '%',
    r'\',
    '^',
    '&&',
    '||',
    '!',
    '=',
    '==',
    '!=',
    '=<',
    '=>',
    '<',
    '>',
  };

  final String source;
  int _offset = 0;
  int _line = 1;
  int _column = 1;

  Lexer(this.source);

  LexerResult scan() {
    final tokens = <Token>[];
    final diagnostics = <Diagnostic>[];
    while (!_atEnd) {
      _skipWhitespaceAndComments();
      if (_atEnd) break;
      final start = _position;
      final char = _peek;
      if (_isArabicLetter(char) || char == '_') {
        tokens.add(_identifier());
      } else if (_isDigit(char)) {
        tokens.add(_number(diagnostics, start));
      } else if (char == '"') {
        tokens.add(_string(diagnostics, start));
      } else if (char == '’' || char == '‘') {
        tokens.add(_character(diagnostics, start));
      } else if (punctuation.contains(char)) {
        _advance();
        final lexeme = switch (char) {
          '؛' => ';',
          '،' => ',',
          _ => char,
        };
        tokens.add(Token(TokenKind.punctuation, lexeme, start));
      } else {
        final pair = _peek + _peekNext;
        if (operators.contains(pair)) {
          _advance();
          _advance();
          tokens.add(Token(TokenKind.operator, pair, start));
        } else if (operators.contains(char)) {
          _advance();
          tokens.add(Token(TokenKind.operator, char, start));
        } else {
          diagnostics.add(Diagnostic('lexical', 'رمز غير معروف: $char', start));
          _advance();
        }
      }
    }
    tokens.add(Token(TokenKind.eof, '', _position));
    return LexerResult(tokens, diagnostics);
  }

  Token _identifier() {
    final start = _position;
    final buffer = StringBuffer();
    while (!_atEnd &&
        (_isArabicLetter(_peek) || _isDigit(_peek) || _peek == '_')) {
      buffer.write(_advance());
    }
    final value = buffer.toString();
    final kind = keywords.contains(value)
        ? (value == 'صح' || value == 'خطأ'
              ? TokenKind.boolean
              : TokenKind.keyword)
        : TokenKind.identifier;
    return Token(kind, value, start);
  }

  Token _number(List<Diagnostic> diagnostics, SourcePosition start) {
    final buffer = StringBuffer();
    while (!_atEnd && _isDigit(_peek)) buffer.write(_advance());
    var kind = TokenKind.integer;
    if (!_atEnd && _peek == '.' && _isDigit(_peekNext)) {
      kind = TokenKind.real;
      buffer.write(_advance());
      while (!_atEnd && _isDigit(_peek)) buffer.write(_advance());
    }
    return Token(kind, buffer.toString(), start);
  }

  Token _string(List<Diagnostic> diagnostics, SourcePosition start) {
    _advance();
    final buffer = StringBuffer();
    while (!_atEnd && _peek != '"') {
      if (_peek == '\n') _line++;
      buffer.write(_advance());
    }
    if (_atEnd) {
      diagnostics.add(Diagnostic('lexical', 'سلسلة نصية غير مغلقة', start));
    } else {
      _advance();
    }
    return Token(TokenKind.string, buffer.toString(), start);
  }

  Token _character(List<Diagnostic> diagnostics, SourcePosition start) {
    _advance();
    final value = _atEnd ? '' : _advance();
    if (_atEnd || !(_peek == '’' || _peek == '‘')) {
      diagnostics.add(Diagnostic('lexical', 'محرف غير مغلق', start));
    } else {
      _advance();
    }
    return Token(TokenKind.character, value, start);
  }

  void _skipWhitespaceAndComments() {
    while (!_atEnd) {
      if (_peek == '/' && _peekNext == '/') {
        while (!_atEnd && _peek != '\n') _advance();
      } else if (_peek.trim().isEmpty) {
        _advance();
      } else {
        break;
      }
    }
  }

  bool get _atEnd => _offset >= source.length;
  String get _peek => _atEnd ? '\u0000' : source[_offset];
  String get _peekNext =>
      _offset + 1 >= source.length ? '\u0000' : source[_offset + 1];
  SourcePosition get _position => SourcePosition(_offset, _line, _column);

  String _advance() {
    final value = source[_offset++];
    if (value == '\n') {
      _line++;
      _column = 1;
    } else {
      _column++;
    }
    return value;
  }

  bool _isDigit(String value) =>
      value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57;

  bool _isArabicLetter(String value) {
    if (value.isEmpty || value == '؛' || value == '،') return false;
    final code = value.codeUnitAt(0);
    return (code >= 0x0600 && code <= 0x06ff) ||
        (code >= 0x0750 && code <= 0x077f) ||
        (code >= 0x08a0 && code <= 0x08ff);
  }
}
