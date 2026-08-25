import '../ast/ast.dart';
import '../model/token.dart';

class ExecutionResult {
  final List<String> output;
  final List<String> diagnostics;

  const ExecutionResult({this.output = const [], this.diagnostics = const []});

  bool get success => diagnostics.isEmpty;
}

class Interpreter {
  final int maxSteps;
  const Interpreter({this.maxSteps = 100000});

  ExecutionResult execute(
    ProgramNode program, {
    Iterable<String> input = const [],
    Iterable<ProcedureDeclaration> externalProcedures = const [],
    Map<String, TypeSpec> externalTypes = const {},
  }) {
    final output = <String>[];
    final diagnostics = <String>[];
    final environment = _Environment();
    final procedures = <String, ProcedureDeclaration>{
      for (final procedure in externalProcedures) procedure.name: procedure,
    };
    final types = <String, TypeSpec>{...externalTypes};
    final inputIterator = input.iterator;
    var steps = 0;

    try {
      for (final declaration in program.declarations) {
        if (declaration is TypeDeclaration) {
          types[declaration.name] = declaration.type;
        } else if (declaration is ProcedureDeclaration) {
          procedures[declaration.name] = declaration;
        }
      }
      for (final declaration in program.declarations) {
        if (declaration is ConstantDeclaration) {
          environment.define(
            declaration.name,
            _eval(declaration.value, environment),
            constant: true,
          );
        } else if (declaration is VariableDeclaration) {
          for (final name in declaration.names) {
            environment.define(
              name,
              _defaultValue(declaration.typeSpec, types),
            );
          }
        }
      }
      _executeStatements(
        program.statements,
        environment,
        procedures,
        types,
        output,
        inputIterator,
        () => ++steps,
      );
    } on _ExecutionException catch (error) {
      diagnostics.add(error.message);
    } catch (error) {
      diagnostics.add('خطأ تنفيذ غير متوقع: $error');
    }
    return ExecutionResult(output: output, diagnostics: diagnostics);
  }

  void _executeStatements(
    Iterable<AstNode> statements,
    _Environment environment,
    Map<String, ProcedureDeclaration> procedures,
    Map<String, TypeSpec> types,
    List<String> output,
    Iterator<String> input,
    int Function() tick,
  ) {
    for (final statement in statements) {
      if (tick() > maxSteps) {
        throw const _ExecutionException('تجاوز البرنامج حد التنفيذ');
      }
      _execute(statement, environment, procedures, types, output, input, tick);
    }
  }

  void _execute(
    AstNode node,
    _Environment environment,
    Map<String, ProcedureDeclaration> procedures,
    Map<String, TypeSpec> types,
    List<String> output,
    Iterator<String> input,
    int Function() tick,
  ) {
    if (node is VariableDeclaration) {
      for (final name in node.names) {
        environment.define(name, _defaultValue(node.typeSpec, types));
      }
      return;
    }
    if (node is ConstantDeclaration) {
      environment.define(
        node.name,
        _eval(node.value, environment),
        constant: true,
      );
      return;
    }
    if (node is Assignment) {
      _writeAccess(
        environment,
        node.name,
        node.selectors,
        _eval(node.expression, environment),
      );
      return;
    }
    if (node is ReadStatement) {
      if (!input.moveNext()) {
        throw const _ExecutionException('لا توجد قيمة إدخال لتعليمة اقرا');
      }
      final current = _readAccess(environment, node.name, node.selectors);
      _writeAccess(
        environment,
        node.name,
        node.selectors,
        _parseInput(input.current, current),
      );
      return;
    }
    if (node is PrintStatement) {
      output.add(
        node.values
            .map((value) => _format(_eval(value, environment)))
            .join(' '),
      );
      return;
    }
    if (node is CallStatement) {
      _call(node, environment, procedures, types, output, input, tick);
      return;
    }
    if (node is IfStatement) {
      final branch = _truthy(_eval(node.condition, environment))
          ? node.thenBranch
          : node.elseBranch;
      _executeStatements(
        branch,
        environment,
        procedures,
        types,
        output,
        input,
        tick,
      );
      return;
    }
    if (node is WhileStatement) {
      while (_truthy(_eval(node.condition, environment))) {
        if (tick() > maxSteps) {
          throw const _ExecutionException('حلقة لا نهائية أو طويلة جدًا');
        }
        _executeStatements(
          node.body,
          environment,
          procedures,
          types,
          output,
          input,
          tick,
        );
      }
      return;
    }
    if (node is RepeatStatement) {
      final start = _asInt(_eval(node.from, environment));
      final end = _asInt(_eval(node.to, environment));
      final step = node.step == null
          ? 1
          : _asInt(_eval(node.step!, environment));
      if (step == 0) {
        throw const _ExecutionException('خطوة التكرار لا يمكن أن تساوي صفرًا');
      }
      _writeAccess(environment, node.variable, const [], start);
      var current = start;
      while (step > 0 ? current <= end : current >= end) {
        if (tick() > maxSteps) {
          throw const _ExecutionException('حلقة لا نهائية أو طويلة جدًا');
        }
        _executeStatements(
          node.body,
          environment,
          procedures,
          types,
          output,
          input,
          tick,
        );
        current += step;
        _writeAccess(environment, node.variable, const [], current);
      }
      return;
    }
    if (node is RepeatUntilStatement) {
      do {
        if (tick() > maxSteps) {
          throw const _ExecutionException('حلقة لا نهائية أو طويلة جدًا');
        }
        _executeStatements(
          node.body,
          environment,
          procedures,
          types,
          output,
          input,
          tick,
        );
      } while (!_truthy(_eval(node.condition, environment)));
    }
  }

  void _call(
    CallStatement call,
    _Environment caller,
    Map<String, ProcedureDeclaration> procedures,
    Map<String, TypeSpec> types,
    List<String> output,
    Iterator<String> input,
    int Function() tick,
  ) {
    final procedure = procedures[call.name];
    if (procedure == null) {
      throw _ExecutionException('الإجراء "${call.name}" غير موجود');
    }
    if (procedure.parameters.length != call.arguments.length) {
      throw _ExecutionException('عدد معاملات الإجراء "${call.name}" غير صحيح');
    }
    final local = _Environment(parent: caller);
    for (var index = 0; index < procedure.parameters.length; index++) {
      final parameter = procedure.parameters[index];
      final argument = call.arguments[index];
      final cell = parameter.byReference && argument is VariableReference
          ? _referenceCell(caller, argument)
          : _Cell(_eval(argument, caller));
      local.defineCell(parameter.name, cell);
    }
    _executeStatements(
      procedure.body,
      local,
      procedures,
      types,
      output,
      input,
      tick,
    );
  }

  _Cell _referenceCell(_Environment environment, VariableReference reference) {
    if (reference.selectors.isEmpty) {
      final cell = environment.cell(reference.name);
      if (cell == null) {
        throw _ExecutionException(
          'المعرف "${reference.name}" غير موجود أثناء التنفيذ',
        );
      }
      return cell;
    }
    return _Cell(
      null,
      getter: () =>
          _readAccess(environment, reference.name, reference.selectors),
      setter: (value) =>
          _writeAccess(environment, reference.name, reference.selectors, value),
    );
  }

  dynamic _eval(AstNode node, _Environment environment) {
    if (node is Literal) {
      return switch (node.type) {
        TokenKind.integer =>
          int.tryParse(node.value) ??
              (throw _ExecutionException(
                'قيمة صحيحة غير صالحة: ${node.value}',
              )),
        TokenKind.real =>
          double.tryParse(node.value) ??
              (throw _ExecutionException(
                'قيمة حقيقية غير صالحة: ${node.value}',
              )),
        TokenKind.boolean =>
          node.value == 'صح'
              ? true
              : node.value == 'خطأ'
              ? false
              : (throw _ExecutionException(
                  'قيمة منطقية غير صالحة: ${node.value}',
                )),
        TokenKind.character || TokenKind.string => node.value,
        _ => node.value,
      };
    }
    if (node is VariableReference) {
      return _readAccess(environment, node.name, node.selectors);
    }
    if (node is UnaryExpression) {
      final value = _eval(node.operand, environment);
      return switch (node.operator) {
        '!' => !_truthy(value),
        '-' => -_asNum(value),
        '+' => _asNum(value),
        _ => throw _ExecutionException(
          'عامل أحادي غير مدعوم: ${node.operator}',
        ),
      };
    }
    if (node is BinaryExpression) {
      final left = _eval(node.left, environment);
      final right = _eval(node.right, environment);
      return switch (node.operator) {
        '+' =>
          left is String || right is String
              ? '$left$right'
              : _asNum(left) + _asNum(right),
        '-' => _asNum(left) - _asNum(right),
        '*' => _asNum(left) * _asNum(right),
        '/' => _divide(left, right),
        r'\' => _integerDivide(left, right),
        '%' => _remainder(left, right),
        '^' => _pow(_asNum(left), _asNum(right)),
        '&&' => _truthy(left) && _truthy(right),
        '||' => _truthy(left) || _truthy(right),
        '==' => left == right,
        '!=' => left != right,
        '<' => _asNum(left) < _asNum(right),
        '>' => _asNum(left) > _asNum(right),
        '=<' => _asNum(left) <= _asNum(right),
        '=>' => _asNum(left) >= _asNum(right),
        _ => throw _ExecutionException(
          'عامل ثنائي غير مدعوم: ${node.operator}',
        ),
      };
    }
    throw const _ExecutionException('تعبير غير قابل للتنفيذ');
  }

  dynamic _divide(dynamic left, dynamic right) {
    final divisor = _asNum(right);
    if (divisor == 0) {
      throw const _ExecutionException('لا يمكن القسمة على صفر');
    }
    return _asNum(left) / divisor;
  }

  int _integerDivide(dynamic left, dynamic right) {
    final divisor = _asInt(right);
    if (divisor == 0) {
      throw const _ExecutionException('لا يمكن القسمة الصحيحة على صفر');
    }
    return _asInt(left) ~/ divisor;
  }

  int _remainder(dynamic left, dynamic right) {
    final divisor = _asInt(right);
    if (divisor == 0) {
      throw const _ExecutionException('لا يمكن حساب باقي القسمة على صفر');
    }
    return _asInt(left) % divisor;
  }

  dynamic _readAccess(
    _Environment environment,
    String name,
    List<AccessSelector> selectors,
  ) {
    final cell = environment.cell(name);
    if (cell == null) {
      throw _ExecutionException('المعرف "$name" غير موجود أثناء التنفيذ');
    }
    dynamic value = cell.read();
    for (final selector in selectors) {
      if (selector is IndexSelector) {
        if (value is! List<dynamic>) {
          throw _ExecutionException('لا يمكن فهرسة قيمة غير قائمة في "$name"');
        }
        final index = _asInt(_eval(selector.index, environment));
        if (index < 0 || index >= value.length) {
          throw _ExecutionException('فهرس خارج حدود القائمة في "$name"');
        }
        value = value[index];
      } else if (selector is FieldSelector) {
        if (value is! Map<String, dynamic>) {
          throw _ExecutionException('لا يمكن الوصول إلى حقل في قيمة غير سجل');
        }
        if (!value.containsKey(selector.name)) {
          throw _ExecutionException(
            'الحقل "${selector.name}" غير موجود أثناء التنفيذ',
          );
        }
        value = value[selector.name];
      }
    }
    return value;
  }

  void _writeAccess(
    _Environment environment,
    String name,
    List<AccessSelector> selectors,
    dynamic value,
  ) {
    final cell = environment.cell(name);
    if (cell == null) {
      throw _ExecutionException('المعرف "$name" غير موجود أثناء التنفيذ');
    }
    if (selectors.isEmpty) {
      cell.write(value);
      return;
    }
    dynamic target = cell.read();
    for (var index = 0; index < selectors.length - 1; index++) {
      final selector = selectors[index];
      if (selector is IndexSelector) {
        if (target is! List<dynamic>) {
          throw _ExecutionException('لا يمكن فهرسة قيمة غير قائمة في "$name"');
        }
        final itemIndex = _asInt(_eval(selector.index, environment));
        if (itemIndex < 0 || itemIndex >= target.length) {
          throw _ExecutionException('فهرس خارج حدود القائمة في "$name"');
        }
        target = target[itemIndex];
      } else if (selector is FieldSelector) {
        if (target is! Map<String, dynamic> ||
            !target.containsKey(selector.name)) {
          throw _ExecutionException(
            'الحقل "${selector.name}" غير موجود أثناء التنفيذ',
          );
        }
        target = target[selector.name];
      }
    }
    final last = selectors.last;
    if (last is IndexSelector) {
      if (target is! List<dynamic>) {
        throw _ExecutionException('لا يمكن إسناد فهرس إلى قيمة غير قائمة');
      }
      final itemIndex = _asInt(_eval(last.index, environment));
      if (itemIndex < 0 || itemIndex >= target.length) {
        throw _ExecutionException('فهرس خارج حدود القائمة في "$name"');
      }
      target[itemIndex] = value;
    } else if (last is FieldSelector) {
      if (target is! Map<String, dynamic> || !target.containsKey(last.name)) {
        throw _ExecutionException(
          'الحقل "${last.name}" غير موجود أثناء التنفيذ',
        );
      }
      target[last.name] = value;
    }
  }

  dynamic _defaultValue(
    TypeSpec? type,
    Map<String, TypeSpec> aliases, [
    Set<String>? resolving,
  ]) {
    final active = resolving ?? <String>{};
    if (type is ArrayTypeSpec) {
      return List<dynamic>.filled(
        type.length,
        _defaultValue(type.elementType, aliases, active),
      );
    }
    if (type is RecordTypeSpec) {
      final result = <String, dynamic>{};
      for (final field in type.fields) {
        for (final name in field.names) {
          result[name] = _defaultValue(field.type, aliases, active);
        }
      }
      return result;
    }
    if (type is NamedTypeSpec) {
      switch (type.name) {
        case 'حقيقي':
          return 0.0;
        case 'منطقي':
          return false;
        case 'حرفي':
        case 'خيط_رمزي':
          return '';
        case 'صحيح':
          return 0;
      }
      final alias = aliases[type.name];
      if (alias == null) {
        throw _ExecutionException(
          'النوع "${type.name}" غير موجود أثناء التنفيذ',
        );
      }
      if (!active.add(type.name)) {
        throw _ExecutionException('مرجع دائري في النوع "${type.name}"');
      }
      final result = _defaultValue(alias, aliases, active);
      active.remove(type.name);
      return result;
    }
    throw const _ExecutionException('نوع متغير غير قابل للتنفيذ');
  }

  dynamic _parseInput(String value, dynamic current) {
    if (current is bool) {
      if (value == 'صح') return true;
      if (value == 'خطأ') return false;
      throw const _ExecutionException('الإدخال المنطقي يجب أن يكون صح أو خطأ');
    }
    if (current is double) {
      final parsed = double.tryParse(value);
      if (parsed == null)
        throw const _ExecutionException('الإدخال الحقيقي غير صالح');
      return parsed;
    }
    if (current is int) {
      final parsed = int.tryParse(value);
      if (parsed == null)
        throw const _ExecutionException('الإدخال الصحيح غير صالح');
      return parsed;
    }
    if (current is String) return value;
    throw const _ExecutionException('نوع الإدخال غير مدعوم');
  }

  num _asNum(dynamic value) {
    if (value is num) return value;
    throw const _ExecutionException('القيمة ليست رقمية أثناء التنفيذ');
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num && value == value.truncate()) return value.toInt();
    throw const _ExecutionException('القيمة ليست عددًا صحيحًا أثناء التنفيذ');
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    throw const _ExecutionException('شرط التنفيذ ليس قيمة منطقية');
  }

  num _pow(num left, num right) {
    final exponent = _asInt(right);
    if (exponent < 0) {
      var result = 1.0;
      for (var index = 0; index > exponent; index--) result /= left;
      return result;
    }
    var result = 1.0;
    for (var index = 0; index < exponent; index++) result *= left;
    return result;
  }

  String _format(dynamic value) {
    if (value is bool) return value ? 'صح' : 'خطأ';
    return '$value';
  }
}

class _Environment {
  final _Environment? parent;
  final Map<String, _Cell> _cells = {};

  _Environment({this.parent});

  void define(String name, dynamic value, {bool constant = false}) =>
      _cells[name] = _Cell(value, constant: constant);

  void defineCell(String name, _Cell cell) => _cells[name] = cell;

  _Cell? cell(String name) => _cells[name] ?? parent?.cell(name);
}

class _Cell {
  dynamic value;
  final bool constant;
  final dynamic Function()? getter;
  final void Function(dynamic value)? setter;

  _Cell(this.value, {this.constant = false, this.getter, this.setter});

  dynamic read() => getter == null ? value : getter!();

  void write(dynamic next) {
    if (constant) {
      throw const _ExecutionException('لا يمكن تغيير قيمة ثابت أثناء التنفيذ');
    }
    if (setter != null) {
      setter!(next);
    } else {
      value = next;
    }
  }
}

class _ExecutionException implements Exception {
  final String message;
  const _ExecutionException(this.message);
}
