%{
#include "protocol.h"
#include "ast.h"
#include "semantic.h"
#include "asm_x86_64.h"
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
  CAstNode *node;
  CAstNodeList list;
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

%type <node> program statement var_decl assign_stmt print_stmt expr term factor
%type <list> declaration_list statement_list

%start program

%%

program
  : TOK_PROGRAM TOK_IDENTIFIER '{' declaration_list statement_list '}' '.'
    {
      $$ = c_ast_new_program($2, $4, $5);
      g_root_ast = $$;
    }
  | TOK_PROGRAM TOK_IDENTIFIER '{' statement_list '}' '.'
    {
      CAstNodeList empty_decls;
      empty_decls.items = NULL;
      empty_decls.count = 0;
      $$ = c_ast_new_program($2, empty_decls, $4);
      g_root_ast = $$;
    }
  | error
    {
      g_root_ast = NULL;
      $$ = NULL;
    }
  ;

declaration_list
  : declaration_list var_decl ';'
    {
      $$ = $1;
      c_ast_list_append(&$$, $2);
    }
  | var_decl ';'
    {
      $$.items = NULL;
      $$.count = 0;
      c_ast_list_append(&$$, $1);
    }
  ;

var_decl
  : TOK_VAR TOK_IDENTIFIER ':' TOK_TYPE_INT
    {
      $$ = c_ast_new_var_decl($2, "صحيح");
    }
  ;

statement_list
  : statement_list statement ';'
    {
      $$ = $1;
      c_ast_list_append(&$$, $2);
    }
  | statement ';'
    {
      $$.items = NULL;
      $$.count = 0;
      c_ast_list_append(&$$, $1);
    }
  | /* empty */
    {
      $$.items = NULL;
      $$.count = 0;
    }
  ;

statement
  : assign_stmt { $$ = $1; }
  | print_stmt  { $$ = $1; }
  ;

assign_stmt
  : TOK_IDENTIFIER '=' expr
    {
      $$ = c_ast_new_assignment($1, $3);
    }
  ;

print_stmt
  : TOK_PRINT '(' expr ')'
    {
      $$ = c_ast_new_print($3);
    }
  ;

expr
  : expr '+' term { $$ = c_ast_new_binary($1, "+", $3); }
  | expr '-' term { $$ = c_ast_new_binary($1, "-", $3); }
  | term          { $$ = $1; }
  ;

term
  : term '*' factor { $$ = c_ast_new_binary($1, "*", $3); }
  | term '/' factor { $$ = c_ast_new_binary($1, "/", $3); }
  | factor          { $$ = $1; }
  ;

factor
  : TOK_INTEGER_LITERAL { $$ = c_ast_new_integer($1); }
  | TOK_IDENTIFIER      { $$ = c_ast_new_reference($1); }
  | '(' expr ')'        { $$ = $2; }
  ;

%%

void yyerror(const char *s) {
  fprintf(stderr, "خطأ نحوي عند السطر %d، العمود %d: %s\n", current_line, current_column, s);
  if (g_protocol_response) {
    ProtocolSpan span = {g_current_source_path, 0, (size_t)current_line, (size_t)current_column, 1};
    protocol_add_diagnostic(g_protocol_response, SEVERITY_ERROR, "syntax", "S001", s, &span);
  }
}