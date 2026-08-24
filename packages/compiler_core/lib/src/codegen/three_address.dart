import '../ast/ast.dart';

class ThreeAddressGenerator {
  final lines = <String>[];
  int _temporary = 0;
  int _label = 0;

  List<String> generate(ProgramNode program) {
    lines.clear();
    _temporary = 0;
    _label = 0;
    for (final declaration in program.declarations) {
      if (declaration is ProcedureDeclaration) {
        lines.add('${declaration.name}:');
        for (final statement in declaration.body) _statement(statement);
        lines.add('return');
      }
    }
    lines.add('entry:');
    for (final statement in program.statements) _statement(statement);
    return List.unmodifiable(lines);
  }

  void _statement(AstNode node) {
    if (node is Assignment) {
      lines.add(
        '${_access(node.name, node.selectors)} = ${_expression(node.expression)}',
      );
    } else if (node is ReadStatement) {
      lines.add('read ${_access(node.name, node.selectors)}');
    } else if (node is PrintStatement) {
      for (final value in node.values) lines.add('print ${_expression(value)}');
    } else if (node is CallStatement) {
      final arguments = node.arguments.map(_expression).join(', ');
      lines.add('call ${node.name}($arguments)');
    } else if (node is IfStatement) {
      final otherwise = _newLabel();
      final end = _newLabel();
      lines.add('ifFalse ${_expression(node.condition)} goto $otherwise');
      for (final child in node.thenBranch) _statement(child);
      lines.add('goto $end');
      lines.add('$otherwise:');
      for (final child in node.elseBranch) _statement(child);
      lines.add('$end:');
    } else if (node is WhileStatement) {
      final start = _newLabel();
      final end = _newLabel();
      lines.add('$start:');
      lines.add('ifFalse ${_expression(node.condition)} goto $end');
      for (final child in node.body) _statement(child);
      lines.add('goto $start');
      lines.add('$end:');
    } else if (node is RepeatStatement) {
      final start = _newLabel();
      final end = _newLabel();
      final step = node.step == null ? '1' : _expression(node.step!);
      lines.add('${node.variable} = ${_expression(node.from)}');
      lines.add('$start:');
      final condition = _newTemporary();
      lines.add('$condition = ${node.variable} <= ${_expression(node.to)}');
      lines.add('ifFalse $condition goto $end');
      for (final child in node.body) _statement(child);
      final next = _newTemporary();
      lines.add('$next = ${node.variable} + $step');
      lines.add('${node.variable} = $next');
      lines.add('goto $start');
      lines.add('$end:');
    } else if (node is RepeatUntilStatement) {
      final start = _newLabel();
      lines.add('$start:');
      for (final child in node.body) _statement(child);
      lines.add('ifFalse ${_expression(node.condition)} goto $start');
    }
  }

  String _expression(AstNode node) {
    if (node is Literal) return node.value;
    if (node is VariableReference) return _access(node.name, node.selectors);
    if (node is UnaryExpression) {
      final temporary = _newTemporary();
      lines.add('$temporary = ${node.operator}${_expression(node.operand)}');
      return temporary;
    }
    if (node is BinaryExpression) {
      final temporary = _newTemporary();
      lines.add(
        '$temporary = ${_expression(node.left)} ${node.operator} ${_expression(node.right)}',
      );
      return temporary;
    }
    return '0';
  }

  String _access(String name, List<AccessSelector> selectors) {
    var value = name;
    for (final selector in selectors) {
      if (selector is IndexSelector) {
        value = '$value[${_expression(selector.index)}]';
      } else if (selector is FieldSelector) {
        value = '$value.${selector.name}';
      }
    }
    return value;
  }

  String _newTemporary() => 't${_temporary++}';
  String _newLabel() => 'L${_label++}';
}
