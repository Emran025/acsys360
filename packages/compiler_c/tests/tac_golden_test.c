#include "ast.h"
#include "tac.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int expect_text(const CTacInstruction *instruction, const char *expected) {
  char *actual = c_tac_instruction_to_text(instruction);
  const int matches = actual && strcmp(actual, expected) == 0;
  if (!matches) {
    fprintf(stderr, "TAC mismatch: expected '%s', got '%s'\n", expected,
            actual ? actual : "<null>");
  }
  free(actual);
  return matches;
}

static char *owned(const char *value) {
  const size_t length = strlen(value);
  char *copy = (char *)malloc(length + 1U);
  if (copy) memcpy(copy, value, length + 1U);
  return copy;
}

int main(void) {
  CAstNodeList declarations = {0};
  CAstNodeList statements = {0};
  c_ast_list_append(&declarations, c_ast_new_var_decl(owned("x"), "صحيح"));
  c_ast_list_append(
      &statements,
      c_ast_new_assignment(
          owned("x"), c_ast_new_binary(c_ast_new_integer("1"), "+", c_ast_new_integer("2"))));
  c_ast_list_append(&statements, c_ast_new_print(c_ast_new_reference(owned("x"))));
  CAstNode *program = c_ast_new_program(owned("main"), declarations, statements);
  if (!program) return 1;

  CTacResult result = {0};
  const int generated = c_generate_tac(program, &result);
  const char *expected[] = {
      "ALLOC x, صحيح",
      "t0 = 1 + 2",
      "x = t0",
      "PRINT x",
  };
  int success = generated && result.count == sizeof(expected) / sizeof(expected[0]);
  if (!success) {
    fprintf(stderr, "expected %zu TAC instructions, got %zu\n",
            sizeof(expected) / sizeof(expected[0]), result.count);
  }
  for (size_t i = 0U; success && i < result.count; i++) {
    success = expect_text(&result.items[i], expected[i]);
  }

  c_tac_result_free(&result);
  c_ast_free(program);
  return success ? 0 : 1;
}
