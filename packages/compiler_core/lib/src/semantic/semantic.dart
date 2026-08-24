import '../ast/ast.dart';
import '../model/token.dart';

class Symbol {
  final String name;
  final String type;
  final SourcePosition position;
  final Set<int> references = {};

  Symbol(this.name, this.type, this.position);

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type,
    'declaredAt': position.toJson(),
    'references': references.toList(),
  };
}

class SemanticResult {
  final Map<String, Symbol> symbols;
  final List<Diagnostic> diagnostics;
  const SemanticResult(this.symbols, this.diagnostics);

  Map<String, Object?> toJson() => {
    'symbols': symbols.values.map((symbol) => symbol.toJson()).toList(),
    'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
  };
}

class SemanticAnalyzer {
  final symbols = <String, Symbol>{};
  final diagnostics = <Diagnostic>[];

  SemanticResult analyze(ProgramNode program) {
    for (final declaration in program.declarations) {
      if (declaration is VariableDeclaration) {
        for (final name in declaration.names) {
          if (symbols.containsKey(name)) {
            _error(declaration.position, 'المتغير "$name" معرف مسبقًا');
          } else {
            symbols[name] = Symbol(
              name,
              declaration.type,
              declaration.position,
            );
          }
        }
      }
    }
    for (final statement in program.statements) _statement(statement);
    return SemanticResult(symbols, diagnostics);
  }

  void _statement(AstNode node) {
    if (node is Assignment) {
      final symbol = symbols[node.name];
      if (symbol == null)
        _error(node.position, 'المتغير "${node.name}" غير معرف');
      _expression(node.expression);
      return;
    }
    if (node is PrintStatement) {
      for (final value in node.values) _expression(value);
      return;
    }
    if (node is IfStatement) {
      _expression(node.condition);
      for (final child in node.thenBranch) _statement(child);
      for (final child in node.elseBranch) _statement(child);
      return;
    }
    if (node is WhileStatement) {
      _expression(node.condition);
      for (final child in node.body) _statement(child);
    }
  }

  void _expression(AstNode node) {
    if (node is VariableReference) {
      final symbol = symbols[node.name];
      if (symbol == null) {
        _error(node.position, 'المتغير "${node.name}" غير معرف');
      } else {
        symbol.references.add(node.position.line);
      }
    } else if (node is BinaryExpression) {
      _expression(node.left);
      _expression(node.right);
    } else if (node is UnaryExpression) {
      _expression(node.operand);
    }
  }

  void _error(SourcePosition position, String message) =>
      diagnostics.add(Diagnostic('semantic', message, position));
}
