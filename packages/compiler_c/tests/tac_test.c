#include "parser.h"
#include "tac.h"

#include <assert.h>
#include <string.h>

int main(void) {
  const char *source = "برنامج حساب { متغير س: صحيح؛ س = 2 + 3 * 4؛ اطبع(س)؛ }.";
  CLexResult lexical;
  CParseResult parsed;
  CTacResult tac;
  const int lex_status = c_lex(source, &lexical);
  assert(lex_status == 1);
  if (lex_status != 1) return 1;
  const int parse_status = c_parse(&lexical, &parsed);
  assert(parse_status == 1);
  if (parse_status != 1 || parsed.program == NULL) return 1;
  const int tac_status = c_generate_tac(parsed.program, &tac);
  assert(tac_status == 1);
  if (tac_status != 1) return 1;
  assert(tac.diagnostic_count == 0U);
  assert(tac.count == 3U);
  assert(strcmp(tac.items[0], "t0 = 3 * 4") == 0);
  assert(strcmp(tac.items[1], "t1 = 2 + t0") == 0);
  assert(strcmp(tac.items[2], "س = t1") == 0);
  c_tac_result_free(&tac);
  c_parse_result_free(&parsed);
  c_lex_result_free(&lexical);
  return 0;
}
