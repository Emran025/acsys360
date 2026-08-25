import '../model/token.dart';

class IrType {
  final String name;
  const IrType(this.name);

  static const integer = IrType('صحيح');
  static const real = IrType('حقيقي');
  static const boolean = IrType('منطقي');
  static const character = IrType('حرفي');
  static const string = IrType('خيط_رمزي');
  static const unknown = IrType('مجهول');

  static IrType fromName(String name) => switch (name) {
    'صحيح' => integer,
    'حقيقي' => real,
    'منطقي' => boolean,
    'حرفي' => character,
    'خيط_رمزي' => string,
    _ => unknown,
  };
}

enum IrOpcode {
  label,
  assign,
  unary,
  binary,
  jump,
  branchFalse,
  call,
  print,
  read,
  returnOp,
}

extension IrOpcodeName on IrOpcode {
  String get value => this == IrOpcode.returnOp ? 'return' : name;
}

class IrInstruction {
  final IrOpcode opcode;
  final String? result;
  final String? left;
  final String? operator;
  final String? right;
  final String? target;
  final IrType type;
  final SourcePosition? position;

  const IrInstruction({
    required this.opcode,
    this.result,
    this.left,
    this.operator,
    this.right,
    this.target,
    this.type = IrType.unknown,
    this.position,
  });

  Map<String, Object?> toJson() => {
    'opcode': opcode.value,
    if (result != null) 'result': result,
    if (left != null) 'left': left,
    if (operator != null) 'operator': operator,
    if (right != null) 'right': right,
    if (target != null) 'target': target,
    'type': type.name,
  };
}

class TypedIrProgram {
  final List<IrInstruction> instructions;
  final List<String> diagnostics;

  const TypedIrProgram(this.instructions, this.diagnostics);

  bool get isValid => diagnostics.isEmpty;

  Map<String, Object?> toJson() => {
    'instructions': instructions.map((item) => item.toJson()).toList(),
    'diagnostics': diagnostics,
  };

  static TypedIrProgram fromTac(
    Iterable<String> tac, {
    Map<String, IrType> symbolTypes = const {},
  }) {
    final instructions = <IrInstruction>[];
    final diagnostics = <String>[];
    final inferredTypes = <String, IrType>{};
    final labels = <String>{};
    final pendingTargets = <({String target, int line})>[];

    IrType typeOf(String value) {
      final normalized = value.trim();
      if (symbolTypes.containsKey(normalized)) return symbolTypes[normalized]!;
      if (inferredTypes.containsKey(normalized))
        return inferredTypes[normalized]!;
      final base = normalized.split(RegExp(r'[.\[]')).first.trim();
      if (symbolTypes.containsKey(base)) return symbolTypes[base]!;
      if (inferredTypes.containsKey(base)) return inferredTypes[base]!;
      if (RegExp(r'^-?[0-9]+$').hasMatch(normalized)) return IrType.integer;
      if (RegExp(r'^-?[0-9]+\.[0-9]+$').hasMatch(normalized)) {
        return IrType.real;
      }
      if (normalized == 'صح' || normalized == 'خطأ') return IrType.boolean;
      if (normalized.startsWith('"') || normalized.startsWith('‘')) {
        return normalized.startsWith('‘') ? IrType.character : IrType.string;
      }
      return IrType.unknown;
    }

    void remember(String name, IrType type) {
      if (type != IrType.unknown) inferredTypes[name] = type;
    }

    for (final raw in tac) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final lineNumber = instructions.length + 1;
      if (line.endsWith(':')) {
        final label = line.substring(0, line.length - 1);
        if (!labels.add(label)) {
          diagnostics.add('IR: label مكرر "$label" عند التعليمة $lineNumber');
        }
        instructions.add(IrInstruction(opcode: IrOpcode.label, target: label));
        continue;
      }
      if (line == 'return') {
        instructions.add(const IrInstruction(opcode: IrOpcode.returnOp));
        continue;
      }
      if (line.startsWith('goto ')) {
        final target = line.substring(5).trim();
        pendingTargets.add((target: target, line: lineNumber));
        instructions.add(IrInstruction(opcode: IrOpcode.jump, target: target));
        continue;
      }
      if (line.startsWith('ifFalse ')) {
        final match = RegExp(
          r'^ifFalse\s+(.+)\s+goto\s+(\S+)$',
        ).firstMatch(line);
        if (match == null) {
          diagnostics.add('IR: branch غير صالح عند التعليمة $lineNumber');
          continue;
        }
        final target = match.group(2)!;
        pendingTargets.add((target: target, line: lineNumber));
        instructions.add(
          IrInstruction(
            opcode: IrOpcode.branchFalse,
            left: match.group(1),
            target: target,
            type: IrType.boolean,
          ),
        );
        continue;
      }
      if (line.startsWith('print ')) {
        final value = line.substring(6).trim();
        instructions.add(
          IrInstruction(
            opcode: IrOpcode.print,
            left: value,
            type: typeOf(value),
          ),
        );
        continue;
      }
      if (line.startsWith('read ')) {
        final value = line.substring(5).trim();
        final type = typeOf(value);
        remember(value, type);
        instructions.add(
          IrInstruction(opcode: IrOpcode.read, result: value, type: type),
        );
        continue;
      }
      if (line.startsWith('call ')) {
        final call = line.substring(5).trim();
        final name = call.split('(').first.trim();
        instructions.add(IrInstruction(opcode: IrOpcode.call, target: name));
        continue;
      }
      final equals = line.indexOf(' = ');
      if (equals == -1) {
        diagnostics.add(
          'IR: تعليمة غير معروفة عند التعليمة $lineNumber: $line',
        );
        continue;
      }
      final result = line.substring(0, equals).trim();
      final expression = line.substring(equals + 3).trim();
      final unary = _findUnary(expression);
      if (unary != null) {
        final type = unary.operator == '!'
            ? IrType.boolean
            : typeOf(unary.operand);
        remember(result, type);
        instructions.add(
          IrInstruction(
            opcode: IrOpcode.unary,
            result: result,
            left: unary.operand,
            operator: unary.operator,
            type: type,
          ),
        );
        continue;
      }
      final binary = _findBinary(expression);
      if (binary != null) {
        final leftType = typeOf(binary.left);
        final rightType = typeOf(binary.right);
        final resultType = _binaryType(binary.operator, leftType, rightType);
        remember(result, resultType);
        instructions.add(
          IrInstruction(
            opcode: IrOpcode.binary,
            result: result,
            left: binary.left,
            operator: binary.operator,
            right: binary.right,
            type: resultType,
          ),
        );
      } else {
        final type = typeOf(expression);
        remember(result, type);
        instructions.add(
          IrInstruction(
            opcode: IrOpcode.assign,
            result: result,
            left: expression,
            type: type,
          ),
        );
      }
    }

    for (final pending in pendingTargets) {
      if (!labels.contains(pending.target)) {
        diagnostics.add(
          'IR: القفز إلى label غير معرف "${pending.target}" عند التعليمة ${pending.line}',
        );
      }
    }
    if (instructions.isEmpty) diagnostics.add('IR: لا توجد تعليمات');
    return TypedIrProgram(
      List.unmodifiable(instructions),
      List.unmodifiable(diagnostics),
    );
  }

  static IrType _binaryType(String operator, IrType left, IrType right) {
    if (const {
      '==',
      '!=',
      '<',
      '>',
      '=<',
      '=>',
      '<=',
      '>=',
      '&&',
      '||',
    }.contains(operator)) {
      return IrType.boolean;
    }
    if (left == IrType.string || right == IrType.string) {
      return operator == '+' ? IrType.string : IrType.unknown;
    }
    if (left == IrType.real || right == IrType.real) return IrType.real;
    if (left == IrType.integer && right == IrType.integer) {
      return IrType.integer;
    }
    return IrType.unknown;
  }

  static _IrUnary? _findUnary(String expression) {
    if (expression.length < 2) return null;
    final operator = expression[0];
    if (operator != '!' && operator != '-') return null;
    final operand = expression.substring(1).trim();
    return operand.isEmpty ? null : _IrUnary(operator, operand);
  }

  static _IrBinary? _findBinary(String expression) {
    for (final operator in const [
      ' || ',
      ' && ',
      ' == ',
      ' != ',
      ' =< ',
      ' => ',
      ' <= ',
      ' < ',
      ' > ',
      ' + ',
      ' - ',
      ' * ',
      ' / ',
      ' % ',
      r' \ ',
      ' ^ ',
    ]) {
      final index = expression.indexOf(operator);
      if (index != -1) {
        return _IrBinary(
          expression.substring(0, index).trim(),
          operator.trim(),
          expression.substring(index + operator.length).trim(),
        );
      }
    }
    return null;
  }
}

class _IrUnary {
  final String operator;
  final String operand;
  const _IrUnary(this.operator, this.operand);
}

class _IrBinary {
  final String left;
  final String operator;
  final String right;
  const _IrBinary(this.left, this.operator, this.right);
}
