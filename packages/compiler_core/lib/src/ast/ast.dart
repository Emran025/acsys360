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

class ConstantDeclaration extends AstNode {
  final String name;
  final AstNode value;

  const ConstantDeclaration(super.position, this.name, this.value);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'ConstantDeclaration',
    'name': name,
    'value': value.toJson(),
  };
}

class TypeDeclaration extends AstNode {
  final String name;
  final TypeSpec type;

  const TypeDeclaration(super.position, this.name, this.type);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'TypeDeclaration',
    'name': name,
    'type': type.toJson(),
  };
}

abstract class TypeSpec {
  const TypeSpec();

  Map<String, Object?> toJson();
}

class NamedTypeSpec extends TypeSpec {
  final String name;
  const NamedTypeSpec(this.name);

  @override
  Map<String, Object?> toJson() => {'kind': 'NamedType', 'name': name};
}

class ArrayTypeSpec extends TypeSpec {
  final int length;
  final TypeSpec elementType;
  const ArrayTypeSpec(this.length, this.elementType);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'ArrayType',
    'length': length,
    'elementType': elementType.toJson(),
  };
}

class RecordTypeSpec extends TypeSpec {
  final List<FieldDeclaration> fields;
  const RecordTypeSpec(this.fields);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'RecordType',
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

class FieldDeclaration {
  final List<String> names;
  final TypeSpec type;
  const FieldDeclaration(this.names, this.type);

  Map<String, Object?> toJson() => {'names': names, 'type': type.toJson()};
}

class VariableDeclaration extends AstNode {
  final List<String> names;
  final String type;
  final TypeSpec? typeSpec;

  const VariableDeclaration(
    super.position,
    this.names,
    this.type, {
    this.typeSpec,
  });

  @override
  Map<String, Object?> toJson() => {
    'kind': 'VariableDeclaration',
    'names': names,
    'type': type,
    if (typeSpec != null) 'typeSpec': typeSpec!.toJson(),
  };
}

class Parameter {
  final String name;
  final String type;
  final bool byReference;
  final TypeSpec? typeSpec;
  const Parameter(
    this.name,
    this.type, {
    this.byReference = false,
    this.typeSpec,
  });

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type,
    if (typeSpec != null) 'typeSpec': typeSpec!.toJson(),
    'byReference': byReference,
  };
}

class ProcedureDeclaration extends AstNode {
  final String name;
  final List<Parameter> parameters;
  final List<AstNode> body;

  const ProcedureDeclaration(
    super.position,
    this.name,
    this.parameters,
    this.body,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'ProcedureDeclaration',
    'name': name,
    'parameters': parameters.map((parameter) => parameter.toJson()).toList(),
    'body': body.map((node) => node.toJson()).toList(),
  };
}

abstract class AccessSelector {
  const AccessSelector();

  Map<String, Object?> toJson();
}

class IndexSelector extends AccessSelector {
  final AstNode index;
  const IndexSelector(this.index);

  @override
  Map<String, Object?> toJson() => {'kind': 'Index', 'index': index.toJson()};
}

class FieldSelector extends AccessSelector {
  final String name;
  const FieldSelector(this.name);

  @override
  Map<String, Object?> toJson() => {'kind': 'Field', 'name': name};
}

class Assignment extends AstNode {
  final String name;
  final AstNode expression;
  final List<AccessSelector> selectors;

  const Assignment(
    super.position,
    this.name,
    this.expression, {
    this.selectors = const [],
  });

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Assignment',
    'name': name,
    'selectors': selectors.map((selector) => selector.toJson()).toList(),
    'expression': expression.toJson(),
  };
}

class ReadStatement extends AstNode {
  final String name;
  final List<AccessSelector> selectors;
  const ReadStatement(super.position, this.name, {this.selectors = const []});

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Read',
    'name': name,
    'selectors': selectors.map((selector) => selector.toJson()).toList(),
  };
}

class CallStatement extends AstNode {
  final String name;
  final List<AstNode> arguments;
  const CallStatement(super.position, this.name, this.arguments);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Call',
    'name': name,
    'arguments': arguments.map((argument) => argument.toJson()).toList(),
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

class RepeatStatement extends AstNode {
  final String variable;
  final AstNode from;
  final AstNode to;
  final AstNode? step;
  final List<AstNode> body;

  const RepeatStatement(
    super.position,
    this.variable,
    this.from,
    this.to,
    this.step,
    this.body,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'Repeat',
    'variable': variable,
    'from': from.toJson(),
    'to': to.toJson(),
    'step': step?.toJson(),
    'body': body.map((node) => node.toJson()).toList(),
  };
}

class RepeatUntilStatement extends AstNode {
  final List<AstNode> body;
  final AstNode condition;

  const RepeatUntilStatement(super.position, this.body, this.condition);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'RepeatUntil',
    'body': body.map((node) => node.toJson()).toList(),
    'condition': condition.toJson(),
  };
}

class EmptyStatement extends AstNode {
  const EmptyStatement(super.position);

  @override
  Map<String, Object?> toJson() => {'kind': 'Empty'};
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
  final List<AccessSelector> selectors;
  const VariableReference(
    super.position,
    this.name, {
    this.selectors = const [],
  });

  @override
  Map<String, Object?> toJson() => {
    'kind': 'VariableReference',
    'name': name,
    'selectors': selectors.map((selector) => selector.toJson()).toList(),
  };
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
