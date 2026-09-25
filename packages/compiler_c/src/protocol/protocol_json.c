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

char *protocol_extract_string_value(const char *payload, const char *key) {
  if (!payload || !key) return NULL;
  const char *p = strstr(payload, key);
  if (!p) return NULL;
  p += strlen(key);
  while (*p && *p != ':') p++;
  if (!*p) return NULL;
  p++;
  while (*p && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
  if (*p != '"') return NULL;
  p++;
  size_t cap = 256;
  size_t len = 0;
  char *buf = malloc(cap);
  if (!buf) return NULL;
  while (*p && *p != '"') {
    char ch = *p++;
    if (ch == '\\' && *p) {
      char esc = *p++;
      switch (esc) {
        case 'n': ch = '\n'; break;
        case 'r': ch = '\r'; break;
        case 't': ch = '\t'; break;
        case '\\': ch = '\\'; break;
        case '"': ch = '"'; break;
        default: ch = esc; break;
      }
    }
    if (len + 1 >= cap) {
      cap *= 2;
      char *nb = realloc(buf, cap);
      if (!nb) { free(buf); return NULL; }
      buf = nb;
    }
    buf[len++] = ch;
  }
  buf[len] = '\0';
  return buf;
}

char *protocol_extract_source_code(const char *payload) {
  if (!payload) return NULL;
  if (strstr(payload, "\"sourceTexts\"") == NULL) {
    size_t len = strlen(payload);
    char *res = malloc(len + 1);
    if (res) memcpy(res, payload, len + 1);
    return res;
  }
  const char *p = strstr(payload, "\"sourceTexts\"");
  if (!p) return NULL;

  p = strchr(p, '{');
  if (!p) return NULL;
  p++;

  while (*p && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
  if (*p != '"') return NULL;
  p++; /* skip opening quote of key */

  /* Extract key as current_source_path */
  size_t ki = 0;
  while (*p && *p != '"' && ki < sizeof(g_source_path_storage) - 1) {
    if (*p == '\\' && *(p + 1)) {
      p++;
      if (*p == '\\') g_source_path_storage[ki++] = '\\';
      else if (*p == '/') g_source_path_storage[ki++] = '/';
      else g_source_path_storage[ki++] = *p;
      p++;
    } else {
      g_source_path_storage[ki++] = *p++;
    }
  }
  g_source_path_storage[ki] = '\0';
  if (*p == '"') p++;
  g_current_source_path = g_source_path_storage;

  while (*p && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
  if (*p != ':') return NULL;
  p++;

  while (*p && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
  if (*p != '"') return NULL;
  p++;

  size_t cap = 4096;
  size_t len = 0;
  char *buf = malloc(cap);
  if (!buf) return NULL;
  while (*p && *p != '"') {
    char ch = *p++;
    if (ch == '\\' && *p) {
      char esc = *p++;
      switch (esc) {
        case 'n': ch = '\n'; break;
        case 'r': ch = '\r'; break;
        case 't': ch = '\t'; break;
        case '"': ch = '"'; break;
        case '\\': ch = '\\'; break;
        case 'u': {
          if (p[0] && p[1] && p[2] && p[3]) {
            unsigned int cp = 0;
            for (int i = 0; i < 4; i++) {
              char hc = p[i];
              cp <<= 4;
              if (hc >= '0' && hc <= '9') cp |= (unsigned)(hc - '0');
              else if (hc >= 'a' && hc <= 'f') cp |= (unsigned)(hc - 'a' + 10);
              else if (hc >= 'A' && hc <= 'F') cp |= (unsigned)(hc - 'A' + 10);
            }
            p += 4;
            char utf8[4];
            int nb = 0;
            if (cp < 0x80) {
              utf8[nb++] = (char)cp;
            } else if (cp < 0x800) {
              utf8[nb++] = (char)(0xC0 | (cp >> 6));
              utf8[nb++] = (char)(0x80 | (cp & 0x3F));
            } else {
              utf8[nb++] = (char)(0xE0 | (cp >> 12));
              utf8[nb++] = (char)(0x80 | ((cp >> 6) & 0x3F));
              utf8[nb++] = (char)(0x80 | (cp & 0x3F));
            }
            if (len + nb >= cap) {
              cap *= 2;
              char *nb2 = realloc(buf, cap);
              if (!nb2) { free(buf); return NULL; }
              buf = nb2;
            }
            for (int i = 0; i < nb; i++) buf[len++] = utf8[i];
            continue;
          }
          ch = 'u';
          break;
        }
        default: ch = esc; break;
      }
    }
    if (len + 1 >= cap) {
      cap *= 2;
      char *nb = realloc(buf, cap);
      if (!nb) { free(buf); return NULL; }
      buf = nb;
    }
    buf[len++] = ch;
  }
  buf[len] = '\0';
  return buf;
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
