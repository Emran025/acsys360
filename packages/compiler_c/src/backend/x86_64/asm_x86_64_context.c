#include "asm_x86_64_internal.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *c_asm_duplicate(const char *value)
{
  const size_t length = strlen(value);
  char *copy = malloc(length + 1U);
  if (copy == NULL)
    return NULL;
  memcpy(copy, value, length + 1U);
  return copy;
}

int c_asm_append(char **text, size_t *length, size_t *capacity,
                  const char *format, ...)
{
  va_list arguments;
  va_start(arguments, format);
  va_list copy;
  va_copy(copy, arguments);
  const int required = vsnprintf(NULL, 0U, format, copy);
  va_end(copy);
  if (required < 0)
  {
    va_end(arguments);
    return 0;
  }
  const size_t needed = *length + (size_t)required + 1U;
  if (needed > *capacity)
  {
    size_t next_capacity = *capacity == 0U ? 1024U : *capacity;
    while (next_capacity < needed)
      next_capacity *= 2U;
    char *next = realloc(*text, next_capacity);
    if (next == NULL)
    {
      va_end(arguments);
      return 0;
    }
    *text = next;
    *capacity = next_capacity;
  }
  (void)vsnprintf(*text + *length, *capacity - *length, format, arguments);
  va_end(arguments);
  *length += (size_t)required;
  return 1;
}

int c_asm_diagnostic_at(CAssemblyResult *result, const CAstNode *node,
                         const char *format, ...)
{
  char **items = realloc(result->diagnostics,
                         (result->diagnostic_count + 1U) * sizeof(*items));
  if (items == NULL)
    return 0;
  result->diagnostics = items;
  char message[512];
  va_list arguments;
  va_start(arguments, format);
  (void)vsnprintf(message, sizeof(message), format, arguments);
  va_end(arguments);
  result->diagnostics[result->diagnostic_count] = c_asm_duplicate(message);
  if (result->diagnostics[result->diagnostic_count] == NULL)
    return 0;
  result->diagnostic_offsets = realloc(
      result->diagnostic_offsets,
      (result->diagnostic_count + 1U) * sizeof(*result->diagnostic_offsets));
  result->diagnostic_lines = realloc(
      result->diagnostic_lines,
      (result->diagnostic_count + 1U) * sizeof(*result->diagnostic_lines));
  result->diagnostic_columns = realloc(
      result->diagnostic_columns,
      (result->diagnostic_count + 1U) * sizeof(*result->diagnostic_columns));
  result->diagnostic_lengths = realloc(
      result->diagnostic_lengths,
      (result->diagnostic_count + 1U) * sizeof(*result->diagnostic_lengths));
  if (!result->diagnostic_offsets || !result->diagnostic_lines ||
      !result->diagnostic_columns || !result->diagnostic_lengths)
    return 0;
  result->diagnostic_offsets[result->diagnostic_count] = node ? node->offset : 0;
  result->diagnostic_lines[result->diagnostic_count] = node ? node->line : 1;
  result->diagnostic_columns[result->diagnostic_count] = node ? node->column : 1;
  result->diagnostic_lengths[result->diagnostic_count] = 1;
  result->diagnostic_count++;
  return 1;
}

int c_asm_slot_for(const CSemanticResult *semantic, const char *name)
{
  for (size_t index = 0U; index < semantic->count; index++)
  {
    if (strcmp(semantic->items[index].name, name) == 0)
    {
      return (int)((index + 1U) * 8U);
    }
  }
  return 0;
}

const char *c_asm_type_for(const CSemanticResult *semantic, const char *name)
{
  for (size_t index = 0U; index < semantic->count; index++)
  {
    if (strcmp(semantic->items[index].name, name) == 0)
    {
      return semantic->items[index].type;
    }
  }
  return NULL;
}
const CAstNode *c_asm_constant_value_for(const CAsmContext *context, const char *name)
{
  if (!context || !context->program || !name)
    return NULL;
  for (size_t i = 0; i < context->program->data.program.declarations.count; i++)
  {
    const CAstNode *declaration = context->program->data.program.declarations.items[i];
    if (declaration->kind == C_AST_CONSTANT_DECLARATION &&
        strcmp(declaration->data.constant.name, name) == 0)
    {
      return declaration->data.constant.value;
    }
  }
  return NULL;
}
