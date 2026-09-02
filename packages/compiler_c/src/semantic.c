#include "semantic.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  CSemanticResult *result;
  const CAstNode *program;
} Analyzer;

static char *duplicate(const char *value) {
  const size_t length = strlen(value);
  char *copy = malloc(length + 1U);
  if (copy == NULL) return NULL;
  memcpy(copy, value, length + 1U);
  return copy;
}

static int diagnostic(Analyzer *analyzer, const char *format, ...) {
  CSemanticResult *result = analyzer->result;
  if (result->diagnostic_count == result->diagnostic_capacity) {
    const size_t capacity = result->diagnostic_capacity == 0U
        ? 4U
        : result->diagnostic_capacity * 2U;
    char **items = realloc(result->diagnostics, capacity * sizeof(*items));
    if (items == NULL) return 0;
    result->diagnostics = items;
    result->diagnostic_capacity = capacity;
  }
  char buffer[256];
  va_list arguments;
  va_start(arguments, format);
  (void)vsnprintf(buffer, sizeof(buffer), format, arguments);
  va_end(arguments);
  result->diagnostics[result->diagnostic_count] = duplicate(buffer);
  if (result->diagnostics[result->diagnostic_count] == NULL) return 0;
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

static int add_symbol_mode(Analyzer *analyzer, const char *name, const char *type,
                           const CAstNode *node, int by_reference) {
  CSemanticResult *result = analyzer->result;
  if (find_symbol(result, name) != NULL) {
    return diagnostic(analyzer, "تعريف مكرر للرمز: %s", name);
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
  symbol->offset = node->offset;
  symbol->line = node->line;
  symbol->column = node->column;
  symbol->by_reference = by_reference;
  if (symbol->name == NULL || symbol->type == NULL) return 0;
  return 1;
}

static int add_symbol(Analyzer *analyzer, const char *name, const char *type,
                      const CAstNode *node) {
  return add_symbol_mode(analyzer, name, type, node, 0);
}

static const char *literal_type(const CAstNode *node) {
  if (node == NULL || node->kind != C_AST_LITERAL) return "";
  switch (node->data.literal.literal_kind) {
    case C_TOKEN_INTEGER: return "صحيح";
    case C_TOKEN_REAL: return "حقيقي";
    case C_TOKEN_BOOLEAN: return "منطقي";
    case C_TOKEN_CHARACTER: return "حرفي";
    case C_TOKEN_STRING: return "خيط_رمزي";
    default: return "";
  }
}

static int check_node(Analyzer *analyzer, const CAstNode *node);
static int check_expression(Analyzer *analyzer, const CAstNode *node);

static const CAstNode *find_procedure(const Analyzer *analyzer, const char *name) {
  const CAstNodeList *declarations = &analyzer->program->data.program.declarations;
  for (size_t index = 0U; index < declarations->count; index++) {
    const CAstNode *node = declarations->items[index];
    if (node->kind == C_AST_PROCEDURE_DECLARATION &&
        strcmp(node->data.procedure.name, name) == 0) return node;
  }
  return NULL;
}

static int check_condition(Analyzer *analyzer, const CAstNode *condition) {
  return check_expression(analyzer, condition);
}

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
        return diagnostic(analyzer, "رمز غير معرف: %s",
                          node->data.reference.name);
      }
      return 1;
    case C_AST_BINARY:
      return check_expression(analyzer, node->data.binary.left) &&
          check_expression(analyzer, node->data.binary.right);
    case C_AST_UNARY:
      return check_expression(analyzer, node->data.unary.operand);
    default:
      return diagnostic(analyzer, "عقدة غير صالحة داخل التعبير");
  }
}

static int check_node(Analyzer *analyzer, const CAstNode *node) {
  if (node == NULL) return 0;
  switch (node->kind) {
    case C_AST_CONSTANT_DECLARATION:
      if (!check_expression(analyzer, node->data.constant.value)) return 0;
      return add_symbol(analyzer, node->data.constant.name,
                        literal_type(node->data.constant.value), node);
    case C_AST_VARIABLE_DECLARATION:
      for (size_t index = 0U; index < node->data.variable.name_count; index++) {
        if (!add_symbol(analyzer, node->data.variable.names[index],
                        node->data.variable.type->name, node)) return 0;
      }
      return 1;
    case C_AST_ASSIGNMENT:
      if (find_symbol(analyzer->result, node->data.assignment.name) == NULL) {
        return diagnostic(analyzer, "رمز غير معرف: %s",
                          node->data.assignment.name);
      }
      return check_expression(analyzer, node->data.assignment.expression);
    case C_AST_CALL: {
      const CAstNode *procedure = find_procedure(analyzer, node->data.call.name);
      if (procedure == NULL) {
        return diagnostic(analyzer, "اجراء غير معرف: %s", node->data.call.name);
      }
      if (node->data.call.arguments.count != procedure->data.procedure.parameter_count) {
        return diagnostic(analyzer, "عدد معاملات الاجراء %s غير صحيح", node->data.call.name);
      }
      for (size_t index = 0U; index < node->data.call.arguments.count; index++) {
        const CParameter *parameter = &procedure->data.procedure.parameters[index];
        const CAstNode *argument = node->data.call.arguments.items[index];
        if (parameter->by_reference &&
            (argument->kind != C_AST_VARIABLE_REFERENCE ||
             argument->data.reference.selectors.count != 0U)) {
          return diagnostic(analyzer, "المعامل بالمرجع %s يتطلب متغيرًا مباشرًا", parameter->name);
        }
        if (!check_expression(analyzer, argument)) return 0;
      }
      return 1;
    }
    case C_AST_IF:
      return check_condition(analyzer, node->data.conditional.condition) &&
          check_list(analyzer, &node->data.conditional.then_branch) &&
          check_list(analyzer, &node->data.conditional.else_branch);
    case C_AST_WHILE:
      return check_condition(analyzer, node->data.loop.condition) &&
          check_list(analyzer, &node->data.loop.body);
    case C_AST_REPEAT:
      return check_expression(analyzer, node->data.repeat.from) &&
          check_expression(analyzer, node->data.repeat.to) &&
          (node->data.repeat.step == NULL ||
           check_expression(analyzer, node->data.repeat.step)) &&
          check_list(analyzer, &node->data.repeat.body);
    case C_AST_REPEAT_UNTIL:
      return check_list(analyzer, &node->data.repeat_until.body) &&
          check_condition(analyzer, node->data.repeat_until.condition);
    case C_AST_PROCEDURE_DECLARATION: {
      const size_t saved_count = analyzer->result->count;
      for (size_t index = 0U; index < node->data.procedure.parameter_count; index++) {
        const CParameter *parameter = &node->data.procedure.parameters[index];
        if (!add_symbol_mode(analyzer, parameter->name,
                             parameter->type == NULL ? "" : parameter->type->name,
                             node, parameter->by_reference)) {
          return 0;
        }
      }
      (void)saved_count;
      return check_list(analyzer, &node->data.procedure.body);
    }
    case C_AST_PRINT:
      for (size_t index = 0U; index < node->data.print.values.count; index++) {
        if (!check_expression(analyzer, node->data.print.values.items[index])) return 0;
      }
      return 1;
    case C_AST_EMPTY:
      return 1;
    default:
      return diagnostic(analyzer, "تعليمة غير مدعومة في Semantic C الحالية");
  }
}

int c_analyze_semantics(const CAstNode *program, CSemanticResult *result) {
  if (program == NULL || result == NULL || program->kind != C_AST_PROGRAM) return 0;
  memset(result, 0, sizeof(*result));
  Analyzer analyzer = {.result = result, .program = program};
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
    free(result->diagnostics[index]);
  }
  free(result->items);
  free(result->diagnostics);
  memset(result, 0, sizeof(*result));
}
