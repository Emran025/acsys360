#include "protocol_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char g_source_path_storage[1024] = "";
const char *g_current_source_path = "";

void json_buf_init(JsonBuffer *b) {
  b->capacity = 1024;
  b->length = 0;
  b->data = (char *)malloc(b->capacity);
  if (b->data) b->data[0] = '\0';
}

void json_buf_append(JsonBuffer *b, const char *str) {
  if (!str) return;
  size_t len = strlen(str);
  while (b->length + len + 1 > b->capacity) {
    b->capacity *= 2;
    b->data = (char *)realloc(b->data, b->capacity);
  }
  memcpy(b->data + b->length, str, len);
  b->length += len;
  b->data[b->length] = '\0';
}

void json_buf_append_char(JsonBuffer *b, char c) {
  if (b->length + 2 > b->capacity) {
    b->capacity *= 2;
    b->data = (char *)realloc(b->data, b->capacity);
  }
  b->data[b->length++] = c;
  b->data[b->length] = '\0';
}

void json_buf_append_escaped(JsonBuffer *b, const char *str) {
  if (!str) {
    json_buf_append(b, "\"\"");
    return;
  }
  json_buf_append_char(b, '"');
  for (const unsigned char *p = (const unsigned char *)str; *p != '\0'; p++) {
    switch (*p) {
      case '"': json_buf_append(b, "\\\""); break;
      case '\\': json_buf_append(b, "\\\\"); break;
      case '\b': json_buf_append(b, "\\b"); break;
      case '\f': json_buf_append(b, "\\f"); break;
      case '\n': json_buf_append(b, "\\n"); break;
      case '\r': json_buf_append(b, "\\r"); break;
      case '\t': json_buf_append(b, "\\t"); break;
      default:
        if (*p < 0x20) {
          char hex[8];
          snprintf(hex, sizeof(hex), "\\u%04x", *p);
          json_buf_append(b, hex);
        } else {
          json_buf_append_char(b, (char)*p);
        }
        break;
    }
  }
  json_buf_append_char(b, '"');
}

void json_buf_append_span(JsonBuffer *b, const ProtocolSpan *span) {
  json_buf_append(b, "{\"sourcePath\":");
  if (span && span->source_path && span->source_path[0] != '\0') {
    json_buf_append_escaped(b, span->source_path);
  } else {
    json_buf_append(b, "null");
  }
  json_buf_append(b, ",\"offset\":");
  char num[32];
  snprintf(num, sizeof(num), "%zu", span ? span->offset : 0);
  json_buf_append(b, num);
  json_buf_append(b, ",\"line\":");
  snprintf(num, sizeof(num), "%zu", (span && span->line > 0) ? span->line : 1);
  json_buf_append(b, num);
  json_buf_append(b, ",\"column\":");
  snprintf(num, sizeof(num), "%zu", (span && span->column > 0) ? span->column : 1);
  json_buf_append(b, num);
  json_buf_append(b, ",\"length\":");
  snprintf(num, sizeof(num), "%zu", span ? span->length : 0);
  json_buf_append(b, num);
  json_buf_append_char(b, '}');
}

char *protocol_strdup(const char *src) {
  if (!src) return NULL;
  size_t len = strlen(src);
  char *dst = (char *)malloc(len + 1);
  if (dst) memcpy(dst, src, len + 1);
  return dst;
}

static void json_skip_space(const char **cursor) {
  while (**cursor == ' ' || **cursor == '\t' || **cursor == '\n' || **cursor == '\r') (*cursor)++;
}

static int json_hex_digit(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

static int json_append_decoded(JsonBuffer *b, unsigned int cp) {
  if (cp < 0x80) json_buf_append_char(b, (char)cp);
  else if (cp < 0x800) {
    json_buf_append_char(b, (char)(0xC0 | (cp >> 6)));
    json_buf_append_char(b, (char)(0x80 | (cp & 0x3F)));
  } else {
    json_buf_append_char(b, (char)(0xE0 | (cp >> 12)));
    json_buf_append_char(b, (char)(0x80 | ((cp >> 6) & 0x3F)));
    json_buf_append_char(b, (char)(0x80 | (cp & 0x3F)));
  }
  return 1;
}

static char *json_parse_string(const char **cursor) {
  if (!cursor || !*cursor || **cursor != '"') return NULL;
  (*cursor)++;
  JsonBuffer b;
  json_buf_init(&b);
  while (**cursor && **cursor != '"') {
    unsigned char ch = (unsigned char)*(*cursor)++;
    if (ch != '\\') {
      json_buf_append_char(&b, (char)ch);
      continue;
    }
    ch = (unsigned char)*(*cursor)++;
    switch (ch) {
      case '"': json_buf_append_char(&b, '"'); break;
      case '\\': json_buf_append_char(&b, '\\'); break;
      case '/': json_buf_append_char(&b, '/'); break;
      case 'b': json_buf_append_char(&b, '\b'); break;
      case 'f': json_buf_append_char(&b, '\f'); break;
      case 'n': json_buf_append_char(&b, '\n'); break;
      case 'r': json_buf_append_char(&b, '\r'); break;
      case 't': json_buf_append_char(&b, '\t'); break;
      case 'u': {
        unsigned int cp = 0;
        for (int i = 0; i < 4; i++) {
          int digit = json_hex_digit((*cursor)[i]);
          if (digit < 0) { free(b.data); return NULL; }
          cp = (cp << 4) | (unsigned int)digit;
        }
        *cursor += 4;
        json_append_decoded(&b, cp);
        break;
      }
      default: free(b.data); return NULL;
    }
  }
  if (**cursor != '"') { free(b.data); return NULL; }
  (*cursor)++;
  return b.data;
}

static int json_skip_value(const char **cursor);

static int json_skip_container(const char **cursor, char open, char close) {
  if (**cursor != open) return 0;
  (*cursor)++;
  json_skip_space(cursor);
  if (**cursor == close) { (*cursor)++; return 1; }
  while (**cursor) {
    if (open == '{') {
      char *key = json_parse_string(cursor);
      free(key);
      if (!key) return 0;
      json_skip_space(cursor);
      if (**cursor != ':') return 0;
      (*cursor)++;
    }
    json_skip_space(cursor);
    if (!json_skip_value(cursor)) return 0;
    json_skip_space(cursor);
    if (**cursor == close) { (*cursor)++; return 1; }
    if (**cursor != ',') return 0;
    (*cursor)++;
    json_skip_space(cursor);
  }
  return 0;
}

static int json_skip_value(const char **cursor) {
  json_skip_space(cursor);
  if (**cursor == '"') {
    char *value = json_parse_string(cursor);
    free(value);
    return value != NULL;
  }
  if (**cursor == '{') return json_skip_container(cursor, '{', '}');
  if (**cursor == '[') return json_skip_container(cursor, '[', ']');
  if (**cursor == '\0') return 0;
  while (**cursor && !strchr(" \t\n\r,]}", **cursor)) (*cursor)++;
  return 1;
}

static char *json_find_string_property(const char *payload, const char *wanted_key) {
  if (!payload || !wanted_key) return NULL;
  const char *cursor = payload;
  json_skip_space(&cursor);
  if (*cursor != '{') return NULL;
  cursor++;
  json_skip_space(&cursor);
  while (*cursor && *cursor != '}') {
    char *key = json_parse_string(&cursor);
    if (!key) return NULL;
    json_skip_space(&cursor);
    if (*cursor != ':') { free(key); return NULL; }
    cursor++;
    json_skip_space(&cursor);
    if (strcmp(key, wanted_key) == 0 && *cursor == '"') {
      free(key);
      return json_parse_string(&cursor);
    }
    free(key);
    if (!json_skip_value(&cursor)) return NULL;
    json_skip_space(&cursor);
    if (*cursor == ',') { cursor++; json_skip_space(&cursor); }
    else if (*cursor != '}') return NULL;
  }
  return NULL;
}

char *protocol_extract_string_value(const char *payload, const char *key) {
  if (!key) return NULL;
  size_t length = strlen(key);
  if (length >= 2 && key[0] == '"' && key[length - 1] == '"') {
    char *plain_key = malloc(length - 1);
    if (!plain_key) return NULL;
    memcpy(plain_key, key + 1, length - 2);
    plain_key[length - 2] = '\0';
    char *value = json_find_string_property(payload, plain_key);
    free(plain_key);
    return value;
  }
  return json_find_string_property(payload, key);
}

char *protocol_extract_source_code(const char *payload) {
  if (!payload) return NULL;
  char *entry_path = protocol_extract_string_value(payload, "\"entryPath\"");
  int found_source_texts = 0;
  const char *cursor = payload;
  json_skip_space(&cursor);
  if (*cursor != '{') goto raw_payload;
  cursor++;
  json_skip_space(&cursor);
  while (*cursor && *cursor != '}') {
    char *key = json_parse_string(&cursor);
    if (!key) break;
    json_skip_space(&cursor);
    if (*cursor != ':') { free(key); break; }
    cursor++;
    json_skip_space(&cursor);
    if (strcmp(key, "sourceTexts") == 0 && *cursor == '{') {
      found_source_texts = 1;
      cursor++;
      json_skip_space(&cursor);
      while (*cursor && *cursor != '}') {
        char *source_path = json_parse_string(&cursor);
        if (!source_path) break;
        json_skip_space(&cursor);
        if (*cursor != ':') { free(source_path); break; }
        cursor++;
        json_skip_space(&cursor);
        char *source = (*cursor == '"') ? json_parse_string(&cursor) : NULL;
        if (source && (!entry_path || strcmp(source_path, entry_path) == 0)) {
          strncpy(g_source_path_storage, source_path, sizeof(g_source_path_storage) - 1);
          g_source_path_storage[sizeof(g_source_path_storage) - 1] = '\0';
          g_current_source_path = g_source_path_storage;
          free(source_path);
          free(entry_path);
          return source;
        }
        free(source_path);
        free(source);
        json_skip_space(&cursor);
        if (*cursor == ',') { cursor++; json_skip_space(&cursor); }
        else if (*cursor != '}') break;
      }
      break;
    }
    free(key);
    if (!json_skip_value(&cursor)) break;
    json_skip_space(&cursor);
    if (*cursor == ',') { cursor++; json_skip_space(&cursor); }
    else if (*cursor != '}') break;
  }
  if (!found_source_texts) goto raw_payload;
  free(entry_path);
  return NULL;

raw_payload:
  free(entry_path);
  {
    size_t len = strlen(payload);
    char *res = malloc(len + 1);
    if (res) memcpy(res, payload, len + 1);
    return res;
  }
}

static void serialize_type(JsonBuffer *b, const CTypeSpec *type) {
  if (!type) { json_buf_append(b, "null"); return; }
  json_buf_append(b, "{\"kind\":");
  json_buf_append_escaped(b, type->kind == C_TYPE_ARRAY ? "array" : type->kind == C_TYPE_RECORD ? "record" : "named");
  if (type->name) { json_buf_append(b, ",\"name\":"); json_buf_append_escaped(b, type->name); }
  if (type->kind == C_TYPE_ARRAY) {
    char number[32]; snprintf(number, sizeof(number), "%zu", type->length);
    json_buf_append(b, ",\"length\":"); json_buf_append(b, number); json_buf_append(b, ",\"elementType\":"); serialize_type(b, type->element_type);
  } else if (type->kind == C_TYPE_RECORD) {
    json_buf_append(b, ",\"fields\":[");
    for (size_t i = 0; i < type->fields.count; i++) { if (i) json_buf_append_char(b, ','); json_buf_append(b, "{\"name\":"); json_buf_append_escaped(b, type->fields.items[i].name); json_buf_append(b, ",\"type\":"); serialize_type(b, type->fields.items[i].type); json_buf_append_char(b, '}'); }
    json_buf_append_char(b, ']');
  }
  json_buf_append_char(b, '}');
}

/* AST to JSON Serializer for the Syntax Tree Tab */
static void serialize_ast_node(JsonBuffer *b, const CAstNode *n) {
  if (!n) { json_buf_append(b, "null"); return; }
  json_buf_append_char(b, '{');
  switch (n->kind) {
    case C_AST_PROGRAM:
      json_buf_append(b, "\"kind\":\"program\",\"name\":");
      json_buf_append_escaped(b, n->data.program.name ? n->data.program.name : "main");
      json_buf_append(b, ",\"declarations\":[");
      for (size_t i = 0; i < n->data.program.declarations.count; i++) {
        if (i > 0) json_buf_append_char(b, ',');
        serialize_ast_node(b, n->data.program.declarations.items[i]);
      }
      json_buf_append(b, "],\"statements\":[");
      for (size_t i = 0; i < n->data.program.statements.count; i++) {
        if (i > 0) json_buf_append_char(b, ',');
        serialize_ast_node(b, n->data.program.statements.items[i]);
      }
      json_buf_append(b, "]");
      break;

    case C_AST_CONSTANT_DECLARATION:
      json_buf_append(b, "\"kind\":\"constant_declaration\",\"name\":"); json_buf_append_escaped(b, n->data.constant.name); json_buf_append(b, ",\"value\":"); serialize_ast_node(b, n->data.constant.value); break;

    case C_AST_TYPE_DECLARATION:
      json_buf_append(b, "\"kind\":\"type_declaration\",\"name\":"); json_buf_append_escaped(b, n->data.type_declaration.name); json_buf_append(b, ",\"type\":"); serialize_type(b, n->data.type_declaration.type); break;

    case C_AST_PROCEDURE_DECLARATION:
      json_buf_append(b, "\"kind\":\"procedure_declaration\",\"name\":"); json_buf_append_escaped(b, n->data.procedure.name); json_buf_append(b, ",\"parameterCount\":"); char pc[32]; snprintf(pc, sizeof(pc), "%zu", n->data.procedure.parameter_count); json_buf_append(b, pc); break;

    case C_AST_VARIABLE_DECLARATION:
      json_buf_append(b, "\"kind\":\"variable_declaration\",\"names\":[");
      for (size_t i = 0; i < n->data.variable.name_count; i++) {
        if (i > 0) json_buf_append_char(b, ',');
        json_buf_append_escaped(b, n->data.variable.names[i]);
      }
      json_buf_append(b, "],\"type\":");
      json_buf_append_escaped(b, n->data.variable.type && n->data.variable.type->name ? n->data.variable.type->name : "صحيح");
      break;

    case C_AST_ASSIGNMENT:
      json_buf_append(b, "\"kind\":\"assignment\",\"name\":");
      json_buf_append_escaped(b, n->data.assignment.name);
      json_buf_append(b, ",\"expression\":");
      serialize_ast_node(b, n->data.assignment.expression);
      json_buf_append(b, ",\"selectorCount\":"); char sc[32]; snprintf(sc, sizeof(sc), "%zu", n->data.assignment.selectors.count); json_buf_append(b, sc);
      break;

    case C_AST_PRINT:
      json_buf_append(b, "\"kind\":\"print\",\"values\":[");
      for (size_t i = 0; i < n->data.print.values.count; i++) {
        if (i > 0) json_buf_append_char(b, ',');
        serialize_ast_node(b, n->data.print.values.items[i]);
      }
      json_buf_append(b, "]");
      break;

    case C_AST_UNARY:
      json_buf_append(b, "\"kind\":\"unary\",\"operator\":"); json_buf_append_escaped(b, n->data.unary.operator); json_buf_append(b, ",\"operand\":"); serialize_ast_node(b, n->data.unary.operand); break;

    case C_AST_BINARY:
      json_buf_append(b, "\"kind\":\"binary\",\"operator\":");
      json_buf_append_escaped(b, n->data.binary.operator);
      json_buf_append(b, ",\"left\":");
      serialize_ast_node(b, n->data.binary.left);
      json_buf_append(b, ",\"right\":");
      serialize_ast_node(b, n->data.binary.right);
      break;

    case C_AST_LITERAL:
      json_buf_append(b, "\"kind\":\"literal\",\"literalKind\":");
      const char *lk = "integer";
      if (n->data.literal.literal_kind == C_TOKEN_STRING) lk = "string";
      else if (n->data.literal.literal_kind == C_TOKEN_REAL) lk = "real";
      else if (n->data.literal.literal_kind == C_TOKEN_CHARACTER) lk = "character";
      else if (n->data.literal.literal_kind == C_TOKEN_BOOLEAN) lk = "boolean";
      json_buf_append_escaped(b, lk);
      json_buf_append(b, ",\"value\":");
      json_buf_append_escaped(b, n->data.literal.value ? n->data.literal.value : "");
      break;

    case C_AST_VARIABLE_REFERENCE:
      json_buf_append(b, "\"kind\":\"variable_reference\",\"name\":");
      json_buf_append_escaped(b, n->data.reference.name);
      json_buf_append(b, ",\"selectorCount\":"); char rc[32]; snprintf(rc, sizeof(rc), "%zu", n->data.reference.selectors.count); json_buf_append(b, rc);
      break;

    default:
      json_buf_append(b, "\"kind\":\"statement\"");
      break;
  }
  json_buf_append_char(b, '}');
}

char *protocol_ast_to_json(const CAstNode *root) {
  if (!root) return NULL;
  JsonBuffer b;
  json_buf_init(&b);
  serialize_ast_node(&b, root);
  return b.data;
}
