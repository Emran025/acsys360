#include "protocol.h"

#include "lexer.h"
#include "parser.h"
#include "semantic.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void json_string(const char *value) {
  putchar('"');
  for (const unsigned char *p = (const unsigned char *)value; *p != '\0'; p++) {
    if (*p == '"' || *p == '\\') printf("\\%c", *p);
    else if (*p == '\n') fputs("\\n", stdout);
    else if (*p == '\r') fputs("\\r", stdout);
    else if (*p == '\t') fputs("\\t", stdout);
    else if (*p < 0x20U) printf("\\u%04x", *p);
    else putchar(*p);
  }
  putchar('"');
}

static const char *skip_space(const char *cursor) {
  while (*cursor != '\0' && isspace((unsigned char)*cursor)) cursor++;
  return cursor;
}

static char *json_value(const char **cursor) {
  const char *p = skip_space(*cursor);
  if (*p != '"') return NULL;
  p++;
  size_t length = 0U;
  size_t capacity = 128U;
  char *value = malloc(capacity);
  if (value == NULL) return NULL;
  while (*p != '\0' && *p != '"') {
    unsigned char character = (unsigned char)*p++;
    if (character == '\\' && *p != '\0') {
      character = (unsigned char)*p++;
      if (character == 'n') character = '\n';
      else if (character == 'r') character = '\r';
      else if (character == 't') character = '\t';
    }
    if (length + 1U >= capacity) {
      capacity *= 2U;
      char *next = realloc(value, capacity);
      if (next == NULL) { free(value); return NULL; }
      value = next;
    }
    value[length++] = (char)character;
  }
  if (*p != '"') { free(value); return NULL; }
  value[length] = '\0';
  *cursor = p + 1;
  return value;
}

static int extract_first_source(const char *payload, char **path, char **source) {
  const char *section = strstr(payload, "\"sourceTexts\"");
  if (section == NULL) return 0;
  const char *cursor = strchr(section, ':');
  if (cursor == NULL) return 0;
  cursor = strchr(cursor, '"');
  if (cursor == NULL) return 0;
  *path = json_value(&cursor);
  if (*path == NULL) return 0;
  cursor = skip_space(cursor);
  if (*cursor != ':') { free(*path); *path = NULL; return 0; }
  cursor++;
  *source = json_value(&cursor);
  if (*source == NULL) { free(*path); *path = NULL; return 0; }
  return 1;
}

static void emit_diagnostic(const char *phase, const char *code, const char *message,
                            const char *path) {
  printf("{\"severity\":\"error\",\"phase\":");
  json_string(phase);
  printf(",\"code\":");
  json_string(code);
  printf(",\"message\":");
  json_string(message);
  printf(",\"span\":{\"sourcePath\":");
  json_string(path == NULL ? "" : path);
  fputs(",\"offset\":0,\"line\":1,\"column\":1,\"length\":0}}", stdout);
}

static void emit_tokens(const CLexResult *lexical) {
  putchar('[');
  for (size_t i = 0U; i < lexical->count; i++) {
    if (i != 0U) putchar(',');
    printf("{\"kind\":");
    json_string(c_token_kind_name(lexical->items[i].kind));
    printf(",\"lexeme\":");
    json_string(lexical->items[i].lexeme);
    printf(",\"span\":{\"offset\":%zu,\"line\":%zu,\"column\":%zu,\"length\":%zu}}",
           lexical->items[i].offset, lexical->items[i].line,
           lexical->items[i].column, lexical->items[i].length);
  }
  putchar(']');
}

int c_run_protocol(const char *payload) {
  char *source_path = NULL;
  char *source = NULL;
  if (payload == NULL || !extract_first_source(payload, &source_path, &source)) {
    fputs("{\"protocolVersion\":\"0.5.0\",\"success\":false,\"diagnostics\":[", stdout);
    emit_diagnostic("protocol", "P002", "يجب أن يحتوي الطلب على sourceTexts صالح", "");
    fputs("]}\n", stdout);
    return 64;
  }

  CLexResult lexical;
  CParseResult parsed;
  CSemanticResult semantic;
  const int lex_ok = c_lex(source, &lexical);
  const int parse_ok = lex_ok && c_parse(&lexical, &parsed);
  const int semantic_ok = parse_ok && parsed.program != NULL &&
      c_analyze_semantics(parsed.program, &semantic);
  const int success = lex_ok && parse_ok && semantic_ok &&
      lexical.diagnostic_count == 0U && parsed.diagnostic_count == 0U &&
      semantic.diagnostic_count == 0U;

  printf("{\"protocolVersion\":\"0.5.0\",\"success\":%s,\"diagnostics\":[",
         success ? "true" : "false");
  int first = 1;
  if (!lex_ok || lexical.diagnostic_count != 0U) {
    emit_diagnostic("lexical", "L001", "فشل التحليل المعجمي", source_path); first = 0;
  }
  if (!parse_ok || (parsed.program == NULL)) {
    if (!first) putchar(',');
    emit_diagnostic("syntax", "S001", "فشل التحليل النحوي", source_path); first = 0;
  }
  if (!semantic_ok || (semantic_ok && semantic.diagnostic_count != 0U)) {
    if (!first) putchar(',');
    emit_diagnostic("semantic", "M001", "فشل التحليل الدلالي", source_path);
  }
  fputs("],\"tokens\":", stdout);
  if (lex_ok) emit_tokens(&lexical); else fputs("[]", stdout);
  fputs(",\"syntaxTree\":", stdout);
  if (parse_ok && parsed.program != NULL) {
    fputs("{\"kind\":\"program\",\"sourcePath\":", stdout);
    json_string(source_path);
    putchar('}');
  } else fputs("null", stdout);
  fputs(",\"symbolTable\":[],\"threeAddressCode\":[],\"assembly\":\"\",\"executionOutput\":[],\"artifacts\":[],\"intermediateRepresentation\":{\"kind\":\"program\",\"sourcePath\":", stdout);
  json_string(source_path);
  fputs("}}\n", stdout);

  if (semantic_ok) c_semantic_result_free(&semantic);
  if (parse_ok) c_parse_result_free(&parsed);
  if (lex_ok) c_lex_result_free(&lexical);
  free(source_path);
  free(source);
  return success ? 0 : 1;
}
