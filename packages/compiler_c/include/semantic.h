#ifndef ARABICC_SEMANTIC_H
#define ARABICC_SEMANTIC_H

#include "ast.h"

typedef struct {
  char *name;
  char *type;
  /* Borrowed pointer into the AST; owned and freed by c_ast_free. */
  const CTypeSpec *type_spec;
  size_t offset;
  size_t line;
  size_t column;
  int is_constant;
} CSymbol;

typedef struct {
  char *message;
  size_t offset;
  size_t line;
  size_t column;
  size_t length;
} CSemanticDiagnostic;

typedef struct {
  CSymbol *items;
  size_t count;
  size_t capacity;
  CSemanticDiagnostic *diagnostics;
  size_t diagnostic_count;
  size_t diagnostic_capacity;
} CSemanticResult;

int c_analyze_semantics(const CAstNode *program, CSemanticResult *result);
void c_semantic_result_free(CSemanticResult *result);

#endif
