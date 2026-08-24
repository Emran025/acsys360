import '../ast/ast.dart';
import '../model/token.dart';

class ParserResult {
  final ProgramNode? program;
  final List<Diagnostic> diagnostics;
  const ParserResult(this.program, this.diagnostics);
}

class Parser {
  final List<Token> tokens;
  int _index = 0;
  final diagnostics = <Diagnostic>[];

  Parser(this.tokens);

  ParserResult parse() {
    final start = _current.position;
    _expectLexeme('برنامج');
    final name =
        _expect(TokenKind.identifier, 'اسم البرنامج')?.lexeme ?? 'غير_معروف';
    _expectLexeme('{');
    final declarations = <AstNode>[];
    while (_isDeclarationStart) declarations.add(_declaration());
    final statements = <AstNode>[];
    while (!_check('}') && !_checkKind(TokenKind.eof)) {
      final statement = _statement();
      if (statement != null)
        statements.add(statement);
      else
        _synchronize();
    }
    _expectLexeme('}');
    _expectLexeme('.');
    return ParserResult(
      ProgramNode(start, name, declarations, statements),
      diagnostics,
    );
  }

  bool get _isDeclarationStart => _check('متغير');

  AstNode _declaration() {
    final start = _current.position;
    _advance();
    final names = <String>[];
    do {
      names.add(
        _expect(TokenKind.identifier, 'اسم المتغير')?.lexeme ?? 'غير_معروف',
      );
    } while (_match(','));
    _expectLexeme(':');
    final type =
        _expect(TokenKind.keyword, 'نوع البيانات')?.lexeme ?? 'غير_معروف';
    _expectLexeme(';');
    return VariableDeclaration(start, names, type);
  }

  AstNode? _statement() {
    if (_checkKind(TokenKind.identifier) && _checkNext('='))
      return _assignment();
    if (_match('اطبع')) return _print(_previous.position);
    if (_match('اقرا')) return _read(_previous.position);
    if (_match('اذا')) return _if(_previous.position);
    if (_match('طالما')) return _while(_previous.position);
    _error(_current.position, 'تعليمة غير متوقعة: ${_current.lexeme}');
    return null;
  }

  AstNode _assignment() {
    final name = _advance();
    _expectLexeme('=');
    final expression = _expression();
    _expectLexeme(';');
    return Assignment(name.position, name.lexeme, expression);
  }

  AstNode _print(SourcePosition start) {
    _expectLexeme('(');
    final values = <AstNode>[_expression()];
    while (_match(',')) values.add(_expression());
    _expectLexeme(')');
    _expectLexeme(';');
    return PrintStatement(start, values);
  }

  AstNode _read(SourcePosition start) {
    _expectLexeme('(');
    final name = _expect(TokenKind.identifier, 'متغير الإدخال');
    _expectLexeme(')');
    _expectLexeme(';');
    return Assignment(
      start,
      name?.lexeme ?? 'غير_معروف',
      Literal(start, 'input', TokenKind.string),
    );
  }

  AstNode _if(SourcePosition start) {
    _expectLexeme('(');
    final condition = _expression();
    _expectLexeme(')');
    _expectLexeme('فان');
    final thenBranch = _block();
    final elseBranch = _match('والا') ? _block() : <AstNode>[];
    return IfStatement(start, condition, thenBranch, elseBranch);
  }

  AstNode _while(SourcePosition start) {
    _expectLexeme('(');
    final condition = _expression();
    _expectLexeme(')');
    _expectLexeme('استمر');
    return WhileStatement(start, condition, _block());
  }

  List<AstNode> _block() {
    _expectLexeme('{');
    final result = <AstNode>[];
    while (!_check('}') && !_checkKind(TokenKind.eof)) {
      final statement = _statement();
      if (statement != null)
        result.add(statement);
      else
        _synchronize();
    }
    _expectLexeme('}');
    return result;
  }

  AstNode _expression() => _logicalOr();
  AstNode _logicalOr() => _binary(_logicalAnd, {'||'});
  AstNode _logicalAnd() => _binary(_equality, {'&&'});
  AstNode _equality() => _binary(_comparison, {'==', '!='});
  AstNode _comparison() => _binary(_term, {'<', '>', '=<', '=>'});
  AstNode _term() => _binary(_factor, {'+', '-'});
  AstNode _factor() => _binary(_unary, {'*', '/', '%', r'\', '^'});

  AstNode _binary(AstNode Function() next, Set<String> operators) {
    var left = next();
    while (operators.contains(_current.lexeme)) {
      final operator = _advance();
      final right = next();
      left = BinaryExpression(operator.position, left, operator.lexeme, right);
    }
    return left;
  }

  AstNode _unary() {
    if (_match('!', '-', '+')) {
      final operator = _previous;
      return UnaryExpression(operator.position, operator.lexeme, _unary());
    }
    return _primary();
  }

  AstNode _primary() {
    if (_matchKind(
      TokenKind.integer,
      TokenKind.real,
      TokenKind.string,
      TokenKind.character,
      TokenKind.boolean,
    )) {
      return Literal(_previous.position, _previous.lexeme, _previous.kind);
    }
    if (_matchKind(TokenKind.identifier))
      return VariableReference(_previous.position, _previous.lexeme);
    if (_match('(')) {
      final expression = _expression();
      _expectLexeme(')');
      return expression;
    }
    _error(_current.position, 'القيمة غير صالحة داخل التعبير');
    return Literal(_current.position, '0', TokenKind.integer);
  }

  Token? _expect(TokenKind kind, String description) {
    if (_checkKind(kind)) return _advance();
    _error(_current.position, 'متوقع $description');
    return null;
  }

  void _expectLexeme(String lexeme) {
    if (!_match(lexeme)) _error(_current.position, 'متوقع "$lexeme"');
  }

  bool _match(String lexeme, [String? second, String? third]) {
    final accepted = {
      lexeme,
      if (second != null) second,
      if (third != null) third,
    };
    if (accepted.contains(_current.lexeme)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _matchKind(
    TokenKind first, [
    TokenKind? second,
    TokenKind? third,
    TokenKind? fourth,
    TokenKind? fifth,
  ]) {
    final accepted = {
      first,
      if (second != null) second,
      if (third != null) third,
      if (fourth != null) fourth,
      if (fifth != null) fifth,
    };
    if (accepted.contains(_current.kind)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _check(String lexeme) => _current.lexeme == lexeme;
  bool _checkNext(String lexeme) =>
      _index + 1 < tokens.length && tokens[_index + 1].lexeme == lexeme;
  bool _checkKind(TokenKind kind) => _current.kind == kind;
  Token get _current =>
      tokens[_index < tokens.length ? _index : tokens.length - 1];
  Token get _previous => tokens[_index - 1];
  Token _advance() => tokens[_index++];

  void _error(SourcePosition position, String message) =>
      diagnostics.add(Diagnostic('syntax', message, position));

  void _synchronize() {
    while (!_checkKind(TokenKind.eof) && !_check(';') && !_check('}'))
      _advance();
    if (_check(';')) _advance();
  }
}
