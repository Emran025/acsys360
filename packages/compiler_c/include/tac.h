#ifndef ARABICC_TAC_H
#define ARABICC_TAC_H

#include "ast.h"

#include <stddef.h>

typedef struct {
  char **items;
  size_t count;
  size_t capacity;
  char **diagnostics;
  size_t diagnostic_count;
  size_t diagnostic_capacity;
} CTacResult;

int c_generate_tac(const CAstNode *program, CTacResult *result);
void c_tac_result_free(CTacResult *result);

#endif
