#ifndef ARABICC_TAC_H
#define ARABICC_TAC_H

#include "ast.h"
#include <stddef.h>

typedef enum {
  C_TAC_ALLOC,
  C_TAC_ASSIGN,
  C_TAC_BINARY,
  C_TAC_PARAM,
  C_TAC_CALL
} CTacOpcode;

typedef struct {
  CTacOpcode opcode;
  char *result;
  char *left;
  char *operator;
  char *right;
  char *type;
  size_t argument_count;
} CTacInstruction;

typedef struct {
  CTacInstruction *items;
  size_t count;
  size_t capacity;
} CTacResult;

int c_generate_tac(const CAstNode *root, CTacResult *result);
void c_tac_result_free(CTacResult *result);
const char *c_tac_opcode_name(CTacOpcode opcode);
char *c_tac_instruction_to_text(const CTacInstruction *instruction);

#endif

