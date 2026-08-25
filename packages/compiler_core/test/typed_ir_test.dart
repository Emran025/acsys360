import 'package:test/test.dart';

import 'package:compiler_core/arabic_compiler.dart';

void main() {
  test('builds typed instructions and resolves control-flow labels', () {
    final ir = TypedIrProgram.fromTac(const [
      'entry:',
      't0 = 1 <= 2',
      'ifFalse t0 goto L0',
      'print t0',
      'goto L1',
      'L0:',
      'print 0',
      'L1:',
      'return',
    ]);

    expect(ir.isValid, isTrue);
    expect(ir.instructions.first.opcode, IrOpcode.label);
    expect(
      ir.instructions.where((item) => item.opcode == IrOpcode.branchFalse),
      hasLength(1),
    );
    final binary = ir.instructions.firstWhere(
      (item) => item.opcode == IrOpcode.binary,
    );
    expect(binary.left, '1');
    expect(binary.operator, '<=');
    expect(binary.right, '2');
    expect(binary.type, IrType.boolean);
    expect(ir.instructions.last.opcode, IrOpcode.returnOp);
    expect(ir.toJson()['diagnostics'], isEmpty);
  });

  test('rejects jumps to undefined labels', () {
    final ir = TypedIrProgram.fromTac(const ['entry:', 'goto missing']);

    expect(ir.isValid, isFalse);
    expect(ir.diagnostics.single, contains('غير معرف'));
  });

  test(
    'rejects malformed TAC instead of emitting an invalid IR instruction',
    () {
      final ir = TypedIrProgram.fromTac(const [
        'entry:',
        'unknown instruction',
      ]);

      expect(ir.isValid, isFalse);
      expect(ir.diagnostics.single, contains('غير معروفة'));
    },
  );

  test('infers unary and temporary types in sequence', () {
    final ir = TypedIrProgram.fromTac(const [
      'entry:',
      't0 = 2 + 3',
      't1 = -t0',
      't2 = ! صح',
      'print t1',
    ]);

    expect(ir.isValid, isTrue);
    final instructions = ir.instructions;
    expect(instructions[1].type, IrType.integer);
    expect(instructions[2].type, IrType.integer);
    expect(instructions[3].type, IrType.boolean);
    expect(instructions[4].type, IrType.integer);
  });

  test('compiler exposes a validated intermediate representation', () {
    final result = const Compiler().compile('''برنامج اختبار {
متغير س: صحيح;
س = 2 + 3;
اطبع(س);
}.''');

    expect(result.success, isTrue);
    expect(result.intermediateRepresentation, isNotNull);
    expect(result.intermediateRepresentation!.isValid, isTrue);
    expect(result.toJson()['intermediateRepresentation'], isNotNull);
  });
}
