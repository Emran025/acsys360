#ifndef ARABICC_LEXER_H
#define ARABICC_LEXER_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  C_TOKEN_KEYWORD,
  C_TOKEN_BOOLEAN,
  C_TOKEN_IDENTIFIER,
  C_TOKEN_INTEGER,
  C_TOKEN_REAL,
  C_TOKEN_STRING,
  C_TOKEN_CHARACTER,
  C_TOKEN_PUNCTUATION,
  C_TOKEN_OPERATOR,
  C_TOKEN_EOF
} CTokenKind;

typedef struct {
  CTokenKind kind;
  char *lexeme;
  size_t offset;
  size_t line;
  size_t column;
  size_t length;
} CToken;

typedef struct {
  CToken *items;
  size_t count;
  size_t capacity;
  char **diagnostics;
  size_t diagnostic_count;
  size_t diagnostic_capacity;
} CLexResult;

int c_lex(const char *source, CLexResult *result);
void c_lex_result_free(CLexResult *result);
const char *c_token_kind_name(CTokenKind kind);

#ifdef __cplusplus
}
#endif

#endif
