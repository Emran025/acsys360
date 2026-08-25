import '../ast/ast.dart';
import '../model/token.dart';

class Symbol {
  final String name;
  final String type;
  final SourcePosition position;
  final String kind;
  final bool isConstant;
  final List<Parameter> parameters;
  final _SemanticType? semanticType;
  final Set<int> references = {};

  Symbol(
    this.name,
    this.type,
    this.position, {
    this.kind = 'variable',
    this.isConstant = false,
    this.parameters = const [],
    this.semanticType,
  });

  Map<String, Object?> toJson() => {
    'name': name,
    'kind': kind,
    'type': type,
    'mutable': !isConstant,
    if (parameters.isNotEmpty)
      'parameters': parameters.map((parameter) => parameter.toJson()).toList(),
    'declaredAt': position.toJson(),
    'references': references.toList()..sort(),
  };
}

class SemanticResult {
  final Map<String, Symbol> symbols;
  final List<Diagnostic> diagnostics;
  const SemanticResult(this.symbols, this.diagnostics);

  Map<String, Object?> toJson() => {
    'symbols': symbols.values.map((symbol) => symbol.toJson()).toList(),
    'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
  };
}

class SemanticAnalyzer {
  final symbols = <String, Symbol>{};
  final diagnostics = <Diagnostic>[];
  final _types = <String, _SemanticType>{};
  final _typeSpecs = <String, TypeSpec>{};
  final _externalSymbols = <String, Symbol>{};
  final _scopes = <Map<String, Symbol>>[];

  SemanticResult analyze(
    ProgramNode program, {
    Iterable<Symbol> externalSymbols = const [],
  }) {
    symbols.clear();
    diagnostics.clear();
    _types
      ..clear()
      ..addAll({
        'صحيح': _SemanticType.integer(),
        'حقيقي': _SemanticType.real(),
        'منطقي': _SemanticType.boolean(),
        'حرفي': _SemanticType.character(),
        'خيط_رمزي': _SemanticType.string(),
      });
    _typeSpecs.clear();
    _externalSymbols
      ..clear()
      ..addEntries(
        externalSymbols.map((symbol) => MapEntry(symbol.name, symbol)),
      );
    _scopes
      ..clear()
      ..add(symbols);
    _collectDeclarations(program.declarations);
    _visitStatements(program.statements);
    return SemanticResult(
      Map.unmodifiable(symbols),
      List.unmodifiable(diagnostics),
    );
  }

  void _collectDeclarations(Iterable<AstNode> declarations) {
    for (final declaration in declarations) {
      if (declaration is TypeDeclaration) {
        if (_types.containsKey(declaration.name) ||
            _typeSpecs.containsKey(declaration.name) ||
            symbols.containsKey(declaration.name)) {
          _error(
            declaration.position,
            'الاسم "${declaration.name}" معرف مسبقًا',
          );
        } else {
          _typeSpecs[declaration.name] = declaration.type;
        }
      }
    }
    for (final declaration in declarations) {
      if (declaration is TypeDeclaration &&
          !symbols.containsKey(declaration.name)) {
        final type = _resolveDeclaredType(
          declaration.name,
          declaration.position,
        );
        symbols[declaration.name] = Symbol(
          declaration.name,
          _typeName(declaration.type),
          declaration.position,
          kind: 'type',
          semanticType: type,
        );
      }
    }
    for (final declaration in declarations) {
      if (declaration is ConstantDeclaration) {
        _declare(
          declaration.name,
          _expressionType(declaration.value),
          declaration.position,
          kind: 'constant',
          isConstant: true,
        );
      } else if (declaration is VariableDeclaration) {
        final type = declaration.typeSpec == null
            ? _resolveTypeName(declaration.type)
            : _fromSpec(declaration.typeSpec!, declaration.position);
        _declareMany(
          declaration.names,
          declaration.typeSpec == null
              ? declaration.type
              : _typeName(declaration.typeSpec!),
          declaration.position,
          semanticType: type,
        );
      } else if (declaration is ProcedureDeclaration) {
        _declare(
          declaration.name,
          'اجراء',
          declaration.position,
          kind: 'procedure',
          parameters: declaration.parameters,
        );
      }
    }
  }

  void _declareMany(
    List<String> names,
    String type,
    SourcePosition position, {
    _SemanticType? semanticType,
  }) {
    for (final name in names) {
      _declare(name, type, position, semanticType: semanticType);
    }
  }

  void _declare(
    String name,
    String type,
    SourcePosition position, {
    String kind = 'variable',
    bool isConstant = false,
    List<Parameter> parameters = const [],
    _SemanticType? semanticType,
  }) {
    final scope = _scopes.last;
    if (scope.containsKey(name)) {
      _error(position, 'الاسم "$name" معرف مسبقًا');
      return;
    }
    scope[name] = Symbol(
      name,
      type,
      position,
      kind: kind,
      isConstant: isConstant,
      parameters: parameters,
      semanticType: semanticType ?? _resolveTypeName(type),
    );
  }

  void _visitStatements(Iterable<AstNode> statements) {
    for (final statement in statements) {
      if (statement is VariableDeclaration ||
          statement is ConstantDeclaration ||
          statement is TypeDeclaration) {
        _collectDeclarations([statement]);
      } else if (statement is ProcedureDeclaration) {
        _visitProcedure(statement);
      } else {
        _statement(statement);
      }
    }
  }

  void _visitProcedure(ProcedureDeclaration procedure) {
    final procedureSymbol = _lookup(procedure.name);
    _scopes.add(<String, Symbol>{});
    for (final parameter in procedure.parameters) {
      final type = parameter.typeSpec == null
          ? _resolveTypeName(parameter.type)
          : _fromSpec(parameter.typeSpec!, procedure.position);
      _declare(
        parameter.name,
        parameter.type,
        procedure.position,
        kind: 'parameter',
        semanticType: type,
      );
    }
    _visitStatements(procedure.body);
    _scopes.removeLast();
    procedureSymbol?.references.add(procedure.position.line);
  }

  void _statement(AstNode node) {
    if (node is Assignment) {
      final target = _accessType(node.name, node.selectors, node.position);
      final symbol = _lookup(node.name);
      if (symbol?.isConstant == true && node.selectors.isEmpty) {
        _error(node.position, 'لا يمكن إسناد قيمة إلى الثابت "${node.name}"');
      }
      final value = _expressionType(node.expression);
      _checkAssignable(target, value, node.position);
    } else if (node is ReadStatement) {
      _accessType(node.name, node.selectors, node.position);
      if (_lookup(node.name)?.isConstant == true) {
        _error(node.position, 'لا يمكن القراءة إلى الثابت "${node.name}"');
      }
    } else if (node is PrintStatement) {
      for (final value in node.values) _expressionType(value);
    } else if (node is CallStatement) {
      _call(node);
    } else if (node is IfStatement) {
      _requireType(
        node.condition,
        'منطقي',
        node.position,
        'شرط اذا يجب أن يكون منطقيًا',
      );
      _scopes.add(<String, Symbol>{});
      _visitStatements(node.thenBranch);
      _scopes.removeLast();
      _scopes.add(<String, Symbol>{});
      _visitStatements(node.elseBranch);
      _scopes.removeLast();
    } else if (node is WhileStatement) {
      _requireType(
        node.condition,
        'منطقي',
        node.position,
        'شرط طالما يجب أن يكون منطقيًا',
      );
      _scopes.add(<String, Symbol>{});
      _visitStatements(node.body);
      _scopes.removeLast();
    } else if (node is RepeatStatement) {
      _requireType(
        node.from,
        'صحيح',
        node.position,
        'بداية مجال التكرار يجب أن تكون صحيحة',
      );
      _requireType(
        node.to,
        'صحيح',
        node.position,
        'نهاية مجال التكرار يجب أن تكون صحيحة',
      );
      if (node.step != null) {
        _requireType(
          node.step!,
          'صحيح',
          node.position,
          'خطوة التكرار يجب أن تكون صحيحة',
        );
      }
      _requireTypeOfName(
        node.variable,
        'صحيح',
        node.position,
        'متغير التكرار يجب أن يكون صحيحًا',
      );
      _scopes.add(<String, Symbol>{});
      _visitStatements(node.body);
      _scopes.removeLast();
    } else if (node is RepeatUntilStatement) {
      _scopes.add(<String, Symbol>{});
      _visitStatements(node.body);
      _scopes.removeLast();
      _requireType(
        node.condition,
        'منطقي',
        node.position,
        'شرط حتى يجب أن يكون منطقيًا',
      );
    }
  }

  void _call(CallStatement call) {
    final symbol = _lookup(call.name);
    if (symbol == null) {
      _error(call.position, 'الإجراء "${call.name}" غير معرف');
      for (final argument in call.arguments) _expressionType(argument);
      return;
    }
    if (symbol.kind != 'procedure') {
      _error(call.position, '"${call.name}" ليس إجراءً');
      return;
    }
    symbol.references.add(call.position.line);
    if (symbol.parameters.length != call.arguments.length) {
      _error(
        call.position,
        'الإجراء "${call.name}" يتطلب ${symbol.parameters.length} معاملًا وليس ${call.arguments.length}',
      );
    }
    final count = symbol.parameters.length < call.arguments.length
        ? symbol.parameters.length
        : call.arguments.length;
    for (var index = 0; index < call.arguments.length; index++) {
      final argument = call.arguments[index];
      final actual = _expressionType(argument);
      if (index >= count) continue;
      final parameter = symbol.parameters[index];
      if (parameter.byReference && argument is! VariableReference) {
        _error(argument.position, 'المعامل بالمرجع يجب أن يكون متغير وصول');
      }
      final expected = parameter.typeSpec == null
          ? parameter.type
          : _fromSpec(parameter.typeSpec!, argument.position).name;
      _checkAssignable(expected, actual, argument.position);
    }
  }

  String _expressionType(AstNode node) {
    if (node is Literal) {
      return switch (node.type) {
        TokenKind.integer => 'صحيح',
        TokenKind.real => 'حقيقي',
        TokenKind.boolean => 'منطقي',
        TokenKind.character => 'حرفي',
        TokenKind.string => 'خيط_رمزي',
        _ => 'مجهول',
      };
    }
    if (node is VariableReference) {
      return _accessType(node.name, node.selectors, node.position);
    }
    if (node is UnaryExpression) {
      final operand = _expressionType(node.operand);
      if (node.operator == '!') {
        _requireType(
          node.operand,
          'منطقي',
          node.position,
          'العامل ! يتطلب قيمة منطقية',
        );
        return 'منطقي';
      }
      _requireNumeric(
        operand,
        node.position,
        'العامل الأحادي يتطلب قيمة رقمية',
      );
      return operand;
    }
    if (node is BinaryExpression) {
      final left = _expressionType(node.left);
      final right = _expressionType(node.right);
      if (node.operator == '&&' || node.operator == '||') {
        _requireTypeName(
          left,
          'منطقي',
          node.position,
          'العامل المنطقي يتطلب قيمًا منطقية',
        );
        _requireTypeName(
          right,
          'منطقي',
          node.position,
          'العامل المنطقي يتطلب قيمًا منطقية',
        );
        return 'منطقي';
      }
      if ({'==', '!=', '<', '>', '=<', '=>'}.contains(node.operator)) {
        _checkComparable(left, right, node.position);
        return 'منطقي';
      }
      _requireNumeric(left, node.position, 'العملية الحسابية تتطلب قيمة رقمية');
      _requireNumeric(
        right,
        node.position,
        'العملية الحسابية تتطلب قيمة رقمية',
      );
      if (node.operator == r'\' || node.operator == '%') return 'صحيح';
      if (node.operator == '/') return 'حقيقي';
      return left == 'حقيقي' || right == 'حقيقي' ? 'حقيقي' : 'صحيح';
    }
    return 'مجهول';
  }

  String _accessType(
    String name,
    List<AccessSelector> selectors,
    SourcePosition position,
  ) {
    final symbol = _lookup(name);
    if (symbol == null) {
      _error(position, 'المعرف "$name" غير معرف');
      return 'مجهول';
    }
    symbol.references.add(position.line);
    var type = symbol.semanticType ?? _resolveTypeName(symbol.type);
    for (final selector in selectors) {
      if (selector is IndexSelector) {
        _requireType(
          selector.index,
          'صحيح',
          position,
          'فهرس القائمة يجب أن يكون صحيحًا',
        );
        if (type.element == null) {
          _error(position, 'لا يمكن فهرسة النوع "${symbol.type}"');
          type = _SemanticType.unknown();
        } else {
          type = type.element!;
        }
      } else if (selector is FieldSelector) {
        final field = type.fields[selector.name];
        if (field == null) {
          _error(position, 'الحقل "${selector.name}" غير موجود في السجل');
          type = _SemanticType.unknown();
        } else {
          type = field;
        }
      }
    }
    return type.name;
  }

  Symbol? _lookup(String name) {
    for (final scope in _scopes.reversed) {
      final symbol = scope[name];
      if (symbol != null) return symbol;
    }
    return _externalSymbols[name];
  }

  _SemanticType _fromSpec(
    TypeSpec spec,
    SourcePosition position, [
    Set<String>? resolving,
  ]) {
    final active = resolving ?? <String>{};
    if (spec is NamedTypeSpec) {
      if (_types.containsKey(spec.name)) return _types[spec.name]!;
      if (_typeSpecs.containsKey(spec.name)) {
        return _resolveDeclaredType(spec.name, position, active);
      }
      final external = _externalSymbols[spec.name];
      if (external?.kind == 'type' && external?.semanticType != null) {
        return external!.semanticType!;
      }
      _error(position, 'النوع "${spec.name}" غير معرف');
      return _SemanticType.unknown();
    }
    if (spec is ArrayTypeSpec) {
      if (spec.length <= 0) {
        _error(position, 'حجم القائمة يجب أن يكون أكبر من صفر');
      }
      return _SemanticType.array(_fromSpec(spec.elementType, position, active));
    }
    if (spec is RecordTypeSpec) {
      final fields = <String, _SemanticType>{};
      for (final field in spec.fields) {
        final type = _fromSpec(field.type, position, active);
        for (final name in field.names) {
          if (fields.containsKey(name)) {
            _error(position, 'الحقل "$name" مكرر في السجل');
          } else {
            fields[name] = type;
          }
        }
      }
      return _SemanticType.record(fields);
    }
    return _SemanticType.unknown();
  }

  _SemanticType _resolveDeclaredType(
    String name,
    SourcePosition position, [
    Set<String>? resolving,
  ]) {
    final known = _types[name];
    if (known != null) return known;
    final spec = _typeSpecs[name];
    if (spec == null) {
      _error(position, 'النوع "$name" غير معرف');
      return _SemanticType.unknown();
    }
    final active = resolving ?? <String>{};
    if (!active.add(name)) {
      _error(position, 'مرجع دائري في تعريف النوع "$name"');
      return _SemanticType.unknown();
    }
    final resolved = _fromSpec(spec, position, active);
    active.remove(name);
    _types[name] = resolved;
    return resolved;
  }

  _SemanticType _resolveTypeName(String name) =>
      _types[name] ??
      (_typeSpecs.containsKey(name)
          ? _resolveDeclaredType(name, const SourcePosition(0, 1, 1))
          : _SemanticType.named(name));

  String _typeName(TypeSpec spec) {
    if (spec is NamedTypeSpec) return spec.name;
    if (spec is ArrayTypeSpec) {
      return 'قائمة[${spec.length}] من ${_typeName(spec.elementType)}';
    }
    return 'سجل';
  }

  void _requireType(
    AstNode node,
    String expected,
    SourcePosition position,
    String message,
  ) {
    _requireTypeName(_expressionType(node), expected, position, message);
  }

  void _requireTypeOfName(
    String name,
    String expected,
    SourcePosition position,
    String message,
  ) {
    _requireTypeName(
      _accessType(name, const [], position),
      expected,
      position,
      message,
    );
  }

  void _requireTypeName(
    String actual,
    String expected,
    SourcePosition position,
    String message,
  ) {
    if (actual != 'مجهول' && actual != expected)
      _error(position, '$message (وجد $actual)');
  }

  void _requireNumeric(String type, SourcePosition position, String message) {
    if (type != 'مجهول' && type != 'صحيح' && type != 'حقيقي')
      _error(position, '$message (وجد $type)');
  }

  void _checkComparable(String left, String right, SourcePosition position) {
    final numeric =
        (left == 'صحيح' || left == 'حقيقي') &&
        (right == 'صحيح' || right == 'حقيقي');
    if (!numeric && left != right && left != 'مجهول' && right != 'مجهول') {
      _error(position, 'لا يمكن مقارنة $left مع $right');
    }
  }

  void _checkAssignable(
    String expected,
    String actual,
    SourcePosition position,
  ) {
    if (expected == 'مجهول' || actual == 'مجهول' || expected == actual) return;
    if (expected == 'حقيقي' && actual == 'صحيح') return;
    _error(position, 'لا يمكن إسناد $actual إلى $expected');
  }

  void _error(SourcePosition position, String message) =>
      diagnostics.add(Diagnostic('semantic', message, position));
}

class _SemanticType {
  final String name;
  final _SemanticType? element;
  final Map<String, _SemanticType> fields;

  const _SemanticType._(this.name, {this.element, this.fields = const {}});

  const _SemanticType.integer() : this._('صحيح');
  const _SemanticType.real() : this._('حقيقي');
  const _SemanticType.boolean() : this._('منطقي');
  const _SemanticType.character() : this._('حرفي');
  const _SemanticType.string() : this._('خيط_رمزي');
  const _SemanticType.unknown() : this._('مجهول');
  const _SemanticType.named(String name) : this._(name);
  const _SemanticType.array(_SemanticType element)
    : this._('قائمة', element: element);
  const _SemanticType.record(Map<String, _SemanticType> fields)
    : this._('سجل', fields: fields);
}
