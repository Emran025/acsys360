#ifndef ARABICC_ASM_X86_64_H
#define ARABICC_ASM_X86_64_H

#include "ast.h"
#include "semantic.h"

#include <stddef.h>

typedef struct {
  char *text;
  char **diagnostics;
  size_t diagnostic_count;
  size_t diagnostic_capacity;
} CAssemblyResult;

int c_generate_nasm_x86_64(const CAstNode *program,
                           const CSemanticResult *semantic,
                           CAssemblyResult *result);
void c_assembly_result_free(CAssemblyResult *result);

#endif
