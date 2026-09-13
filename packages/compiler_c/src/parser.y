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
static char *parser_strdup(const char *value) {
  size_t length = strlen(value);
  char *copy = malloc(length + 1U);
  if (copy != NULL) memcpy(copy, value, length + 1U);
  return copy;
}
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

%left TOK_OR
%left TOK_AND
%left TOK_EQ TOK_NE TOK_LE TOK_GE '<' '>'
%left '+' '-'
%left '*' '/' '%' '\\'
%right '^'
%right UPLUS UMINUS '!'

%type <node> program statement var_decl assign_stmt print_stmt expr term factor
%type <list> declaration_list statement_list print_arg_list
%type <node> read_stmt call_stmt if_stmt while_stmt repeat_stmt
%type <node> repeat_step block_stmt
%type <list> argument_list

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
  | TOK_PROGRAM TOK_IDENTIFIER ';' '{' declaration_list statement_list '}' '.'
    {
      $$ = c_ast_new_program($2, $5, $6);
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
  | statement
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
  | read_stmt   { $$ = $1; }
  | call_stmt   { $$ = $1; }
  | if_stmt     { $$ = $1; }
  | while_stmt  { $$ = $1; }
  | repeat_stmt { $$ = $1; }
  | block_stmt  { $$ = $1; }
  ;

block_stmt
  : '{' statement_list '}'
    {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_PROGRAM;
      $$->data.program.statements = $2;
    }
  ;

read_stmt
  : TOK_READ '(' TOK_IDENTIFIER ')'
    {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_READ;
      $$->data.access.name = $3;
    }
  ;

call_stmt
  : TOK_IDENTIFIER '(' argument_list ')'
    {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_CALL;
      $$->data.call.name = $1;
      $$->data.call.arguments = $3;
    }
  ;

if_stmt
  : TOK_IF '(' expr ')' TOK_THEN statement
    {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_IF;
      $$->data.conditional.condition = $3;
      c_ast_list_append(&$$->data.conditional.then_branch, $6);
    }
  | TOK_IF '(' expr ')' TOK_THEN statement TOK_ELSE statement
    {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_IF;
      $$->data.conditional.condition = $3;
      c_ast_list_append(&$$->data.conditional.then_branch, $6);
      c_ast_list_append(&$$->data.conditional.else_branch, $8);
    }
  | TOK_IF '(' expr ')' TOK_THEN statement ';' TOK_ELSE statement
    {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_IF;
      $$->data.conditional.condition = $3;
      c_ast_list_append(&$$->data.conditional.then_branch, $6);
      c_ast_list_append(&$$->data.conditional.else_branch, $9);
    }
  ;

while_stmt
  : TOK_WHILE '(' expr ')' TOK_DO statement
    {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_WHILE;
      $$->data.loop.condition = $3;
      c_ast_list_append(&$$->data.loop.body, $6);
    }
  ;

repeat_stmt
  : TOK_REPEAT '(' TOK_IDENTIFIER '=' expr TOK_TO expr repeat_step ')' statement
    {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_REPEAT;
      $$->data.repeat.variable = $3;
      $$->data.repeat.from = $5;
      $$->data.repeat.to = $7;
      $$->data.repeat.step = $8;
      c_ast_list_append(&$$->data.repeat.body, $10);
    }
  ;

repeat_step
  : TOK_STEP expr { $$ = $2; }
  | /* empty */ { $$ = NULL; }
  ;

argument_list
  : argument_list ',' expr { $$ = $1; c_ast_list_append(&$$, $3); }
  | expr { $$.items = NULL; $$.count = 0; c_ast_list_append(&$$, $1); }
  | /* empty */ { $$.items = NULL; $$.count = 0; }
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
  | expr TOK_EQ term { $$ = c_ast_new_binary($1, "==", $3); }
  | expr TOK_NE term { $$ = c_ast_new_binary($1, "!=", $3); }
  | expr TOK_LE term { $$ = c_ast_new_binary($1, "<=", $3); }
  | expr TOK_GE term { $$ = c_ast_new_binary($1, ">=", $3); }
  | expr '<' term { $$ = c_ast_new_binary($1, "<", $3); }
  | expr '>' term { $$ = c_ast_new_binary($1, ">", $3); }
  | expr TOK_AND term { $$ = c_ast_new_binary($1, "&&", $3); }
  | expr TOK_OR term { $$ = c_ast_new_binary($1, "||", $3); }
  | term          { $$ = $1; }
  ;

term
  : term '*' factor { $$ = c_ast_new_binary($1, "*", $3); }
  | term '/' factor { $$ = c_ast_new_binary($1, "/", $3); }
  | term '%' factor { $$ = c_ast_new_binary($1, "%", $3); }
  | term '\\' factor { $$ = c_ast_new_binary($1, "\\", $3); }
  | factor          { $$ = $1; }
  ;

factor
  : TOK_INTEGER_LITERAL { $$ = c_ast_new_integer($1); }
  | TOK_REAL_LITERAL    { $$ = c_ast_new_integer($1); }
  | TOK_STRING_LITERAL  { $$ = c_ast_new_string($1); }
  | TOK_TRUE            { $$ = c_ast_new_integer("1"); }
  | TOK_FALSE           { $$ = c_ast_new_integer("0"); }
  | TOK_IDENTIFIER      { $$ = c_ast_new_reference($1); }
  | '!' factor          { CAstNode *n = calloc(1, sizeof(CAstNode)); n->kind = C_AST_UNARY; n->data.unary.operator = parser_strdup("!"); n->data.unary.operand = $2; $$ = n; }
  | '-' factor          { CAstNode *n = calloc(1, sizeof(CAstNode)); n->kind = C_AST_UNARY; n->data.unary.operator = parser_strdup("-"); n->data.unary.operand = $2; $$ = n; }
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
