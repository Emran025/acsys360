import 'dart:io';

import '../ast/ast.dart';
import '../model/token.dart';

class NativeArtifactResult {
  final String? executablePath;
  final String sourcePath;
  final List<String> diagnostics;
  final bool verified;

  const NativeArtifactResult({
    required this.sourcePath,
    this.executablePath,
    this.diagnostics = const [],
    this.verified = false,
  });

  bool get success => executablePath != null && diagnostics.isEmpty && verified;
}

class DartNativeEmitter {
  final Map<String, String> _globalNames = {};
  final Map<String, String> _procedureNames = {};
  final Map<String, ProcedureDeclaration> _procedures = {};
  final Map<String, TypeSpec> _types = {};
  Map<String, String> _names = {};
  int _nameIndex = 0;
  int _indent = 0;

  String emit(ProgramNode program) {
    _reset(program);
    _names = Map<String, String>.from(_globalNames);
    final out = <String>[];
    out.add("import 'dart:io';");
    out.add('');
    out.add('class _Box<T> {');
    out.add('  T value;');
    out.add('  _Box(this.value);');
    out.add('}');
    out.add('');
    out.add('dynamic _readValue(dynamic current) {');
    out.add('  final line = stdin.readLineSync();');
    out.add("  if (line == null) throw StateError('لا توجد قيمة إدخال');");
    out.add("  if (current is bool) {");
    out.add("    if (line == 'صح') return true;");
    out.add("    if (line == 'خطأ') return false;");
    out.add("    throw StateError('الإدخال المنطقي يجب أن يكون صح أو خطأ');");
    out.add('  }');
    out.add('  if (current is double) {');
    out.add('    final parsed = double.tryParse(line);');
    out.add(
      "    if (parsed == null) throw StateError('الإدخال الحقيقي غير صالح');",
    );
    out.add('    return parsed;');
    out.add('  }');
    out.add('  if (current is int) {');
    out.add('    final parsed = int.tryParse(line);');
    out.add(
      "    if (parsed == null) throw StateError('الإدخال الصحيح غير صالح');",
    );
    out.add('    return parsed;');
    out.add('  }');
    out.add('  return line;');
    out.add('}');
    out.add('');
    out.add('String _formatValue(dynamic value) =>');
    out.add("    value is bool ? (value ? 'صح' : 'خطأ') : '\u0024value';");
    out.add('void _printValues(List<dynamic> values) =>');
    out.add('    print(values.map(_formatValue).join(\' \'));');
    out.add('dynamic _arabicAdd(dynamic left, dynamic right) =>');
    out.add(
      "    left is String || right is String ? '\u0024left\u0024right' : left + right;",
    );
    out.add('num _asNum(dynamic value) {');
    out.add('  if (value is num) return value;');
    out.add("  throw StateError('القيمة ليست رقمية أثناء التنفيذ');");
    out.add('}');
    out.add('int _asInt(dynamic value) {');
    out.add('  if (value is int) return value;');
    out.add(
      '  if (value is num && value == value.truncate()) return value.toInt();',
    );
    out.add("  throw StateError('القيمة ليست عددًا صحيحًا أثناء التنفيذ');");
    out.add('}');
    out.add('num _arabicDivide(dynamic left, dynamic right) {');
    out.add('  final divisor = _asNum(right);');
    out.add("  if (divisor == 0) throw StateError('لا يمكن القسمة على صفر');");
    out.add('  return _asNum(left) / divisor;');
    out.add('}');
    out.add('int _arabicIntegerDivide(dynamic left, dynamic right) {');
    out.add('  final divisor = _asInt(right);');
    out.add(
      "  if (divisor == 0) throw StateError('لا يمكن القسمة الصحيحة على صفر');",
    );
    out.add('  return _asInt(left) ~/ divisor;');
    out.add('}');
    out.add('int _arabicRemainder(dynamic left, dynamic right) {');
    out.add('  final divisor = _asInt(right);');
    out.add(
      "  if (divisor == 0) throw StateError('لا يمكن حساب باقي القسمة على صفر');",
    );
    out.add('  return _asInt(left) % divisor;');
    out.add('}');
    out.add('num _arabicPow(dynamic left, dynamic right) {');
    out.add('  final base = _asNum(left);');
    out.add('  final exponent = _asInt(right);');
    out.add('  var result = 1.0;');
    out.add('  if (exponent < 0) {');
    out.add(
      '    for (var index = 0; index > exponent; index--) result /= base;',
    );
    out.add('  } else {');
    out.add(
      '    for (var index = 0; index < exponent; index++) result *= base;',
    );
    out.add('  }');
    out.add('  return result;');
    out.add('}');
    out.add('');

    for (final declaration in program.declarations) {
      if (declaration is VariableDeclaration) {
        for (final name in declaration.names) {
          out.add(
            'dynamic ${_globalNames[name]} = ${_defaultValue(declaration.typeSpec, declaration.type)};',
          );
        }
      } else if (declaration is ConstantDeclaration) {
        out.add(
          'final ${_globalNames[declaration.name]} = ${_expression(declaration.value)};',
        );
      }
    }
    if (_globalNames.isNotEmpty) out.add('');

    for (final declaration in program.declarations) {
      if (declaration is ProcedureDeclaration) {
        out.addAll(_procedure(declaration));
        out.add('');
      }
    }

    out.add('void main() {');
    _indent = 1;
    for (final statement in program.statements) {
      out.add(_statement(statement));
    }
    out.add('}');
    return out.join('\n');
  }

  void _reset(ProgramNode program) {
    _globalNames.clear();
    _procedureNames.clear();
    _procedures.clear();
    _types.clear();
    _names = {};
    _nameIndex = 0;
    for (final declaration in program.declarations) {
      if (declaration is TypeDeclaration) {
        _types[declaration.name] = declaration.type;
      } else if (declaration is ProcedureDeclaration) {
        _procedures[declaration.name] = declaration;
        _procedureNames[declaration.name] = 'p${_procedureNames.length}';
      }
    }
    for (final declaration in program.declarations) {
      if (declaration is VariableDeclaration) {
        for (final name in declaration.names) {
          _globalNames[name] = _newName();
        }
      } else if (declaration is ConstantDeclaration) {
        _globalNames[declaration.name] = _newName();
      }
    }
  }

  List<String> _procedure(ProcedureDeclaration procedure) {
    final previous = _names;
    _names = Map<String, String>.from(_globalNames);
    final parameters = <String>[];
    for (final parameter in procedure.parameters) {
      final dartName = _newName();
      _names[parameter.name] = parameter.byReference
          ? '$dartName.value'
          : dartName;
      final type = parameter.byReference ? '_Box<dynamic>' : 'dynamic';
      parameters.add('$type $dartName');
    }
    final result = <String>[
      'void ${_procedureNames[procedure.name]}(${parameters.join(', ')}) {',
    ];
    _indent = 1;
    for (final statement in procedure.body) {
      result.add(_statement(statement));
    }
    result.add('}');
    _names = previous;
    return result;
  }

  String _statement(AstNode node) {
    final prefix = '  ' * _indent;
    if (node is VariableDeclaration) {
      return [
        for (final name in node.names)
          '$prefix dynamic ${_declareLocal(name)} = ${_defaultValue(node.typeSpec, node.type)};',
      ].join('\n');
    }
    if (node is ConstantDeclaration) {
      final name = _declareLocal(node.name);
      return '$prefix final $name = ${_expression(node.value)};';
    }
    if (node is Assignment) {
      return '$prefix${_lvalue(node.name, node.selectors)} = ${_expression(node.expression)};';
    }
    if (node is ReadStatement) {
      final target = _lvalue(node.name, node.selectors);
      return '$prefix$target = _readValue($target);';
    }
    if (node is PrintStatement) {
      return '$prefix${'_printValues([${node.values.map(_expression).join(', ')}]);'}';
    }
    if (node is CallStatement) return _call(node, prefix);
    if (node is IfStatement) {
      final result = <String>['${prefix}if (${_expression(node.condition)}) {'];
      _indent++;
      result.addAll(node.thenBranch.map(_statement));
      _indent--;
      if (node.elseBranch.isNotEmpty) {
        result.add('$prefix} else {');
        _indent++;
        result.addAll(node.elseBranch.map(_statement));
        _indent--;
      }
      result.add('$prefix}');
      return result.join('\n');
    }
    if (node is WhileStatement) {
      final result = <String>[
        '${prefix}while (${_expression(node.condition)}) {',
      ];
      _indent++;
      result.addAll(node.body.map(_statement));
      _indent--;
      result.add('$prefix}');
      return result.join('\n');
    }
    if (node is RepeatStatement) {
      final variable = _names[node.variable] ?? _declareLocal(node.variable);
      final from = _expression(node.from);
      final to = _expression(node.to);
      final step = node.step == null ? '1' : _expression(node.step!);
      final stepName = '_step${_nameIndex++}';
      final result = <String>[
        '${prefix}final $stepName = _asInt($step);',
        '${prefix}if ($stepName == 0) throw StateError(\'خطوة التكرار لا يمكن أن تساوي صفرًا\');',
        '${prefix}for (dynamic $variable = _asInt($from); ; $variable += $stepName) {',
        '${'  ' * (_indent + 1)}if (($stepName >= 0 && $variable > _asInt($to)) || ($stepName < 0 && $variable < _asInt($to))) break;',
      ];
      _indent++;
      result.addAll(node.body.map(_statement));
      _indent--;
      result.add('$prefix}');
      return result.join('\n');
    }
    if (node is RepeatUntilStatement) {
      final result = <String>['${prefix}do {'];
      _indent++;
      result.addAll(node.body.map(_statement));
      _indent--;
      result.add('$prefix} while (!(${_expression(node.condition)}));');
      return result.join('\n');
    }
    return '${prefix}// empty';
  }

  String _call(CallStatement call, String prefix) {
    final procedure = _procedures[call.name];
    final name = _procedureNames[call.name] ?? call.name;
    if (procedure == null) {
      throw StateError('الإجراء "${call.name}" غير موجود في native backend');
    }
    if (procedure.parameters.length != call.arguments.length) {
      throw StateError('عدد معاملات الإجراء "${call.name}" غير صحيح');
    }
    if (!procedure.parameters.any((item) => item.byReference)) {
      return '$prefix$name(${call.arguments.map(_expression).join(', ')});';
    }
    final result = <String>['${prefix}{'];
    final post = <String>[];
    final arguments = <String>[];
    for (var index = 0; index < call.arguments.length; index++) {
      final argument = call.arguments[index];
      final parameter = procedure.parameters[index];
      if (parameter.byReference) {
        if (argument is! VariableReference) {
          throw StateError('معامل المرجع يجب أن يكون متغيرًا قابلًا للإسناد');
        }
        final box = '_box${index}_${_nameIndex++}';
        final target = _lvalue(argument.name, argument.selectors);
        result.add(
          '${'  ' * (_indent + 1)}final $box = _Box<dynamic>($target);',
        );
        arguments.add(box);
        post.add('${'  ' * (_indent + 1)}$target = $box.value;');
      } else {
        arguments.add(_expression(argument));
      }
    }
    result.add('${'  ' * (_indent + 1)}$name(${arguments.join(', ')});');
    result.addAll(post);
    result.add('$prefix}');
    return result.join('\n');
  }

  String _expression(AstNode node) {
    if (node is Literal) return _literal(node.value, node.type);
    if (node is VariableReference) return _lvalue(node.name, node.selectors);
    if (node is UnaryExpression) {
      final operand = _expression(node.operand);
      return node.operator == '!'
          ? '!($operand)'
          : '(${node.operator}$operand)';
    }
    if (node is BinaryExpression) {
      final left = _expression(node.left);
      final right = _expression(node.right);
      return switch (node.operator) {
        '+' => '_arabicAdd($left, $right)',
        r'\' => '_arabicIntegerDivide($left, $right)',
        '/' => '_arabicDivide($left, $right)',
        '%' => '_arabicRemainder($left, $right)',
        '^' => '_arabicPow($left, $right)',
        '=< ' => '($left <= $right)',
        '=<' => '($left <= $right)',
        '=>' => '($left >= $right)',
        _ => '($left ${node.operator} $right)',
      };
    }
    throw StateError('تعبير غير مدعوم في native backend');
  }

  String _lvalue(String name, List<AccessSelector> selectors) {
    var value = _names[name] ?? name;
    for (final selector in selectors) {
      if (selector is IndexSelector) {
        value = '$value[${_expression(selector.index)}]';
      } else if (selector is FieldSelector) {
        value = "$value['${_escapeDart(selector.name)}']";
      }
    }
    return value;
  }

  String _defaultValue(
    TypeSpec? spec,
    String? simple, [
    Set<String>? resolving,
  ]) {
    final active = resolving ?? <String>{};
    if (spec is NamedTypeSpec) {
      final builtin = _defaultSimple(spec.name);
      if (builtin != null) return builtin;
      final alias = _types[spec.name];
      if (alias == null) {
        throw StateError('النوع "${spec.name}" غير موجود في native backend');
      }
      if (!active.add(spec.name)) {
        throw StateError('مرجع دائري في النوع "${spec.name}"');
      }
      final result = _defaultValue(alias, null, active);
      active.remove(spec.name);
      return result;
    }
    if (spec is ArrayTypeSpec) {
      return 'List<dynamic>.generate(${spec.length}, (_) => ${_defaultValue(spec.elementType, null, active)})';
    }
    if (spec is RecordTypeSpec) {
      final fields = <String>[];
      for (final field in spec.fields) {
        for (final name in field.names) {
          fields.add(
            "'${_escapeDart(name)}': ${_defaultValue(field.type, null, active)}",
          );
        }
      }
      return '{${fields.join(', ')}}';
    }
    return _defaultSimple(simple) ?? '0';
  }

  String? _defaultSimple(String? type) => switch (type) {
    'منطقي' => 'false',
    'حرفي' => "''",
    'خيط_رمزي' => "''",
    'حقيقي' => '0.0',
    'صحيح' => '0',
    _ => null,
  };

  String _literal(String value, TokenKind type) => switch (type) {
    TokenKind.boolean when value == 'صح' => 'true',
    TokenKind.boolean when value == 'خطأ' => 'false',
    TokenKind.integer => value,
    TokenKind.real => value,
    TokenKind.string || TokenKind.character => "'${_escapeDart(value)}'",
    _ => "'${_escapeDart(value)}'",
  };

  String _escapeDart(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');

  String _declareLocal(String name) {
    final dartName = _newName();
    _names[name] = dartName;
    return dartName;
  }

  String _newName() => '_v${_nameIndex++}';
}

class DartNativeArtifactBuilder {
  const DartNativeArtifactBuilder();

  Future<NativeArtifactResult> build(
    ProgramNode program, {
    required String outputDirectory,
    String dartExecutable = 'dart',
    String executableName = 'arabic360_program',
  }) async {
    final directory = Directory(outputDirectory);
    await directory.create(recursive: true);
    final sourcePath =
        '${directory.path}${Platform.pathSeparator}$executableName.dart';
    final executablePath =
        '${directory.path}${Platform.pathSeparator}$executableName${Platform.isWindows ? '.exe' : ''}';
    try {
      await File(sourcePath).writeAsString(DartNativeEmitter().emit(program));
      final process = await Process.run(dartExecutable, [
        'compile',
        'exe',
        sourcePath,
        '-o',
        executablePath,
      ], runInShell: Platform.isWindows);
      final exists = File(executablePath).existsSync();
      if (process.exitCode != 0 || !exists) {
        return NativeArtifactResult(
          sourcePath: sourcePath,
          diagnostics: ['فشل بناء native artifact: ${process.stderr}'.trim()],
        );
      }
      final stat = await File(executablePath).stat();
      final executableBit = Platform.isWindows || (stat.mode & 0x49) != 0;
      if (!executableBit || stat.size == 0) {
        return NativeArtifactResult(
          sourcePath: sourcePath,
          diagnostics: ['تم إنشاء ملف غير قابل للتنفيذ: $executablePath'],
        );
      }
      return NativeArtifactResult(
        sourcePath: sourcePath,
        executablePath: executablePath,
        verified: true,
      );
    } on Object catch (error) {
      return NativeArtifactResult(
        sourcePath: sourcePath,
        diagnostics: ['فشل بناء native artifact: $error'],
      );
    }
  }
}
