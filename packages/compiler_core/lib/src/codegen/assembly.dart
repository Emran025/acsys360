class AssemblyGenerator {
  const AssemblyGenerator();

  String generate(Iterable<String> threeAddressCode) {
    final variables = <String>{};
    final body = <String>[];
    for (final instruction in threeAddressCode) {
      final trimmed = instruction.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.endsWith(':')) {
        body.add('${trimmed.substring(0, trimmed.length - 1)}:');
        continue;
      }
      if (trimmed == 'return') {
        body.add('    ret');
        continue;
      }
      if (trimmed.startsWith('goto ')) {
        body.add('    jmp ${trimmed.substring(5)}');
        continue;
      }
      if (trimmed.startsWith('ifFalse ')) {
        final parts = trimmed.split(' ');
        if (parts.length >= 4) {
          body.add('    cmp ${parts[1]}, 0');
          body.add('    je ${parts[3]}');
        }
        continue;
      }
      if (trimmed.startsWith('print ')) {
        final value = trimmed.substring(6);
        variables.add(value);
        body.add('    ; اطبع $value عبر runtime العربي');
        body.add('    mov rdi, $value');
        body.add('    call arabic_print');
        continue;
      }
      if (trimmed.startsWith('read ')) {
        final value = trimmed.substring(5);
        variables.add(value);
        body.add('    ; اقرأ إلى $value عبر runtime العربي');
        body.add('    mov rdi, $value');
        body.add('    call arabic_read');
        continue;
      }
      if (trimmed.startsWith('call ')) {
        final open = trimmed.indexOf('(');
        final name = open == -1
            ? trimmed.substring(5)
            : trimmed.substring(5, open);
        body.add('    call $name');
        continue;
      }
      final equals = trimmed.indexOf(' = ');
      if (equals == -1) {
        body.add('    ; غير معروف: $trimmed');
        continue;
      }
      final target = trimmed.substring(0, equals);
      final expression = trimmed.substring(equals + 3);
      variables.add(target);
      final binary = _binary(expression);
      if (binary == null) {
        body.add('    mov $target, $expression');
      } else {
        body.add('    mov rax, ${binary.left}');
        body.add(_operation(binary.operator, binary.right));
        body.add('    mov $target, rax');
      }
    }
    final data = variables
        .where((name) => _isName(name))
        .map((name) => '$name: dq 0')
        .join('\n');
    return [
      '; Arabic360 assembly output — NASM-like x86-64 target',
      'section .data',
      'arabic_runtime: db 0',
      'section .bss',
      if (data.isNotEmpty) data,
      'section .text',
      'global entry',
      'extern arabic_print',
      'extern arabic_read',
      'entry:',
      ...body,
      '    ret',
    ].join('\n');
  }

  _Binary? _binary(String expression) {
    for (final operator in const [
      ' || ',
      ' && ',
      ' == ',
      ' != ',
      ' =< ',
      ' => ',
      ' < ',
      ' <= ',
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
        return _Binary(
          expression.substring(0, index).trim(),
          operator.trim(),
          expression.substring(index + operator.length).trim(),
        );
      }
    }
    return null;
  }

  String _operation(String operator, String right) => switch (operator) {
    '+' => '    add rax, $right',
    '-' => '    sub rax, $right',
    '*' => '    imul rax, $right',
    '/' => '    ; قسمة حقيقية عبر runtime: rax / $right',
    r'\' => '    ; قسمة صحيحة عبر runtime: rax \\ $right',
    '%' => '    ; باقي القسمة عبر runtime: rax % $right',
    '^' => '    ; أس عبر runtime: rax ^ $right',
    '&&' => '    and rax, $right',
    '||' => '    or rax, $right',
    '==' => '    ; مقارنة مساواة: rax == $right',
    '!=' => '    ; مقارنة عدم مساواة: rax != $right',
    '=<' => '    ; مقارنة أصغر أو يساوي',
    '=>' => '    ; مقارنة أكبر أو يساوي',
    '<' => '    ; مقارنة أصغر',
    '<=' => '    ; مقارنة أصغر أو يساوي',
    '>' => '    ; مقارنة أكبر',
    _ => '    ; operator $operator $right',
  };

  bool _isName(String value) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value);
}

class _Binary {
  final String left;
  final String operator;
  final String right;
  const _Binary(this.left, this.operator, this.right);
}
