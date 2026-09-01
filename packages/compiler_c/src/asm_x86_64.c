#include "asm_x86_64.h"

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

static int append(char **text, size_t *length, size_t *capacity,
                  const char *format, ...) {
  va_list arguments;
  va_start(arguments, format);
  va_list copy;
  va_copy(copy, arguments);
  const int required = vsnprintf(NULL, 0U, format, copy);
  va_end(copy);
  if (required < 0) {
    va_end(arguments);
    return 0;
  }
  const size_t needed = *length + (size_t)required + 1U;
  if (needed > *capacity) {
    size_t next_capacity = *capacity == 0U ? 1024U : *capacity;
    while (next_capacity < needed) next_capacity *= 2U;
    char *next = realloc(*text, next_capacity);
    if (next == NULL) {
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

static int diagnostic(CAssemblyResult *result, const char *message) {
  char **items = realloc(result->diagnostics,
                         (result->diagnostic_count + 1U) * sizeof(*items));
  if (items == NULL) return 0;
  result->diagnostics = items;
  result->diagnostics[result->diagnostic_count] = duplicate(message);
  if (result->diagnostics[result->diagnostic_count] == NULL) return 0;
  result->diagnostic_count++;
  return 1;
}

static const CSymbol *symbol_for(const CSemanticResult *semantic, const char *name) {
  for (size_t index = 0U; index < semantic->count; index++) {
    if (strcmp(semantic->items[index].name, name) == 0) return &semantic->items[index];
  }
  return NULL;
}

static int slot_for(const CSemanticResult *semantic, const char *name) {
  const CSymbol *symbol = symbol_for(semantic, name);
  if (symbol == NULL) return 0;
  return (int)(((size_t)(symbol - semantic->items) + 1U) * 8U);
}

static int emit_expression(const CAstNode *node, const CSemanticResult *semantic,
                           char **text, size_t *length, size_t *capacity) {
  if (node == NULL) return 0;
  if (node->kind == C_AST_LITERAL) {
    if (node->data.literal.literal_kind != C_TOKEN_INTEGER) return 0;
    return append(text, length, capacity, "    mov rax, %s\n",
                  node->data.literal.value);
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE) {
    const int slot = slot_for(semantic, node->data.reference.name);
    const CSymbol *symbol = symbol_for(semantic, node->data.reference.name);
    if (slot <= 0 || symbol == NULL || !append(text, length, capacity,
                              "    mov rax, [rbp-%d]\n", slot)) return 0;
    if (symbol->by_reference && !append(text, length, capacity, "    mov rax, [rax]\n")) return 0;
    return 1;
  }
  if (node->kind == C_AST_BINARY) {
    if (!emit_expression(node->data.binary.left, semantic, text, length,
                         capacity) ||
        !append(text, length, capacity, "    push rax\n") ||
        !emit_expression(node->data.binary.right, semantic, text, length,
                         capacity) ||
        !append(text, length, capacity, "    mov rcx, rax\n    pop rax\n")) {
      return 0;
    }
    if (strcmp(node->data.binary.operator, "+") == 0) {
      return append(text, length, capacity, "    add rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "-") == 0) {
      return append(text, length, capacity, "    sub rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "*") == 0) {
      return append(text, length, capacity, "    imul rax, rcx\n");
    }
    if (strcmp(node->data.binary.operator, "/") == 0) {
      return append(text, length, capacity,
                    "    cqo\n    idiv rcx\n");
    }
    const char *condition = NULL;
    if (strcmp(node->data.binary.operator, ">") == 0) condition = "g";
    else if (strcmp(node->data.binary.operator, "<") == 0) condition = "l";
    else if (strcmp(node->data.binary.operator, ">=") == 0) condition = "ge";
    else if (strcmp(node->data.binary.operator, "<=") == 0) condition = "le";
    else if (strcmp(node->data.binary.operator, "==") == 0) condition = "e";
    else if (strcmp(node->data.binary.operator, "!=") == 0) condition = "ne";
    if (condition != NULL) {
      return append(text, length, capacity,
                    "    cmp rax, rcx\n    set%s al\n    movzx rax, al\n", condition);
    }
  }
  return 0;
}

static const CAstNode *find_procedure(const CAstNode *program, const char *name) {
  for (size_t index = 0U; index < program->data.program.declarations.count; index++) {
    const CAstNode *declaration = program->data.program.declarations.items[index];
    if (declaration->kind == C_AST_PROCEDURE_DECLARATION &&
        strcmp(declaration->data.procedure.name, name) == 0) return declaration;
  }
  return NULL;
}

static int emit_statements(const CAstNode *program, const CAstNodeList *list, const CSemanticResult *semantic,
                           CAssemblyResult *result, char **text, size_t *length,
                           size_t *capacity, size_t *label) {
  for (size_t index = 0U; index < list->count; index++) {
    const CAstNode *statement = list->items[index];
    if (statement->kind == C_AST_EMPTY) continue;
    if (statement->kind == C_AST_ASSIGNMENT) {
      if (statement->data.assignment.selectors.count != 0U ||
          !emit_expression(statement->data.assignment.expression, semantic, text, length, capacity)) return 0;
      const int slot = slot_for(semantic, statement->data.assignment.name);
      const CSymbol *target = symbol_for(semantic, statement->data.assignment.name);
      if (slot == 0 || target == NULL) return 0;
      if (target->by_reference) {
        if (!append(text, length, capacity, "    mov rcx, [rbp-%d]\n    mov [rcx], rax\n", slot)) return 0;
      } else if (!append(text, length, capacity, "    mov [rbp-%d], rax\n", slot)) return 0;
    } else if (statement->kind == C_AST_PRINT) {
      for (size_t value = 0U; value < statement->data.print.values.count; value++) {
        if (!emit_expression(statement->data.print.values.items[value], semantic, text, length, capacity) ||
            !append(text, length, capacity, "    mov rsi, rax\n    lea rdi, [rel fmt_int]\n    xor eax, eax\n    call printf\n")) return 0;
      }
    } else if (statement->kind == C_AST_IF) {
      const size_t else_label = (*label)++; const size_t end_label = (*label)++;
      if (!emit_expression(statement->data.conditional.condition, semantic, text, length, capacity) ||
          !append(text, length, capacity, "    test rax, rax\n    jz L%zu\n", else_label) ||
          !emit_statements(program, &statement->data.conditional.then_branch, semantic, result, text, length, capacity, label) ||
          !append(text, length, capacity, "    jmp L%zu\nL%zu:\n", end_label, else_label) ||
          !emit_statements(program, &statement->data.conditional.else_branch, semantic, result, text, length, capacity, label) ||
          !append(text, length, capacity, "L%zu:\n", end_label)) return 0;
    } else if (statement->kind == C_AST_REPEAT) {
      const size_t begin_label = (*label)++; const size_t end_label = (*label)++;
      const int descending = statement->data.repeat.step != NULL &&
          statement->data.repeat.step->kind == C_AST_UNARY &&
          strcmp(statement->data.repeat.step->data.unary.operator, "-") == 0;
      const int slot = slot_for(semantic, statement->data.repeat.variable);
      if (slot == 0 || !emit_expression(statement->data.repeat.from, semantic, text, length, capacity) ||
          !append(text, length, capacity, "    mov [rbp-%d], rax\nL%zu:\n", slot, begin_label) ||
          !emit_expression(statement->data.repeat.to, semantic, text, length, capacity) ||
          !append(text, length, capacity, "    mov rcx, rax\n    mov rax, [rbp-%d]\n    cmp rax, rcx\n    j%s L%zu\n", slot, descending ? "l" : "g", end_label) ||
          !emit_statements(program, &statement->data.repeat.body, semantic, result, text, length, capacity, label) ||
          !append(text, length, capacity, "    mov rax, [rbp-%d]\n    %s rax, 1\n    mov [rbp-%d], rax\n    jmp L%zu\nL%zu:\n", slot, descending ? "sub" : "add", slot, begin_label, end_label)) return 0;
    } else if (statement->kind == C_AST_CALL) {
      const CAstNode *procedure = find_procedure(program, statement->data.call.name);
      if (procedure == NULL || statement->data.call.arguments.count > procedure->data.procedure.parameter_count) return 0;
      for (size_t argument = 0U; argument < statement->data.call.arguments.count; argument++) {
        const CParameter *parameter = &procedure->data.procedure.parameters[argument];
        const int parameter_slot = slot_for(semantic, parameter->name);
        if (parameter_slot == 0) return 0;
        const CAstNode *argument_node = statement->data.call.arguments.items[argument];
        if (parameter->by_reference) {
          if (argument_node->kind != C_AST_VARIABLE_REFERENCE || argument_node->data.reference.selectors.count != 0U) return 0;
          const int argument_slot = slot_for(semantic, argument_node->data.reference.name);
          if (argument_slot == 0 || !append(text, length, capacity, "    lea rax, [rbp-%d]\n", argument_slot)) return 0;
        } else if (!emit_expression(argument_node, semantic, text, length, capacity)) return 0;
        if (!append(text, length, capacity, "    mov [rbp-%d], rax\n", parameter_slot)) return 0;
      }
      if (!append(text, length, capacity, "    call %s\n", statement->data.call.name)) return 0;
    } else if (statement->kind == C_AST_WHILE) {
      const size_t begin_label = (*label)++; const size_t end_label = (*label)++;
      if (!append(text, length, capacity, "L%zu:\n", begin_label) ||
          !emit_expression(statement->data.loop.condition, semantic, text, length, capacity) ||
          !append(text, length, capacity, "    test rax, rax\n    jz L%zu\n", end_label) ||
          !emit_statements(program, &statement->data.loop.body, semantic, result, text, length, capacity, label) ||
          !append(text, length, capacity, "    jmp L%zu\nL%zu:\n", begin_label, end_label)) return 0;
    } else {
      (void)diagnostic(result, "تعليمة غير مدعومة في NASM backend الحالي");
      return 0;
    }
  }
  return 1;
}

int c_generate_nasm_x86_64(const CAstNode *program,
                           const CSemanticResult *semantic,
                           CAssemblyResult *result) {
  if (program == NULL || semantic == NULL || result == NULL ||
      program->kind != C_AST_PROGRAM) return 0;
  memset(result, 0, sizeof(*result));
  size_t length = 0U;
  size_t capacity = 0U;
  const size_t frame_size = ((semantic->count * 8U) + 15U) & ~15U;
  if (!append(&result->text, &length, &capacity,
              "; generated by arabicc C\n"
              "global main\n"
              "extern printf\n"
              "section .data\n"
              "fmt_int: db \"%%ld\", 10, 0\n"
              "section .text\n"
              "main:\n"
              "    push rbp\n"
              "    mov rbp, rsp\n"
              "    sub rsp, %zu\n", frame_size)) {
    c_assembly_result_free(result);
    return 0;
  }
  size_t label = 0U;
  if (!emit_statements(program, &program->data.program.statements, semantic, result,
                       &result->text, &length, &capacity, &label)) return 1;
  if (!append(&result->text, &length, &capacity,
              "    xor eax, eax\n    leave\n    ret\n")) {
    c_assembly_result_free(result);
    return 0;
  }
  for (size_t index = 0U; index < program->data.program.declarations.count; index++) {
    const CAstNode *declaration = program->data.program.declarations.items[index];
    if (declaration->kind != C_AST_PROCEDURE_DECLARATION) continue;
    if (!append(&result->text, &length, &capacity, "%s:\n", declaration->data.procedure.name) ||
        !emit_statements(program, &declaration->data.procedure.body, semantic, result,
                         &result->text, &length, &capacity, &label) ||
        !append(&result->text, &length, &capacity, "    ret\n")) {
      c_assembly_result_free(result);
      return 0;
    }
  }
  if (!append(&result->text, &length, &capacity,
              "section .note.GNU-stack noalloc noexec nowrite progbits\n")) {
    c_assembly_result_free(result);
    return 0;
  }
  return 1;
}

void c_assembly_result_free(CAssemblyResult *result) {
  if (result == NULL) return;
  free(result->text);
  for (size_t index = 0U; index < result->diagnostic_count; index++) {
    free(result->diagnostics[index]);
  }
  free(result->diagnostics);
  memset(result, 0, sizeof(*result));
}
