#include "parser.h"
#include "semantic.h"

#include <assert.h>

static int parse_source(const char *source, CLexResult *lexical,
                        CParseResult *parsed) {
  const int lex_status = c_lex(source, lexical);
  assert(lex_status == 1);
  if (lex_status != 1) return 0;
  const int parse_status = c_parse(lexical, parsed);
  assert(parse_status == 1);
  return parse_status == 1;
}

int main(void) {
  CLexResult lexical;
  CParseResult parsed;
  CSemanticResult semantic;
  const int first_parse = parse_source(
      "برنامج سعيد { متغير س: صحيح؛ س = 4؛ اطبع(س)؛ }.", &lexical, &parsed);
  assert(first_parse == 1);
  if (first_parse != 1) return 1;
  const int first_semantic = c_analyze_semantics(parsed.program, &semantic);
  assert(first_semantic == 1);
  if (first_semantic != 1) return 1;
  assert(semantic.diagnostic_count == 0U);
  assert(semantic.count == 1U);
  c_semantic_result_free(&semantic);
  c_parse_result_free(&parsed);
  c_lex_result_free(&lexical);

  const int second_parse = parse_source("برنامج فشل { اطبع(س)؛ }.",
                                         &lexical, &parsed);
  assert(second_parse == 1);
  if (second_parse != 1) return 1;
  const int second_semantic = c_analyze_semantics(parsed.program, &semantic);
  assert(second_semantic == 1);
  if (second_semantic != 1) return 1;
  assert(semantic.diagnostic_count == 1U);
  c_semantic_result_free(&semantic);
  c_parse_result_free(&parsed);
  c_lex_result_free(&lexical);
  return 0;
}
