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

extern int yy_token_offset;
extern int yy_token_line;
extern int yy_token_column;
extern int yy_token_length;
extern char *yytext;

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
%type <list> declaration_list statement_list print_arg_list

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
      if ($$) { $$->offset = (size_t)yy_token_offset; $$->line = (size_t)yy_token_line; $$->column = (size_t)yy_token_column; }
    }
  | TOK_VAR TOK_IDENTIFIER ':' TOK_TYPE_REAL
    {
      $$ = c_ast_new_var_decl($2, "حقيقي");
      if ($$) { $$->offset = (size_t)yy_token_offset; $$->line = (size_t)yy_token_line; $$->column = (size_t)yy_token_column; }
    }
  | TOK_VAR TOK_IDENTIFIER ':' TOK_TYPE_STRING
    {
      $$ = c_ast_new_var_decl($2, "خيط_رمزي");
      if ($$) { $$->offset = (size_t)yy_token_offset; $$->line = (size_t)yy_token_line; $$->column = (size_t)yy_token_column; }
    }
  | TOK_VAR TOK_IDENTIFIER ':' TOK_TYPE_BOOL
    {
      $$ = c_ast_new_var_decl($2, "منطقي");
      if ($$) { $$->offset = (size_t)yy_token_offset; $$->line = (size_t)yy_token_line; $$->column = (size_t)yy_token_column; }
    }
  | TOK_VAR TOK_IDENTIFIER ':' TOK_TYPE_CHAR
    {
      $$ = c_ast_new_var_decl($2, "حرفي");
      if ($$) { $$->offset = (size_t)yy_token_offset; $$->line = (size_t)yy_token_line; $$->column = (size_t)yy_token_column; }
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

print_arg_list
  : print_arg_list ',' expr
    {
      $$ = $1;
      c_ast_list_append(&$$, $3);
    }
  | expr
    {
      $$.items = NULL;
      $$.count = 0;
      c_ast_list_append(&$$, $1);
    }
  ;

print_stmt
  : TOK_PRINT '(' print_arg_list ')'
    {
      CAstNode *node = calloc(1, sizeof(CAstNode));
      node->kind = C_AST_PRINT;
      node->data.print.values = $3;
      $$ = node;
    }
  | TOK_PRINT '(' ')'
    {
      CAstNode *node = calloc(1, sizeof(CAstNode));
      node->kind = C_AST_PRINT;
      node->data.print.values.items = NULL;
      node->data.print.values.count = 0;
      $$ = node;
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
  | TOK_REAL_LITERAL    { $$ = c_ast_new_integer($1); }
  | TOK_STRING_LITERAL  { $$ = c_ast_new_string($1); }
  | TOK_TRUE            { $$ = c_ast_new_integer("1"); }
  | TOK_FALSE           { $$ = c_ast_new_integer("0"); }
  | TOK_IDENTIFIER      { $$ = c_ast_new_reference($1); }
  | '(' expr ')'        { $$ = $2; }
  ;

%%

void yyerror(const char *s) {
  int line = yy_token_line > 0 ? yy_token_line : 1;
  int col = yy_token_column > 0 ? yy_token_column : 1;
  fprintf(stderr, "خطأ نحوي عند السطر %d، العمود %d: %s\n", line, col, s);
  if (g_protocol_response) {
    size_t len = yy_token_length > 0 ? (size_t)yy_token_length : 1;
    ProtocolSpan span;
    span.source_path = (g_current_source_path && g_current_source_path[0] != '\0') ? g_current_source_path : NULL;
    span.offset = (size_t)yy_token_offset;
    span.line = (size_t)line;
    span.column = (size_t)col;
    span.length = len;

    char msg[256];
    if (yytext && yytext[0] != '\0') {
      snprintf(msg, sizeof(msg), "رمز غير متوقع «%s»", yytext);
    } else {
      snprintf(msg, sizeof(msg), "خطأ نحوي: متوقع تعليمة أو إغلاق القوس");
    }
    protocol_add_diagnostic(g_protocol_response, SEVERITY_ERROR, "syntax", "S001", msg, &span);
  }
}