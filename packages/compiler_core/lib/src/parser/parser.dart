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
    if (_check(';')) _advance();
    _expectLexeme('{');
    final declarations = _declarations();
    final statements = _statementsUntil('}');
    _expectLexeme('}');
    _expectLexeme('.');
    return ParserResult(
      ProgramNode(start, name, declarations, statements),
      List.unmodifiable(diagnostics),
    );
  }

  List<AstNode> _declarations() {
    final result = <AstNode>[];
    while (_isDeclarationStart) {
      result.add(_declaration());
    }
    return result;
  }

  bool get _isDeclarationStart =>
      _check('ثابت') || _check('نوع') || _check('متغير') || _check('اجراء');

  AstNode _declaration() {
    if (_match('ثابت')) return _constantDeclaration(_previous.position);
    if (_match('نوع')) return _typeDeclaration(_previous.position);
    if (_match('متغير')) return _variableDeclaration(_previous.position);
    return _procedureDeclaration();
  }

  AstNode _constantDeclaration(SourcePosition start) {
    final name =
        _expect(TokenKind.identifier, 'اسم الثابت')?.lexeme ?? 'غير_معروف';
    _expectLexeme('=');
    final value = _constantValue();
    _expectLexeme(';');
    return ConstantDeclaration(start, name, value);
  }

  AstNode _typeDeclaration(SourcePosition start) {
    final name =
        _expect(TokenKind.identifier, 'اسم النوع')?.lexeme ?? 'غير_معروف';
    _expectLexeme('=');
    final type = _typeSpec();
    _expectLexeme(';');
    return TypeDeclaration(start, name, type);
  }

  AstNode _variableDeclaration(SourcePosition start) {
    final names = <String>[_expectIdentifier('اسم المتغير')];
    while (_match(',')) names.add(_expectIdentifier('اسم المتغير'));
    _expectLexeme(':');
    final type = _typeSpec();
    _expectLexeme(';');
    return VariableDeclaration(start, names, _typeName(type), typeSpec: type);
  }

  AstNode _procedureDeclaration() {
    final start = _expectLexeme('اجراء');
    final name = _expectIdentifier('اسم الإجراء');
    _expectLexeme('(');
    final parameters = _parameters();
    _expectLexeme(')');
    _expectLexeme(';');
    final body = _blockContents();
    _expectLexeme(';');
    return ProcedureDeclaration(start, name, parameters, body);
  }

  List<Parameter> _parameters() {
    final result = <Parameter>[];
    while (!_check(')') && !_checkKind(TokenKind.eof)) {
      final byReference = _match('بالمرجع');
      if (!byReference) _expectLexeme('بالقيمة');
      final names = <String>[_expectIdentifier('اسم المعامل')];
      while (_match(',')) names.add(_expectIdentifier('اسم المعامل'));
      _expectLexeme(':');
      final type = _typeSpec();
      final typeName = _typeName(type);
      for (final name in names) {
        result.add(
          Parameter(name, typeName, byReference: byReference, typeSpec: type),
        );
      }
      if (!_match(';') && !_match(',')) break;
    }
    return result;
  }

  TypeSpec _typeSpec() {
    if (_match('قائمة')) {
      _expectLexeme('[');
      final length =
          int.tryParse(
            _expect(TokenKind.integer, 'حجم القائمة')?.lexeme ?? '',
          ) ??
          0;
      _expectLexeme(']');
      _expectLexeme('من');
      return ArrayTypeSpec(length, _typeSpec());
    }
    if (_match('سجل')) {
      _expectLexeme('{');
      final fields = <FieldDeclaration>[];
      while (!_check('}') && !_checkKind(TokenKind.eof)) {
        final names = <String>[_expectIdentifier('اسم الحقل')];
        while (_match(',')) names.add(_expectIdentifier('اسم الحقل'));
        _expectLexeme(':');
        final type = _typeSpec();
        fields.add(FieldDeclaration(names, type));
        if (!_match(';')) break;
      }
      _expectLexeme('}');
      return RecordTypeSpec(fields);
    }
    Token? token;
    const primitiveTypes = {'صحيح', 'حقيقي', 'منطقي', 'حرفي', 'خيط_رمزي'};
    if (_checkKind(TokenKind.identifier) ||
        (_checkKind(TokenKind.keyword) &&
            primitiveTypes.contains(_current.lexeme))) {
      token = _advance();
    } else {
      _error(_current.position, 'متوقع نوع بيانات رسمي أو اسم نوع معرف');
      if (!_checkKind(TokenKind.eof)) _advance();
    }
    return NamedTypeSpec(token?.lexeme ?? 'غير_معروف');
  }

  String _typeName(TypeSpec type) {
    if (type is NamedTypeSpec) return type.name;
    if (type is ArrayTypeSpec) {
      return 'قائمة[${type.length}] من ${_typeName(type.elementType)}';
    }
    if (type is RecordTypeSpec) return 'سجل';
    return 'غير_معروف';
  }

  List<AstNode> _blockContents() {
    _expectLexeme('{');
    final result = <AstNode>[..._declarations()];
    result.addAll(_statementsUntil('}'));
    _expectLexeme('}');
    return result;
  }

  List<AstNode> _statementsUntil(String terminator) {
    final result = <AstNode>[];
    while (!_check(terminator) && !_checkKind(TokenKind.eof)) {
      final statement = _statement();
      if (statement != null) {
        result.add(statement);
      } else {
        _synchronize();
      }
    }
    return result;
  }

  AstNode? _statement() {
    if (_match(';')) return EmptyStatement(_previous.position);
    if (_check('اطبع')) {
      _advance();
      return _print(_previous.position);
    }
    if (_check('اقرا')) {
      _advance();
      return _read(_previous.position);
    }
    if (_check('اذا')) {
      _advance();
      return _if(_previous.position);
    }
    if (_check('طالما')) {
      _advance();
      return _while(_previous.position);
    }
    if (_check('كرر')) {
      _advance();
      return _repeat(_previous.position);
    }
    if (_check('اعد')) {
      _advance();
      return _repeatUntil(_previous.position);
    }
    if (_checkKind(TokenKind.identifier)) {
      if (_checkNext('=') || _checkNext('[') || _checkNext('.')) {
        return _assignment();
      }
      if (_checkNext('(')) return _call();
    }
    _error(_current.position, 'تعليمة غير متوقعة: ${_current.lexeme}');
    return null;
  }

  AstNode _assignment() {
    final name = _advance();
    final selectors = _selectors();
    _expectLexeme('=');
    final expression = _expression();
    _expectLexeme(';');
    return Assignment(
      name.position,
      name.lexeme,
      expression,
      selectors: selectors,
    );
  }

  AstNode _read(SourcePosition start) {
    _expectLexeme('(');
    final access = _access();
    _expectLexeme(')');
    _expectLexeme(';');
    return ReadStatement(start, access.name, selectors: access.selectors);
  }

  AstNode _print(SourcePosition start) {
    _expectLexeme('(');
    final values = <AstNode>[];
    if (!_check(')')) {
      values.add(_expression());
      while (_match(',')) values.add(_expression());
    }
    _expectLexeme(')');
    _expectLexeme(';');
    return PrintStatement(start, values);
  }

  AstNode _call() {
    final name = _advance();
    _expectLexeme('(');
    final arguments = <AstNode>[];
    if (!_check(')')) {
      arguments.add(_expression());
      while (_match(',')) arguments.add(_expression());
    }
    _expectLexeme(')');
    _expectLexeme(';');
    return CallStatement(name.position, name.lexeme, arguments);
  }

  AstNode _if(SourcePosition start) {
    _expectLexeme('(');
    final condition = _expression();
    _expectLexeme(')');
    _expectLexeme('فان');
    final thenBranch = _body();
    _match(';');
    if (!_match('والا')) {
      return IfStatement(start, condition, thenBranch, const []);
    }
    _match(';');
    final elseBranch = _match('اذا')
        ? <AstNode>[_if(_previous.position)]
        : _body();
    return IfStatement(start, condition, thenBranch, elseBranch);
  }

  AstNode _while(SourcePosition start) {
    _expectLexeme('(');
    final condition = _expression();
    _expectLexeme(')');
    _expectLexeme('استمر');
    return WhileStatement(start, condition, _body());
  }

  AstNode _repeat(SourcePosition start) {
    _expectLexeme('(');
    final variable = _expectIdentifier('متغير التكرار');
    _expectLexeme('=');
    final from = _expression();
    _expectLexeme('الى');
    final to = _expression();
    final step = _match('اضف') ? _expression() : null;
    _expectLexeme(')');
    return RepeatStatement(start, variable, from, to, step, _body());
  }

  AstNode _repeatUntil(SourcePosition start) {
    final body = _body();
    _expectLexeme('حتى');
    _expectLexeme('(');
    final condition = _expression();
    _expectLexeme(')');
    return RepeatUntilStatement(start, body, condition);
  }

  List<AstNode> _body() => _check('{')
      ? _blockContents()
      : <AstNode>[_statement() ?? EmptyStatement(_current.position)];

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
    if (_checkKind(TokenKind.identifier)) {
      final access = _access();
      return VariableReference(
        access.position,
        access.name,
        selectors: access.selectors,
      );
    }
    if (_match('(')) {
      final expression = _expression();
      _expectLexeme(')');
      return expression;
    }
    _error(_current.position, 'القيمة غير صالحة داخل التعبير');
    return Literal(_current.position, '0', TokenKind.integer);
  }

  _Access _access() {
    final token = _expect(TokenKind.identifier, 'اسم المتغير') ?? _current;
    return _Access(token.position, token.lexeme, _selectors());
  }

  List<AccessSelector> _selectors() {
    final result = <AccessSelector>[];
    while (true) {
      if (_match('[')) {
        final index = _expression();
        _expectLexeme(']');
        result.add(IndexSelector(index));
      } else if (_match('.')) {
        result.add(FieldSelector(_expectIdentifier('اسم الحقل')));
      } else {
        return result;
      }
    }
  }

  AstNode _constantValue() {
    if (_checkKind(TokenKind.identifier) && !_checkNext('(')) {
      final access = _access();
      return VariableReference(
        access.position,
        access.name,
        selectors: access.selectors,
      );
    }
    return _primary();
  }

  Token? _expect(TokenKind kind, String description) {
    if (_checkKind(kind)) return _advance();
    _error(_current.position, 'متوقع $description');
    return null;
  }

  SourcePosition _expectLexeme(String lexeme) {
    if (_match(lexeme)) return _previous.position;
    _error(_current.position, 'متوقع "$lexeme"');
    return _current.position;
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

  String _expectIdentifier(String description) =>
      _expect(TokenKind.identifier, description)?.lexeme ?? 'غير_معروف';

  bool _check(String lexeme) => _current.lexeme == lexeme;
  bool _checkNext(String lexeme) =>
      _index + 1 < tokens.length && tokens[_index + 1].lexeme == lexeme;
  bool _checkKind(TokenKind kind) => _current.kind == kind;

  Token get _current => tokens[_index.clamp(0, tokens.length - 1)];
  Token get _previous => tokens[(_index - 1).clamp(0, tokens.length - 1)];

  Token _advance() {
    final token = _current;
    if (_index < tokens.length - 1) _index++;
    return token;
  }

  void _error(SourcePosition position, String message) =>
      diagnostics.add(Diagnostic('syntax', message, position));

  void _synchronize() {
    while (!_checkKind(TokenKind.eof) && !_check(';') && !_check('}')) {
      _advance();
    }
    if (_check(';')) _advance();
  }
}

class _Access {
  final SourcePosition position;
  final String name;
  final List<AccessSelector> selectors;

  const _Access(this.position, this.name, this.selectors);
}
