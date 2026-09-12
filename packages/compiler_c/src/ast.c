#include "ast.h"

#include <stdlib.h>
#include <string.h>

static void free_list(CAstNodeList *list) {
  if (list == NULL) return;
  for (size_t index = 0U; index < list->count; index++) {
    c_ast_free(list->items[index]);
  }
  free(list->items);
  list->items = NULL;
  list->count = 0U;
}

void c_type_free(CTypeSpec *type) {
  if (type == NULL) return;
  free(type->name);
  c_type_free(type->element_type);
  for (size_t index = 0U; index < type->fields.count; index++) {
    free(type->fields.items[index].name);
    c_type_free(type->fields.items[index].type);
  }
  free(type->fields.items);
  free(type);
}

void c_ast_free(CAstNode *node) {
  if (node == NULL) return;
  switch (node->kind) {
    case C_AST_PROGRAM:
      free(node->data.program.name);
      free_list(&node->data.program.declarations);
      free_list(&node->data.program.statements);
      break;
    case C_AST_CONSTANT_DECLARATION:
      free(node->data.constant.name);
      c_ast_free(node->data.constant.value);
      break;
    case C_AST_TYPE_DECLARATION:
      free(node->data.type_declaration.name);
      c_type_free(node->data.type_declaration.type);
      break;
    case C_AST_VARIABLE_DECLARATION:
      for (size_t index = 0U; index < node->data.variable.name_count; index++) {
        free(node->data.variable.names[index]);
      }
      free(node->data.variable.names);
      c_type_free(node->data.variable.type);
      break;
    case C_AST_PROCEDURE_DECLARATION:
      free(node->data.procedure.name);
      for (size_t index = 0U; index < node->data.procedure.parameter_count; index++) {
        free(node->data.procedure.parameters[index].name);
        c_type_free(node->data.procedure.parameters[index].type);
      }
      free(node->data.procedure.parameters);
      free_list(&node->data.procedure.body);
      break;
    case C_AST_ASSIGNMENT:
      free(node->data.assignment.name);
      c_ast_free(node->data.assignment.expression);
      free_list(&node->data.assignment.selectors);
      break;
    case C_AST_READ:
      free(node->data.access.name);
      free_list(&node->data.access.selectors);
      break;
    case C_AST_CALL:
      free(node->data.call.name);
      free_list(&node->data.call.arguments);
      break;
    case C_AST_PRINT:
      free_list(&node->data.print.values);
      break;
    case C_AST_IF:
      c_ast_free(node->data.conditional.condition);
      free_list(&node->data.conditional.then_branch);
      free_list(&node->data.conditional.else_branch);
      break;
    case C_AST_WHILE:
      c_ast_free(node->data.loop.condition);
      free_list(&node->data.loop.body);
      break;
    case C_AST_REPEAT:
      free(node->data.repeat.variable);
      c_ast_free(node->data.repeat.from);
      c_ast_free(node->data.repeat.to);
      c_ast_free(node->data.repeat.step);
      free_list(&node->data.repeat.body);
      break;
    case C_AST_REPEAT_UNTIL:
      free_list(&node->data.repeat_until.body);
      c_ast_free(node->data.repeat_until.condition);
      break;
    case C_AST_EMPTY:
      break;
    case C_AST_LITERAL:
      free(node->data.literal.value);
      break;
    case C_AST_VARIABLE_REFERENCE:
      free(node->data.reference.name);
      free_list(&node->data.reference.selectors);
      break;
    case C_AST_BINARY:
      c_ast_free(node->data.binary.left);
      free(node->data.binary.operator);
      c_ast_free(node->data.binary.right);
      break;
    case C_AST_UNARY:
      free(node->data.unary.operator);
      c_ast_free(node->data.unary.operand);
      break;
  }
  free(node);
}

static char *c_copy_str(const char *src) {
  if (!src) return NULL;
  size_t len = strlen(src);
  char *d = malloc(len + 1);
  if (d) memcpy(d, src, len + 1);
  return d;
}

void c_ast_list_append(CAstNodeList *list, CAstNode *node) {
  if (!list || !node) return;
  CAstNode **new_items = realloc(list->items, (list->count + 1) * sizeof(CAstNode *));
  if (!new_items) return;
  list->items = new_items;
  list->items[list->count++] = node;
}

CAstNode *c_ast_new_program(char *name, CAstNodeList decls, CAstNodeList stmts) {
  CAstNode *node = calloc(1, sizeof(CAstNode));
  if (!node) return NULL;
  node->kind = C_AST_PROGRAM;
  node->data.program.name = name;
  node->data.program.declarations = decls;
  node->data.program.statements = stmts;
  return node;
}

CAstNode *c_ast_new_var_decl(char *name, const char *type_name) {
  CAstNode *node = calloc(1, sizeof(CAstNode));
  if (!node) return NULL;
  node->kind = C_AST_VARIABLE_DECLARATION;
  node->data.variable.names = malloc(sizeof(char *));
  if (node->data.variable.names) {
    node->data.variable.names[0] = name;
    node->data.variable.name_count = 1;
  }
  node->data.variable.type = calloc(1, sizeof(CTypeSpec));
  if (node->data.variable.type) {
    node->data.variable.type->kind = C_TYPE_NAMED;
    node->data.variable.type->name = c_copy_str(type_name);
  }
  return node;
}

CAstNode *c_ast_new_assignment(char *name, CAstNode *expr) {
  CAstNode *node = calloc(1, sizeof(CAstNode));
  if (!node) return NULL;
  node->kind = C_AST_ASSIGNMENT;
  node->data.assignment.name = name;
  node->data.assignment.expression = expr;
  return node;
}

CAstNode *c_ast_new_print(CAstNode *expr) {
  CAstNode *node = calloc(1, sizeof(CAstNode));
  if (!node) return NULL;
  node->kind = C_AST_PRINT;
  c_ast_list_append(&node->data.print.values, expr);
  return node;
}

CAstNode *c_ast_new_binary(CAstNode *left, const char *op, CAstNode *right) {
  CAstNode *node = calloc(1, sizeof(CAstNode));
  if (!node) return NULL;
  node->kind = C_AST_BINARY;
  node->data.binary.left = left;
  node->data.binary.operator = c_copy_str(op);
  node->data.binary.right = right;
  return node;
}

CAstNode *c_ast_new_integer(const char *value) {
  CAstNode *node = calloc(1, sizeof(CAstNode));
  if (!node) return NULL;
  node->kind = C_AST_LITERAL;
  node->data.literal.value = c_copy_str(value);
  node->data.literal.literal_kind = C_TOKEN_INTEGER;
  return node;
}

CAstNode *c_ast_new_string(char *value) {
  CAstNode *node = calloc(1, sizeof(CAstNode));
  if (!node) return NULL;
  node->kind = C_AST_LITERAL;
  node->data.literal.value = value; /* takes ownership (already strdup'd by lexer) */
  node->data.literal.literal_kind = C_TOKEN_STRING;
  return node;
}

CAstNode *c_ast_new_reference(char *name) {
  CAstNode *node = calloc(1, sizeof(CAstNode));
  if (!node) return NULL;
  node->kind = C_AST_VARIABLE_REFERENCE;
  node->data.reference.name = name;
  return node;
}
