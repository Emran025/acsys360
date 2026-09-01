#include "parser.h"
#include "semantic.h"
#include "typed_ir.h"

#include <assert.h>
#include <string.h>

int main(void) {
  const char *source = "برنامج انواع { متغير س: صحيح؛ س = 2 + 3؛ اطبع(س)؛ }.";
  CLexResult lexical;
  CParseResult parsed;
  CSemanticResult semantic;
  CTypedIrResult ir;
  const int lex_status = c_lex(source, &lexical);
  assert(lex_status == 1);
  if (lex_status != 1) return 1;
  const int parse_status = c_parse(&lexical, &parsed);
  assert(parse_status == 1);
  if (parse_status != 1 || parsed.program == NULL) return 1;
  const int semantic_status = c_analyze_semantics(parsed.program, &semantic);
  assert(semantic_status == 1);
  if (semantic_status != 1) return 1;
  const int ir_status = c_build_typed_ir(parsed.program, &semantic, &ir);
  assert(ir_status == 1);
  if (ir_status != 1) return 1;
  assert(ir.diagnostic_count == 0U);
  assert(ir.count == 3U);
  assert(strcmp(ir.items[0], "t0: integer = 2 + 3") == 0);
  assert(strcmp(ir.items[1], "store س: integer <- t0") == 0);
  assert(strcmp(ir.items[2], "print integer: س") == 0);
  c_typed_ir_result_free(&ir);
  c_semantic_result_free(&semantic);
  c_parse_result_free(&parsed);
  c_lex_result_free(&lexical);
  return 0;
}
