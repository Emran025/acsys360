#ifndef ARABICC_SEMANTIC_H
#define ARABICC_SEMANTIC_H

#include "ast.h"

typedef struct {
  char *name;
  char *type;
  size_t offset;
  size_t line;
  size_t column;
} CSymbol;

typedef struct {
  CSymbol *items;
  size_t count;
  size_t capacity;
  char **diagnostics;
  size_t diagnostic_count;
  size_t diagnostic_capacity;
} CSemanticResult;

int c_analyze_semantics(const CAstNode *program, CSemanticResult *result);
void c_semantic_result_free(CSemanticResult *result);

#endif
