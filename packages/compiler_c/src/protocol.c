#include "protocol.h"
#include "ast.h"
#include "semantic.h"
#include "asm_x86_64.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Dynamic String Buffer */
typedef struct {
  char *data;
  size_t length;
  size_t capacity;
} Buffer;

static void buf_init(Buffer *b) {
  b->capacity = 1024;
  b->length = 0;
  b->data = (char *)malloc(b->capacity);
  if (b->data) b->data[0] = '\0';
}

static void buf_append(Buffer *b, const char *str) {
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

static void buf_append_char(Buffer *b, char c) {
  if (b->length + 2 > b->capacity) {
    b->capacity *= 2;
    b->data = (char *)realloc(b->data, b->capacity);
  }
  b->data[b->length++] = c;
  b->data[b->length] = '\0';
}

static void buf_append_escaped(Buffer *b, const char *str) {
  if (!str) {
    buf_append(b, "\"\"");
    return;
  }
  buf_append_char(b, '"');
  for (const unsigned char *p = (const unsigned char *)str; *p != '\0'; p++) {
    switch (*p) {
      case '"': buf_append(b, "\\\""); break;
      case '\\': buf_append(b, "\\\\"); break;
      case '\b': buf_append(b, "\\b"); break;
      case '\f': buf_append(b, "\\f"); break;
      case '\n': buf_append(b, "\\n"); break;
      case '\r': buf_append(b, "\\r"); break;
      case '\t': buf_append(b, "\\t"); break;
      default:
        if (*p < 0x20) {
          char hex[8];
          snprintf(hex, sizeof(hex), "\\u%04x", *p);
          buf_append(b, hex);
        } else {
          buf_append_char(b, (char)*p);
        }
        break;
    }
  }
  buf_append_char(b, '"');
}

static void buf_append_span(Buffer *b, const ProtocolSpan *span) {
  buf_append(b, "{\"sourcePath\":");
  if (span && span->source_path && span->source_path[0] != '\0') {
    buf_append_escaped(b, span->source_path);
  } else {
    buf_append(b, "null");
  }
  buf_append(b, ",\"offset\":");
  char num[32];
  snprintf(num, sizeof(num), "%zu", span ? span->offset : 0);
  buf_append(b, num);
  buf_append(b, ",\"line\":");
  snprintf(num, sizeof(num), "%zu", (span && span->line > 0) ? span->line : 1);
  buf_append(b, num);
  buf_append(b, ",\"column\":");
  snprintf(num, sizeof(num), "%zu", (span && span->column > 0) ? span->column : 1);
  buf_append(b, num);
  buf_append(b, ",\"length\":");
  snprintf(num, sizeof(num), "%zu", span ? span->length : 0);
  buf_append(b, num);
  buf_append_char(b, '}');
}

static char *c_strdup(const char *src) {
  if (!src) return NULL;
  size_t len = strlen(src);
  char *dst = (char *)malloc(len + 1);
  if (dst) memcpy(dst, src, len + 1);
  return dst;
}

void protocol_response_init(ProtocolResponse *resp) {
  memset(resp, 0, sizeof(*resp));
  resp->success = 1;
}

void protocol_response_free(ProtocolResponse *resp) {
  if (!resp) return;
  for (size_t i = 0; i < resp->diagnostic_count; i++) {
    free((char *)resp->diagnostics[i].phase);
    free((char *)resp->diagnostics[i].code);
    free((char *)resp->diagnostics[i].message);
  }
  free(resp->diagnostics);

  for (size_t i = 0; i < resp->token_count; i++) {
    free((char *)resp->tokens[i].kind);
    free((char *)resp->tokens[i].lexeme);
  }
  free(resp->tokens);

  for (size_t i = 0; i < resp->symbol_count; i++) {
    free((char *)resp->symbols[i].name);
    free((char *)resp->symbols[i].kind);
    free((char *)resp->symbols[i].type);
  }
  free(resp->symbols);
  free(resp->syntax_tree_json);
  free(resp->assembly);
  free(resp->intermediate_representation_json);

  for (size_t i = 0; i < resp->tac_count; i++) free(resp->three_address_code[i]);
  free(resp->three_address_code);

  for (size_t i = 0; i < resp->output_count; i++) free(resp->execution_output[i]);
  free(resp->execution_output);

  for (size_t i = 0; i < resp->artifact_count; i++) free(resp->artifacts[i]);
  free(resp->artifacts);

  memset(resp, 0, sizeof(*resp));
}

void protocol_add_diagnostic(ProtocolResponse *resp, DiagnosticSeverity severity, const char *phase, const char *code, const char *message, const ProtocolSpan *span) {
  if (resp->diagnostic_count >= resp->diagnostic_capacity) {
    resp->diagnostic_capacity = resp->diagnostic_capacity == 0 ? 8 : resp->diagnostic_capacity * 2;
    resp->diagnostics = (ProtocolDiagnostic *)realloc(resp->diagnostics, resp->diagnostic_capacity * sizeof(ProtocolDiagnostic));
  }
  ProtocolDiagnostic *d = &resp->diagnostics[resp->diagnostic_count++];
  d->severity = severity;
  d->phase = phase ? c_strdup(phase) : NULL;
  d->code = code ? c_strdup(code) : NULL;
  d->message = message ? c_strdup(message) : NULL;
  if (span) {
    d->has_span = 1;
    d->span = *span;
  } else {
    d->has_span = 0;
  }
  if (severity == SEVERITY_ERROR) {
    resp->success = 0;
  }
}

void protocol_add_token(ProtocolResponse *resp, const char *kind, const char *lexeme, ProtocolSpan span) {
  if (resp->token_count >= resp->token_capacity) {
    resp->token_capacity = resp->token_capacity == 0 ? 64 : resp->token_capacity * 2;
    resp->tokens = (ProtocolTokenItem *)realloc(resp->tokens, resp->token_capacity * sizeof(ProtocolTokenItem));
  }
  ProtocolTokenItem *t = &resp->tokens[resp->token_count++];
  t->kind = kind ? c_strdup(kind) : NULL;
  t->lexeme = lexeme ? c_strdup(lexeme) : NULL;
  t->span = span;
}

void protocol_add_symbol(ProtocolResponse *resp, const char *name, const char *kind, const char *type, ProtocolSpan span) {
  if (resp->symbol_count >= resp->symbol_capacity) {
    resp->symbol_capacity = resp->symbol_capacity == 0 ? 16 : resp->symbol_capacity * 2;
    resp->symbols = (ProtocolSymbol *)realloc(resp->symbols, resp->symbol_capacity * sizeof(ProtocolSymbol));
  }
  ProtocolSymbol *s = &resp->symbols[resp->symbol_count++];
  s->name = name ? c_strdup(name) : NULL;
  s->kind = kind ? c_strdup(kind) : NULL;
  s->type = type ? c_strdup(type) : NULL;
  s->span = span;
}

void protocol_add_tac(ProtocolResponse *resp, const char *instruction) {
  if (!instruction) return;
  if (resp->tac_count >= resp->tac_capacity) {
    resp->tac_capacity = resp->tac_capacity == 0 ? 16 : resp->tac_capacity * 2;
    resp->three_address_code = (char **)realloc(resp->three_address_code, resp->tac_capacity * sizeof(char *));
  }
  resp->three_address_code[resp->tac_count++] = c_strdup(instruction);
}

void protocol_set_assembly(ProtocolResponse *resp, const char *assembly) {
  free(resp->assembly);
  resp->assembly = c_strdup(assembly);
}

void protocol_add_output(ProtocolResponse *resp, const char *line) {
  if (!line) return;
  if (resp->output_count >= resp->output_capacity) {
    resp->output_capacity = resp->output_capacity == 0 ? 8 : resp->output_capacity * 2;
    resp->execution_output = (char **)realloc(resp->execution_output, resp->output_capacity * sizeof(char *));
  }
  resp->execution_output[resp->output_count++] = c_strdup(line);
}

void protocol_add_artifact(ProtocolResponse *resp, const char *artifact) {
  if (!artifact) return;
  if (resp->artifact_count >= resp->artifact_capacity) {
    resp->artifact_capacity = resp->artifact_capacity == 0 ? 8 : resp->artifact_capacity * 2;
    resp->artifacts = (char **)realloc(resp->artifacts, resp->artifact_capacity * sizeof(char *));
  }
  resp->artifacts[resp->artifact_count++] = c_strdup(artifact);
}

void protocol_set_syntax_tree_json(ProtocolResponse *resp, const char *json) {
  free(resp->syntax_tree_json);
  resp->syntax_tree_json = c_strdup(json);
}

void protocol_set_ir_json(ProtocolResponse *resp, const char *json) {
  free(resp->intermediate_representation_json);
  resp->intermediate_representation_json = c_strdup(json);
}

char *protocol_serialize_response(const ProtocolResponse *resp) {
  Buffer b;
  buf_init(&b);
  buf_append(&b, "{\"protocolVersion\":\"" ARABICC_PROTOCOL_VERSION "\",\"success\":");
  buf_append(&b, resp->success ? "true" : "false");

  /* diagnostics */
  buf_append(&b, ",\"diagnostics\":[");
  for (size_t i = 0; i < resp->diagnostic_count; i++) {
    if (i > 0) buf_append_char(&b, ',');
    const ProtocolDiagnostic *d = &resp->diagnostics[i];
    buf_append(&b, "{\"severity\":");
    const char *sev_str = "error";
    if (d->severity == SEVERITY_INFO) sev_str = "info";
    else if (d->severity == SEVERITY_WARNING) sev_str = "warning";
    buf_append_escaped(&b, sev_str);
    buf_append(&b, ",\"phase\":");
    buf_append_escaped(&b, d->phase ? d->phase : "compiler");
    buf_append(&b, ",\"code\":");
    buf_append_escaped(&b, d->code ? d->code : "C001");
    buf_append(&b, ",\"message\":");
    buf_append_escaped(&b, d->message ? d->message : "");
    buf_append(&b, ",\"span\":");
    if (d->has_span) {
      buf_append_span(&b, &d->span);
    } else {
      buf_append(&b, "null");
    }
    buf_append_char(&b, '}');
  }
  buf_append_char(&b, ']');

  /* tokens */
  buf_append(&b, ",\"tokens\":[");
  for (size_t i = 0; i < resp->token_count; i++) {
    if (i > 0) buf_append_char(&b, ',');
    const ProtocolTokenItem *tok = &resp->tokens[i];
    buf_append(&b, "{\"kind\":");
    buf_append_escaped(&b, tok->kind ? tok->kind : "unknown");
    buf_append(&b, ",\"lexeme\":");
    buf_append_escaped(&b, tok->lexeme ? tok->lexeme : "");
    buf_append(&b, ",\"span\":");
    buf_append_span(&b, &tok->span);
    buf_append_char(&b, '}');
  }
  buf_append_char(&b, ']');

  /* syntaxTree */
  buf_append(&b, ",\"syntaxTree\":");
  if (resp->syntax_tree_json && resp->syntax_tree_json[0] != '\0') {
    buf_append(&b, resp->syntax_tree_json);
  } else {
    buf_append(&b, "null");
  }

  /* symbolTable */
  buf_append(&b, ",\"symbolTable\":[");
  for (size_t i = 0; i < resp->symbol_count; i++) {
    if (i > 0) buf_append_char(&b, ',');
    const ProtocolSymbol *sym = &resp->symbols[i];
    buf_append(&b, "{\"name\":");
    buf_append_escaped(&b, sym->name ? sym->name : "");
    buf_append(&b, ",\"kind\":");
    buf_append_escaped(&b, sym->kind ? sym->kind : "variable");
    buf_append(&b, ",\"type\":");
    buf_append_escaped(&b, sym->type ? sym->type : "صحيح");
    buf_append(&b, ",\"span\":");
    buf_append_span(&b, &sym->span);
    buf_append_char(&b, '}');
  }
  buf_append_char(&b, ']');

  /* threeAddressCode */
  buf_append(&b, ",\"threeAddressCode\":[");
  for (size_t i = 0; i < resp->tac_count; i++) {
    if (i > 0) buf_append_char(&b, ',');
    buf_append_escaped(&b, resp->three_address_code[i]);
  }
  buf_append_char(&b, ']');

  /* assembly */
  buf_append(&b, ",\"assembly\":");
  buf_append_escaped(&b, resp->assembly ? resp->assembly : "");

  /* executionOutput */
  buf_append(&b, ",\"executionOutput\":[");
  for (size_t i = 0; i < resp->output_count; i++) {
    if (i > 0) buf_append_char(&b, ',');
    buf_append_escaped(&b, resp->execution_output[i]);
  }
  buf_append_char(&b, ']');

  /* artifacts */
  buf_append(&b, ",\"artifacts\":[");
  for (size_t i = 0; i < resp->artifact_count; i++) {
    if (i > 0) buf_append_char(&b, ',');
    buf_append_escaped(&b, resp->artifacts[i]);
  }
  buf_append_char(&b, ']');

  /* intermediateRepresentation */
  buf_append(&b, ",\"intermediateRepresentation\":");
  if (resp->intermediate_representation_json && resp->intermediate_representation_json[0] != '\0') {
    buf_append(&b, resp->intermediate_representation_json);
  } else {
    buf_append(&b, "{}");
  }

  buf_append(&b, "}\n");
  return b.data;
}

typedef struct yy_buffer_state *YY_BUFFER_STATE;
extern YY_BUFFER_STATE yy_scan_string(const char *str);
extern void yy_delete_buffer(YY_BUFFER_STATE buffer);
extern int yyparse(void);
extern CAstNode *g_root_ast;
extern ProtocolResponse *g_protocol_response;
extern int current_line;
extern int current_column;
extern int current_offset;

static char g_source_path_storage[1024] = "";
const char *g_current_source_path = "";

/* Extracts a top-level string value from JSON payload: e.g. "entryPath": "..." */
static char *extract_string_value(const char *payload, const char *key) {
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

static char *extract_source_code(const char *payload) {
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

/* AST to JSON Serializer for the Syntax Tree Tab */
static void serialize_ast_node(Buffer *b, const CAstNode *n) {
  if (!n) { buf_append(b, "null"); return; }
  buf_append_char(b, '{');
  switch (n->kind) {
    case C_AST_PROGRAM:
      buf_append(b, "\"kind\":\"program\",\"name\":");
      buf_append_escaped(b, n->data.program.name ? n->data.program.name : "main");
      buf_append(b, ",\"declarations\":[");
      for (size_t i = 0; i < n->data.program.declarations.count; i++) {
        if (i > 0) buf_append_char(b, ',');
        serialize_ast_node(b, n->data.program.declarations.items[i]);
      }
      buf_append(b, "],\"statements\":[");
      for (size_t i = 0; i < n->data.program.statements.count; i++) {
        if (i > 0) buf_append_char(b, ',');
        serialize_ast_node(b, n->data.program.statements.items[i]);
      }
      buf_append(b, "]");
      break;

    case C_AST_VARIABLE_DECLARATION:
      buf_append(b, "\"kind\":\"variable_declaration\",\"names\":[");
      for (size_t i = 0; i < n->data.variable.name_count; i++) {
        if (i > 0) buf_append_char(b, ',');
        buf_append_escaped(b, n->data.variable.names[i]);
      }
      buf_append(b, "],\"type\":");
      buf_append_escaped(b, n->data.variable.type && n->data.variable.type->name ? n->data.variable.type->name : "صحيح");
      break;

    case C_AST_ASSIGNMENT:
      buf_append(b, "\"kind\":\"assignment\",\"name\":");
      buf_append_escaped(b, n->data.assignment.name);
      buf_append(b, ",\"expression\":");
      serialize_ast_node(b, n->data.assignment.expression);
      break;

    case C_AST_PRINT:
      buf_append(b, "\"kind\":\"print\",\"values\":[");
      for (size_t i = 0; i < n->data.print.values.count; i++) {
        if (i > 0) buf_append_char(b, ',');
        serialize_ast_node(b, n->data.print.values.items[i]);
      }
      buf_append(b, "]");
      break;

    case C_AST_BINARY:
      buf_append(b, "\"kind\":\"binary\",\"operator\":");
      buf_append_escaped(b, n->data.binary.operator);
      buf_append(b, ",\"left\":");
      serialize_ast_node(b, n->data.binary.left);
      buf_append(b, ",\"right\":");
      serialize_ast_node(b, n->data.binary.right);
      break;

    case C_AST_LITERAL:
      buf_append(b, "\"kind\":\"literal\",\"literalKind\":");
      const char *lk = "integer";
      if (n->data.literal.literal_kind == C_TOKEN_STRING) lk = "string";
      else if (n->data.literal.literal_kind == C_TOKEN_REAL) lk = "real";
      buf_append_escaped(b, lk);
      buf_append(b, ",\"value\":");
      buf_append_escaped(b, n->data.literal.value ? n->data.literal.value : "");
      break;

    case C_AST_VARIABLE_REFERENCE:
      buf_append(b, "\"kind\":\"variable_reference\",\"name\":");
      buf_append_escaped(b, n->data.reference.name);
      break;

    default:
      buf_append(b, "\"kind\":\"statement\"");
      break;
  }
  buf_append_char(b, '}');
}

static char *ast_to_json(const CAstNode *root) {
  if (!root) return NULL;
  Buffer b;
  buf_init(&b);
  serialize_ast_node(&b, root);
  return b.data;
}

/* 3AC Generation for the 3AC Tab */
static int g_tac_temp_counter = 0;

static char *emit_tac_expr(ProtocolResponse *resp, const CAstNode *expr) {
  if (!expr) return c_strdup("0");
  if (expr->kind == C_AST_LITERAL) {
    return c_strdup(expr->data.literal.value ? expr->data.literal.value : "0");
  }
  if (expr->kind == C_AST_VARIABLE_REFERENCE) {
    return c_strdup(expr->data.reference.name ? expr->data.reference.name : "");
  }
  if (expr->kind == C_AST_BINARY) {
    char *left = emit_tac_expr(resp, expr->data.binary.left);
    char *right = emit_tac_expr(resp, expr->data.binary.right);
    char temp[32];
    snprintf(temp, sizeof(temp), "t%d", g_tac_temp_counter++);
    char buf[256];
    snprintf(buf, sizeof(buf), "%s = %s %s %s", temp, left, expr->data.binary.operator ? expr->data.binary.operator : "+", right);
    protocol_add_tac(resp, buf);
    free(left);
    free(right);
    return c_strdup(temp);
  }
  return c_strdup("0");
}

static void generate_tac(ProtocolResponse *resp, const CAstNode *root) {
  if (!root || root->kind != C_AST_PROGRAM) return;
  g_tac_temp_counter = 0;
  for (size_t i = 0; i < root->data.program.declarations.count; i++) {
    const CAstNode *d = root->data.program.declarations.items[i];
    if (d && d->kind == C_AST_VARIABLE_DECLARATION) {
      for (size_t j = 0; j < d->data.variable.name_count; j++) {
        char buf[128];
        snprintf(buf, sizeof(buf), "ALLOC %s, %s",
                 d->data.variable.names[j],
                 d->data.variable.type && d->data.variable.type->name ? d->data.variable.type->name : "صحيح");
        protocol_add_tac(resp, buf);
      }
    }
  }
  for (size_t i = 0; i < root->data.program.statements.count; i++) {
    const CAstNode *s = root->data.program.statements.items[i];
    if (!s) continue;
    if (s->kind == C_AST_ASSIGNMENT && s->data.assignment.name) {
      char *val = emit_tac_expr(resp, s->data.assignment.expression);
      char buf[256];
      snprintf(buf, sizeof(buf), "%s = %s", s->data.assignment.name, val);
      protocol_add_tac(resp, buf);
      free(val);
    } else if (s->kind == C_AST_PRINT) {
      for (size_t j = 0; j < s->data.print.values.count; j++) {
        char *val = emit_tac_expr(resp, s->data.print.values.items[j]);
        char buf[256];
        snprintf(buf, sizeof(buf), "PARAM %s", val);
        protocol_add_tac(resp, buf);
        protocol_add_tac(resp, "CALL print, 1");
        free(val);
      }
    }
  }
}

/* Typed IR Generation for the Typed IR Tab */
static char *generate_typed_ir(const CAstNode *root, const CSemanticResult *semantic) {
  if (!root || root->kind != C_AST_PROGRAM) return NULL;
  Buffer b;
  buf_init(&b);
  buf_append(&b, "{\"unit\":\"برنامج\",\"name\":");
  buf_append_escaped(&b, root->data.program.name ? root->data.program.name : "main");
  buf_append(&b, ",\"target\":\"x86_64\",\"types\":[\"صحيح\",\"حقيقي\",\"خيط_رمزي\",\"منطقي\",\"حرفي\"],\"symbols\":[");
  if (semantic) {
    for (size_t i = 0; i < semantic->count; i++) {
      if (i > 0) buf_append_char(&b, ',');
      buf_append(&b, "{\"name\":");
      buf_append_escaped(&b, semantic->items[i].name);
      buf_append(&b, ",\"type\":");
      buf_append_escaped(&b, semantic->items[i].type);
      buf_append(&b, ",\"offset\":");
      char num[32];
      snprintf(num, sizeof(num), "%d", (int)(i * 8 + 8));
      buf_append(&b, num);
      buf_append_char(&b, '}');
    }
  }
  buf_append(&b, "],\"blocks\":[{\"name\":\"main\",\"statementCount\":");
  char num[32];
  snprintf(num, sizeof(num), "%zu", root->data.program.statements.count);
  buf_append(&b, num);
  buf_append(&b, "}]}");
  return b.data;
}

/* Simple AST Execution for the Execution Output Tab */
typedef struct {
  char *name;
  long long value;
} ExecVar;

static long long eval_ast_expr(const CAstNode *e, ExecVar *vars, size_t var_count) {
  if (!e) return 0;
  if (e->kind == C_AST_LITERAL) {
    if (e->data.literal.value) {
      return atoll(e->data.literal.value);
    }
    return 0;
  }
  if (e->kind == C_AST_VARIABLE_REFERENCE && e->data.reference.name) {
    for (size_t i = 0; i < var_count; i++) {
      if (strcmp(vars[i].name, e->data.reference.name) == 0) {
        return vars[i].value;
      }
    }
    return 0;
  }
  if (e->kind == C_AST_BINARY) {
    long long l = eval_ast_expr(e->data.binary.left, vars, var_count);
    long long r = eval_ast_expr(e->data.binary.right, vars, var_count);
    const char *op = e->data.binary.operator ? e->data.binary.operator : "+";
    if (strcmp(op, "+") == 0) return l + r;
    if (strcmp(op, "-") == 0) return l - r;
    if (strcmp(op, "*") == 0) return l * r;
    if (strcmp(op, "/") == 0) return r != 0 ? l / r : 0;
    if (strcmp(op, "%") == 0) return r != 0 ? l % r : 0;
  }
  return 0;
}

static void execute_ast_program(ProtocolResponse *resp, const CAstNode *root) {
  if (!root || root->kind != C_AST_PROGRAM) return;
  ExecVar vars[128];
  size_t var_count = 0;

  for (size_t i = 0; i < root->data.program.statements.count; i++) {
    const CAstNode *s = root->data.program.statements.items[i];
    if (!s) continue;
    if (s->kind == C_AST_ASSIGNMENT && s->data.assignment.name) {
      long long val = eval_ast_expr(s->data.assignment.expression, vars, var_count);
      int found = 0;
      for (size_t v = 0; v < var_count; v++) {
        if (strcmp(vars[v].name, s->data.assignment.name) == 0) {
          vars[v].value = val;
          found = 1;
          break;
        }
      }
      if (!found && var_count < 128) {
        vars[var_count].name = s->data.assignment.name;
        vars[var_count].value = val;
        var_count++;
      }
    } else if (s->kind == C_AST_PRINT) {
      for (size_t j = 0; j < s->data.print.values.count; j++) {
        const CAstNode *v = s->data.print.values.items[j];
        if (!v) continue;
        if (v->kind == C_AST_LITERAL && v->data.literal.literal_kind == C_TOKEN_STRING) {
          const char *raw = v->data.literal.value ? v->data.literal.value : "";
          if (raw[0] == '"') {
            size_t len = strlen(raw);
            char *clean = malloc(len + 1);
            size_t ci = 0;
            for (size_t k = 1; k < len && raw[k] != '"'; k++) {
              if (raw[k] == '\\' && k + 1 < len) {
                k++;
                switch (raw[k]) {
                  case 'n': clean[ci++] = '\n'; break;
                  case 't': clean[ci++] = '\t'; break;
                  default: clean[ci++] = raw[k]; break;
                }
              } else {
                clean[ci++] = raw[k];
              }
            }
            clean[ci] = '\0';
            protocol_add_output(resp, clean);
            free(clean);
          } else {
            protocol_add_output(resp, raw);
          }
        } else {
          long long val = eval_ast_expr(v, vars, var_count);
          char buf[64];
          snprintf(buf, sizeof(buf), "%lld", val);
          protocol_add_output(resp, buf);
        }
      }
    }
  }
}

int c_run_protocol(const char *payload) {
  if (payload == NULL || payload[0] == '\0') {
    fputs("{\"protocolVersion\":\"" ARABICC_PROTOCOL_VERSION "\",\"success\":false,\"diagnostics\":[{\"severity\":\"error\",\"phase\":\"driver\",\"code\":\"P001\",\"message\":\"حزمة الطلب فارغة\",\"span\":null}],\"tokens\":[],\"syntaxTree\":null,\"symbolTable\":[],\"threeAddressCode\":[],\"assembly\":\"\",\"executionOutput\":[],\"artifacts\":[],\"intermediateRepresentation\":{}}\n", stdout);
    return 1;
  }

  /* Handle assist request */
  if (strstr(payload, "\"requestType\"") != NULL && strstr(payload, "\"assist\"") != NULL) {
    fputs("{\"protocolVersion\":\"" ARABICC_PROTOCOL_VERSION "\",\"success\":true,\"requestType\":\"assist\",\"action\":\"completion\",\"expected\":\"\",\"prefix\":\"\",\"replaceStart\":0,\"replaceLength\":0,\"items\":[],\"help\":null}\n", stdout);
    return 0;
  }

  /* Compilation response */
  ProtocolResponse resp;
  protocol_response_init(&resp);
  resp.success = 1;

  /* Check for entryPath */
  char *entry_path = extract_string_value(payload, "\"entryPath\"");
  if (entry_path && entry_path[0] != '\0') {
    strncpy(g_source_path_storage, entry_path, sizeof(g_source_path_storage) - 1);
    g_current_source_path = g_source_path_storage;
    free(entry_path);
  }

  char *source = extract_source_code(payload);
  if (source && source[0] != '\0') {
    g_protocol_response = &resp;
    current_line = 1;
    current_column = 1;
    current_offset = 0;
    g_root_ast = NULL;

    YY_BUFFER_STATE buffer = yy_scan_string(source);
    int parse_res = yyparse();
    yy_delete_buffer(buffer);

    if (parse_res == 0 && g_root_ast != NULL) {
      /* 1. Syntax Tree */
      char *st_json = ast_to_json(g_root_ast);
      if (st_json) {
        protocol_set_syntax_tree_json(&resp, st_json);
        free(st_json);
      }

      /* 2. Semantic analysis */
      CSemanticResult semantic;
      memset(&semantic, 0, sizeof(semantic));
      if (c_analyze_semantics(g_root_ast, &semantic)) {
        for (size_t i = 0; i < semantic.count; i++) {
          ProtocolSpan span = {
            g_current_source_path[0] != '\0' ? g_current_source_path : NULL,
            semantic.items[i].offset,
            semantic.items[i].line,
            semantic.items[i].column,
            0
          };
          protocol_add_symbol(&resp, semantic.items[i].name, "variable", semantic.items[i].type, span);
        }

        /* 3. Assembly */
        CAssemblyResult assembly;
        memset(&assembly, 0, sizeof(assembly));
        if (c_generate_nasm_x86_64(g_root_ast, &semantic, &assembly) && assembly.text) {
          protocol_set_assembly(&resp, assembly.text);
        }
        c_assembly_result_free(&assembly);
      }

      for (size_t i = 0; i < semantic.diagnostic_count; i++) {
        protocol_add_diagnostic(&resp, SEVERITY_ERROR, "semantic", "SEM001", semantic.diagnostics[i], NULL);
      }

      /* 4. Typed IR */
      char *ir_json = generate_typed_ir(g_root_ast, &semantic);
      if (ir_json) {
        protocol_set_ir_json(&resp, ir_json);
        free(ir_json);
      }
      c_semantic_result_free(&semantic);

      /* 5. Three Address Code (3AC) */
      generate_tac(&resp, g_root_ast);

      /* 6. Execution output */
      execute_ast_program(&resp, g_root_ast);

      /* 7. Artifacts */
      char *artifact_dir = extract_string_value(payload, "\"artifactDirectory\"");
      if (artifact_dir && artifact_dir[0] != '\0') {
        char asm_path[1024];
        snprintf(asm_path, sizeof(asm_path), "%s/arabicc.asm", artifact_dir);
        if (resp.assembly && resp.assembly[0] != '\0') {
          FILE *af = fopen(asm_path, "w");
          if (af) {
            fputs(resp.assembly, af);
            fclose(af);
            protocol_add_artifact(&resp, asm_path);
          }
        }
        free(artifact_dir);
      }

      c_ast_free(g_root_ast);
      g_root_ast = NULL;
    }
    free(source);
  }

  char *json_out = protocol_serialize_response(&resp);
  if (json_out) {
    fputs(json_out, stdout);
    free(json_out);
  }
  protocol_response_free(&resp);
  return 0;
}