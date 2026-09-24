#include "semantic.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  CSemanticResult *result;
} Analyzer;

static char *duplicate(const char *value) {
  const size_t length = strlen(value);
  char *copy = malloc(length + 1U);
  if (copy == NULL) return NULL;
  memcpy(copy, value, length + 1U);
  return copy;
}

static int diagnostic(Analyzer *analyzer, const CAstNode *node,
                      const char *format, ...) {
  CSemanticResult *result = analyzer->result;
  if (result->diagnostic_count == result->diagnostic_capacity) {
    const size_t capacity = result->diagnostic_capacity == 0U
        ? 4U
        : result->diagnostic_capacity * 2U;
    CSemanticDiagnostic *items = realloc(result->diagnostics,
                                         capacity * sizeof(*items));
    if (items == NULL) return 0;
    result->diagnostics = items;
    result->diagnostic_capacity = capacity;
  }
  char buffer[256];
  va_list arguments;
  va_start(arguments, format);
  (void)vsnprintf(buffer, sizeof(buffer), format, arguments);
  va_end(arguments);
  CSemanticDiagnostic *item = &result->diagnostics[result->diagnostic_count];
  item->message = duplicate(buffer);
  if (item->message == NULL) return 0;
  item->offset = node != NULL ? node->offset : 0U;
  item->line = node != NULL ? node->line : 1U;
  item->column = node != NULL ? node->column : 1U;
  item->length = 1U;
  result->diagnostic_count++;
  return 1;
}

static const CSymbol *find_symbol(const CSemanticResult *result,
                                  const char *name) {
  for (size_t index = 0U; index < result->count; index++) {
    if (strcmp(result->items[index].name, name) == 0) return &result->items[index];
  }
  return NULL;
}

static const CTypeSpec *resolve_type(const CSemanticResult *result,
                                     const CTypeSpec *type) {
  const CTypeSpec *current = type;
  size_t guard = 0U;
  while (current != NULL && current->kind == C_TYPE_NAMED &&
         current->name != NULL && guard++ < result->count + 1U) {
    const CSymbol *named = find_symbol(result, current->name);
    if (named == NULL || named->type == NULL ||
        strcmp(named->type, "نوع") != 0 || named->type_spec == current) break;
    current = named->type_spec;
  }
  return current;
}

static const CTypeSpec *selected_type(const CSemanticResult *result,
                                      const CSymbol *symbol,
                                      const CAstNodeList *selectors) {
  const CTypeSpec *type = resolve_type(result, symbol->type_spec);
  if (selectors == NULL) return type;
  for (size_t index = 0U; index < selectors->count; index++) {
    const CAstNode *selector = selectors->items[index];
    type = resolve_type(result, type);
    if (type == NULL || selector == NULL ||
        selector->kind != C_AST_VARIABLE_REFERENCE) return NULL;
    if (strcmp(selector->data.reference.name, "[]") == 0) {
      if (type->kind != C_TYPE_ARRAY || selector->data.reference.selectors.count != 1U)
        return NULL;
      type = type->element_type;
    } else {
      if (type->kind != C_TYPE_RECORD) return NULL;
      const CTypeSpec *record = type;
      type = NULL;
      for (size_t field = 0U; field < record->fields.count; field++) {
        if (strcmp(selector->data.reference.name,
                   record->fields.items[field].name) == 0) {
          type = record->fields.items[field].type;
          break;
        }
      }
    }
  }
  return resolve_type(result, type);
}

static const char *access_type(const CSemanticResult *result,
                               const char *name,
                               const CAstNodeList *selectors) {
  const CSymbol *symbol = find_symbol(result, name);
  if (symbol == NULL) return NULL;
  const CTypeSpec *type = selected_type(result, symbol, selectors);
  if (type != NULL && type->kind == C_TYPE_NAMED) return type->name;
  return selectors != NULL && selectors->count > 0U ? NULL : symbol->type;
}

static const char *expression_type(const CSemanticResult *result,
                                   const CAstNode *node) {
  if (!node) return NULL;
  if (node->kind == C_AST_LITERAL) {
    switch (node->data.literal.literal_kind) {
      case C_TOKEN_INTEGER: return "صحيح";
      case C_TOKEN_REAL: return "حقيقي";
      case C_TOKEN_BOOLEAN: return "منطقي";
      case C_TOKEN_CHARACTER: return "حرفي";
      case C_TOKEN_STRING: return "خيط_رمزي";
      default: return NULL;
    }
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE) {
    return access_type(result, node->data.reference.name,
                       &node->data.reference.selectors);
  }
  if (node->kind == C_AST_UNARY) {
    if (strcmp(node->data.unary.operator, "!") == 0) return "منطقي";
    return expression_type(result, node->data.unary.operand);
  }
  if (node->kind == C_AST_BINARY) {
    const char *left = expression_type(result, node->data.binary.left);
    const char *right = expression_type(result, node->data.binary.right);
    const char *op = node->data.binary.operator;
    if (!left || !right) return NULL;
    if (strcmp(op, "==") == 0 || strcmp(op, "!=") == 0 ||
        strcmp(op, "<") == 0 || strcmp(op, ">") == 0 ||
        strcmp(op, "<=") == 0 || strcmp(op, ">=") == 0 ||
        strcmp(op, "&&") == 0 || strcmp(op, "||") == 0) return "منطقي";
    if (strcmp(op, "+") == 0 &&
        (strcmp(left, "خيط_رمزي") == 0 || strcmp(right, "خيط_رمزي") == 0)) {
      return "خيط_رمزي";
    }
    if ((strcmp(left, "صحيح") == 0 || strcmp(left, "حقيقي") == 0) &&
        (strcmp(right, "صحيح") == 0 || strcmp(right, "حقيقي") == 0)) {
      return strcmp(left, "حقيقي") == 0 || strcmp(right, "حقيقي") == 0
          ? "حقيقي" : "صحيح";
    }
  }
  return NULL;
}

static int types_compatible(const char *expected, const char *actual) {
  if (!expected || !actual) return 0;
  return strcmp(expected, actual) == 0 ||
      (strcmp(expected, "حقيقي") == 0 && strcmp(actual, "صحيح") == 0);
}

static int add_symbol(Analyzer *analyzer, const char *name, const char *type,
                      const CTypeSpec *type_spec, const CAstNode *node,
                      int is_constant) {
  CSemanticResult *result = analyzer->result;
  if (find_symbol(result, name) != NULL) {
    return diagnostic(analyzer, node, "تعريف مكرر للرمز: %s", name);
  }
  if (result->count == result->capacity) {
    const size_t capacity = result->capacity == 0U ? 8U : result->capacity * 2U;
    CSymbol *items = realloc(result->items, capacity * sizeof(*items));
    if (items == NULL) return 0;
    result->items = items;
    result->capacity = capacity;
  }
  CSymbol *symbol = &result->items[result->count++];
  symbol->name = duplicate(name);
  symbol->type = duplicate(type);
  symbol->type_spec = type_spec;
  symbol->offset = node->offset;
  symbol->line = node->line;
  symbol->column = node->column;
  symbol->is_constant = is_constant;
  if (symbol->name == NULL || symbol->type == NULL) return 0;
  return 1;
}

static int check_node(Analyzer *analyzer, const CAstNode *node);

static int check_list(Analyzer *analyzer, const CAstNodeList *list) {
  for (size_t index = 0U; index < list->count; index++) {
    if (!check_node(analyzer, list->items[index])) return 0;
  }
  return 1;
}

static int check_expression(Analyzer *analyzer, const CAstNode *node) {
  if (node == NULL) return 0;
  switch (node->kind) {
    case C_AST_LITERAL:
      return 1;
    case C_AST_VARIABLE_REFERENCE:
      if (find_symbol(analyzer->result, node->data.reference.name) == NULL) {
        return diagnostic(analyzer, node, "رمز غير معرف: %s",
                          node->data.reference.name);
      }
      for (size_t index = 0U; index < node->data.reference.selectors.count;
           index++) {
        const CAstNode *selector = node->data.reference.selectors.items[index];
        if (selector != NULL && strcmp(selector->data.reference.name, "[]") == 0 &&
            selector->data.reference.selectors.count == 1U &&
            !check_expression(analyzer,
                              selector->data.reference.selectors.items[0])) {
          return 0;
        }
      }
      return 1;
    case C_AST_BINARY:
      return check_expression(analyzer, node->data.binary.left) &&
          check_expression(analyzer, node->data.binary.right);
    case C_AST_UNARY:
      return check_expression(analyzer, node->data.unary.operand);
    default:
      return diagnostic(analyzer, node, "عقدة غير صالحة داخل التعبير");
  }
}

static int check_node(Analyzer *analyzer, const CAstNode *node) {
  if (node == NULL) return 0;
  switch (node->kind) {
    case C_AST_PROGRAM:
      return check_list(analyzer, &node->data.program.statements);
    case C_AST_CONSTANT_DECLARATION:
      if (!check_expression(analyzer, node->data.constant.value)) return 0;
      if (!add_symbol(analyzer, node->data.constant.name,
                      expression_type(analyzer->result, node->data.constant.value),
                      NULL, node, 1)) return 0;
      return 1;
    case C_AST_TYPE_DECLARATION:
      return add_symbol(analyzer, node->data.type_declaration.name, "نوع",
                        node->data.type_declaration.type, node, 0);
    case C_AST_VARIABLE_DECLARATION:
      for (size_t index = 0U; index < node->data.variable.name_count; index++) {
        if (!add_symbol(analyzer, node->data.variable.names[index],
                        node->data.variable.type && node->data.variable.type->name
                            ? node->data.variable.type->name : "نوع مركب",
                        node->data.variable.type, node, 0)) return 0;
      }
      return 1;
    case C_AST_PROCEDURE_DECLARATION:
      if (!add_symbol(analyzer, node->data.procedure.name, "اجراء", NULL,
                      node, 0)) return 0;
      for (size_t index = 0U; index < node->data.procedure.parameter_count; index++) {
        const CParameter *parameter = &node->data.procedure.parameters[index];
        const char *type = parameter->type && parameter->type->name
            ? parameter->type->name : "نوع مركب";
        if (!add_symbol(analyzer, parameter->name, type, parameter->type,
                        node, 0)) return 0;
      }
      return check_list(analyzer, &node->data.procedure.body);
    case C_AST_ASSIGNMENT:
      {
        const CSymbol *symbol = find_symbol(analyzer->result, node->data.assignment.name);
        if (symbol == NULL) {
          return diagnostic(analyzer, node, "رمز غير معرف: %s",
                            node->data.assignment.name);
        }
        if (symbol->is_constant)
          return diagnostic(analyzer, node, "لا يمكن تعديل الثابت: %s",
                            node->data.assignment.name);
        for (size_t index = 0U; index < node->data.assignment.selectors.count;
             index++) {
          const CAstNode *selector = node->data.assignment.selectors.items[index];
          if (selector != NULL && strcmp(selector->data.reference.name, "[]") == 0 &&
              selector->data.reference.selectors.count == 1U &&
              !check_expression(analyzer,
                                selector->data.reference.selectors.items[0])) {
            return 0;
          }
        }
        if (!check_expression(analyzer, node->data.assignment.expression)) return 0;
        const char *actual = expression_type(analyzer->result,
                                             node->data.assignment.expression);
        const char *expected = access_type(analyzer->result,
                                           node->data.assignment.name,
                                           &node->data.assignment.selectors);
        if (expected == NULL || !types_compatible(expected, actual))
          return diagnostic(analyzer, node,
                            "عدم توافق نوع الإسناد للرمز «%s»: المتوقع «%s» والمستلم «%s»",
                            node->data.assignment.name, expected ? expected : symbol->type,
                            actual ? actual : "غير معروف");
        return 1;
      }
    case C_AST_PRINT:
      for (size_t index = 0U; index < node->data.print.values.count; index++) {
        if (!check_expression(analyzer, node->data.print.values.items[index])) return 0;
      }
      return 1;
    case C_AST_READ:
      return find_symbol(analyzer->result, node->data.access.name) != NULL;
    case C_AST_CALL:
      for (size_t index = 0U; index < node->data.call.arguments.count; index++) {
        if (!check_expression(analyzer, node->data.call.arguments.items[index])) return 0;
      }
      return 1;
    case C_AST_IF:
      return check_expression(analyzer, node->data.conditional.condition) &&
          check_list(analyzer, &node->data.conditional.then_branch) &&
          check_list(analyzer, &node->data.conditional.else_branch);
    case C_AST_WHILE:
      return check_expression(analyzer, node->data.loop.condition) &&
          check_list(analyzer, &node->data.loop.body);
    case C_AST_REPEAT:
      return check_expression(analyzer, node->data.repeat.from) &&
          check_expression(analyzer, node->data.repeat.to) &&
          (node->data.repeat.step == NULL || check_expression(analyzer, node->data.repeat.step)) &&
          check_list(analyzer, &node->data.repeat.body);
    case C_AST_REPEAT_UNTIL:
      return check_list(analyzer, &node->data.repeat_until.body) &&
          check_expression(analyzer, node->data.repeat_until.condition);
    case C_AST_EMPTY:
      return 1;
    default:
      return diagnostic(analyzer, node, "تعليمة غير مدعومة في Semantic C الحالية");
  }
}

int c_analyze_semantics(const CAstNode *program, CSemanticResult *result) {
  if (program == NULL || result == NULL || program->kind != C_AST_PROGRAM) return 0;
  memset(result, 0, sizeof(*result));
  Analyzer analyzer = {.result = result};
  if (!check_list(&analyzer, &program->data.program.declarations)) return 0;
  if (!check_list(&analyzer, &program->data.program.statements)) return 0;
  return 1;
}

void c_semantic_result_free(CSemanticResult *result) {
  if (result == NULL) return;
  for (size_t index = 0U; index < result->count; index++) {
    free(result->items[index].name);
    free(result->items[index].type);
  }
  for (size_t index = 0U; index < result->diagnostic_count; index++) {
    free(result->diagnostics[index].message);
  }
  free(result->items);
  free(result->diagnostics);
  memset(result, 0, sizeof(*result));
}
