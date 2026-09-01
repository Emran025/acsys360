#ifndef ARABICC_TYPED_IR_H
#define ARABICC_TYPED_IR_H

#include "ast.h"
#include "semantic.h"

#include <stddef.h>

typedef enum {
  C_IR_UNKNOWN,
  C_IR_INTEGER,
  C_IR_REAL,
  C_IR_BOOLEAN,
  C_IR_CHARACTER,
  C_IR_STRING
} CIrType;

typedef struct {
  char **items;
  size_t count;
  size_t capacity;
  char **diagnostics;
  size_t diagnostic_count;
  size_t diagnostic_capacity;
} CTypedIrResult;

int c_build_typed_ir(const CAstNode *program, const CSemanticResult *semantic,
                     CTypedIrResult *result);
void c_typed_ir_result_free(CTypedIrResult *result);
const char *c_ir_type_name(CIrType type);

#endif
