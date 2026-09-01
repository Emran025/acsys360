#include "asm_x86_64.h"
#include "parser.h"
#include "semantic.h"

#include <assert.h>
#include <string.h>

int main(void) {
  const char *source = "برنامج تجميع { متغير س: صحيح؛ س = 2 + 3؛ اطبع(س)؛ }.";
  CLexResult lexical;
  CParseResult parsed;
  CSemanticResult semantic;
  CAssemblyResult assembly;
  const int lex_status = c_lex(source, &lexical);
  assert(lex_status == 1);
  if (lex_status != 1) return 1;
  const int parse_status = c_parse(&lexical, &parsed);
  assert(parse_status == 1);
  if (parse_status != 1 || parsed.program == NULL) return 1;
  const int semantic_status = c_analyze_semantics(parsed.program, &semantic);
  assert(semantic_status == 1);
  if (semantic_status != 1) return 1;
  const int assembly_status = c_generate_nasm_x86_64(parsed.program, &semantic,
                                                      &assembly);
  assert(assembly_status == 1);
  if (assembly_status != 1) return 1;
  assert(assembly.diagnostic_count == 0U);
  assert(strstr(assembly.text, "global main") != NULL);
  assert(strstr(assembly.text, "add rax, rcx") != NULL);
  assert(strstr(assembly.text, "call printf") != NULL);
  c_assembly_result_free(&assembly);
  c_semantic_result_free(&semantic);
  c_parse_result_free(&parsed);
  c_lex_result_free(&lexical);
  return 0;
}
