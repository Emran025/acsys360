#include "protocol_internal.h"
#include <stdlib.h>
#include <string.h>

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
  d->phase = phase ? protocol_strdup(phase) : NULL;
  d->code = code ? protocol_strdup(code) : NULL;
  d->message = message ? protocol_strdup(message) : NULL;
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
  t->kind = kind ? protocol_strdup(kind) : NULL;
  t->lexeme = lexeme ? protocol_strdup(lexeme) : NULL;
  t->span = span;
}

void protocol_add_symbol(ProtocolResponse *resp, const char *name, const char *kind, const char *type, ProtocolSpan span) {
  if (resp->symbol_count >= resp->symbol_capacity) {
    resp->symbol_capacity = resp->symbol_capacity == 0 ? 16 : resp->symbol_capacity * 2;
    resp->symbols = (ProtocolSymbol *)realloc(resp->symbols, resp->symbol_capacity * sizeof(ProtocolSymbol));
  }
  ProtocolSymbol *s = &resp->symbols[resp->symbol_count++];
  s->name = name ? protocol_strdup(name) : NULL;
  s->kind = kind ? protocol_strdup(kind) : NULL;
  s->type = type ? protocol_strdup(type) : NULL;
  s->span = span;
}

void protocol_add_tac(ProtocolResponse *resp, const char *instruction) {
  if (!instruction) return;
  if (resp->tac_count >= resp->tac_capacity) {
    resp->tac_capacity = resp->tac_capacity == 0 ? 16 : resp->tac_capacity * 2;
    resp->three_address_code = (char **)realloc(resp->three_address_code, resp->tac_capacity * sizeof(char *));
  }
  resp->three_address_code[resp->tac_count++] = protocol_strdup(instruction);
}

void protocol_set_assembly(ProtocolResponse *resp, const char *assembly) {
  free(resp->assembly);
  resp->assembly = protocol_strdup(assembly);
}

void protocol_add_output(ProtocolResponse *resp, const char *line) {
  if (!line) return;
  if (resp->output_count >= resp->output_capacity) {
    resp->output_capacity = resp->output_capacity == 0 ? 8 : resp->output_capacity * 2;
    resp->execution_output = (char **)realloc(resp->execution_output, resp->output_capacity * sizeof(char *));
  }
  resp->execution_output[resp->output_count++] = protocol_strdup(line);
}

void protocol_add_artifact(ProtocolResponse *resp, const char *artifact) {
  if (!artifact) return;
  if (resp->artifact_count >= resp->artifact_capacity) {
    resp->artifact_capacity = resp->artifact_capacity == 0 ? 8 : resp->artifact_capacity * 2;
    resp->artifacts = (char **)realloc(resp->artifacts, resp->artifact_capacity * sizeof(char *));
  }
  resp->artifacts[resp->artifact_count++] = protocol_strdup(artifact);
}

void protocol_set_syntax_tree_json(ProtocolResponse *resp, const char *json) {
  free(resp->syntax_tree_json);
  resp->syntax_tree_json = protocol_strdup(json);
}

void protocol_set_ir_json(ProtocolResponse *resp, const char *json) {
  free(resp->intermediate_representation_json);
  resp->intermediate_representation_json = protocol_strdup(json);
}

char *protocol_serialize_response(const ProtocolResponse *resp) {
  JsonBuffer b;
  json_buf_init(&b);
  json_buf_append(&b, "{\"protocolVersion\":\"" ARABICC_PROTOCOL_VERSION "\",\"success\":");
  json_buf_append(&b, resp->success ? "true" : "false");

  /* diagnostics */
  json_buf_append(&b, ",\"diagnostics\":[");
  for (size_t i = 0; i < resp->diagnostic_count; i++) {
    if (i > 0) json_buf_append_char(&b, ',');
    const ProtocolDiagnostic *d = &resp->diagnostics[i];
    json_buf_append(&b, "{\"severity\":");
    const char *sev_str = "error";
    if (d->severity == SEVERITY_INFO) sev_str = "info";
    else if (d->severity == SEVERITY_WARNING) sev_str = "warning";
    json_buf_append_escaped(&b, sev_str);
    json_buf_append(&b, ",\"phase\":");
    json_buf_append_escaped(&b, d->phase ? d->phase : "compiler");
    json_buf_append(&b, ",\"code\":");
    json_buf_append_escaped(&b, d->code ? d->code : "C001");
    json_buf_append(&b, ",\"message\":");
    json_buf_append_escaped(&b, d->message ? d->message : "");
    json_buf_append(&b, ",\"span\":");
    if (d->has_span) {
      json_buf_append_span(&b, &d->span);
    } else {
      json_buf_append(&b, "null");
    }
    json_buf_append_char(&b, '}');
  }
  json_buf_append_char(&b, ']');

  /* tokens */
  json_buf_append(&b, ",\"tokens\":[");
  for (size_t i = 0; i < resp->token_count; i++) {
    if (i > 0) json_buf_append_char(&b, ',');
    const ProtocolTokenItem *tok = &resp->tokens[i];
    json_buf_append(&b, "{\"kind\":");
    json_buf_append_escaped(&b, tok->kind ? tok->kind : "unknown");
    json_buf_append(&b, ",\"lexeme\":");
    json_buf_append_escaped(&b, tok->lexeme ? tok->lexeme : "");
    json_buf_append(&b, ",\"span\":");
    json_buf_append_span(&b, &tok->span);
    json_buf_append_char(&b, '}');
  }
  json_buf_append_char(&b, ']');

  /* syntaxTree */
  json_buf_append(&b, ",\"syntaxTree\":");
  if (resp->syntax_tree_json && resp->syntax_tree_json[0] != '\0') {
    json_buf_append(&b, resp->syntax_tree_json);
  } else {
    json_buf_append(&b, "null");
  }

  /* symbolTable */
  json_buf_append(&b, ",\"symbolTable\":[");
  for (size_t i = 0; i < resp->symbol_count; i++) {
    if (i > 0) json_buf_append_char(&b, ',');
    const ProtocolSymbol *sym = &resp->symbols[i];
    json_buf_append(&b, "{\"name\":");
    json_buf_append_escaped(&b, sym->name ? sym->name : "");
    json_buf_append(&b, ",\"kind\":");
    json_buf_append_escaped(&b, sym->kind ? sym->kind : "variable");
    json_buf_append(&b, ",\"type\":");
    json_buf_append_escaped(&b, sym->type ? sym->type : "صحيح");
    json_buf_append(&b, ",\"span\":");
    json_buf_append_span(&b, &sym->span);
    json_buf_append_char(&b, '}');
  }
  json_buf_append_char(&b, ']');

  /* threeAddressCode */
  json_buf_append(&b, ",\"threeAddressCode\":[");
  for (size_t i = 0; i < resp->tac_count; i++) {
    if (i > 0) json_buf_append_char(&b, ',');
    json_buf_append_escaped(&b, resp->three_address_code[i]);
  }
  json_buf_append_char(&b, ']');

  /* assembly */
  json_buf_append(&b, ",\"assembly\":");
  json_buf_append_escaped(&b, resp->assembly ? resp->assembly : "");

  /* executionOutput */
  json_buf_append(&b, ",\"executionOutput\":[");
  for (size_t i = 0; i < resp->output_count; i++) {
    if (i > 0) json_buf_append_char(&b, ',');
    json_buf_append_escaped(&b, resp->execution_output[i]);
  }
  json_buf_append_char(&b, ']');

  /* artifacts */
  json_buf_append(&b, ",\"artifacts\":[");
  for (size_t i = 0; i < resp->artifact_count; i++) {
    if (i > 0) json_buf_append_char(&b, ',');
    json_buf_append_escaped(&b, resp->artifacts[i]);
  }
  json_buf_append_char(&b, ']');

  /* intermediateRepresentation */
  json_buf_append(&b, ",\"intermediateRepresentation\":");
  if (resp->intermediate_representation_json && resp->intermediate_representation_json[0] != '\0') {
    json_buf_append(&b, resp->intermediate_representation_json);
  } else {
    json_buf_append(&b, "{}");
  }

  json_buf_append(&b, "}\n");
  return b.data;
}
