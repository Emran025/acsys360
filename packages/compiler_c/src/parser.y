%{
#include "protocol.h"
#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex(void);
extern int yyparse(void);
extern void yyerror(const char *s);
extern int current_line;
extern int current_column;

extern ProtocolResponse *g_protocol_response;
extern const char *g_current_source_path;

CAstNode *g_root_ast = NULL;
%}

%union {
  char *str;
  int int_val;
  double real_val;
  CAstNode *node;
  CTypeSpec *type;
}

%token <str> TOK_IDENTIFIER
%token <str> TOK_STRING_LITERAL
%token <str> TOK_CHAR_LITERAL
%token <str> TOK_INTEGER_LITERAL
%token <str> TOK_REAL_LITERAL

%token TOK_PROGRAM TOK_CONST TOK_TYPE TOK_VAR TOK_PROCEDURE
%token TOK_BY_VALUE TOK_BY_REF TOK_PRINT TOK_READ
%token TOK_IF TOK_THEN TOK_ELSE TOK_REPEAT TOK_WHILE TOK_DO TOK_AGAIN
%token TOK_FROM TOK_TO TOK_STEP TOK_UNTIL
%token TOK_TYPE_INT TOK_TYPE_REAL TOK_TYPE_BOOL TOK_TYPE_CHAR TOK_TYPE_STRING
%token TOK_ARRAY TOK_RECORD
%token TOK_TRUE TOK_FALSE

%token TOK_EQ TOK_NE TOK_LE TOK_GE TOK_AND TOK_OR
%token TOK_ASSIGN

%start program

%%

program
  : TOK_PROGRAM TOK_IDENTIFIER block '.'
    {
      g_root_ast = NULL;
    }
  | error
    {
      g_root_ast = NULL;
    }
  ;

block
  : '{' declaration_list statement_list '}'
  | '{' statement_list '}'
  ;

declaration_list
  : declaration_list declaration
  | /* empty */
  ;

declaration
  : var_decl ';'
  ;

var_decl
  : TOK_VAR TOK_IDENTIFIER ':' TOK_TYPE_INT
    {
      if (g_protocol_response) {
        ProtocolSpan span = {g_current_source_path, 0, (size_t)current_line, (size_t)current_column, 0};
        protocol_add_symbol(g_protocol_response, $2, "variable", "صحيح", span);
      }
    }
  ;

statement_list
  : statement_list statement
  | /* empty */
  ;

statement
  : print_stmt ';'
  | assign_stmt ';'
  | ';'
  ;

print_stmt
  : TOK_PRINT '(' TOK_IDENTIFIER ')'
  | TOK_PRINT '(' TOK_STRING_LITERAL ')'
  ;

assign_stmt
  : TOK_IDENTIFIER '=' TOK_INTEGER_LITERAL
  ;

%%

void yyerror(const char *s) {
  if (g_protocol_response) {
    ProtocolSpan span = {g_current_source_path, 0, (size_t)current_line, (size_t)current_column, 1};
    protocol_add_diagnostic(g_protocol_response, SEVERITY_ERROR, "syntax", "S001", s, &span);
  }
}