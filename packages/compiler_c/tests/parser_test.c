#include "parser.h"

#include <assert.h>

int main(void) {
  const char *source = "برنامج سعيد { متغير س: صحيح؛ اطبع(س + 12)؛ }.";
  CLexResult lexical;
  const int first_status = c_lex(source, &lexical);
  assert(first_status == 1);
  if (first_status != 1) return 1;
  CParseResult parsed;
  const int first_parse_status = c_parse(&lexical, &parsed);
  assert(first_parse_status == 1);
  if (first_parse_status != 1) return 1;
  assert(parsed.diagnostic_count == 0U);
  assert(parsed.program != NULL);
  if (parsed.program == NULL) return 1;
  assert(parsed.program->kind == C_AST_PROGRAM);
  assert(parsed.program->data.program.declarations.count == 1U);
  assert(parsed.program->data.program.statements.count == 1U);
  if (parsed.program->data.program.statements.count == 0U) return 1;
  assert(parsed.program->data.program.statements.items[0] != NULL);
  if (parsed.program->data.program.statements.items[0] == NULL) return 1;
  assert(parsed.program->data.program.statements.items[0]->kind == C_AST_PRINT);
  c_parse_result_free(&parsed);
  c_lex_result_free(&lexical);

  const int second_status = c_lex("برنامج ناقص { اطبع(1) }", &lexical);
  assert(second_status == 1);
  if (second_status != 1) return 1;
  const int second_parse_status = c_parse(&lexical, &parsed);
  assert(second_parse_status == 1);
  if (second_parse_status != 1) return 1;
  assert(parsed.diagnostic_count > 0U);
  c_parse_result_free(&parsed);
  c_lex_result_free(&lexical);
  return 0;
}
