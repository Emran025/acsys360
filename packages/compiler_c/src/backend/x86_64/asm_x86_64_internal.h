#ifndef ARABICC_ASM_X86_64_INTERNAL_H
#define ARABICC_ASM_X86_64_INTERNAL_H

#include "asm_x86_64.h"

#include <stddef.h>

typedef struct {
  const CAstNode *program;
  const char **text_values;
  size_t text_count;
  const char **real_values;
  size_t real_count;
} CAsmContext;

char *c_asm_duplicate(const char *value);
int c_asm_append(char **text, size_t *length, size_t *capacity,
                 const char *format, ...);
int c_asm_diagnostic_at(CAssemblyResult *result, const CAstNode *node,
                        const char *format, ...);
int c_asm_slot_for(const CSemanticResult *semantic, const char *name);
const char *c_asm_type_for(const CSemanticResult *semantic, const char *name);
const CAstNode *c_asm_constant_value_for(const CAsmContext *context,
                                         const char *name);

int c_asm_text_index(const char **values, size_t count, const char *value);
int c_asm_real_literal_index(const char **values, size_t count,
                             const char *value);
void c_asm_collect_real_literals(const CAstNode *node, const char ***values,
                                 size_t *count, size_t *capacity);
void c_asm_collect_text_literal(const CAstNode *node, const char ***values,
                                size_t *count, size_t *capacity);
void c_asm_collect_strings(const CAstNodeList *list, const char ***strings,
                           size_t *count, size_t *capacity);
int c_asm_emit_nasm_string(char **text, size_t *length, size_t *capacity,
                           const char *value);
int c_asm_emit_nasm_bytes(char **text, size_t *length, size_t *capacity,
                          const char *value);

int c_asm_expression_is_text(const CAstNode *node,
                             const CSemanticResult *semantic);
int c_asm_expression_is_boolean(const CAstNode *node,
                                const CSemanticResult *semantic);
int c_asm_expression_is_real(const CAstNode *node,
                             const CSemanticResult *semantic);
const char *c_asm_assignment_expression_kind(const CAstNode *node);
int c_asm_emit_text_expression(const CAsmContext *context,
                               const CAstNode *node,
                               const CSemanticResult *semantic,
                               char **text, size_t *length, size_t *capacity);
int c_asm_emit_expression(const CAsmContext *context, const CAstNode *node,
                          const CSemanticResult *semantic, char **text,
                          size_t *length, size_t *capacity);
int c_asm_emit_real_expression(const CAsmContext *context,
                               const CAstNode *node,
                               const CSemanticResult *semantic,
                               const char **real_values, size_t real_count,
                               char **text, size_t *length, size_t *capacity);

int c_asm_emit_native_statements(const CAsmContext *context,
                                 const CAstNodeList *statements,
                                 const CSemanticResult *semantic, char **text,
                                 size_t *length, size_t *capacity,
                                 size_t *label_index);

size_t c_asm_frame_size(const CSemanticResult *semantic);
size_t c_asm_read_count(const CAstNodeList *statements);
int c_asm_emit_prologue(char **text, size_t *length, size_t *capacity,
                        size_t frame_size, size_t read_count);
int c_asm_emit_epilogue(char **text, size_t *length, size_t *capacity);

#endif
