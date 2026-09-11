#ifndef ARABICC_PROTOCOL_H
#define ARABICC_PROTOCOL_H

#include <stddef.h>

#define ARABICC_PROTOCOL_VERSION "0.5.0"

typedef enum {
  SEVERITY_INFO,
  SEVERITY_WARNING,
  SEVERITY_ERROR
} DiagnosticSeverity;

typedef struct {
  const char *source_path;
  size_t offset;
  size_t line;
  size_t column;
  size_t length;
} ProtocolSpan;

typedef struct {
  DiagnosticSeverity severity;
  const char *phase;
  const char *code;
  const char *message;
  int has_span;
  ProtocolSpan span;
} ProtocolDiagnostic;

typedef struct {
  const char *kind;
  const char *lexeme;
  ProtocolSpan span;
} ProtocolTokenItem;

typedef struct {
  const char *name;
  const char *kind;
  const char *type;
  ProtocolSpan span;
} ProtocolSymbol;

typedef struct {
  int success;

  ProtocolDiagnostic *diagnostics;
  size_t diagnostic_count;
  size_t diagnostic_capacity;

  ProtocolTokenItem *tokens;
  size_t token_count;
  size_t token_capacity;

  char *syntax_tree_json;

  ProtocolSymbol *symbols;
  size_t symbol_count;
  size_t symbol_capacity;

  char **three_address_code;
  size_t tac_count;
  size_t tac_capacity;

  char *assembly;

  char **execution_output;
  size_t output_count;
  size_t output_capacity;

  char **artifacts;
  size_t artifact_count;
  size_t artifact_capacity;

  char *intermediate_representation_json;
} ProtocolResponse;

void protocol_response_init(ProtocolResponse *resp);
void protocol_response_free(ProtocolResponse *resp);

void protocol_add_diagnostic(ProtocolResponse *resp, DiagnosticSeverity severity, const char *phase, const char *code, const char *message, const ProtocolSpan *span);
void protocol_add_token(ProtocolResponse *resp, const char *kind, const char *lexeme, ProtocolSpan span);
void protocol_add_symbol(ProtocolResponse *resp, const char *name, const char *kind, const char *type, ProtocolSpan span);
void protocol_add_tac(ProtocolResponse *resp, const char *instruction);
void protocol_set_assembly(ProtocolResponse *resp, const char *assembly);
void protocol_add_output(ProtocolResponse *resp, const char *line);
void protocol_add_artifact(ProtocolResponse *resp, const char *artifact);
void protocol_set_syntax_tree_json(ProtocolResponse *resp, const char *json);
void protocol_set_ir_json(ProtocolResponse *resp, const char *json);

char *protocol_serialize_response(const ProtocolResponse *resp);

int c_run_protocol(const char *payload);

#endif
