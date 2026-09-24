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

static int slot_for(const CSemanticResult *semantic, const char *name) {
  for (size_t index = 0U; index < semantic->count; index++) {
    if (strcmp(semantic->items[index].name, name) == 0) {
      return (int)((index + 1U) * 8U);
    }
  }
  return 0;
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
    return slot > 0 && append(text, length, capacity,
                              "    mov rax, [rbp-%d]\n", slot);
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
  }
  return 0;
}

/* Collect all string literals from the AST for the .data section */
static void collect_strings(const CAstNodeList *list,
                            const char ***strings, size_t *count, size_t *cap) {
  for (size_t i = 0; i < list->count; i++) {
    const CAstNode *n = list->items[i];
    if (!n) continue;
    if (n->kind == C_AST_PRINT) {
      for (size_t j = 0; j < n->data.print.values.count; j++) {
        const CAstNode *v = n->data.print.values.items[j];
        if (v && v->kind == C_AST_LITERAL &&
            v->data.literal.literal_kind == C_TOKEN_STRING) {
          if (*count >= *cap) {
            *cap = *cap == 0 ? 8 : *cap * 2;
            *strings = realloc(*strings, *cap * sizeof(char *));
          }
          (*strings)[(*count)++] = v->data.literal.value;
        }
      }
    }
  }
}

/* Find index of a string literal in the collected strings array (-1 if not found) */
static int string_index(const char **strings, size_t count, const char *value) {
  for (size_t i = 0; i < count; i++) {
    if (strings[i] == value) return (int)i;
  }
  return -1;
}

/* Emit a C-escaped string as NASM byte sequence */
static int emit_nasm_string(char **text, size_t *length, size_t *capacity,
                            const char *json_str) {
  /* json_str includes surrounding quotes from lexer, e.g. "hello" */
  const char *p = json_str;
  if (*p == '"') p++; /* skip opening quote */

  if (!append(text, length, capacity, "    db ")) return 0;
  int first = 1;
  while (*p && *p != '"') {
    char c = *p++;
    if (c == '\\' && *p) {
      c = *p++;
      switch (c) {
        case 'n': c = '\n'; break;
        case 't': c = '\t'; break;
        case 'r': c = '\r'; break;
        default: break;
      }
    }
    if (!first && !append(text, length, capacity, ", ")) return 0;
    if (!append(text, length, capacity, "%d", (unsigned char)c)) return 0;
    first = 0;
  }
  if (!first && !append(text, length, capacity, ", ")) return 0;
  return append(text, length, capacity, "0\n");
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

  /* Collect string literals for .data section */
  const char **strings = NULL;
  size_t str_count = 0, str_cap = 0;
  collect_strings(&program->data.program.statements, &strings, &str_count, &str_cap);

  /* .data section */
  if (!append(&result->text, &length, &capacity,
              "; generated by arabicc C\n"
              "default rel\n"
              "global main\n"
              "extern printf\n"
              "extern scanf\n"
              "section .data\n"
              "fmt_int: db \"%%ld\", 10, 0\n"
              "fmt_str: db \"%%s\", 10, 0\n"
              "fmt_read_int: db \"%%ld\", 0\n")) {
    free(strings);
    c_assembly_result_free(result);
    return 0;
  }
  for (size_t i = 0; i < str_count; i++) {
    if (!append(&result->text, &length, &capacity, "str%zu: ", i)) {
      free(strings); c_assembly_result_free(result); return 0;
    }
    if (!emit_nasm_string(&result->text, &length, &capacity, strings[i])) {
      free(strings); c_assembly_result_free(result); return 0;
    }
  }

  /* .text / main prologue */
  if (!append(&result->text, &length, &capacity,
              "section .text\n"
              "main:\n"
              "    push rbp\n"
              "    mov rbp, rsp\n"
              "    sub rsp, %zu\n", (frame_size == 0 ? 16 : frame_size) + 32U)) {
    free(strings); c_assembly_result_free(result); return 0;
  }

  /* Statements */
  for (size_t index = 0U; index < program->data.program.statements.count; index++) {
    const CAstNode *statement = program->data.program.statements.items[index];
    if (statement->kind == C_AST_ASSIGNMENT) {
      if (!emit_expression(statement->data.assignment.expression, semantic,
                           &result->text, &length, &capacity)) {
        (void)diagnostic(result, "تعذر تحويل تعبير الإسناد إلى NASM integer");
        free(strings); return 1;
      }
      const int slot = slot_for(semantic, statement->data.assignment.name);
      if (slot == 0 || !append(&result->text, &length, &capacity,
                               "    mov [rbp-%d], rax\n", slot)) {
        (void)diagnostic(result, "متغير الإسناد غير موجود في stack layout");
        free(strings); return 1;
      }
    } else if (statement->kind == C_AST_READ) {
      const int slot = slot_for(semantic, statement->data.access.name);
      if (slot == 0 || !append(&result->text, &length, &capacity,
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
                               ", [rel fmt_read_int]\n"
                               "    xor eax, eax\n"
                               "    call scanf\n", slot)) {
        (void)diagnostic(result, "تعذر تحويل اقرأ إلى scanf");
        free(strings); return 1;
      }
    } else if (statement->kind == C_AST_PRINT) {
      for (size_t vi = 0; vi < statement->data.print.values.count; vi++) {
        const CAstNode *val = statement->data.print.values.items[vi];
        if (!val) continue;
        /* String literal → use fmt_str */
        if (val->kind == C_AST_LITERAL &&
            val->data.literal.literal_kind == C_TOKEN_STRING) {
          int idx = string_index(strings, str_count, val->data.literal.value);
          if (idx < 0 || !append(&result->text, &length, &capacity,
                                  "    lea "
#ifdef _WIN32
                                  "rdx"
#else
                                  "rsi"
#endif
                                  ", [rel str%d]\n"
                                  "    lea "
#ifdef _WIN32
                                  "rcx"
#else
                                  "rdi"
#endif
                                  ", [rel fmt_str]\n"
                                  "    xor eax, eax\n"
                                  "    call printf\n", idx)) {
            (void)diagnostic(result, "تعذر تحويل print string إلى NASM");
            free(strings); return 1;
          }
        } else {
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
                      "    call printf\n")) {
            (void)diagnostic(result, "تعذر تحويل print integer إلى NASM");
            free(strings); return 1;
          }
        }
      }
    } else if (statement->kind != C_AST_EMPTY) {
      (void)diagnostic(result, "تعليمة غير مدعومة في NASM backend الحالي");
      free(strings); return 1;
    }
  }
  free(strings);
  if (!append(&result->text, &length, &capacity,
              "    xor eax, eax\n    leave\n    ret\n"
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
