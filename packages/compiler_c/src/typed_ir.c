#include "typed_ir.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *duplicate(const char *value) {
  const size_t length = strlen(value);
  char *copy = malloc(length + 1U);
  if (copy == NULL) return NULL;
  memcpy(copy, value, length + 1U);
  return copy;
}

static int push_line(CTypedIrResult *result, const char *format, ...) {
  char buffer[256];
  va_list arguments;
  va_start(arguments, format);
  const int written = vsnprintf(buffer, sizeof(buffer), format, arguments);
  va_end(arguments);
  if (written < 0 || (size_t)written >= sizeof(buffer)) return 0;
  if (result->count == result->capacity) {
    const size_t capacity = result->capacity == 0U ? 8U : result->capacity * 2U;
    char **items = realloc(result->items, capacity * sizeof(*items));
    if (items == NULL) return 0;
    result->items = items;
    result->capacity = capacity;
  }
  result->items[result->count] = duplicate(buffer);
  if (result->items[result->count] == NULL) return 0;
  result->count++;
  return 1;
}

static int push_diagnostic(CTypedIrResult *result, const char *message) {
  char **items = realloc(result->diagnostics,
                         (result->diagnostic_count + 1U) * sizeof(*items));
  if (items == NULL) return 0;
  result->diagnostics = items;
  result->diagnostics[result->diagnostic_count] = duplicate(message);
  if (result->diagnostics[result->diagnostic_count] == NULL) return 0;
  result->diagnostic_count++;
  return 1;
}

static CIrType literal_type(CTokenKind kind) {
  switch (kind) {
    case C_TOKEN_INTEGER: return C_IR_INTEGER;
    case C_TOKEN_REAL: return C_IR_REAL;
    case C_TOKEN_BOOLEAN: return C_IR_BOOLEAN;
    case C_TOKEN_CHARACTER: return C_IR_CHARACTER;
    case C_TOKEN_STRING: return C_IR_STRING;
    default: return C_IR_UNKNOWN;
  }
}

const char *c_ir_type_name(CIrType type) {
  switch (type) {
    case C_IR_INTEGER: return "integer";
    case C_IR_REAL: return "real";
    case C_IR_BOOLEAN: return "boolean";
    case C_IR_CHARACTER: return "character";
    case C_IR_STRING: return "string";
    case C_IR_UNKNOWN: return "unknown";
  }
  return "unknown";
}

static CIrType symbol_type(const CSemanticResult *semantic, const char *name) {
  for (size_t index = 0U; index < semantic->count; index++) {
    if (strcmp(semantic->items[index].name, name) != 0) continue;
    if (strcmp(semantic->items[index].type, "حقيقي") == 0) return C_IR_REAL;
    if (strcmp(semantic->items[index].type, "منطقي") == 0) return C_IR_BOOLEAN;
    if (strcmp(semantic->items[index].type, "حرفي") == 0) return C_IR_CHARACTER;
    if (strcmp(semantic->items[index].type, "خيط_رمزي") == 0) return C_IR_STRING;
    return C_IR_INTEGER;
  }
  return C_IR_UNKNOWN;
}

static CIrType infer(const CAstNode *node, const CSemanticResult *semantic,
                     CTypedIrResult *result, size_t *temporary, char *value,
                     size_t value_size) {
  if (node == NULL) return C_IR_UNKNOWN;
  if (node->kind == C_AST_LITERAL) {
    (void)snprintf(value, value_size, "%s", node->data.literal.value);
    return literal_type(node->data.literal.literal_kind);
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE) {
    (void)snprintf(value, value_size, "%s", node->data.reference.name);
    return symbol_type(semantic, node->data.reference.name);
  }
  if (node->kind == C_AST_UNARY) {
    char operand[128];
    const CIrType type = infer(node->data.unary.operand, semantic, result,
                               temporary, operand, sizeof(operand));
    if (type == C_IR_UNKNOWN) return type;
    const size_t current = (*temporary)++;
    if (!push_line(result, "t%zu: %s = %s%s", current, c_ir_type_name(type),
                   node->data.unary.operator, operand)) return C_IR_UNKNOWN;
    (void)snprintf(value, value_size, "t%zu", current);
    return type;
  }
  if (node->kind == C_AST_BINARY) {
    char left[128];
    char right[128];
    const CIrType left_type = infer(node->data.binary.left, semantic, result,
                                    temporary, left, sizeof(left));
    const CIrType right_type = infer(node->data.binary.right, semantic, result,
                                     temporary, right, sizeof(right));
    if (left_type == C_IR_UNKNOWN || right_type == C_IR_UNKNOWN ||
        (left_type != right_type &&
         !(left_type == C_IR_REAL && right_type == C_IR_INTEGER) &&
         !(left_type == C_IR_INTEGER && right_type == C_IR_REAL))) {
      (void)push_diagnostic(result, "أنواع غير متوافقة داخل العملية الثنائية");
      return C_IR_UNKNOWN;
    }
    const int is_comparison = strcmp(node->data.binary.operator, ">") == 0 ||
        strcmp(node->data.binary.operator, "<") == 0 ||
        strcmp(node->data.binary.operator, ">=") == 0 ||
        strcmp(node->data.binary.operator, "<=") == 0 ||
        strcmp(node->data.binary.operator, "==") == 0 ||
        strcmp(node->data.binary.operator, "!=") == 0 ||
        strcmp(node->data.binary.operator, "&&") == 0 ||
        strcmp(node->data.binary.operator, "||") == 0;
    const CIrType result_type = is_comparison ? C_IR_BOOLEAN :
        (left_type == C_IR_REAL || right_type == C_IR_REAL ? C_IR_REAL : left_type);
    const size_t current = (*temporary)++;
    if (!push_line(result, "t%zu: %s = %s %s %s", current,
                   c_ir_type_name(result_type), left, node->data.binary.operator,
                   right)) return C_IR_UNKNOWN;
    (void)snprintf(value, value_size, "t%zu", current);
    return result_type;
  }
  return C_IR_UNKNOWN;
}

static int build_statements(const CAstNodeList *list, const CSemanticResult *semantic,
                             CTypedIrResult *result, size_t *temporary, size_t *label) {
  for (size_t index = 0U; index < list->count; index++) {
    const CAstNode *statement = list->items[index];
    if (statement->kind == C_AST_EMPTY) continue;
    if (statement->kind == C_AST_ASSIGNMENT) {
      char value[128];
      const CIrType type = infer(statement->data.assignment.expression, semantic, result, temporary, value, sizeof(value));
      if (type == C_IR_UNKNOWN || !push_line(result, "store %s: %s <- %s", statement->data.assignment.name, c_ir_type_name(type), value)) return 0;
    } else if (statement->kind == C_AST_PRINT) {
      for (size_t value_index = 0U; value_index < statement->data.print.values.count; value_index++) {
        char value[128];
        const CIrType type = infer(statement->data.print.values.items[value_index], semantic, result, temporary, value, sizeof(value));
        if (type == C_IR_UNKNOWN || !push_line(result, "print %s: %s", c_ir_type_name(type), value)) return 0;
      }
    } else if (statement->kind == C_AST_IF) {
      char condition[128];
      const CIrType type = infer(statement->data.conditional.condition, semantic, result, temporary, condition, sizeof(condition));
      const size_t else_label = (*label)++; const size_t end_label = (*label)++;
      if (type == C_IR_UNKNOWN || !push_line(result, "ifFalse %s goto L%zu", condition, else_label) ||
          !build_statements(&statement->data.conditional.then_branch, semantic, result, temporary, label) ||
          !push_line(result, "goto L%zu", end_label) || !push_line(result, "L%zu:", else_label) ||
          !build_statements(&statement->data.conditional.else_branch, semantic, result, temporary, label) ||
          !push_line(result, "L%zu:", end_label)) return 0;
    } else if (statement->kind == C_AST_WHILE) {
      char condition[128]; const size_t begin_label = (*label)++; const size_t end_label = (*label)++;
      if (!push_line(result, "L%zu:", begin_label) ||
          infer(statement->data.loop.condition, semantic, result, temporary, condition, sizeof(condition)) == C_IR_UNKNOWN ||
          !push_line(result, "ifFalse %s goto L%zu", condition, end_label) ||
          !build_statements(&statement->data.loop.body, semantic, result, temporary, label) ||
          !push_line(result, "goto L%zu", begin_label) || !push_line(result, "L%zu:", end_label)) return 0;
    } else if (statement->kind == C_AST_REPEAT) {
      char from[128]; char to[128]; const size_t begin_label = (*label)++; const size_t end_label = (*label)++;
      if (infer(statement->data.repeat.from, semantic, result, temporary, from, sizeof(from)) == C_IR_UNKNOWN ||
          infer(statement->data.repeat.to, semantic, result, temporary, to, sizeof(to)) == C_IR_UNKNOWN ||
          !push_line(result, "store %s: integer <- %s", statement->data.repeat.variable, from) ||
          !push_line(result, "L%zu:", begin_label) || !push_line(result, "if %s > %s goto L%zu", statement->data.repeat.variable, to, end_label) ||
          !build_statements(&statement->data.repeat.body, semantic, result, temporary, label) ||
          !push_line(result, "goto L%zu", begin_label) || !push_line(result, "L%zu:", end_label)) return 0;
    } else if (statement->kind != C_AST_CALL) {
      return 0;
    }
  }
  return 1;
}

int c_build_typed_ir(const CAstNode *program, const CSemanticResult *semantic,
                     CTypedIrResult *result) {
  if (program == NULL || semantic == NULL || result == NULL ||
      program->kind != C_AST_PROGRAM) return 0;
  memset(result, 0, sizeof(*result));
  size_t temporary = 0U;
  size_t label = 0U;
  if (!build_statements(&program->data.program.statements, semantic, result, &temporary, &label)) {
    (void)push_diagnostic(result, "تعليمة غير مدعومة في Typed IR C الحالية");
    return 1;
  }
  return 1;
}

void c_typed_ir_result_free(CTypedIrResult *result) {
  if (result == NULL) return;
  for (size_t index = 0U; index < result->count; index++) free(result->items[index]);
  for (size_t index = 0U; index < result->diagnostic_count; index++) free(result->diagnostics[index]);
  free(result->items);
  free(result->diagnostics);
  memset(result, 0, sizeof(*result));
}
