#include "asm_x86_64.h"

#include <stdarg.h>
#include <stdint.h>
#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *duplicate(const char *value)
{
  const size_t length = strlen(value);
  char *copy = malloc(length + 1U);
  if (copy == NULL)
    return NULL;
  memcpy(copy, value, length + 1U);
  return copy;
}

static int emit_expression(const CAstNode *node, const CSemanticResult *semantic,
                           char **text, size_t *length, size_t *capacity);
static const CAstNode *g_program = NULL;
static const char **g_text_values = NULL;
static size_t g_text_count = 0;

static int append(char **text, size_t *length, size_t *capacity,
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

static int diagnostic_at(CAssemblyResult *result, const CAstNode *node,
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
  result->diagnostics[result->diagnostic_count] = duplicate(message);
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

static int slot_for(const CSemanticResult *semantic, const char *name)
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

static const char *type_for(const CSemanticResult *semantic, const char *name)
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
static const CAstNode *constant_value_for(const char *name)
{
  if (!g_program || !name)
    return NULL;
  for (size_t i = 0; i < g_program->data.program.declarations.count; i++)
  {
    const CAstNode *declaration = g_program->data.program.declarations.items[i];
    if (declaration->kind == C_AST_CONSTANT_DECLARATION &&
        strcmp(declaration->data.constant.name, name) == 0)
    {
      return declaration->data.constant.value;
    }
  }
  return NULL;
}

static int text_index(const char **values, size_t count, const char *value)
{
  for (size_t i = 0; i < count; i++)
  {
    if (strcmp(values[i], value) == 0)
      return (int)i;
  }
  return -1;
}

static const char *literal_kind_name(CTokenKind kind)
{
  switch (kind)
  {
  case C_TOKEN_INTEGER:
    return "صحيح";
  case C_TOKEN_REAL:
    return "حقيقي";
  case C_TOKEN_BOOLEAN:
    return "منطقي";
  case C_TOKEN_CHARACTER:
    return "حرفي";
  case C_TOKEN_STRING:
    return "خيط_رمزي";
  default:
    return "غير معروف";
  }
}

static const char *assignment_expression_kind(const CAstNode *node)
{
  if (node == NULL)
    return "فارغ";
  if (node->kind == C_AST_LITERAL)
  {
    return literal_kind_name(node->data.literal.literal_kind);
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE)
    return "مرجع متغير/ثابت";
  if (node->kind == C_AST_BINARY)
    return "تعبير حسابي";
  if (node->kind == C_AST_UNARY)
    return "تعبير أحادي";
  return "تعبير غير معروف";
}

static int expression_is_text(const CAstNode *node,
                              const CSemanticResult *semantic)
{
  if (!node)
    return 0;
  if (node->kind == C_AST_LITERAL)
  {
    return node->data.literal.literal_kind == C_TOKEN_STRING ||
           node->data.literal.literal_kind == C_TOKEN_CHARACTER;
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE)
  {
    const char *type = type_for(semantic, node->data.reference.name);
    return type && (strcmp(type, "خيط_رمزي") == 0 || strcmp(type, "حرفي") == 0);
  }
  return 0;
}

static int expression_is_boolean(const CAstNode *node,
                                 const CSemanticResult *semantic)
{
  if (!node)
    return 0;
  if (node->kind == C_AST_LITERAL)
    return node->data.literal.literal_kind == C_TOKEN_BOOLEAN;
  if (node->kind == C_AST_VARIABLE_REFERENCE)
  {
    const char *type = type_for(semantic, node->data.reference.name);
    return type && strcmp(type, "منطقي") == 0;
  }
  return 0;
}

static int emit_text_expression(const CAstNode *node,
                                const CSemanticResult *semantic,
                                char **text, size_t *length, size_t *capacity)
{
  const CAstNode *value = node;
  if (node && node->kind == C_AST_VARIABLE_REFERENCE)
  {
    value = constant_value_for(node->data.reference.name);
    if (!value)
    {
      const int slot = slot_for(semantic, node->data.reference.name);
      return slot > 0 && append(text, length, capacity,
                                "    mov rax, [rbp-%d]\n", slot);
    }
  }
  if (!value || (value->kind != C_AST_LITERAL) ||
      (value->data.literal.literal_kind != C_TOKEN_STRING &&
       value->data.literal.literal_kind != C_TOKEN_CHARACTER))
    return 0;
  const int index = text_index(g_text_values, g_text_count,
                               value->data.literal.value);
  return index >= 0 && append(text, length, capacity,
                              "    lea rax, [rel text%d]\n", index);
}
static int expression_is_real(const CAstNode *node,
                              const CSemanticResult *semantic)
{
  if (!node)
    return 0;
  if (node->kind == C_AST_LITERAL)
  {
    return node->data.literal.literal_kind == C_TOKEN_REAL;
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE)
  {
    return type_for(semantic, node->data.reference.name) &&
           strcmp(type_for(semantic, node->data.reference.name), "حقيقي") == 0;
  }
  if (node->kind == C_AST_UNARY)
  {
    return expression_is_real(node->data.unary.operand, semantic);
  }
  if (node->kind == C_AST_BINARY)
  {
    return expression_is_real(node->data.binary.left, semantic) ||
           expression_is_real(node->data.binary.right, semantic);
  }
  return 0;
}

static void collect_real_literals(const CAstNode *node,
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
    collect_real_literals(node->data.binary.left, values, count, capacity);
    collect_real_literals(node->data.binary.right, values, count, capacity);
  }
  else if (node->kind == C_AST_UNARY)
  {
    collect_real_literals(node->data.unary.operand, values, count, capacity);
  }
  else if (node->kind == C_AST_ASSIGNMENT)
  {
    collect_real_literals(node->data.assignment.expression, values, count,
                          capacity);
  }
  else if (node->kind == C_AST_PRINT)
  {
    for (size_t i = 0; i < node->data.print.values.count; i++)
    {
      collect_real_literals(node->data.print.values.items[i], values, count,
                            capacity);
    }
  }
}

static void collect_text_literal(const CAstNode *node,
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
    collect_text_literal(node->data.binary.left, values, count, capacity);
    collect_text_literal(node->data.binary.right, values, count, capacity);
  }
  else if (node->kind == C_AST_ASSIGNMENT)
  {
    collect_text_literal(node->data.assignment.expression, values, count,
                         capacity);
  }
  else if (node->kind == C_AST_PRINT)
  {
    for (size_t i = 0; i < node->data.print.values.count; i++)
    {
      collect_text_literal(node->data.print.values.items[i], values, count,
                           capacity);
    }
  }
  else if (node->kind == C_AST_IF)
  {
    collect_text_literal(node->data.conditional.condition, values, count,
                         capacity);
    for (size_t i = 0; i < node->data.conditional.then_branch.count; i++)
      collect_text_literal(node->data.conditional.then_branch.items[i], values,
                           count, capacity);
    for (size_t i = 0; i < node->data.conditional.else_branch.count; i++)
      collect_text_literal(node->data.conditional.else_branch.items[i], values,
                           count, capacity);
  }
  else if (node->kind == C_AST_PROGRAM)
  {
    for (size_t i = 0; i < node->data.program.statements.count; i++)
      collect_text_literal(node->data.program.statements.items[i], values,
                           count, capacity);
  }
}

static int real_literal_index(const char **values, size_t count,
                              const char *value)
{
  for (size_t i = 0; i < count; i++)
  {
    if (strcmp(values[i], value) == 0)
      return (int)i;
  }
  return -1;
}

static int emit_real_expression(const CAstNode *node,
                                const CSemanticResult *semantic,
                                const char **real_values, size_t real_count,
                                char **text, size_t *length, size_t *capacity);

static int emit_numeric_as_real(const CAstNode *node,
                                const CSemanticResult *semantic,
                                const char **real_values, size_t real_count,
                                char **text, size_t *length, size_t *capacity)
{
  if (expression_is_real(node, semantic))
  {
    return emit_real_expression(node, semantic, real_values, real_count,
                                text, length, capacity);
  }
  return emit_expression(node, semantic, text, length, capacity) &&
         append(text, length, capacity, "    cvtsi2sd xmm0, rax\n");
}

static int emit_real_expression(const CAstNode *node,
                                const CSemanticResult *semantic,
                                const char **real_values, size_t real_count,
                                char **text, size_t *length, size_t *capacity)
{
  if (node == NULL)
    return 0;
  if (node->kind == C_AST_LITERAL &&
      node->data.literal.literal_kind == C_TOKEN_REAL)
  {
    const int index = real_literal_index(real_values, real_count,
                                         node->data.literal.value);
    return index >= 0 && append(text, length, capacity,
                                "    movsd xmm0, [rel real%d]\n", index);
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE)
  {
    const int slot = slot_for(semantic, node->data.reference.name);
    if (slot <= 0)
      return 0;
    if (strcmp(type_for(semantic, node->data.reference.name), "حقيقي") == 0)
    {
      return append(text, length, capacity,
                    "    movsd xmm0, [rbp-%d]\n", slot);
    }
    return emit_expression(node, semantic, text, length, capacity) &&
           append(text, length, capacity, "    cvtsi2sd xmm0, rax\n");
  }
  if (node->kind == C_AST_UNARY &&
      strcmp(node->data.unary.operator, "-") == 0)
  {
    return emit_numeric_as_real(node->data.unary.operand, semantic,
                                real_values, real_count, text, length,
                                capacity) &&
           append(text, length, capacity,
                  "    xorpd xmm1, xmm1\n    subsd xmm1, xmm0\n"
                  "    movsd xmm0, xmm1\n");
  }
  if (node->kind == C_AST_BINARY)
  {
    if (!emit_numeric_as_real(node->data.binary.left, semantic, real_values,
                              real_count, text, length, capacity) ||
        !append(text, length, capacity,
                "    sub rsp, 8\n    movsd [rsp], xmm0\n") ||
        !emit_numeric_as_real(node->data.binary.right, semantic, real_values,
                              real_count, text, length, capacity) ||
        !append(text, length, capacity, "    movsd xmm1, [rsp]\n    add rsp, 8\n"))
    {
      return 0;
    }
    if (strcmp(node->data.binary.operator, "+") == 0)
    {
      return append(text, length, capacity, "    addsd xmm1, xmm0\n    movsd xmm0, xmm1\n");
    }
    if (strcmp(node->data.binary.operator, "-") == 0)
    {
      return append(text, length, capacity, "    subsd xmm1, xmm0\n    movsd xmm0, xmm1\n");
    }
    if (strcmp(node->data.binary.operator, "*") == 0)
    {
      return append(text, length, capacity, "    mulsd xmm1, xmm0\n    movsd xmm0, xmm1\n");
    }
    if (strcmp(node->data.binary.operator, "/") == 0)
    {
      return append(text, length, capacity, "    divsd xmm1, xmm0\n    movsd xmm0, xmm1\n");
    }
  }
  return 0;
}

static int emit_expression(const CAstNode *node, const CSemanticResult *semantic,
                           char **text, size_t *length, size_t *capacity)
{
  if (node == NULL)
    return 0;
  if (node->kind == C_AST_LITERAL)
  {
    if (node->data.literal.literal_kind == C_TOKEN_STRING ||
        node->data.literal.literal_kind == C_TOKEN_CHARACTER)
    {
      const int index = text_index(g_text_values, g_text_count,
                                   node->data.literal.value);
      return index >= 0 && append(text, length, capacity,
                                  "    lea rax, [rel text%d]\n", index);
    }
    if (node->data.literal.literal_kind == C_TOKEN_BOOLEAN)
      return append(text, length, capacity, "    mov rax, %d\n",
                    strcmp(node->data.literal.value, "صح") == 0 ? 1 : 0);
    if (node->data.literal.literal_kind != C_TOKEN_INTEGER)
      return 0;
    return append(text, length, capacity, "    mov rax, %s\n",
                  node->data.literal.value);
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE)
  {
    const CAstNode *constant = constant_value_for(node->data.reference.name);
    if (constant)
    {
      return emit_expression(constant, semantic, text, length, capacity);
    }
    const int slot = slot_for(semantic, node->data.reference.name);
    return slot > 0 && append(text, length, capacity,
                              "    mov rax, [rbp-%d]\n", slot);
  }
  if (node->kind == C_AST_BINARY)
  {
    if (!emit_expression(node->data.binary.left, semantic, text, length,
                         capacity) ||
        !append(text, length, capacity, "    push rax\n") ||
        !emit_expression(node->data.binary.right, semantic, text, length,
                         capacity) ||
        !append(text, length, capacity, "    mov rcx, rax\n    pop rax\n"))
    {
      return 0;
    }
    if (strcmp(node->data.binary.operator, "+") == 0)
    {
      return append(text, length, capacity, "    add rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "-") == 0)
    {
      return append(text, length, capacity, "    sub rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "*") == 0)
    {
      return append(text, length, capacity, "    imul rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "/") == 0)
    {
      return append(text, length, capacity,
                    "    cqo\n    idiv rcx\n");
    }
    const char *set_instruction = NULL;
    if (strcmp(node->data.binary.operator, "==") == 0)
      set_instruction = "sete";
    else if (strcmp(node->data.binary.operator, "!=") == 0)
      set_instruction = "setne";
    else if (strcmp(node->data.binary.operator, "<") == 0)
      set_instruction = "setl";
    else if (strcmp(node->data.binary.operator, "<=") == 0)
      set_instruction = "setle";
    else if (strcmp(node->data.binary.operator, ">") == 0)
      set_instruction = "setg";
    else if (strcmp(node->data.binary.operator, ">=") == 0)
      set_instruction = "setge";
    if (set_instruction != NULL)
    {
      return append(text, length, capacity,
                    "    cmp rax, rcx\n    %s al\n    movzx rax, al\n",
                    set_instruction);
    }
  }
  return 0;
}

/* Collect all string literals from the AST for the .data section */
static void collect_strings(const CAstNodeList *list,
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
static int emit_nasm_string(char **text, size_t *length, size_t *capacity,
                            const char *json_str)
{
  /* json_str includes surrounding quotes from lexer, e.g. "hello" */
  const char *p = json_str;
  if (*p == '"')
    p++; /* skip opening quote */

  if (!append(text, length, capacity, "    db "))
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
    if (!first && !append(text, length, capacity, ", "))
      return 0;
    if (!append(text, length, capacity, "%d", (unsigned char)c))
      return 0;
    first = 0;
  }
  if (!first && !append(text, length, capacity, ", "))
    return 0;
  return append(text, length, capacity, "0\n");
}

static int emit_nasm_bytes(char **text, size_t *length, size_t *capacity,
                           const char *value)
{
  if (!append(text, length, capacity, "    db "))
    return 0;
  for (size_t i = 0; value[i] != '\0'; i++)
  {
    if (i > 0 && !append(text, length, capacity, ", "))
      return 0;
    if (!append(text, length, capacity, "%u", (unsigned char)value[i]))
      return 0;
  }
  return append(text, length, capacity, "%s0\n", value[0] ? ", " : "");
}

static int emit_native_statements(const CAstNodeList *statements,
                                  const CSemanticResult *semantic,
                                  char **text, size_t *length, size_t *capacity,
                                  size_t *label_index)
{
  for (size_t i = 0; i < statements->count; i++)
  {
    const CAstNode *statement = statements->items[i];
    if (statement->kind == C_AST_IF)
    {
      const size_t label = (*label_index)++;
      if (!emit_expression(statement->data.conditional.condition, semantic,
                           text, length, capacity) ||
          !append(text, length, capacity,
                  "    cmp rax, 0\n    je if_else%zu\n", label) ||
          !emit_native_statements(&statement->data.conditional.then_branch,
                                  semantic, text, length, capacity, label_index) ||
          !append(text, length, capacity,
                  "    jmp if_done%zu\nif_else%zu:\n", label, label) ||
          !emit_native_statements(&statement->data.conditional.else_branch,
                                  semantic, text, length, capacity, label_index) ||
          !append(text, length, capacity, "if_done%zu:\n", label))
        return 0;
      continue;
    }
    if (statement->kind == C_AST_PROGRAM)
    {
      if (!emit_native_statements(&statement->data.program.statements, semantic,
                                  text, length, capacity, label_index))
        return 0;
      continue;
    }
    if (statement->kind == C_AST_ASSIGNMENT)
    {
      const int slot = slot_for(semantic, statement->data.assignment.name);
      if (slot == 0 ||
          !emit_expression(statement->data.assignment.expression, semantic,
                           text, length, capacity) ||
          !append(text, length, capacity, "    mov [rbp-%d], rax\n", slot))
        return 0;
      continue;
    }
    if (statement->kind != C_AST_PRINT)
      return 0;
    for (size_t vi = 0; vi < statement->data.print.values.count; vi++)
    {
      const CAstNode *value = statement->data.print.values.items[vi];
      if (value == NULL)
        continue;
      const char *value_register =
#ifdef _WIN32
          "rdx";
      const char *format_register = "rcx";
#else
          "rsi";
      const char *format_register = "rdi";
#endif
      if (expression_is_boolean(value, semantic))
      {
        const size_t label = (*label_index)++;
        if (!emit_expression(value, semantic, text, length, capacity) ||
            !append(text, length, capacity,
                    "    cmp rax, 0\n    jne if_bool_true%zu\n"
                    "    lea %s, [rel fmt_bool_false]\n"
                    "    xor eax, eax\n    call printf\n"
                    "    jmp if_bool_done%zu\n"
                    "if_bool_true%zu:\n    lea %s, [rel fmt_bool_true]\n"
                    "    xor eax, eax\n    call printf\n"
                    "if_bool_done%zu:\n",
                    label, format_register, label, label, format_register,
                    label))
          return 0;
      }
      else
      {
        const char *format = expression_is_text(value, semantic) ? "fmt_str" : "fmt_int";
        const int emitted = expression_is_text(value, semantic)
                                ? emit_text_expression(value, semantic, text,
                                                       length, capacity)
                                : emit_expression(value, semantic, text, length,
                                                  capacity);
        if (!emitted ||
            !append(text, length, capacity,
                    "    mov %s, rax\n    lea %s, [rel %s]\n"
                    "    xor eax, eax\n    call printf\n",
                    value_register, format_register, format))
          return 0;
      }
    }
  }
  return 1;
}

int c_generate_nasm_x86_64(const CAstNode *program,
                           const CSemanticResult *semantic,
                           CAssemblyResult *result)
{
  if (program == NULL || semantic == NULL || result == NULL ||
      program->kind != C_AST_PROGRAM)
    return 0;
  memset(result, 0, sizeof(*result));
  size_t length = 0U;
  size_t capacity = 0U;
  const size_t frame_size = ((semantic->count * 8U) + 15U) & ~15U;
  size_t read_count = 0U;
  for (size_t i = 0; i < program->data.program.statements.count; i++)
    if (program->data.program.statements.items[i]->kind == C_AST_READ)
      read_count++;

  /* Collect string literals for .data section */
  const char **strings = NULL;
  size_t str_count = 0, str_cap = 0;
  const char **real_values = NULL;
  size_t real_count = 0, real_capacity = 0;
  g_program = program;
  g_text_values = NULL;
  g_text_count = 0;
  size_t text_capacity = 0;
  collect_strings(&program->data.program.statements, &strings, &str_count, &str_cap);
  for (size_t i = 0; i < program->data.program.declarations.count; i++)
  {
    const CAstNode *declaration = program->data.program.declarations.items[i];
    if (declaration->kind == C_AST_CONSTANT_DECLARATION)
    {
      collect_text_literal(declaration->data.constant.value, &g_text_values,
                           &g_text_count, &text_capacity);
      collect_real_literals(declaration->data.constant.value, &real_values,
                            &real_count, &real_capacity);
    }
  }
  for (size_t i = 0; i < program->data.program.statements.count; i++)
  {
    collect_text_literal(program->data.program.statements.items[i],
                         &g_text_values, &g_text_count, &text_capacity);
    collect_real_literals(program->data.program.statements.items[i],
                          &real_values, &real_count, &real_capacity);
  }

  /* .data section */
  if (!append(&result->text, &length, &capacity,
              "; generated by arabicc C\n"
              "default rel\n"
              "global main\n"
              "extern printf\n"
              "extern scanf\n"
              "extern fflush\n"
              "section .data\n"
              "fmt_int: db \"%%ld\", 10, 0\n"
              "fmt_real: db \"%%.15g\", 10, 0\n"
              "fmt_str: db \"%%s\", 10, 0\n"
              "fmt_bool_true: db \"صح\", 10, 0\n"
              "fmt_bool_false: db \"خطأ\", 10, 0\n"
              "fmt_read_int: db \"%%ld\", 0\n"
              "fmt_read_real: db \"%%lf\", 0\n"
              "fmt_read_bool: db \"%%d\", 0\n"
              "fmt_read_char: db \"%%255s\", 0\n"
              "fmt_read_str: db \"%%255s\", 0\n"))
  {
    free(strings);
    c_assembly_result_free(result);
    return 0;
  }
  for (size_t i = 0; i < str_count; i++)
  {
    if (!append(&result->text, &length, &capacity, "str%zu: ", i))
    {
      free(strings);
      c_assembly_result_free(result);
      return 0;
    }
    if (!emit_nasm_string(&result->text, &length, &capacity, strings[i]))
    {
      free(strings);
      c_assembly_result_free(result);
      return 0;
    }
  }
  for (size_t i = 0; i < real_count; i++)
  {
    char *end = NULL;
    const double value = strtod(real_values[i], &end);
    uint64_t bits = 0;
    memcpy(&bits, &value, sizeof(bits));
    if (end == real_values[i] ||
        !append(&result->text, &length, &capacity,
                "real%zu: dq 0x%" PRIx64 "\n", i, bits))
    {
      free(strings);
      free(real_values);
      c_assembly_result_free(result);
      return 0;
    }
  }
  for (size_t i = 0; i < g_text_count; i++)
  {
    if (!append(&result->text, &length, &capacity, "text%zu: ", i) ||
        !emit_nasm_string(&result->text, &length, &capacity, g_text_values[i]))
    {
      free(strings);
      free(real_values);
      free(g_text_values);
      g_text_values = NULL;
      g_text_count = 0;
      c_assembly_result_free(result);
      return 0;
    }
  }
  size_t request_label_index = 0U;
  for (size_t i = 0; i < program->data.program.statements.count; i++)
  {
    const CAstNode *read = program->data.program.statements.items[i];
    if (read->kind != C_AST_READ)
      continue;
    char request_json[1024];
    const char *read_type = type_for(semantic, read->data.access.name);
    const int written = snprintf(
        request_json, sizeof(request_json),
        "{\"requestType\":\"input\",\"name\":\"%s\",\"type\":\"%s\"}\n",
        read->data.access.name, read_type ? read_type : "غير معروف");
    if (written < 0 || (size_t)written >= sizeof(request_json) ||
        !append(&result->text, &length, &capacity,
                "fmt_input_request%zu: ", request_label_index) ||
        !emit_nasm_bytes(&result->text, &length, &capacity, request_json))
    {
      free(strings);
      free(real_values);
      free(g_text_values);
      g_text_values = NULL;
      g_text_count = 0;
      c_assembly_result_free(result);
      return 0;
    }
    request_label_index++;
  }

  /* .text / main prologue */
  if (!append(&result->text, &length, &capacity,
              "section .text\n"
              "main:\n"
              "    push rbp\n"
              "    mov rbp, rsp\n"
              "    sub rsp, %zu\n",
              (frame_size == 0 ? 16 : frame_size) + 32U + read_count * 256U))
  {
    free(strings);
    c_assembly_result_free(result);
    return 0;
  }

  /* Statements */
  size_t read_index = 0U;
  size_t boolean_print_index = 0U;
  size_t if_label_index = 0U;
  for (size_t index = 0U; index < program->data.program.statements.count; index++)
  {
    const CAstNode *statement = program->data.program.statements.items[index];
    if (statement->kind == C_AST_IF)
    {
      const size_t label = if_label_index++;
      if (!emit_expression(statement->data.conditional.condition, semantic,
                           &result->text, &length, &capacity) ||
          !append(&result->text, &length, &capacity,
                  "    cmp rax, 0\n    je if_else%zu\n", label) ||
          !emit_native_statements(&statement->data.conditional.then_branch,
                                  semantic, &result->text, &length, &capacity,
                                  &if_label_index))
      {
        (void)diagnostic_at(result, statement,
                            "تعذر تحويل الفرع الشرطي إلى NASM");
        free(strings);
        return 1;
      }
      if (!append(&result->text, &length, &capacity,
                  "    jmp if_done%zu\nif_else%zu:\n", label, label) ||
          !emit_native_statements(&statement->data.conditional.else_branch,
                                  semantic, &result->text, &length, &capacity,
                                  &if_label_index) ||
          !append(&result->text, &length, &capacity, "if_done%zu:\n", label))
      {
        (void)diagnostic_at(result, statement,
                            "تعذر تحويل الفرع الشرطي إلى NASM");
        free(strings);
        return 1;
      }
      continue;
    }
    if (statement->kind == C_AST_ASSIGNMENT)
    {
      const char *target_type = type_for(semantic, statement->data.assignment.name);
      const int is_real = target_type && strcmp(target_type, "حقيقي") == 0;
      const int emitted = is_real
                              ? emit_real_expression(statement->data.assignment.expression, semantic,
                                                     real_values, real_count, &result->text,
                                                     &length, &capacity)
                              : emit_expression(statement->data.assignment.expression, semantic,
                                                &result->text, &length, &capacity);
      if (!emitted)
      {
        (void)diagnostic_at(
            result,
            statement,
            "الإسناد صحيح دلالياً: «%s» من النوع «%s»، لكن مولّد NASM "
            "native لا يدعم هذا النوع حالياً؛ الدعم الحالي محصور في "
            "تخزين وتعبيرات integer",
            statement->data.assignment.name,
            type_for(semantic, statement->data.assignment.name)
                ? type_for(semantic, statement->data.assignment.name)
                : assignment_expression_kind(statement->data.assignment.expression));
        free(strings);
        return 1;
      }
      const int slot = slot_for(semantic, statement->data.assignment.name);
      if (slot == 0 || !append(&result->text, &length, &capacity,
                               is_real ? "    movsd [rbp-%d], xmm0\n"
                                       : "    mov [rbp-%d], rax\n",
                               slot))
      {
        (void)diagnostic_at(result, statement,
                            "متغير الإسناد غير موجود في stack layout");
        free(strings);
        return 1;
      }
    }
    else if (statement->kind == C_AST_READ)
    {
      const int slot = slot_for(semantic, statement->data.access.name);
      const char *type = type_for(semantic, statement->data.access.name);
      if (type == NULL ||
          (strcmp(type, "صحيح") != 0 && strcmp(type, "حقيقي") != 0 &&
           strcmp(type, "منطقي") != 0 && strcmp(type, "حرفي") != 0 &&
           strcmp(type, "خيط_رمزي") != 0))
      {
        (void)diagnostic_at(
            result,
            statement,
            "نوع الإدخال native غير مدعوم؛ المتغير «%s» نوعه «%s»",
            statement->data.access.name,
            type ? type : "غير معروف");
        free(strings);
        return 1;
      }
      const int is_text_input =
          strcmp(type, "حرفي") == 0 || strcmp(type, "خيط_رمزي") == 0;
      const int buffer_slot = (int)(frame_size + 32U + read_index * 256U);
      if (slot == 0 || !append(&result->text, &length, &capacity,
                               "    lea "
#ifdef _WIN32
                               "rcx"
#else
                               "rdi"
#endif
                               ", [rel fmt_input_request%zu]\n"
                               "    xor eax, eax\n"
                               "    call printf\n"
                               "    xor "
#ifdef _WIN32
                               "ecx"
#else
                               "edi"
#endif
                               ", "
#ifdef _WIN32
                               "ecx"
#else
                               "edi"
#endif
                               "\n"
                               "    call fflush\n"
                               "    lea "
#ifdef _WIN32
                               "rdx"
#else
                               "rsi"
#endif
                               ", [rbp-%d]\n"
                               "    lea "
#ifdef _WIN32
                               "rcx"
#else
                               "rdi"
#endif
                               ", [rel %s]\n"
                               "    xor eax, eax\n"
                               "    call scanf\n",
                               read_index,
                               is_text_input ? buffer_slot : slot,
                               strcmp(type, "حقيقي") == 0
                                   ? "fmt_read_real"
                                   : strcmp(type, "منطقي") == 0
                                         ? "fmt_read_bool"
                                         : strcmp(type, "حرفي") == 0
                                               ? "fmt_read_char"
                                               : strcmp(type, "خيط_رمزي") == 0
                                                     ? "fmt_read_str"
                                                     : "fmt_read_int"))
      {
        (void)diagnostic_at(result, statement, "تعذر تحويل اقرأ إلى scanf");
        free(strings);
        return 1;
      }
      if (is_text_input &&
          !append(&result->text, &length, &capacity,
                  "    lea rax, [rbp-%d]\n"
                  "    mov [rbp-%d], rax\n",
                  buffer_slot, slot))
      {
        (void)diagnostic_at(result, statement,
                            "تعذر حفظ الإدخال النصي native");
        free(strings);
        return 1;
      }
      read_index++;
    }
    else if (statement->kind == C_AST_PRINT)
    {
      for (size_t vi = 0; vi < statement->data.print.values.count; vi++)
      {
        const CAstNode *val = statement->data.print.values.items[vi];
        if (!val)
          continue;
        if (expression_is_real(val, semantic))
        {
          if (!emit_real_expression(val, semantic, real_values, real_count,
                                    &result->text, &length, &capacity) ||
              !append(&result->text, &length, &capacity,
                      "    movq "
#ifdef _WIN32
                      "rdx"
#else
                      "rsi"
#endif
                      ", xmm0\n"
                      "    lea "
#ifdef _WIN32
                      "rcx"
#else
                      "rdi"
#endif
                      ", [rel fmt_real]\n"
                      "    mov eax, 1\n"
                      "    call printf\n"))
          {
            (void)diagnostic_at(result, statement,
                                "تعذر تحويل طباعة الحقيقي إلى NASM");
            free(strings);
            free(real_values);
            return 1;
          }
          continue;
        }
        if (expression_is_boolean(val, semantic))
        {
          const size_t label = boolean_print_index++;
          if (!emit_expression(val, semantic, &result->text, &length,
                               &capacity) ||
              !append(&result->text, &length, &capacity,
                      "    cmp rax, 0\n"
                      "    jne bool_true%zu\n"
                      "    lea "
#ifdef _WIN32
                      "rcx"
#else
                      "rdi"
#endif
                      ", [rel fmt_bool_false]\n"
                      "    xor eax, eax\n"
                      "    call printf\n"
                      "    jmp bool_done%zu\n"
                      "bool_true%zu:\n"
                      "    lea "
#ifdef _WIN32
                      "rcx"
#else
                      "rdi"
#endif
                      ", [rel fmt_bool_true]\n"
                      "    xor eax, eax\n"
                      "    call printf\n"
                      "bool_done%zu:\n",
                      label, label, label, label))
          {
            (void)diagnostic_at(result, statement,
                                "تعذر تحويل طباعة المنطقي إلى NASM");
            free(strings);
            free(real_values);
            return 1;
          }
          continue;
        }
        /* Text values and references → use fmt_str */
        if (expression_is_text(val, semantic))
        {
          if (!emit_text_expression(val, semantic, &result->text, &length,
                                    &capacity) ||
              !append(&result->text, &length, &capacity,
                      "    mov "
#ifdef _WIN32
                      "rdx"
#else
                      "rsi"
#endif
                      ", rax\n"
                      "    lea "
#ifdef _WIN32
                      "rcx"
#else
                      "rdi"
#endif
                      ", [rel fmt_str]\n"
                      "    xor eax, eax\n"
                      "    call printf\n"))
          {
            (void)diagnostic_at(result, statement, "تعذر تحويل print string إلى NASM");
            free(strings);
            free(real_values);
            free(g_text_values);
            g_text_values = NULL;
            g_text_count = 0;
            return 1;
          }
        }
        else
        {
          /* Integer / variable / expression → use fmt_int */
          if (!emit_expression(val, semantic, &result->text, &length, &capacity) ||
              !append(&result->text, &length, &capacity,
                      "    mov "
#ifdef _WIN32
                      "rdx"
#else
                      "rsi"
#endif
                      ", rax\n"
                      "    lea "
#ifdef _WIN32
                      "rcx"
#else
                      "rdi"
#endif
                      ", [rel fmt_int]\n"
                      "    xor eax, eax\n"
                      "    call printf\n"))
          {
            (void)diagnostic_at(result, statement, "تعذر تحويل print integer إلى NASM");
            free(strings);
            return 1;
          }
        }
      }
    }
    else if (statement->kind != C_AST_EMPTY)
    {
      (void)diagnostic_at(result, statement,
                          "تعليمة غير مدعومة في NASM backend الحالي");
      free(strings);
      return 1;
    }
  }
  free(strings);
  if (!append(&result->text, &length, &capacity,
              "    xor eax, eax\n    leave\n    ret\n"
              "section .note.GNU-stack noalloc noexec nowrite progbits\n"))
  {
    c_assembly_result_free(result);
    return 0;
  }
  return 1;
}

void c_assembly_result_free(CAssemblyResult *result)
{
  if (result == NULL)
    return;
  free(result->text);
  for (size_t index = 0U; index < result->diagnostic_count; index++)
  {
    free(result->diagnostics[index]);
  }
  free(result->diagnostics);
  free(result->diagnostic_offsets);
  free(result->diagnostic_lines);
  free(result->diagnostic_columns);
  free(result->diagnostic_lengths);
  memset(result, 0, sizeof(*result));
}
