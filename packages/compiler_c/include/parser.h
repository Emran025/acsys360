#ifndef ARABICC_PARSER_H
#define ARABICC_PARSER_H

#include "ast.h"
#include "lexer.h"

typedef struct {
  CAstNode *program;
  char **diagnostics;
  size_t diagnostic_count;
  size_t diagnostic_capacity;
} CParseResult;

int c_parse(const CLexResult *tokens, CParseResult *result);
void c_parse_result_free(CParseResult *result);

#endif
