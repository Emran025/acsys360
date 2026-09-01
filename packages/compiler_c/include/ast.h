#ifndef ARABICC_AST_H
#define ARABICC_AST_H

#include "lexer.h"

#include <stddef.h>

typedef enum {
  C_AST_PROGRAM,
  C_AST_CONSTANT_DECLARATION,
  C_AST_TYPE_DECLARATION,
  C_AST_VARIABLE_DECLARATION,
  C_AST_PROCEDURE_DECLARATION,
  C_AST_ASSIGNMENT,
  C_AST_READ,
  C_AST_CALL,
  C_AST_PRINT,
  C_AST_IF,
  C_AST_WHILE,
  C_AST_REPEAT,
  C_AST_REPEAT_UNTIL,
  C_AST_EMPTY,
  C_AST_LITERAL,
  C_AST_VARIABLE_REFERENCE,
  C_AST_BINARY,
  C_AST_UNARY
} CAstKind;

typedef enum {
  C_TYPE_NAMED,
  C_TYPE_ARRAY,
  C_TYPE_RECORD
} CTypeKind;

typedef struct CTypeSpec CTypeSpec;
typedef struct CAstNode CAstNode;

typedef struct {
  char *name;
  CTypeSpec *type;
  int by_reference;
} CParameter;

typedef struct {
  char *name;
  CTypeSpec *type;
} CField;

typedef struct {
  CField *items;
  size_t count;
} CFieldList;

struct CTypeSpec {
  CTypeKind kind;
  char *name;
  size_t length;
  CTypeSpec *element_type;
  CFieldList fields;
};

typedef struct {
  CAstNode **items;
  size_t count;
} CAstNodeList;

struct CAstNode {
  CAstKind kind;
  size_t offset;
  size_t line;
  size_t column;
  union {
    struct {
      char *name;
      CAstNodeList declarations;
      CAstNodeList statements;
    } program;
    struct {
      char *name;
      CAstNode *value;
    } constant;
    struct {
      char *name;
      CTypeSpec *type;
    } type_declaration;
    struct {
      char **names;
      size_t name_count;
      CTypeSpec *type;
    } variable;
    struct {
      char *name;
      CParameter *parameters;
      size_t parameter_count;
      CAstNodeList body;
    } procedure;
    struct {
      char *name;
      CAstNode *expression;
      CAstNodeList selectors;
    } assignment;
    struct {
      char *name;
      CAstNodeList selectors;
    } access;
    struct {
      char *name;
      CAstNodeList arguments;
    } call;
    struct {
      CAstNodeList values;
    } print;
    struct {
      CAstNode *condition;
      CAstNodeList then_branch;
      CAstNodeList else_branch;
    } conditional;
    struct {
      CAstNode *condition;
      CAstNodeList body;
    } loop;
    struct {
      char *variable;
      CAstNode *from;
      CAstNode *to;
      CAstNode *step;
      CAstNodeList body;
    } repeat;
    struct {
      CAstNodeList body;
      CAstNode *condition;
    } repeat_until;
    struct {
      char *value;
      CTokenKind literal_kind;
    } literal;
    struct {
      char *name;
      CAstNodeList selectors;
    } reference;
    struct {
      CAstNode *left;
      char *operator;
      CAstNode *right;
    } binary;
    struct {
      char *operator;
      CAstNode *operand;
    } unary;
  } data;
};

void c_ast_free(CAstNode *node);
void c_type_free(CTypeSpec *type);

#endif
