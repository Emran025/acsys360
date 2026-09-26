#include "asm_x86_64_internal.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int c_asm_text_index(const char **values, size_t count, const char *value)
{
  for (size_t i = 0; i < count; i++)
  {
    if (strcmp(values[i], value) == 0)
      return (int)i;
  }
  return -1;
}
void c_asm_collect_real_literals(const CAstNode *node,
                                  const char ***values, size_t *count,
                                  size_t *capacity)
{
  if (!node)
    return;
  if (node->kind == C_AST_LITERAL &&
      node->data.literal.literal_kind == C_TOKEN_REAL)
  {
    for (size_t i = 0; i < *count; i++)
    {
      if (strcmp((*values)[i], node->data.literal.value) == 0)
        return;
    }
    if (*count == *capacity)
    {
      *capacity = *capacity == 0 ? 8 : *capacity * 2;
      *values = realloc(*values, *capacity * sizeof(**values));
    }
    (*values)[(*count)++] = node->data.literal.value;
    return;
  }
  if (node->kind == C_AST_BINARY)
  {
    c_asm_collect_real_literals(node->data.binary.left, values, count, capacity);
    c_asm_collect_real_literals(node->data.binary.right, values, count, capacity);
  }
  else if (node->kind == C_AST_UNARY)
  {
    c_asm_collect_real_literals(node->data.unary.operand, values, count, capacity);
  }
  else if (node->kind == C_AST_ASSIGNMENT)
  {
    c_asm_collect_real_literals(node->data.assignment.expression, values, count,
                          capacity);
  }
  else if (node->kind == C_AST_PRINT)
  {
    for (size_t i = 0; i < node->data.print.values.count; i++)
    {
      c_asm_collect_real_literals(node->data.print.values.items[i], values, count,
                            capacity);
    }
  }
}

void c_asm_collect_text_literal(const CAstNode *node,
                                 const char ***values, size_t *count,
                                 size_t *capacity)
{
  if (!node)
    return;
  if (node->kind == C_AST_LITERAL &&
      (node->data.literal.literal_kind == C_TOKEN_STRING ||
       node->data.literal.literal_kind == C_TOKEN_CHARACTER))
  {
    for (size_t i = 0; i < *count; i++)
    {
      if (strcmp((*values)[i], node->data.literal.value) == 0)
        return;
    }
    if (*count == *capacity)
    {
      *capacity = *capacity == 0 ? 8 : *capacity * 2;
      *values = realloc(*values, *capacity * sizeof(**values));
    }
    (*values)[(*count)++] = node->data.literal.value;
    return;
  }
  if (node->kind == C_AST_BINARY)
  {
    c_asm_collect_text_literal(node->data.binary.left, values, count, capacity);
    c_asm_collect_text_literal(node->data.binary.right, values, count, capacity);
  }
  else if (node->kind == C_AST_ASSIGNMENT)
  {
    c_asm_collect_text_literal(node->data.assignment.expression, values, count,
                         capacity);
  }
  else if (node->kind == C_AST_PRINT)
  {
    for (size_t i = 0; i < node->data.print.values.count; i++)
    {
      c_asm_collect_text_literal(node->data.print.values.items[i], values, count,
                           capacity);
    }
  }
  else if (node->kind == C_AST_IF)
  {
    c_asm_collect_text_literal(node->data.conditional.condition, values, count,
                         capacity);
    for (size_t i = 0; i < node->data.conditional.then_branch.count; i++)
      c_asm_collect_text_literal(node->data.conditional.then_branch.items[i], values,
                           count, capacity);
    for (size_t i = 0; i < node->data.conditional.else_branch.count; i++)
      c_asm_collect_text_literal(node->data.conditional.else_branch.items[i], values,
                           count, capacity);
  }
  else if (node->kind == C_AST_PROGRAM)
  {
    for (size_t i = 0; i < node->data.program.statements.count; i++)
      c_asm_collect_text_literal(node->data.program.statements.items[i], values,
                           count, capacity);
  }
}

int c_asm_real_literal_index(const char **values, size_t count,
                              const char *value)
{
  for (size_t i = 0; i < count; i++)
  {
    if (strcmp(values[i], value) == 0)
      return (int)i;
  }
  return -1;
}
/* Collect all string literals from the AST for the .data section */
void c_asm_collect_strings(const CAstNodeList *list,
                            const char ***strings, size_t *count, size_t *cap)
{
  for (size_t i = 0; i < list->count; i++)
  {
    const CAstNode *n = list->items[i];
    if (!n)
      continue;
    if (n->kind == C_AST_PRINT)
    {
      for (size_t j = 0; j < n->data.print.values.count; j++)
      {
        const CAstNode *v = n->data.print.values.items[j];
        if (v && v->kind == C_AST_LITERAL &&
            v->data.literal.literal_kind == C_TOKEN_STRING)
        {
          if (*count >= *cap)
          {
            *cap = *cap == 0 ? 8 : *cap * 2;
            *strings = realloc(*strings, *cap * sizeof(char *));
          }
          (*strings)[(*count)++] = v->data.literal.value;
        }
      }
    }
  }
}

/* Emit a C-escaped string as NASM byte sequence */
int c_asm_emit_nasm_string(char **text, size_t *length, size_t *capacity,
                            const char *json_str)
{
  /* json_str includes surrounding quotes from lexer, e.g. "hello" */
  const char *p = json_str;
  if (*p == '"')
    p++; /* skip opening quote */

  if (!c_asm_append(text, length, capacity, "    db "))
    return 0;
  int first = 1;
  while (*p && *p != '"')
  {
    char c = *p++;
    if (c == '\\' && *p)
    {
      c = *p++;
      switch (c)
      {
      case 'n':
        c = '\n';
        break;
      case 't':
        c = '\t';
        break;
      case 'r':
        c = '\r';
        break;
      default:
        break;
      }
    }
    if (!first && !c_asm_append(text, length, capacity, ", "))
      return 0;
    if (!c_asm_append(text, length, capacity, "%d", (unsigned char)c))
      return 0;
    first = 0;
  }
  if (!first && !c_asm_append(text, length, capacity, ", "))
    return 0;
  return c_asm_append(text, length, capacity, "0\n");
}

int c_asm_emit_nasm_bytes(char **text, size_t *length, size_t *capacity,
                           const char *value)
{
  if (!c_asm_append(text, length, capacity, "    db "))
    return 0;
  for (size_t i = 0; value[i] != '\0'; i++)
  {
    if (i > 0 && !c_asm_append(text, length, capacity, ", "))
      return 0;
    if (!c_asm_append(text, length, capacity, "%u", (unsigned char)value[i]))
      return 0;
  }
  return c_asm_append(text, length, capacity, "%s0\n", value[0] ? ", " : "");
}
