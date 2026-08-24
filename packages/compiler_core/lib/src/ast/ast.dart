import '../model/token.dart';

abstract class AstNode {
  final SourcePosition position;
  const AstNode(this.position);

  Map<String, Object?> toJson();
}

class ProgramNode extends AstNode {
  final String name;
  final List<AstNode> declarations;
  final List<AstNode> statements;

  const ProgramNode(
    super.position,
    this.name,
    this.declarations,
    this.statements,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Program',
    'name': name,
    'declarations': declarations.map((node) => node.toJson()).toList(),
    'statements': statements.map((node) => node.toJson()).toList(),
  };
}

class VariableDeclaration extends AstNode {
  final List<String> names;
  final String type;

  const VariableDeclaration(super.position, this.names, this.type);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'VariableDeclaration',
    'names': names,
    'type': type,
  };
}

class Assignment extends AstNode {
  final String name;
  final AstNode expression;

  const Assignment(super.position, this.name, this.expression);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Assignment',
    'name': name,
    'expression': expression.toJson(),
  };
}

class PrintStatement extends AstNode {
  final List<AstNode> values;
  const PrintStatement(super.position, this.values);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Print',
    'values': values.map((node) => node.toJson()).toList(),
  };
}

class IfStatement extends AstNode {
  final AstNode condition;
  final List<AstNode> thenBranch;
  final List<AstNode> elseBranch;

  const IfStatement(
    super.position,
    this.condition,
    this.thenBranch,
    this.elseBranch,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'If',
    'condition': condition.toJson(),
    'then': thenBranch.map((node) => node.toJson()).toList(),
    'else': elseBranch.map((node) => node.toJson()).toList(),
  };
}

class WhileStatement extends AstNode {
  final AstNode condition;
  final List<AstNode> body;
  const WhileStatement(super.position, this.condition, this.body);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'While',
    'condition': condition.toJson(),
    'body': body.map((node) => node.toJson()).toList(),
  };
}

class Literal extends AstNode {
  final String value;
  final TokenKind type;
  const Literal(super.position, this.value, this.type);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Literal',
    'value': value,
    'type': type.name,
  };
}

class VariableReference extends AstNode {
  final String name;
  const VariableReference(super.position, this.name);

  @override
  Map<String, Object?> toJson() => {'kind': 'VariableReference', 'name': name};
}

class UnaryExpression extends AstNode {
  final String operator;
  final AstNode operand;
  const UnaryExpression(super.position, this.operator, this.operand);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Unary',
    'operator': operator,
    'operand': operand.toJson(),
  };
}

class BinaryExpression extends AstNode {
  final AstNode left;
  final String operator;
  final AstNode right;
  const BinaryExpression(super.position, this.left, this.operator, this.right);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Binary',
    'operator': operator,
    'left': left.toJson(),
    'right': right.toJson(),
  };
}
