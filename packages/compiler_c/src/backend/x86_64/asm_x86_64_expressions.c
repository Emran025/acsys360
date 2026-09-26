#include "asm_x86_64_internal.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int c_asm_expression_is_text(const CAstNode *node,
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
    const char *type = c_asm_type_for(semantic, node->data.reference.name);
    return type && (strcmp(type, "خيط_رمزي") == 0 || strcmp(type, "حرفي") == 0);
  }
  return 0;
}

int c_asm_expression_is_boolean(const CAstNode *node,
                                 const CSemanticResult *semantic)
{
  if (!node)
    return 0;
  if (node->kind == C_AST_LITERAL)
    return node->data.literal.literal_kind == C_TOKEN_BOOLEAN;
  if (node->kind == C_AST_VARIABLE_REFERENCE)
  {
    const char *type = c_asm_type_for(semantic, node->data.reference.name);
    return type && strcmp(type, "منطقي") == 0;
  }
  return 0;
}

int c_asm_emit_text_expression(const CAsmContext *context,
                                const CAstNode *node,
                                const CSemanticResult *semantic,
                                char **text, size_t *length, size_t *capacity)
{
  const CAstNode *value = node;
  if (node && node->kind == C_AST_VARIABLE_REFERENCE)
  {
    value = c_asm_constant_value_for(context, node->data.reference.name);
    if (!value)
    {
      const int slot = c_asm_slot_for(semantic, node->data.reference.name);
      return slot > 0 && c_asm_append(text, length, capacity,
                                "    mov rax, [rbp-%d]\n", slot);
    }
  }
  if (!value || (value->kind != C_AST_LITERAL) ||
      (value->data.literal.literal_kind != C_TOKEN_STRING &&
       value->data.literal.literal_kind != C_TOKEN_CHARACTER))
    return 0;
  const int index = c_asm_text_index(context->text_values, context->text_count,
                               value->data.literal.value);
  return index >= 0 && c_asm_append(text, length, capacity,
                              "    lea rax, [rel text%d]\n", index);
}
int c_asm_expression_is_real(const CAstNode *node,
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
    return c_asm_type_for(semantic, node->data.reference.name) &&
           strcmp(c_asm_type_for(semantic, node->data.reference.name), "حقيقي") == 0;
  }
  if (node->kind == C_AST_UNARY)
  {
    return c_asm_expression_is_real(node->data.unary.operand, semantic);
  }
  if (node->kind == C_AST_BINARY)
  {
    return c_asm_expression_is_real(node->data.binary.left, semantic) ||
           c_asm_expression_is_real(node->data.binary.right, semantic);
  }
  return 0;
}
int c_asm_emit_real_expression(const CAsmContext *context,
                                const CAstNode *node,
                                const CSemanticResult *semantic,
                                const char **real_values, size_t real_count,
                                char **text, size_t *length, size_t *capacity);

static int c_asm_emit_numeric_as_real(const CAsmContext *context,
                                const CAstNode *node,
                                const CSemanticResult *semantic,
                                const char **real_values, size_t real_count,
                                char **text, size_t *length, size_t *capacity)
{
  if (c_asm_expression_is_real(node, semantic))
  {
    return c_asm_emit_real_expression(context, node, semantic, real_values, real_count,
                                text, length, capacity);
  }
  return c_asm_emit_expression(context, node, semantic, text, length, capacity) &&
         c_asm_append(text, length, capacity, "    cvtsi2sd xmm0, rax\n");
}

int c_asm_emit_real_expression(const CAsmContext *context,
                                const CAstNode *node,
                                const CSemanticResult *semantic,
                                const char **real_values, size_t real_count,
                                char **text, size_t *length, size_t *capacity)
{
  if (node == NULL)
    return 0;
  if (node->kind == C_AST_LITERAL &&
      node->data.literal.literal_kind == C_TOKEN_REAL)
  {
    const int index = c_asm_real_literal_index(real_values, real_count,
                                         node->data.literal.value);
    return index >= 0 && c_asm_append(text, length, capacity,
                                "    movsd xmm0, [rel real%d]\n", index);
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE)
  {
    const int slot = c_asm_slot_for(semantic, node->data.reference.name);
    if (slot <= 0)
      return 0;
    if (strcmp(c_asm_type_for(semantic, node->data.reference.name), "حقيقي") == 0)
    {
      return c_asm_append(text, length, capacity,
                    "    movsd xmm0, [rbp-%d]\n", slot);
    }
    return c_asm_emit_expression(context, node, semantic, text, length, capacity) &&
           c_asm_append(text, length, capacity, "    cvtsi2sd xmm0, rax\n");
  }
  if (node->kind == C_AST_UNARY &&
      strcmp(node->data.unary.operator, "-") == 0)
  {
    return c_asm_emit_numeric_as_real(context, node->data.unary.operand, semantic,
                                real_values, real_count, text, length,
                                capacity) &&
           c_asm_append(text, length, capacity,
                  "    xorpd xmm1, xmm1\n    subsd xmm1, xmm0\n"
                  "    movsd xmm0, xmm1\n");
  }
  if (node->kind == C_AST_BINARY)
  {
    if (!c_asm_emit_numeric_as_real(context, node->data.binary.left, semantic, real_values,
                              real_count, text, length, capacity) ||
        !c_asm_append(text, length, capacity,
                "    sub rsp, 8\n    movsd [rsp], xmm0\n") ||
        !c_asm_emit_numeric_as_real(context, node->data.binary.right, semantic, real_values,
                              real_count, text, length, capacity) ||
        !c_asm_append(text, length, capacity, "    movsd xmm1, [rsp]\n    add rsp, 8\n"))
    {
      return 0;
    }
    if (strcmp(node->data.binary.operator, "+") == 0)
    {
      return c_asm_append(text, length, capacity, "    addsd xmm1, xmm0\n    movsd xmm0, xmm1\n");
    }
    if (strcmp(node->data.binary.operator, "-") == 0)
    {
      return c_asm_append(text, length, capacity, "    subsd xmm1, xmm0\n    movsd xmm0, xmm1\n");
    }
    if (strcmp(node->data.binary.operator, "*") == 0)
    {
      return c_asm_append(text, length, capacity, "    mulsd xmm1, xmm0\n    movsd xmm0, xmm1\n");
    }
    if (strcmp(node->data.binary.operator, "/") == 0)
    {
      return c_asm_append(text, length, capacity, "    divsd xmm1, xmm0\n    movsd xmm0, xmm1\n");
    }
  }
  return 0;
}

int c_asm_emit_expression(const CAsmContext *context,
                           const CAstNode *node, const CSemanticResult *semantic,
                           char **text, size_t *length, size_t *capacity)
{
  if (node == NULL)
    return 0;
  if (node->kind == C_AST_LITERAL)
  {
    if (node->data.literal.literal_kind == C_TOKEN_STRING ||
        node->data.literal.literal_kind == C_TOKEN_CHARACTER)
    {
      const int index = c_asm_text_index(context->text_values, context->text_count,
                                   node->data.literal.value);
      return index >= 0 && c_asm_append(text, length, capacity,
                                  "    lea rax, [rel text%d]\n", index);
    }
    if (node->data.literal.literal_kind == C_TOKEN_BOOLEAN)
      return c_asm_append(text, length, capacity, "    mov rax, %d\n",
                    strcmp(node->data.literal.value, "صح") == 0 ? 1 : 0);
    if (node->data.literal.literal_kind != C_TOKEN_INTEGER)
      return 0;
    return c_asm_append(text, length, capacity, "    mov rax, %s\n",
                  node->data.literal.value);
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE)
  {
    const CAstNode *constant = c_asm_constant_value_for(context, node->data.reference.name);
    if (constant)
    {
      return c_asm_emit_expression(context, constant, semantic, text, length, capacity);
    }
    const int slot = c_asm_slot_for(semantic, node->data.reference.name);
    return slot > 0 && c_asm_append(text, length, capacity,
                              "    mov rax, [rbp-%d]\n", slot);
  }
  if (node->kind == C_AST_BINARY)
  {
    if (!c_asm_emit_expression(context, node->data.binary.left, semantic, text, length,
                         capacity) ||
        !c_asm_append(text, length, capacity, "    push rax\n") ||
        !c_asm_emit_expression(context, node->data.binary.right, semantic, text, length,
                         capacity) ||
        !c_asm_append(text, length, capacity, "    mov rcx, rax\n    pop rax\n"))
    {
      return 0;
    }
    if (strcmp(node->data.binary.operator, "+") == 0)
    {
      return c_asm_append(text, length, capacity, "    add rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "-") == 0)
    {
      return c_asm_append(text, length, capacity, "    sub rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "*") == 0)
    {
      return c_asm_append(text, length, capacity, "    imul rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "/") == 0)
    {
      return c_asm_append(text, length, capacity,
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
      return c_asm_append(text, length, capacity,
                    "    cmp rax, rcx\n    %s al\n    movzx rax, al\n",
                    set_instruction);
    }
  }
  return 0;
}
