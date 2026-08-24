import '../ast/ast.dart';

class ThreeAddressGenerator {
  final lines = <String>[];
  int _temporary = 0;
  int _label = 0;

  List<String> generate(ProgramNode program) {
    lines.clear();
    _temporary = 0;
    _label = 0;
    for (final statement in program.statements) _statement(statement);
    return List.unmodifiable(lines);
  }

  void _statement(AstNode node) {
    if (node is Assignment) {
      lines.add('${node.name} = ${_expression(node.expression)}');
    } else if (node is PrintStatement) {
      for (final value in node.values) lines.add('print ${_expression(value)}');
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
    }
  }

  String _expression(AstNode node) {
    if (node is Literal) return node.value;
    if (node is VariableReference) return node.name;
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

  String _newTemporary() => 't${_temporary++}';
  String _newLabel() => 'L${_label++}';
}
