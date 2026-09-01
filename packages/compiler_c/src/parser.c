#include "parser.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  const CLexResult *tokens;
  size_t index;
  CParseResult *result;
} Parser;

static char *copy_string(const char *value) {
  const size_t length = strlen(value);
  char *copy = malloc(length + 1U);
  if (copy == NULL) return NULL;
  memcpy(copy, value, length + 1U);
  return copy;
}

static int add_error(Parser *parser, const char *format, ...) {
  if (parser->result->diagnostic_count == parser->result->diagnostic_capacity) {
    const size_t capacity = parser->result->diagnostic_capacity == 0U
        ? 4U
        : parser->result->diagnostic_capacity * 2U;
    char **items = realloc(parser->result->diagnostics,
                           capacity * sizeof(*items));
    if (items == NULL) return 0;
    parser->result->diagnostics = items;
    parser->result->diagnostic_capacity = capacity;
  }
  char buffer[256];
  va_list arguments;
  va_start(arguments, format);
  (void)vsnprintf(buffer, sizeof(buffer), format, arguments);
  va_end(arguments);
  parser->result->diagnostics[parser->result->diagnostic_count] =
      copy_string(buffer);
  if (parser->result->diagnostics[parser->result->diagnostic_count] == NULL) {
    return 0;
  }
  parser->result->diagnostic_count++;
  return 1;
}

static const CToken *current(const Parser *parser) {
  if (parser->index >= parser->tokens->count) {
    return &parser->tokens->items[parser->tokens->count - 1U];
  }
  return &parser->tokens->items[parser->index];
}

static int check(const Parser *parser, const char *lexeme) {
  return strcmp(current(parser)->lexeme, lexeme) == 0;
}

static int match(Parser *parser, const char *lexeme) {
  if (!check(parser, lexeme)) return 0;
  parser->index++;
  return 1;
}

static const CToken *advance_token(Parser *parser) {
  const CToken *token = current(parser);
  if (parser->index + 1U < parser->tokens->count) parser->index++;
  return token;
}

static int expect(Parser *parser, const char *lexeme, const char *description) {
  if (match(parser, lexeme)) return 1;
  const CToken *token = current(parser);
  (void)add_error(parser, "متوقع %s عند السطر %zu والعمود %zu، ووجد %s",
                  description, token->line, token->column, token->lexeme);
  return 0;
}

static CAstNode *new_node(CAstKind kind, const CToken *token) {
  CAstNode *node = calloc(1U, sizeof(*node));
  if (node == NULL) return NULL;
  node->kind = kind;
  node->offset = token->offset;
  node->line = token->line;
  node->column = token->column;
  return node;
}

static int list_push(CAstNodeList *list, CAstNode *node) {
  CAstNode **items = realloc(list->items,
                             (list->count + 1U) * sizeof(*items));
  if (items == NULL) return 0;
  list->items = items;
  list->items[list->count++] = node;
  return 1;
}

static CTypeSpec *named_type(const char *name) {
  CTypeSpec *type = calloc(1U, sizeof(*type));
  if (type == NULL) return NULL;
  type->kind = C_TYPE_NAMED;
  type->name = copy_string(name);
  if (type->name == NULL) {
    free(type);
    return NULL;
  }
  return type;
}

static CAstNode *parse_expression(Parser *parser);

static int parse_selectors(Parser *parser, CAstNodeList *selectors) {
  while (match(parser, "[") || match(parser, ".")) {
    const CToken *marker = &parser->tokens->items[parser->index - 1U];
    if (marker->lexeme[0] == '[') {
      CAstNode *index = parse_expression(parser);
      if (index == NULL || !expect(parser, "]", "القوس ]") ||
          !list_push(selectors, index)) {
        c_ast_free(index);
        return 0;
      }
    } else {
      const CToken *field = current(parser);
      if (field->kind != C_TOKEN_IDENTIFIER) {
        (void)add_error(parser, "متوقع اسم الحقل");
        return 0;
      }
      CAstNode *field_node = new_node(C_AST_VARIABLE_REFERENCE, field);
      if (field_node == NULL) return 0;
      field_node->data.reference.name = copy_string(field->lexeme);
      if (field_node->data.reference.name == NULL || !list_push(selectors, field_node)) {
        c_ast_free(field_node);
        return 0;
      }
      advance_token(parser);
    }
  }
  return 1;
}

static CTypeSpec *parse_type_spec(Parser *parser) {
  const CToken *token = current(parser);
  if (match(parser, "قائمة")) {
    if (!expect(parser, "[", "القوس [")) return NULL;
    const CToken *length = current(parser);
    if (length->kind != C_TOKEN_INTEGER) {
      (void)add_error(parser, "متوقع طول القائمة");
      return NULL;
    }
    const size_t count = (size_t)strtoull(length->lexeme, NULL, 10);
    advance_token(parser);
    if (!expect(parser, "]", "القوس ]") || !expect(parser, "من", "الكلمة من")) {
      return NULL;
    }
    CTypeSpec *type = calloc(1U, sizeof(*type));
    if (type == NULL) return NULL;
    type->kind = C_TYPE_ARRAY;
    type->length = count;
    type->element_type = parse_type_spec(parser);
    if (type->element_type == NULL) {
      c_type_free(type);
      return NULL;
    }
    return type;
  }
  if (match(parser, "سجل")) {
    CTypeSpec *type = calloc(1U, sizeof(*type));
    if (type == NULL) return NULL;
    type->kind = C_TYPE_RECORD;
    if (!expect(parser, "{", "القوس {") ) {
      c_type_free(type);
      return NULL;
    }
    while (!check(parser, "}") && current(parser)->kind != C_TOKEN_EOF) {
      const CToken *field = current(parser);
      if (field->kind != C_TOKEN_IDENTIFIER) {
        (void)add_error(parser, "متوقع اسم حقل");
        c_type_free(type);
        return NULL;
      }
      CField *fields = realloc(type->fields.items,
          (type->fields.count + 1U) * sizeof(*fields));
      if (fields == NULL) {
        c_type_free(type);
        return NULL;
      }
      type->fields.items = fields;
      type->fields.items[type->fields.count].name = copy_string(field->lexeme);
      advance_token(parser);
      if (!expect(parser, ":", "النقطتين :")) {
        c_type_free(type);
        return NULL;
      }
      type->fields.items[type->fields.count].type = parse_type_spec(parser);
      if (type->fields.items[type->fields.count].name == NULL ||
          type->fields.items[type->fields.count].type == NULL) {
        c_type_free(type);
        return NULL;
      }
      type->fields.count++;
      if (!expect(parser, ";", "الفاصلة المنقوطة ;")) {
        c_type_free(type);
        return NULL;
      }
    }
    if (!expect(parser, "}", "القوس }") ) {
      c_type_free(type);
      return NULL;
    }
    return type;
  }
  if (token->kind != C_TOKEN_IDENTIFIER && token->kind != C_TOKEN_KEYWORD) {
    (void)add_error(parser, "متوقع نوع");
    return NULL;
  }
  advance_token(parser);
  return named_type(token->lexeme);
}

static CAstNode *parse_primary(Parser *parser) {
  const CToken *token = current(parser);
  if (token->kind == C_TOKEN_INTEGER || token->kind == C_TOKEN_REAL ||
      token->kind == C_TOKEN_STRING || token->kind == C_TOKEN_CHARACTER ||
      token->kind == C_TOKEN_BOOLEAN) {
    advance_token(parser);
    CAstNode *node = new_node(C_AST_LITERAL, token);
    if (node == NULL) return NULL;
    node->data.literal.value = copy_string(token->lexeme);
    node->data.literal.literal_kind = token->kind;
    if (node->data.literal.value == NULL) {
      c_ast_free(node);
      return NULL;
    }
    return node;
  }
  if (token->kind == C_TOKEN_IDENTIFIER) {
    advance_token(parser);
    CAstNode *node = new_node(C_AST_VARIABLE_REFERENCE, token);
    if (node == NULL) return NULL;
    node->data.reference.name = copy_string(token->lexeme);
    if (node->data.reference.name == NULL ||
        !parse_selectors(parser, &node->data.reference.selectors)) {
      c_ast_free(node);
      return NULL;
    }
    return node;
  }
  if (match(parser, "(")) {
    CAstNode *node = parse_expression(parser);
    (void)expect(parser, ")", "القوس )");
    return node;
  }
  (void)add_error(parser, "القيمة غير صالحة داخل التعبير عند السطر %zu",
                  token->line);
  advance_token(parser);
  return NULL;
}

static CAstNode *parse_unary(Parser *parser) {
  if (check(parser, "!") || check(parser, "-") || check(parser, "+")) {
    const CToken *operator = advance_token(parser);
    CAstNode *node = new_node(C_AST_UNARY, operator);
    if (node == NULL) return NULL;
    node->data.unary.operator = copy_string(operator->lexeme);
    node->data.unary.operand = parse_unary(parser);
    if (node->data.unary.operator == NULL || node->data.unary.operand == NULL) {
      c_ast_free(node);
      return NULL;
    }
    return node;
  }
  return parse_primary(parser);
}

static CAstNode *parse_binary(Parser *parser, int multiplication) {
  CAstNode *left = parse_unary(parser);
  while (check(parser, multiplication ? "*" : "+") ||
         check(parser, multiplication ? "/" : "-") ||
         (multiplication && check(parser, "%"))) {
    const CToken *operator = advance_token(parser);
    CAstNode *right = parse_unary(parser);
    CAstNode *node = new_node(C_AST_BINARY, operator);
    if (node == NULL || right == NULL || left == NULL) {
      c_ast_free(node);
      c_ast_free(left);
      c_ast_free(right);
      return NULL;
    }
    node->data.binary.left = left;
    node->data.binary.operator = copy_string(operator->lexeme);
    node->data.binary.right = right;
    if (node->data.binary.operator == NULL) {
      c_ast_free(node);
      return NULL;
    }
    left = node;
  }
  return left;
}

static CAstNode *parse_additive(Parser *parser) {
  CAstNode *left = parse_binary(parser, 1);
  while (check(parser, "+") || check(parser, "-")) {
    const CToken *operator = advance_token(parser);
    CAstNode *right = parse_binary(parser, 1);
    CAstNode *node = new_node(C_AST_BINARY, operator);
    if (node == NULL || right == NULL || left == NULL) {
      c_ast_free(node);
      c_ast_free(left);
      c_ast_free(right);
      return NULL;
    }
    node->data.binary.left = left;
    node->data.binary.operator = copy_string(operator->lexeme);
    node->data.binary.right = right;
    if (node->data.binary.operator == NULL) {
      c_ast_free(node);
      return NULL;
    }
    left = node;
  }
  return left;
}

static CAstNode *parse_comparison(Parser *parser) {
  CAstNode *left = parse_additive(parser);
  while (check(parser, "==") || check(parser, "!=") || check(parser, "<") ||
         check(parser, "<=") || check(parser, ">") || check(parser, ">=")) {
    const CToken *operator = advance_token(parser);
    CAstNode *right = parse_additive(parser);
    CAstNode *node = new_node(C_AST_BINARY, operator);
    if (node == NULL || left == NULL || right == NULL) {
      c_ast_free(node);
      c_ast_free(left);
      c_ast_free(right);
      return NULL;
    }
    node->data.binary.left = left;
    node->data.binary.operator = copy_string(operator->lexeme);
    node->data.binary.right = right;
    if (node->data.binary.operator == NULL) {
      c_ast_free(node);
      return NULL;
    }
    left = node;
  }
  return left;
}

static CAstNode *parse_expression(Parser *parser) {
  CAstNode *left = parse_comparison(parser);
  while (check(parser, "&&") || check(parser, "||")) {
    const CToken *operator = advance_token(parser);
    CAstNode *right = parse_comparison(parser);
    CAstNode *node = new_node(C_AST_BINARY, operator);
    if (node == NULL || left == NULL || right == NULL) {
      c_ast_free(node);
      c_ast_free(left);
      c_ast_free(right);
      return NULL;
    }
    node->data.binary.left = left;
    node->data.binary.operator = copy_string(operator->lexeme);
    node->data.binary.right = right;
    if (node->data.binary.operator == NULL) {
      c_ast_free(node);
      return NULL;
    }
    left = node;
  }
  return left;
}

static CAstNode *parse_constant(Parser *parser, const CToken *start) {
  const CToken *name = current(parser);
  if (name->kind != C_TOKEN_IDENTIFIER) {
    (void)add_error(parser, "متوقع اسم الثابت");
    return NULL;
  }
  advance_token(parser);
  if (!expect(parser, "=", "علامة الإسناد =")) return NULL;
  CAstNode *node = new_node(C_AST_CONSTANT_DECLARATION, start);
  if (node == NULL) return NULL;
  node->data.constant.name = copy_string(name->lexeme);
  node->data.constant.value = parse_expression(parser);
  if (node->data.constant.name == NULL || node->data.constant.value == NULL ||
      !expect(parser, ";", "الفاصلة المنقوطة ;")) {
    c_ast_free(node);
    return NULL;
  }
  return node;
}

static CAstNode *parse_type_declaration(Parser *parser, const CToken *start) {
  const CToken *name = current(parser);
  if (name->kind != C_TOKEN_IDENTIFIER) {
    (void)add_error(parser, "متوقع اسم النوع");
    return NULL;
  }
  advance_token(parser);
  if (!expect(parser, "=", "علامة الإسناد =")) return NULL;
  CTypeSpec *type = parse_type_spec(parser);
  if (type == NULL || !expect(parser, ";", "الفاصلة المنقوطة ;")) {
    c_type_free(type);
    return NULL;
  }
  CAstNode *node = new_node(C_AST_TYPE_DECLARATION, start);
  if (node == NULL) {
    c_type_free(type);
    return NULL;
  }
  node->data.type_declaration.name = copy_string(name->lexeme);
  node->data.type_declaration.type = type;
  if (node->data.type_declaration.name == NULL) {
    c_ast_free(node);
    return NULL;
  }
  return node;
}

static CAstNode *parse_variable(Parser *parser, const CToken *start) {
  char **names = NULL;
  size_t count = 0U;
  do {
    const CToken *name = current(parser);
    if (name->kind != C_TOKEN_IDENTIFIER) {
      (void)add_error(parser, "متوقع اسم المتغير");
      free(names);
      return NULL;
    }
    char **next = realloc(names, (count + 1U) * sizeof(*next));
    if (next == NULL) {
      free(names);
      return NULL;
    }
    names = next;
    names[count] = copy_string(name->lexeme);
    if (names[count] == NULL) {
      for (size_t index = 0U; index < count; index++) free(names[index]);
      free(names);
      return NULL;
    }
    count++;
    advance_token(parser);
  } while (match(parser, ","));
  if (!expect(parser, ":", "النقطتين :")) goto fail;
  CTypeSpec *type = parse_type_spec(parser);
  if (type == NULL || !expect(parser, ";", "الفاصلة المنقوطة ;")) {
    c_type_free(type);
    goto fail;
  }
  CAstNode *node = new_node(C_AST_VARIABLE_DECLARATION, start);
  if (node == NULL) {
    c_type_free(type);
    goto fail;
  }
  node->data.variable.names = names;
  node->data.variable.name_count = count;
  node->data.variable.type = type;
  if (node->data.variable.type == NULL) {
    c_ast_free(node);
    return NULL;
  }
  return node;
fail:
  for (size_t index = 0U; index < count; index++) free(names[index]);
  free(names);
  return NULL;
}

static CAstNode *parse_statement(Parser *parser);
static CAstNode *parse_variable(Parser *parser, const CToken *start);

static int parse_block(Parser *parser, CAstNodeList *body) {
  if (!expect(parser, "{", "القوس {")) return 0;
  while (!check(parser, "}") && current(parser)->kind != C_TOKEN_EOF) {
    CAstNode *statement = match(parser, "متغير")
        ? parse_variable(parser, current(parser))
        : parse_statement(parser);
    if (statement == NULL || !list_push(body, statement)) {
      c_ast_free(statement);
      return 0;
    }
  }
  return expect(parser, "}", "القوس }");
}

static CAstNode *parse_if_statement(Parser *parser, const CToken *start) {
  CAstNode *node = new_node(C_AST_IF, start);
  if (node == NULL || !expect(parser, "(", "القوس (")) {
    c_ast_free(node);
    return NULL;
  }
  node->data.conditional.condition = parse_expression(parser);
  if (node->data.conditional.condition == NULL ||
      !expect(parser, ")", "القوس )") || !expect(parser, "فان", "الكلمة فان") ||
      !parse_block(parser, &node->data.conditional.then_branch)) {
    c_ast_free(node);
    return NULL;
  }
  if (match(parser, ";")) return node;
  if (match(parser, "والا")) {
    if (match(parser, "اذا")) {
      CAstNode *nested = parse_if_statement(parser, current(parser));
      if (nested == NULL || !list_push(&node->data.conditional.else_branch, nested)) {
        c_ast_free(nested);
        c_ast_free(node);
        return NULL;
      }
    } else if (!parse_block(parser, &node->data.conditional.else_branch)) {
      c_ast_free(node);
      return NULL;
    }
    (void)match(parser, ";");
  }
  return node;
}

static CAstNode *parse_procedure(Parser *parser, const CToken *start) {
  CAstNode *node = new_node(C_AST_PROCEDURE_DECLARATION, start);
  const CToken *name = current(parser);
  if (node == NULL || name->kind != C_TOKEN_IDENTIFIER) {
    c_ast_free(node);
    (void)add_error(parser, "متوقع اسم الإجراء");
    return NULL;
  }
  node->data.procedure.name = copy_string(name->lexeme);
  advance_token(parser);
  if (node->data.procedure.name == NULL || !expect(parser, "(", "القوس (")) {
    c_ast_free(node);
    return NULL;
  }
  while (!check(parser, ")") && current(parser)->kind != C_TOKEN_EOF) {
    int by_reference = 0;
    if (match(parser, "بالمرجع")) by_reference = 1;
    else if (!match(parser, "بالقيمة")) {
      (void)add_error(parser, "متوقع بالقيمة أو بالمرجع");
      c_ast_free(node);
      return NULL;
    }
    const CToken *parameter = current(parser);
    if (parameter->kind != C_TOKEN_IDENTIFIER) {
      (void)add_error(parser, "متوقع اسم المعامل");
      c_ast_free(node);
      return NULL;
    }
    CParameter *items = realloc(node->data.procedure.parameters,
        (node->data.procedure.parameter_count + 1U) * sizeof(*items));
    if (items == NULL) {
      c_ast_free(node);
      return NULL;
    }
    node->data.procedure.parameters = items;
    CParameter *item = &items[node->data.procedure.parameter_count];
    item->name = copy_string(parameter->lexeme);
    item->by_reference = by_reference;
    advance_token(parser);
    if (!expect(parser, ":", "النقطتين :")) {
      c_ast_free(node);
      return NULL;
    }
    item->type = parse_type_spec(parser);
    if (item->name == NULL || item->type == NULL) {
      c_ast_free(node);
      return NULL;
    }
    node->data.procedure.parameter_count++;
    if (!match(parser, ";") && !match(parser, ",") && !check(parser, ")")) {
      (void)add_error(parser, "متوقع فاصل المعاملات");
      c_ast_free(node);
      return NULL;
    }
  }
  if (!expect(parser, ")", "القوس )") || !expect(parser, ";", "الفاصلة المنقوطة ;") ||
      !parse_block(parser, &node->data.procedure.body)) {
    c_ast_free(node);
    return NULL;
  }
  (void)match(parser, ";");
  return node;
}

static CAstNode *parse_call_statement(Parser *parser, const CToken *start) {
  CAstNode *node = new_node(C_AST_CALL, start);
  if (node == NULL) return NULL;
  node->data.call.name = copy_string(start->lexeme);
  if (node->data.call.name == NULL || !expect(parser, "(", "القوس (")) {
    c_ast_free(node);
    return NULL;
  }
  if (!check(parser, ")")) {
    do {
      CAstNode *argument = parse_expression(parser);
      if (argument == NULL || !list_push(&node->data.call.arguments, argument)) {
        c_ast_free(argument);
        c_ast_free(node);
        return NULL;
      }
    } while (match(parser, ","));
  }
  if (!expect(parser, ")", "القوس )") || !expect(parser, ";", "الفاصلة المنقوطة ;")) {
    c_ast_free(node);
    return NULL;
  }
  return node;
}

static CAstNode *parse_repeat_statement(Parser *parser, const CToken *start) {
  CAstNode *node = new_node(C_AST_REPEAT, start);
  if (node == NULL || !expect(parser, "(", "القوس (")) {
    c_ast_free(node);
    return NULL;
  }
  const CToken *variable = current(parser);
  if (variable->kind != C_TOKEN_IDENTIFIER) {
    (void)add_error(parser, "متوقع متغير التكرار");
    c_ast_free(node);
    return NULL;
  }
  node->data.repeat.variable = copy_string(variable->lexeme);
  advance_token(parser);
  if (node->data.repeat.variable == NULL || !expect(parser, "=", "علامة =")) {
    c_ast_free(node);
    return NULL;
  }
  node->data.repeat.from = parse_expression(parser);
  if (node->data.repeat.from == NULL || !expect(parser, "الى", "الكلمة الى")) {
    c_ast_free(node);
    return NULL;
  }
  node->data.repeat.to = parse_expression(parser);
  if (node->data.repeat.to == NULL) {
    c_ast_free(node);
    return NULL;
  }
  if (match(parser, "اضف")) {
    node->data.repeat.step = parse_expression(parser);
    if (node->data.repeat.step == NULL) {
      c_ast_free(node);
      return NULL;
    }
  }
  if (!expect(parser, ")", "القوس )") ||
      !parse_block(parser, &node->data.repeat.body)) {
    c_ast_free(node);
    return NULL;
  }
  (void)match(parser, ";");
  return node;
}

static CAstNode *parse_while_statement(Parser *parser, const CToken *start) {
  CAstNode *node = new_node(C_AST_WHILE, start);
  if (node == NULL || !expect(parser, "(", "القوس (")) {
    c_ast_free(node);
    return NULL;
  }
  node->data.loop.condition = parse_expression(parser);
  if (node->data.loop.condition == NULL || !expect(parser, ")", "القوس )")) {
    c_ast_free(node);
    return NULL;
  }
  (void)match(parser, "استمر");
  if (!parse_block(parser, &node->data.loop.body)) {
    c_ast_free(node);
    return NULL;
  }
  (void)match(parser, ";");
  return node;
}

static CAstNode *parse_statement(Parser *parser) {
  const CToken *start = current(parser);
  CAstNode *node = NULL;
  if (match(parser, ";")) return new_node(C_AST_EMPTY, start);
  if (match(parser, "اذا")) {
    return parse_if_statement(parser, start);
  }
  if (match(parser, "طالما")) {
    return parse_while_statement(parser, start);
  }
  if (match(parser, "كرر")) {
    return parse_repeat_statement(parser, start);
  }
  if (match(parser, "اطبع")) {
    node = new_node(C_AST_PRINT, start);
    if (node == NULL) return NULL;
    if (!expect(parser, "(", "القوس (")) goto fail;
    if (!check(parser, ")")) {
      do {
        CAstNode *value = parse_expression(parser);
        if (value == NULL || !list_push(&node->data.print.values, value)) {
          c_ast_free(value);
          goto fail;
        }
      } while (match(parser, ","));
    }
    if (!expect(parser, ")", "القوس )") ||
        !expect(parser, ";", "الفاصلة المنقوطة ;")) goto fail;
    return node;
  }
  if (start->kind == C_TOKEN_IDENTIFIER) {
    if (current(parser)->kind == C_TOKEN_IDENTIFIER) {
      const CToken *next = current(parser);
      (void)next;
    }
    advance_token(parser);
    if (match(parser, "(")) {
      parser->index--;
      return parse_call_statement(parser, start);
    }
    CAstNodeList selectors = {0};
    if (!parse_selectors(parser, &selectors) ||
        !expect(parser, "=", "علامة الإسناد =")) {
      for (size_t index = 0U; index < selectors.count; index++) {
        c_ast_free(selectors.items[index]);
      }
      free(selectors.items);
      return NULL;
    }
    node = new_node(C_AST_ASSIGNMENT, start);
    if (node == NULL) {
      for (size_t index = 0U; index < selectors.count; index++) {
        c_ast_free(selectors.items[index]);
      }
      free(selectors.items);
      return NULL;
    }
    node->data.assignment.name = copy_string(start->lexeme);
    node->data.assignment.selectors = selectors;
    node->data.assignment.expression = parse_expression(parser);
    if (node->data.assignment.name == NULL ||
        node->data.assignment.expression == NULL ||
        !expect(parser, ";", "الفاصلة المنقوطة ;")) {
      c_ast_free(node);
      return NULL;
    }
    return node;
  }
  (void)add_error(parser, "تعليمة غير متوقعة: %s", start->lexeme);
  advance_token(parser);
  return NULL;
fail:
  c_ast_free(node);
  return NULL;
}

int c_parse(const CLexResult *tokens, CParseResult *result) {
  if (tokens == NULL || result == NULL || tokens->count == 0U) return 0;
  memset(result, 0, sizeof(*result));
  Parser parser = {.tokens = tokens, .result = result};
  const CToken *start = current(&parser);
  if (!expect(&parser, "برنامج", "الكلمة برنامج")) return 1;
  const CToken *name = current(&parser);
  if (name->kind != C_TOKEN_IDENTIFIER) {
    (void)add_error(&parser, "متوقع اسم البرنامج");
    return 1;
  }
  advance_token(&parser);
  (void)match(&parser, ";");
  if (!expect(&parser, "{", "القوس {") ) return 1;
  CAstNode *program = new_node(C_AST_PROGRAM, start);
  if (program == NULL) return 0;
  program->data.program.name = copy_string(name->lexeme);
  if (program->data.program.name == NULL) {
    c_ast_free(program);
    return 0;
  }
  while (!check(&parser, "}") && current(&parser)->kind != C_TOKEN_EOF) {
    CAstNode *node;
    if (match(&parser, "متغير")) {
      node = parse_variable(&parser, start);
    } else if (match(&parser, "ثابت")) {
      node = parse_constant(&parser, start);
    } else if (match(&parser, "نوع")) {
      node = parse_type_declaration(&parser, start);
    } else if (match(&parser, "اجراء")) {
      node = parse_procedure(&parser, start);
    } else {
      node = parse_statement(&parser);
    }
    if (node == NULL || !list_push(
        (node != NULL && (node->kind == C_AST_VARIABLE_DECLARATION ||
                          node->kind == C_AST_CONSTANT_DECLARATION ||
                          node->kind == C_AST_TYPE_DECLARATION))
            ? &program->data.program.declarations
            : &program->data.program.statements,
        node)) {
      c_ast_free(node);
      break;
    }
  }
  if (!expect(&parser, "}", "القوس }") || !expect(&parser, ".", "النقطة .")) {
    c_ast_free(program);
    return 1;
  }
  result->program = program;
  return 1;
}

void c_parse_result_free(CParseResult *result) {
  if (result == NULL) return;
  c_ast_free(result->program);
  for (size_t index = 0U; index < result->diagnostic_count; index++) {
    free(result->diagnostics[index]);
  }
  free(result->diagnostics);
  memset(result, 0, sizeof(*result));
}
