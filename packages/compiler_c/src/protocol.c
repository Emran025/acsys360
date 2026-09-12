#include "protocol.h"

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
  buf_append_escaped(b, span->source_path ? span->source_path : "");
  buf_append(b, ",\"offset\":");
  char num[32];
  snprintf(num, sizeof(num), "%zu", span->offset);
  buf_append(b, num);
  buf_append(b, ",\"line\":");
  snprintf(num, sizeof(num), "%zu", span->line > 0 ? span->line : 1);
  buf_append(b, num);
  buf_append(b, ",\"column\":");
  snprintf(num, sizeof(num), "%zu", span->column > 0 ? span->column : 1);
  buf_append(b, num);
  buf_append(b, ",\"length\":");
  snprintf(num, sizeof(num), "%zu", span->length);
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
  free(resp->diagnostics);
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
  d->phase = phase;
  d->code = code;
  d->message = message;
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
    resp->token_capacity = resp->token_capacity == 0 ? 32 : resp->token_capacity * 2;
    resp->tokens = (ProtocolTokenItem *)realloc(resp->tokens, resp->token_capacity * sizeof(ProtocolTokenItem));
  }
  ProtocolTokenItem *t = &resp->tokens[resp->token_count++];
  t->kind = kind;
  t->lexeme = lexeme;
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
  if (resp->output_count >= resp->output_capacity) {
    resp->output_capacity = resp->output_capacity == 0 ? 8 : resp->output_capacity * 2;
    resp->execution_output = (char **)realloc(resp->execution_output, resp->output_capacity * sizeof(char *));
  }
  resp->execution_output[resp->output_count++] = c_strdup(line);
}

void protocol_add_artifact(ProtocolResponse *resp, const char *artifact) {
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

#include "ast.h"
#include "semantic.h"
#include "asm_x86_64.h"

typedef struct yy_buffer_state *YY_BUFFER_STATE;
extern YY_BUFFER_STATE yy_scan_string(const char *str);
extern void yy_delete_buffer(YY_BUFFER_STATE buffer);
extern int yyparse(void);
extern CAstNode *g_root_ast;
extern ProtocolResponse *g_protocol_response;
extern int current_line;
extern int current_column;
extern const char *g_current_source_path;

/* skip_json_string: advances *pp past a JSON string (including surrounding quotes).
   Returns 1 on success, 0 if malformed. */
static int skip_json_string(const char **pp) {
  const char *p = *pp;
  if (*p != '"') return 0;
  p++; /* skip opening quote */
  while (*p && *p != '"') {
    if (*p == '\\') {
      p++; /* skip escape char */
      if (!*p) return 0;
    }
    p++;
  }
  if (*p != '"') return 0;
  p++; /* skip closing quote */
  *pp = p;
  return 1;
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

  /* advance past "sourceTexts" then find the opening { of the object */
  p = strchr(p, '{');
  if (!p) return NULL;
  p++; /* skip '{' */

  /* skip optional whitespace */
  while (*p && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;

  /* p should now be at the opening " of the first key string */
  if (*p != '"') return NULL;
  /* skip the key string (e.g. "C:/test/main.arb") */
  if (!skip_json_string(&p)) return NULL;

  /* skip optional whitespace then ':' */
  while (*p && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
  if (*p != ':') return NULL;
  p++; /* skip ':' */

  /* skip optional whitespace */
  while (*p && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;

  /* p should now be at the opening " of the source text value */
  if (*p != '"') return NULL;
  p++; /* skip opening quote of value */

  /* read and unescape the value */
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
          /* \uXXXX → UTF-8 */
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
            /* encode cp as UTF-8 into buf */
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
          ch = 'u'; /* fallback */
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

  char *source = extract_source_code(payload);
  if (source && source[0] != '\0') {
    g_protocol_response = &resp;
    current_line = 1;
    current_column = 1;
    g_root_ast = NULL;

    YY_BUFFER_STATE buffer = yy_scan_string(source);
    int parse_res = yyparse();
    yy_delete_buffer(buffer);

    if (parse_res == 0 && g_root_ast != NULL) {
      CSemanticResult semantic;
      memset(&semantic, 0, sizeof(semantic));
      if (c_analyze_semantics(g_root_ast, &semantic)) {
        for (size_t i = 0; i < semantic.count; i++) {
          ProtocolSpan span = {g_current_source_path, semantic.items[i].offset, semantic.items[i].line, semantic.items[i].column, 0};
          protocol_add_symbol(&resp, semantic.items[i].name, "variable", semantic.items[i].type, span);
        }
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
      c_semantic_result_free(&semantic);
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
