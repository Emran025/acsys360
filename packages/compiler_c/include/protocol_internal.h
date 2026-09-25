#ifndef ARABICC_PROTOCOL_INTERNAL_H
#define ARABICC_PROTOCOL_INTERNAL_H

#include "ast.h"
#include "protocol.h"
#include "semantic.h"

typedef struct {
  char *data;
  size_t length;
  size_t capacity;
} JsonBuffer;

void json_buf_init(JsonBuffer *buffer);
void json_buf_append(JsonBuffer *buffer, const char *text);
void json_buf_append_char(JsonBuffer *buffer, char value);
void json_buf_append_escaped(JsonBuffer *buffer, const char *text);
void json_buf_append_span(JsonBuffer *buffer, const ProtocolSpan *span);
char *protocol_strdup(const char *source);
char *protocol_extract_string_value(const char *payload, const char *key);
char *protocol_extract_source_code(const char *payload);
char *protocol_ast_to_json(const CAstNode *root);
char *protocol_generate_typed_ir(const CAstNode *root, const CSemanticResult *semantic);

int protocol_handle_assist(const char *payload);
int protocol_request_executes(const char *payload);
int protocol_request_interactive(const char *payload);

void runtime_begin(const char *input_values_payload, int interactive);
int runtime_had_error(void);
void runtime_end(void);
void runtime_execute_ast(ProtocolResponse *response, const CAstNode *root);

int compiler_driver_run(const char *payload);

#endif
