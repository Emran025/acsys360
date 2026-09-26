#include "asm_x86_64_internal.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


static const char *c_asm_literal_kind_name(CTokenKind kind)
{
  switch (kind)
  {
  case C_TOKEN_INTEGER: return "صحيح";
  case C_TOKEN_REAL: return "حقيقي";
  case C_TOKEN_BOOLEAN: return "منطقي";
  case C_TOKEN_CHARACTER: return "حرفي";
  case C_TOKEN_STRING: return "خيط_رمزي";
  default: return "غير معروف";
  }
}

const char *c_asm_assignment_expression_kind(const CAstNode *node)
{
  if (node == NULL) return "فارغ";
  if (node->kind == C_AST_LITERAL)
    return c_asm_literal_kind_name(node->data.literal.literal_kind);
  if (node->kind == C_AST_VARIABLE_REFERENCE) return "مرجع متغير/ثابت";
  if (node->kind == C_AST_BINARY) return "تعبير حسابي";
  if (node->kind == C_AST_UNARY) return "تعبير أحادي";
  return "تعبير غير معروف";
}

int c_asm_emit_native_statements(const CAsmContext *context,
                                  const CAstNodeList *statements,
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
      if (!c_asm_emit_expression(context, statement->data.conditional.condition, semantic,
                           text, length, capacity) ||
          !c_asm_append(text, length, capacity,
                  "    cmp rax, 0\n    je if_else%zu\n", label) ||
          !c_asm_emit_native_statements(context, &statement->data.conditional.then_branch,
                                  semantic, text, length, capacity, label_index) ||
          !c_asm_append(text, length, capacity,
                  "    jmp if_done%zu\nif_else%zu:\n", label, label) ||
          !c_asm_emit_native_statements(context, &statement->data.conditional.else_branch,
                                  semantic, text, length, capacity, label_index) ||
          !c_asm_append(text, length, capacity, "if_done%zu:\n", label))
        return 0;
      continue;
    }
    if (statement->kind == C_AST_PROGRAM)
    {
      if (!c_asm_emit_native_statements(context, &statement->data.program.statements, semantic,
                                  text, length, capacity, label_index))
        return 0;
      continue;
    }
    if (statement->kind == C_AST_ASSIGNMENT)
    {
      const int slot = c_asm_slot_for(semantic, statement->data.assignment.name);
      if (slot == 0 ||
          !c_asm_emit_expression(context, statement->data.assignment.expression, semantic,
                           text, length, capacity) ||
          !c_asm_append(text, length, capacity, "    mov [rbp-%d], rax\n", slot))
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
      if (c_asm_expression_is_boolean(value, semantic))
      {
        const size_t label = (*label_index)++;
        if (!c_asm_emit_expression(context, value, semantic, text, length, capacity) ||
            !c_asm_append(text, length, capacity,
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
        const char *format = c_asm_expression_is_text(value, semantic) ? "fmt_str" : "fmt_int";
        const int emitted = c_asm_expression_is_text(value, semantic)
                                ? c_asm_emit_text_expression(context, value, semantic, text,
                                                       length, capacity)
                                : c_asm_emit_expression(context, value, semantic, text, length,
                                                  capacity);
        if (!emitted ||
            !c_asm_append(text, length, capacity,
                    "    mov %s, rax\n    lea %s, [rel %s]\n"
                    "    xor eax, eax\n    call printf\n",
                    value_register, format_register, format))
          return 0;
      }
    }
  }
  return 1;
}
