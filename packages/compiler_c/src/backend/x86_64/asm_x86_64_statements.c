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

int c_asm_emit_program_statements(const CAsmContext *context,
                                  const CSemanticResult *semantic,
                                  CAssemblyResult *result,
                                  size_t frame_size,
                                  size_t *length, size_t *capacity)
{
  size_t read_index = 0U;
  size_t boolean_print_index = 0U;
  size_t if_label_index = 0U;
  for (size_t index = 0U; index < context->program->data.program.statements.count; index++)
  {
    const CAstNode *statement = context->program->data.program.statements.items[index];
    if (statement->kind == C_AST_IF)
    {
      const size_t label = if_label_index++;
      if (!c_asm_emit_expression(context, statement->data.conditional.condition, semantic,
                           &result->text, length, capacity) ||
          !c_asm_append(&result->text, length, capacity,
                  "    cmp rax, 0\n    je if_else%zu\n", label) ||
          !c_asm_emit_native_statements(context, &statement->data.conditional.then_branch,
                                  semantic, &result->text, length, capacity,
                                  &if_label_index))
      {
        (void)c_asm_diagnostic_at(result, statement,
                            "تعذر تحويل الفرع الشرطي إلى NASM");
        return 0;
      }
      if (!c_asm_append(&result->text, length, capacity,
                  "    jmp if_done%zu\nif_else%zu:\n", label, label) ||
          !c_asm_emit_native_statements(context, &statement->data.conditional.else_branch,
                                  semantic, &result->text, length, capacity,
                                  &if_label_index) ||
          !c_asm_append(&result->text, length, capacity, "if_done%zu:\n", label))
      {
        (void)c_asm_diagnostic_at(result, statement,
                            "تعذر تحويل الفرع الشرطي إلى NASM");
        return 0;
      }
      continue;
    }
    if (statement->kind == C_AST_ASSIGNMENT)
    {
      const char *target_type = c_asm_type_for(semantic, statement->data.assignment.name);
      const int is_real = target_type && strcmp(target_type, "حقيقي") == 0;
      const int emitted = is_real
                              ? c_asm_emit_real_expression(context, statement->data.assignment.expression, semantic,
                                                     context->real_values, context->real_count, &result->text,
                                                     length, capacity)
                              : c_asm_emit_expression(context, statement->data.assignment.expression, semantic,
                                                &result->text, length, capacity);
      if (!emitted)
      {
        (void)c_asm_diagnostic_at(
            result,
            statement,
            "الإسناد صحيح دلالياً: «%s» من النوع «%s»، لكن مولّد NASM "
            "native لا يدعم هذا النوع حالياً؛ الدعم الحالي محصور في "
            "تخزين وتعبيرات integer",
            statement->data.assignment.name,
            c_asm_type_for(semantic, statement->data.assignment.name)
                ? c_asm_type_for(semantic, statement->data.assignment.name)
                : c_asm_assignment_expression_kind(statement->data.assignment.expression));
        return 0;
      }
      const int slot = c_asm_slot_for(semantic, statement->data.assignment.name);
      if (slot == 0 || !c_asm_append(&result->text, length, capacity,
                               is_real ? "    movsd [rbp-%d], xmm0\n"
                                       : "    mov [rbp-%d], rax\n",
                               slot))
      {
        (void)c_asm_diagnostic_at(result, statement,
                            "متغير الإسناد غير موجود في stack layout");
        return 0;
      }
    }
    else if (statement->kind == C_AST_READ)
    {
      const int slot = c_asm_slot_for(semantic, statement->data.access.name);
      const char *type = c_asm_type_for(semantic, statement->data.access.name);
      if (type == NULL ||
          (strcmp(type, "صحيح") != 0 && strcmp(type, "حقيقي") != 0 &&
           strcmp(type, "منطقي") != 0 && strcmp(type, "حرفي") != 0 &&
           strcmp(type, "خيط_رمزي") != 0))
      {
        (void)c_asm_diagnostic_at(
            result,
            statement,
            "نوع الإدخال native غير مدعوم؛ المتغير «%s» نوعه «%s»",
            statement->data.access.name,
            type ? type : "غير معروف");
        return 0;
      }
      const int is_text_input =
          strcmp(type, "حرفي") == 0 || strcmp(type, "خيط_رمزي") == 0;
      const int buffer_slot = (int)(frame_size + 32U + read_index * 256U);
      if (slot == 0 || !c_asm_append(&result->text, length, capacity,
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
        (void)c_asm_diagnostic_at(result, statement, "تعذر تحويل اقرأ إلى scanf");
        return 0;
      }
      if (is_text_input &&
          !c_asm_append(&result->text, length, capacity,
                  "    lea rax, [rbp-%d]\n"
                  "    mov [rbp-%d], rax\n",
                  buffer_slot, slot))
      {
        (void)c_asm_diagnostic_at(result, statement,
                            "تعذر حفظ الإدخال النصي native");
        return 0;
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
        if (c_asm_expression_is_real(val, semantic))
        {
          if (!c_asm_emit_real_expression(context, val, semantic, context->real_values, context->real_count,
                                    &result->text, length, capacity) ||
              !c_asm_append(&result->text, length, capacity,
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
            (void)c_asm_diagnostic_at(result, statement,
                                "تعذر تحويل طباعة الحقيقي إلى NASM");
                      return 0;
          }
          continue;
        }
        if (c_asm_expression_is_boolean(val, semantic))
        {
          const size_t label = boolean_print_index++;
          if (!c_asm_emit_expression(context, val, semantic, &result->text, length,
                               capacity) ||
              !c_asm_append(&result->text, length, capacity,
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
            (void)c_asm_diagnostic_at(result, statement,
                                "تعذر تحويل طباعة المنطقي إلى NASM");
                      return 0;
          }
          continue;
        }
        /* Text values and references → use fmt_str */
        if (c_asm_expression_is_text(val, semantic))
        {
          if (!c_asm_emit_text_expression(context, val, semantic, &result->text, length,
                                    capacity) ||
              !c_asm_append(&result->text, length, capacity,
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
            (void)c_asm_diagnostic_at(result, statement, "تعذر تحويل print string إلى NASM");
                            return 0;
          }
        }
        else
        {
          /* Integer / variable / expression → use fmt_int */
          if (!c_asm_emit_expression(context, val, semantic, &result->text, length, capacity) ||
              !c_asm_append(&result->text, length, capacity,
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
            (void)c_asm_diagnostic_at(result, statement, "تعذر تحويل print integer إلى NASM");
                return 0;
          }
        }
      }
    }
    else if (statement->kind != C_AST_EMPTY)
    {
      (void)c_asm_diagnostic_at(result, statement,
                          "تعليمة غير مدعومة في NASM backend الحالي");
      return 0;
    }
  }
  return 1;
}
