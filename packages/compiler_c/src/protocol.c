#include "protocol.h"

#include "lexer.h"
#include "parser.h"
#include "semantic.h"
#include "ast.h"
#include "tac.h"
#include "typed_ir.h"
#include "asm_x86_64.h"

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

static int extract_source_at(const char *payload, size_t wanted, char **path, char **source) {
  const char *section = strstr(payload, "\"sourceTexts\"");
  if (section == NULL) return 0;
  const char *cursor = strchr(section, ':');
  if (cursor == NULL) return 0;
  cursor = strchr(cursor, '{');
  if (cursor == NULL) return 0;
  cursor++;
  size_t index = 0U;
  while (*cursor != '\0') {
    cursor = skip_space(cursor);
    if (*cursor == '}') return 0;
    char *candidate_path = json_value(&cursor);
    if (candidate_path == NULL) return 0;
    cursor = skip_space(cursor);
    if (*cursor != ':') { free(candidate_path); return 0; }
    cursor++;
    char *candidate_source = json_value(&cursor);
    if (candidate_source == NULL) { free(candidate_path); return 0; }
    if (index == wanted) {
      *path = candidate_path;
      *source = candidate_source;
      return 1;
    }
    free(candidate_path);
    free(candidate_source);
    index++;
    cursor = skip_space(cursor);
    if (*cursor == ',') cursor++;
  }
  return 0;
}

static int extract_source_for_path(const char *payload, const char *wanted_path,
                                   char **path, char **source) {
  for (size_t index = 0U; ; index++) {
    char *candidate_path = NULL;
    char *candidate_source = NULL;
    if (!extract_source_at(payload, index, &candidate_path, &candidate_source)) return 0;
    if (strcmp(candidate_path, wanted_path) == 0) {
      *path = candidate_path;
      *source = candidate_source;
      return 1;
    }
    free(candidate_path);
    free(candidate_source);
  }
}

static int validate_additional_sources(const char *payload) {
  for (size_t index = 1U; ; index++) {
    char *path = NULL;
    char *source = NULL;
    if (!extract_source_at(payload, index, &path, &source)) return 1;
    CLexResult lexical = {0};
    CParseResult parsed = {0};
    CSemanticResult semantic = {0};
    const int lex_ok = c_lex(source, &lexical);
    const int parse_ok = lex_ok && c_parse(&lexical, &parsed);
    const int semantic_ok = parse_ok && parsed.program != NULL &&
        c_analyze_semantics(parsed.program, &semantic);
    const int valid = lex_ok && parse_ok && semantic_ok &&
        lexical.diagnostic_count == 0U && parsed.diagnostic_count == 0U &&
        semantic.diagnostic_count == 0U;
    if (semantic_ok) c_semantic_result_free(&semantic);
    if (parse_ok) c_parse_result_free(&parsed);
    if (lex_ok) c_lex_result_free(&lexical);
    free(path);
    free(source);
    if (!valid) return 0;
  }
}

static int load_request_source(const char *payload, char **path, char **source) {
  char *entry_path = extract_first_path(payload);
  if (entry_path == NULL) return 0;
  if (extract_source_for_path(payload, entry_path, path, source)) {
    free(entry_path);
    return 1;
  }
  *path = entry_path;
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

static int emit_execution_body(const CAstNode *program, const CSemanticResult *semantic, int *first) {
  RuntimeValue *values = calloc(semantic->count, sizeof(*values));
  if (values == NULL) return 0;
  for (size_t i = 0U; i < semantic->count; i++) {
    values[i].name = semantic->items[i].name;
    values[i].value = 0;
  }
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
          if (!*first) putchar(',');
          printf("\"%ld\"", value);
          *first = 0;
        }
      }
    }
  }
  free(values);
  return 1;
}

static int emit_execution(const CAstNode *program, const CSemanticResult *semantic) {
  putchar('[');
  int first = 1;
  const int success = emit_execution_body(program, semantic, &first);
  putchar(']');
  return success;
}

static void emit_symbols(const CSemanticResult *semantic, const char *source_path) {
  putchar('[');
  for (size_t i = 0U; i < semantic->count; i++) {
    if (i != 0U) putchar(',');
    fputs("{\"name\":", stdout); json_string(semantic->items[i].name);
    fputs(",\"type\":", stdout); json_string(semantic->items[i].type);
    fputs(",\"kind\":\"variable\",\"span\":{\"sourcePath\":", stdout);
    json_string(source_path == NULL ? "" : source_path);
    fputs(",\"offset\":", stdout);
    printf("%zu,\"line\":%zu,\"column\":%zu,\"length\":0}}", semantic->items[i].offset,
           semantic->items[i].line, semantic->items[i].column);
  }
  putchar(']');
}

static void emit_lines(char **items, size_t count) {
  putchar('[');
  for (size_t index = 0U; index < count; index++) {
    if (index != 0U) putchar(',');
    json_string(items[index]);
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
  const int project_ok = parse_ok && validate_additional_sources(payload);
  const int semantic_ok = parse_ok && parsed.program != NULL &&
      c_analyze_semantics(parsed.program, &semantic);
  CTacResult tac = {0};
  CTypedIrResult typed_ir = {0};
  CAssemblyResult assembly = {0};
  const int tac_ok = semantic_ok && c_generate_tac(parsed.program, &tac);
  const int typed_ir_ok = semantic_ok && c_build_typed_ir(parsed.program, &semantic, &typed_ir);
  const int assembly_ok = semantic_ok && c_generate_nasm_x86_64(parsed.program, &semantic, &assembly);
  const int success = lex_ok && parse_ok && semantic_ok &&
      lexical.diagnostic_count == 0U && parsed.diagnostic_count == 0U &&
      semantic.diagnostic_count == 0U && project_ok && tac_ok && tac.diagnostic_count == 0U &&
      typed_ir_ok && typed_ir.diagnostic_count == 0U && assembly_ok &&
      assembly.diagnostic_count == 0U;

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
  if (semantic_ok) emit_symbols(&semantic, source_path); else fputs("[]", stdout);
  fputs(",\"threeAddressCode\":", stdout);
  if (tac_ok) emit_lines(tac.items, tac.count); else fputs("[]", stdout);
  fputs(",\"assembly\":", stdout);
  if (assembly_ok && assembly.text != NULL) json_string(assembly.text); else fputs("\"\"", stdout);
  fputs(",\"executionOutput\":", stdout);
  if (semantic_ok && parse_ok && parsed.program != NULL) emit_execution(parsed.program, &semantic); else fputs("[]", stdout);
  fputs(",\"artifacts\":[],\"intermediateRepresentation\":{\"kind\":\"typed-ir\",\"items\":", stdout);
  if (typed_ir_ok) emit_lines(typed_ir.items, typed_ir.count); else fputs("[]", stdout);
  fputs(",\"sourcePath\":", stdout);
  json_string(source_path);
  fputs("}}\n", stdout);

  c_assembly_result_free(&assembly);
  c_typed_ir_result_free(&typed_ir);
  c_tac_result_free(&tac);
  if (semantic_ok) c_semantic_result_free(&semantic);
  if (parse_ok) c_parse_result_free(&parsed);
  if (lex_ok) c_lex_result_free(&lexical);
  free(source_path);
  free(source);
  return success ? 0 : 1;
}

int c_run_assist(const char *payload) {
  if (payload == NULL || !has_protocol_v05(payload) || strstr(payload, "\"requestType\":\"assist\"") == NULL) {
    fputs("{\"protocolVersion\":\"0.5.0\",\"success\":false,\"requestType\":\"assist\",\"action\":\"completion\",\"expected\":\"\",\"prefix\":\"\",\"replaceStart\":0,\"replaceLength\":0,\"items\":[],\"help\":null}\n", stdout);
    return 64;
  }
  const int help = strstr(payload, "\"action\":\"help\"") != NULL;
  if (help) {
    fputs("{\"protocolVersion\":\"0.5.0\",\"success\":true,\"requestType\":\"assist\",\"action\":\"help\",\"expected\":\"\",\"prefix\":\"\",\"replaceStart\":0,\"replaceLength\":0,\"items\":[],\"help\":{\"keyword\":\"اذا\",\"title\":\"تعليمة شرطية\",\"description\":\"تنفذ فرعًا عند تحقق الشرط ويمكن أن تتبعه والا.\",\"syntax\":\"اذا(الشرط) فان { ... }\"}}\n", stdout);
    return 0;
  }
  static const char *keywords[] = {"اذا", "والا", "طالما", "كرر", "متغير", "ثابت", "اجراء", "اطبع"};
  fputs("{\"protocolVersion\":\"0.5.0\",\"success\":true,\"requestType\":\"assist\",\"action\":\"completion\",\"expected\":\"\",\"prefix\":\"\",\"replaceStart\":0,\"replaceLength\":0,\"items\":[", stdout);
  for (size_t i = 0U; i < sizeof(keywords) / sizeof(keywords[0]); i++) {
    if (i != 0U) putchar(',');
    fputs("{\"label\":", stdout); json_string(keywords[i]);
    fputs(",\"insertText\":", stdout); json_string(keywords[i]);
    fputs(",\"kind\":\"keyword\",\"detail\":\"كلمة محجوزة في اللغة\"}", stdout);
  }
  fputs("],\"help\":null}\n", stdout);
  return 0;
}
