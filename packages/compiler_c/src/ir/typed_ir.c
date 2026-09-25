#include "protocol_internal.h"
#include <stdio.h>
#include <stdlib.h>

/* Typed IR Generation for the Typed IR Tab */
char *protocol_generate_typed_ir(const CAstNode *root, const CSemanticResult *semantic) {
  if (!root || root->kind != C_AST_PROGRAM) return NULL;
  JsonBuffer b;
  json_buf_init(&b);
  json_buf_append(&b, "{\"unit\":\"برنامج\",\"name\":");
  json_buf_append_escaped(&b, root->data.program.name ? root->data.program.name : "main");
  json_buf_append(&b, ",\"target\":\"x86_64\",\"types\":[\"صحيح\",\"حقيقي\",\"خيط_رمزي\",\"منطقي\",\"حرفي\"],\"symbols\":[");
  if (semantic) {
    for (size_t i = 0; i < semantic->count; i++) {
      if (i > 0) json_buf_append_char(&b, ',');
      json_buf_append(&b, "{\"name\":");
      json_buf_append_escaped(&b, semantic->items[i].name);
      json_buf_append(&b, ",\"type\":");
      json_buf_append_escaped(&b, semantic->items[i].type);
      json_buf_append(&b, ",\"offset\":");
      char num[32];
      snprintf(num, sizeof(num), "%d", (int)(i * 8 + 8));
      json_buf_append(&b, num);
      json_buf_append_char(&b, '}');
    }
  }
  json_buf_append(&b, "],\"blocks\":[{\"name\":\"main\",\"statementCount\":");
  char num[32];
  snprintf(num, sizeof(num), "%zu", root->data.program.statements.count);
  json_buf_append(&b, num);
  json_buf_append(&b, "}]}");
  return b.data;
}
