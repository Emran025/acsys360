import 'dart:io';

import '../ast/ast.dart';

class NativeArtifactResult {
  final String? executablePath;
  final String sourcePath;
  final List<String> diagnostics;

  const NativeArtifactResult({
    required this.sourcePath,
    this.executablePath,
    this.diagnostics = const [],
  });

  bool get success => executablePath != null && diagnostics.isEmpty;
}

class DartNativeEmitter {
  DartNativeEmitter();

  final Map<String, String> _globalNames = {};
  final Map<String, String> _procedureNames = {};
  final Map<String, ProcedureDeclaration> _procedures = {};
  final Map<String, TypeSpec> _types = {};
  Map<String, String> _names = {};
  int _nameIndex = 0;
  int _indent = 0;

  String emit(ProgramNode program) {
    _reset(program);
    final out = <String>[];
    out.add("import 'dart:io';");
    out.add("import 'dart:math' as math;");
    out.add('');
    out.add('class _Box<T> {');
    out.add('  T value;');
    out.add('  _Box(this.value);');
    out.add('}');
    out.add('');
    out.add('dynamic _readValue() {');
    out.add('  final line = stdin.readLineSync();');
    out.add("  if (line == null) return 0;");
    out.add("  if (line == 'صح') return true;");
    out.add("  if (line == 'خطأ') return false;");
    out.add('  return num.tryParse(line!) ?? line;');
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

    _names = Map<String, String>.from(_globalNames);
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
      if (declaration is TypeDeclaration)
        _types[declaration.name] = declaration.type;
      if (declaration is ProcedureDeclaration) {
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
      return '$prefix${_lvalue(node.name, node.selectors)} = _readValue();';
    }
    if (node is PrintStatement) {
      return [
        for (final value in node.values)
          '${prefix}print(${_expression(value)});',
      ].join('\n');
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
      final result = <String>[
        '${prefix}for (dynamic $variable = $from, _step = $step; ; $variable += _step) {',
        '${'  ' * (_indent + 1)}if ((_step >= 0 && $variable > $to) || (_step < 0 && $variable < $to)) break;',
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
    if (procedure == null ||
        !procedure.parameters.any((item) => item.byReference)) {
      return '$prefix$name(${call.arguments.map(_expression).join(', ')});';
    }
    final result = <String>['${prefix}{'];
    final post = <String>[];
    final arguments = <String>[];
    for (var index = 0; index < call.arguments.length; index++) {
      final argument = call.arguments[index];
      final parameter = index < procedure.parameters.length
          ? procedure.parameters[index]
          : null;
      if (parameter?.byReference == true && argument is VariableReference) {
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
      final operator = switch (node.operator) {
        '=< ' => '<=',
        '=<' => '<=',
        '=>' => '>=',
        r'\' => '~/',
        '^' => '^',
        _ => node.operator,
      };
      if (node.operator == '^') return 'math.pow($left, $right)';
      return '($left $operator $right)';
    }
    return 'null';
  }

  String _lvalue(String name, List<AccessSelector> selectors) {
    var value = _names[name] ?? name;
    for (final selector in selectors) {
      if (selector is IndexSelector) {
        value = '$value[${_expression(selector.index)}]';
      } else if (selector is FieldSelector) {
        value = "$value['${selector.name}']";
      }
    }
    return value;
  }

  String _defaultValue(TypeSpec? spec, String? simple) {
    if (spec is NamedTypeSpec) {
      final alias = _types[spec.name];
      if (alias != null) return _defaultValue(alias, spec.name);
      return _defaultValue(null, spec.name);
    }
    if (spec is ArrayTypeSpec) {
      return 'List<dynamic>.filled(${spec.length}, ${_defaultValue(spec.elementType, null)})';
    }
    if (spec is RecordTypeSpec) {
      final fields = <String>[];
      for (final field in spec.fields) {
        for (final name in field.names) {
          fields.add("'$name': ${_defaultValue(field.type, null)}");
        }
      }
      return '{${fields.join(', ')}}';
    }
    return switch (simple) {
      'منطقي' => 'false',
      'حرفي' => "''",
      'خيط_رمزي' => "''",
      'حقيقي' => '0.0',
      _ => '0',
    };
  }

  String _literal(String value, dynamic type) {
    if (value == 'صح') return 'true';
    if (value == 'خطأ') return 'false';
    if (value.startsWith('"') ||
        value.startsWith("'") ||
        value.startsWith('‘')) {
      if (value.startsWith('‘') && value.endsWith('’')) {
        return "'${value.substring(1, value.length - 1)}'";
      }
      return value;
    }
    return value;
  }

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
    await File(sourcePath).writeAsString(DartNativeEmitter().emit(program));
    final process = await Process.run(dartExecutable, [
      'compile',
      'exe',
      sourcePath,
      '-o',
      executablePath,
    ], runInShell: Platform.isWindows);
    if (process.exitCode != 0 || !File(executablePath).existsSync()) {
      return NativeArtifactResult(
        sourcePath: sourcePath,
        diagnostics: ['فشل بناء native artifact: ${process.stderr}'.trim()],
      );
    }
    return NativeArtifactResult(
      sourcePath: sourcePath,
      executablePath: executablePath,
    );
  }
}
