#include "protocol.h"

#include "lexer.h"
#include "parser.h"
#include "semantic.h"
#include "ast.h"

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

static int has_protocol_v05(const char *payload) {
  return strstr(payload, "\"protocolVersion\":\"0.5.0\"") != NULL;
}

static int has_source_paths(const char *payload) {
  return strstr(payload, "\"sourcePaths\"") != NULL;
}

static char *extract_named_string(const char *payload, const char *name) {
  char needle[96];
  (void)snprintf(needle, sizeof(needle), "\"%s\"", name);
  const char *cursor = strstr(payload, needle);
  if (cursor == NULL) return NULL;
  cursor = strchr(cursor, ':');
  if (cursor == NULL) return NULL;
  cursor++;
  return json_value(&cursor);
}

static char *extract_first_path(const char *payload) {
  const char *cursor = strstr(payload, "\"sourcePaths\"");
  if (cursor == NULL) return NULL;
  cursor = strchr(cursor, '[');
  if (cursor == NULL) return NULL;
  cursor++;
  return json_value(&cursor);
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

static int load_request_source(const char *payload, char **path, char **source) {
  if (extract_first_source(payload, path, source)) return 1;
  *path = extract_first_path(payload);
  if (*path == NULL) return 0;
  char *root = extract_named_string(payload, "rootPath");
  if (root == NULL) { free(*path); *path = NULL; return 0; }
  size_t length = strlen(root) + strlen(*path) + 2U;
  char *filename = malloc(length);
  if (filename == NULL) { free(root); free(*path); *path = NULL; return 0; }
  (void)snprintf(filename, length, "%s/%s", root, *path);
  FILE *file = fopen(filename, "rb");
  free(root);
  free(filename);
  if (file == NULL) { free(*path); *path = NULL; return 0; }
  size_t capacity = 1024U;
  size_t used = 0U;
  *source = malloc(capacity);
  if (*source == NULL) { fclose(file); free(*path); *path = NULL; return 0; }
  int character;
  while ((character = fgetc(file)) != EOF) {
    if (used + 1U >= capacity) {
      capacity *= 2U;
      char *next = realloc(*source, capacity);
      if (next == NULL) { fclose(file); free(*source); *source = NULL; free(*path); *path = NULL; return 0; }
      *source = next;
    }
    (*source)[used++] = (char)character;
  }
  fclose(file);
  (*source)[used] = '\0';
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

typedef struct {
  char *name;
  long value;
} RuntimeValue;

static int eval_expression(const CAstNode *node, RuntimeValue *values, size_t count, long *out) {
  if (node == NULL || out == NULL) return 0;
  if (node->kind == C_AST_LITERAL && node->data.literal.literal_kind == C_TOKEN_INTEGER) {
    char *end = NULL;
    *out = strtol(node->data.literal.value, &end, 10);
    return end != node->data.literal.value && *end == '\0';
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE && node->data.reference.selectors.count == 0U) {
    for (size_t i = 0U; i < count; i++) {
      if (strcmp(values[i].name, node->data.reference.name) == 0) { *out = values[i].value; return 1; }
    }
    return 0;
  }
  if (node->kind == C_AST_BINARY) {
    long left = 0; long right = 0;
    if (!eval_expression(node->data.binary.left, values, count, &left) ||
        !eval_expression(node->data.binary.right, values, count, &right)) return 0;
    if (strcmp(node->data.binary.operator, "+") == 0) *out = left + right;
    else if (strcmp(node->data.binary.operator, "-") == 0) *out = left - right;
    else if (strcmp(node->data.binary.operator, "*") == 0) *out = left * right;
    else if (strcmp(node->data.binary.operator, "/") == 0 && right != 0) *out = left / right;
    else return 0;
    return 1;
  }
  return 0;
}

static int emit_execution(const CAstNode *program, const CSemanticResult *semantic) {
  RuntimeValue *values = calloc(semantic->count, sizeof(*values));
  if (values == NULL) return 0;
  for (size_t i = 0U; i < semantic->count; i++) {
    values[i].name = semantic->items[i].name;
    values[i].value = 0;
  }
  putchar('[');
  int first = 1;
  for (size_t i = 0U; i < program->data.program.statements.count; i++) {
    const CAstNode *statement = program->data.program.statements.items[i];
    if (statement->kind == C_AST_ASSIGNMENT && statement->data.assignment.selectors.count == 0U) {
      long value = 0;
      if (eval_expression(statement->data.assignment.expression, values, semantic->count, &value)) {
        for (size_t j = 0U; j < semantic->count; j++) {
          if (strcmp(values[j].name, statement->data.assignment.name) == 0) values[j].value = value;
        }
      }
    } else if (statement->kind == C_AST_PRINT) {
      for (size_t j = 0U; j < statement->data.print.values.count; j++) {
        long value = 0;
        if (eval_expression(statement->data.print.values.items[j], values, semantic->count, &value)) {
          if (!first) putchar(',');
          printf("\"%ld\"", value);
          first = 0;
        }
      }
    }
  }
  putchar(']');
  free(values);
  return 1;
}

static void emit_symbols(const CSemanticResult *semantic) {
  putchar('[');
  for (size_t i = 0U; i < semantic->count; i++) {
    if (i != 0U) putchar(',');
    fputs("{\"name\":", stdout); json_string(semantic->items[i].name);
    fputs(",\"type\":", stdout); json_string(semantic->items[i].type);
    fputs(",\"kind\":\"variable\"}", stdout);
  }
  putchar(']');
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
  if (payload == NULL || !has_protocol_v05(payload) || !has_source_paths(payload) ||
      !load_request_source(payload, &source_path, &source)) {
    fputs("{\"protocolVersion\":\"0.5.0\",\"success\":false,\"diagnostics\":[", stdout);
    emit_diagnostic("protocol", "P002", "طلب Compilation غير صالح أو غير مكتمل", "");
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
  fputs(",\"symbolTable\":", stdout);
  if (semantic_ok) emit_symbols(&semantic); else fputs("[]", stdout);
  fputs(",\"threeAddressCode\":[],\"assembly\":\"\",\"executionOutput\":", stdout);
  if (semantic_ok && parse_ok && parsed.program != NULL) emit_execution(parsed.program, &semantic); else fputs("[]", stdout);
  fputs(",\"artifacts\":[],\"intermediateRepresentation\":{\"kind\":\"program\",\"sourcePath\":", stdout);
  json_string(source_path);
  fputs("}}\n", stdout);

  if (semantic_ok) c_semantic_result_free(&semantic);
  if (parse_ok) c_parse_result_free(&parsed);
  if (lex_ok) c_lex_result_free(&lexical);
  free(source_path);
  free(source);
  return success ? 0 : 1;
}
