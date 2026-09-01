#include "lexer.h"

#include <assert.h>
#include <string.h>

int main(void) {
  CLexResult result;
  const char *source = "برنامج سعيد { // تعليق\n متغير س: صحيح؛ اطبع(س + 12)؛ }.";
  const int first_status = c_lex(source, &result);
  assert(first_status == 1);
  if (first_status != 1) return 1;
  assert(result.diagnostic_count == 0U);
  assert(result.count > 10U);
  assert(result.items[0].kind == C_TOKEN_KEYWORD);
  assert(strcmp(result.items[0].lexeme, "برنامج") == 0);
  assert(result.items[0].offset == 0U);
  assert(result.items[0].length == 6U);
  assert(result.items[1].kind == C_TOKEN_IDENTIFIER);
  assert(strcmp(result.items[1].lexeme, "سعيد") == 0);
  assert(result.items[1].length == 4U);
  assert(result.items[result.count - 1U].kind == C_TOKEN_EOF);
  c_lex_result_free(&result);

  const int second_status = c_lex("اطبع(\"غير مغلق)", &result);
  assert(second_status == 1);
  if (second_status != 1) return 1;
  assert(result.diagnostic_count == 1U);
  c_lex_result_free(&result);

  const int third_status = c_lex("اطبع(&)", &result);
  assert(third_status == 1);
  if (third_status != 1) return 1;
  assert(result.diagnostic_count == 1U);
  c_lex_result_free(&result);
  return 0;
}
