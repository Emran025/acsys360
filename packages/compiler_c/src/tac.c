#include "tac.h"

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

static int push_line(CTacResult *result, const char *format, ...) {
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

static int diagnostic(CTacResult *result, const char *message) {
  char **items = realloc(result->diagnostics,
                         (result->diagnostic_count + 1U) * sizeof(*items));
  if (items == NULL) return 0;
  result->diagnostics = items;
  result->diagnostics[result->diagnostic_count] = duplicate(message);
  if (result->diagnostics[result->diagnostic_count] == NULL) return 0;
  result->diagnostic_count++;
  return 1;
}

static int expression(const CAstNode *node, CTacResult *result, size_t *temporary,
                      char *out, size_t out_size) {
  if (node == NULL) return 0;
  switch (node->kind) {
    case C_AST_LITERAL:
      return snprintf(out, out_size, "%s", node->data.literal.value) >= 0;
    case C_AST_VARIABLE_REFERENCE:
      return snprintf(out, out_size, "%s", node->data.reference.name) >= 0;
    case C_AST_UNARY: {
      char operand[128];
      if (!expression(node->data.unary.operand, result, temporary, operand,
                      sizeof(operand))) return 0;
      const size_t current = (*temporary)++;
      if (!push_line(result, "t%zu = %s%s", current,
                     node->data.unary.operator, operand)) return 0;
      return snprintf(out, out_size, "t%zu", current) >= 0;
    }
    case C_AST_BINARY: {
      char left[128];
      char right[128];
      if (!expression(node->data.binary.left, result, temporary, left,
                      sizeof(left)) ||
          !expression(node->data.binary.right, result, temporary, right,
                      sizeof(right))) return 0;
      const size_t current = (*temporary)++;
      if (!push_line(result, "t%zu = %s %s %s", current, left,
                     node->data.binary.operator, right)) return 0;
      return snprintf(out, out_size, "t%zu", current) >= 0;
    }
    default:
      return 0;
  }
}

int c_generate_tac(const CAstNode *program, CTacResult *result) {
  if (program == NULL || result == NULL || program->kind != C_AST_PROGRAM) return 0;
  memset(result, 0, sizeof(*result));
  size_t temporary = 0U;
  for (size_t index = 0U; index < program->data.program.statements.count; index++) {
    const CAstNode *statement = program->data.program.statements.items[index];
    if (statement->kind == C_AST_ASSIGNMENT) {
      char value[128];
      if (!expression(statement->data.assignment.expression, result, &temporary,
                      value, sizeof(value)) ||
          !push_line(result, "%s = %s", statement->data.assignment.name, value)) {
        (void)diagnostic(result, "تعذر توليد TAC للإسناد");
        return 1;
      }
    } else if (statement->kind == C_AST_PRINT) {
      for (size_t value_index = 0U;
           value_index < statement->data.print.values.count; value_index++) {
        char value[128];
        if (!expression(statement->data.print.values.items[value_index], result,
                        &temporary, value, sizeof(value)) ||
            !push_line(result, "print %s", value)) {
          (void)diagnostic(result, "تعذر توليد TAC للطباعة");
          return 1;
        }
      }
    } else if (statement->kind != C_AST_EMPTY) {
      (void)diagnostic(result, "تعليمة غير مدعومة في TAC C الحالية");
      return 1;
    }
  }
  return 1;
}

void c_tac_result_free(CTacResult *result) {
  if (result == NULL) return;
  for (size_t index = 0U; index < result->count; index++) free(result->items[index]);
  for (size_t index = 0U; index < result->diagnostic_count; index++) {
    free(result->diagnostics[index]);
  }
  free(result->items);
  free(result->diagnostics);
  memset(result, 0, sizeof(*result));
}
