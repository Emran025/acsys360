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
extern int current_offset;
extern int current_line;
extern int current_column;
extern const char *g_current_source_text;

extern ProtocolResponse *g_protocol_response;
extern const char *g_current_source_path;

typedef struct { CParameter *items; size_t count; } ParserParameters;
CAstNode *g_root_ast = NULL;
static char *parser_strdup(const char *value) {
  size_t length = strlen(value);
  char *copy = malloc(length + 1U);
  if (copy != NULL) memcpy(copy, value, length + 1U);
  return copy;
}
static CAstNode *parser_literal(char *value, CTokenKind kind) {
  CAstNode *node = calloc(1, sizeof(*node));
  if (node != NULL) {
    node->kind = C_AST_LITERAL;
    node->data.literal.value = value;
    node->data.literal.literal_kind = kind;
  } else {
    free(value);
  }
  return node;
}
static size_t parser_offset_at(int line, int column) {
  const unsigned char *source = (const unsigned char *)g_current_source_text;
  if (source == NULL) return (size_t)yy_token_offset;
  size_t offset = 0U;
  int source_line = 1;
  int source_column = 1;
  while (*source != '\0') {
    if (source_line == line && source_column == column) return offset;
    const unsigned char first = *source;
    size_t bytes = first < 0x80 ? 1U :
        (first & 0xE0) == 0xC0 ? 2U :
        (first & 0xF0) == 0xE0 ? 3U :
        (first & 0xF8) == 0xF0 ? 4U : 1U;
    if (first == '\n') {
      source_line++;
      source_column = 1;
      offset++;
    } else {
      source_column += bytes == 4U ? 2 : 1;
      offset += bytes == 4U ? 2U : 1U;
    }
    size_t available = 1U;
    while (available < bytes && source[available] != '\0' &&
           (source[available] & 0xC0) == 0x80) available++;
    bytes = available;
    source += bytes;
  }
  return offset;
}
static void parser_set_location(CAstNode *node, int first_line,
                                int first_column, int last_line,
                                int last_column) {
  if (node == NULL) return;
  node->line = (size_t)(first_line > 0 ? first_line : 1);
  node->column = (size_t)(first_column > 0 ? first_column : 1);
  node->offset = parser_offset_at(first_line, first_column);
  const size_t end = parser_offset_at(last_line, last_column);
  node->length = end >= node->offset ? end - node->offset : 0U;
}
%}

%union {
  char *str;
  CAstNode *node;
  CAstNodeList list;
  CTypeSpec *type;
  struct { CParameter *items; size_t count; } parameters;
  struct { char **items; size_t count; } names;
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
%type <list> argument_list full_arguments full_declarations full_statements full_fields full_selectors
%type <node> full_program full_block full_declaration full_const full_type_decl full_var full_proc full_statement full_assign full_read full_call full_if full_while full_repeat full_repeat_until full_print full_access full_selector full_expr full_term full_factor
%type <type> full_type
%type <parameters> full_parameters full_parameter_group
%type <names> full_names

%start program
%locations
%define parse.error detailed


%%

full_program
  : TOK_PROGRAM TOK_IDENTIFIER ';' full_declarations full_block '.' {
      $$ = c_ast_new_program($2, $4, $5->data.program.statements);
      free($5);
    }
  ;
full_block
  : '{' full_statements '}' {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_PROGRAM;
      $$->data.program.declarations.items = NULL;
      $$->data.program.declarations.count = 0;
      $$->data.program.statements = $2;
    }
  ;
full_declarations : /* empty */ { $$.items = NULL; $$.count = 0; } | full_declarations full_declaration ';' { $$=$1; c_ast_list_append(&$$,$2); } ;
full_declaration : full_const {$$=$1;} | full_type_decl {$$=$1;} | full_var {$$=$1;} | full_proc {$$=$1;} ;
full_const : TOK_CONST TOK_IDENTIFIER '=' full_expr { $$=calloc(1,sizeof(CAstNode)); $$->kind=C_AST_CONSTANT_DECLARATION; $$->data.constant.name=$2; $$->data.constant.value=$4; parser_set_location($$, @2.first_line, @2.first_column, @2.last_line, @2.last_column); } ;
full_type_decl : TOK_TYPE TOK_IDENTIFIER '=' full_type { $$=calloc(1,sizeof(CAstNode)); $$->kind=C_AST_TYPE_DECLARATION; $$->data.type_declaration.name=$2; $$->data.type_declaration.type=$4; parser_set_location($$, @2.first_line, @2.first_column, @2.last_line, @2.last_column); } ;
full_var : TOK_VAR full_names ':' full_type { $$=calloc(1,sizeof(CAstNode)); $$->kind=C_AST_VARIABLE_DECLARATION; $$->data.variable.names=$2.items; $$->data.variable.name_count=$2.count; $$->data.variable.type=$4; parser_set_location($$, @2.first_line, @2.first_column, @2.last_line, @2.last_column); } ;
full_names : TOK_IDENTIFIER {$$.items=NULL;$$.count=0; char **p=realloc($$.items,sizeof(char*)); $$.items=p; $$.items[$$.count++]=$1;} | full_names ',' TOK_IDENTIFIER {$$=$1; char **p=realloc($$.items,($$.count+1)*sizeof(char*)); $$.items=p; $$.items[$$.count++]=$3;} ;
full_type : TOK_TYPE_INT {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_NAMED;$$->name=parser_strdup("صحيح");} | TOK_TYPE_REAL {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_NAMED;$$->name=parser_strdup("حقيقي");} | TOK_TYPE_BOOL {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_NAMED;$$->name=parser_strdup("منطقي");} | TOK_TYPE_CHAR {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_NAMED;$$->name=parser_strdup("حرفي");} | TOK_TYPE_STRING {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_NAMED;$$->name=parser_strdup("خيط_رمزي");} | TOK_IDENTIFIER {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_NAMED;$$->name=$1;} | TOK_ARRAY '[' TOK_INTEGER_LITERAL ']' TOK_FROM full_type {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_ARRAY;$$->length=strtoul($3,NULL,10);$$->element_type=$6;free($3);} | TOK_ARRAY '[' TOK_IDENTIFIER ']' TOK_FROM full_type {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_ARRAY;$$->length=0;$$->element_type=$6;free($3);} | TOK_RECORD '{' full_fields full_field_end '}' {$$=calloc(1,sizeof(*$$));$$->kind=C_TYPE_RECORD;$$->fields.items=NULL;$$->fields.count=0; for(size_t i=0;i<$3.count;i++){CAstNode *f=$3.items[i]; CField *p=realloc($$->fields.items,($$->fields.count+1)*sizeof(CField));$$->fields.items=p;$$->fields.items[$$->fields.count].name=f->data.variable.names[0];$$->fields.items[$$->fields.count].type=f->data.variable.type;$$->fields.count++;free(f->data.variable.names);free(f);} free($3.items);} ;
full_field_end : ';' | /* empty */ ;
full_fields : TOK_IDENTIFIER ':' full_type {$$.items=NULL;$$.count=0;CAstNode*f=calloc(1,sizeof(CAstNode));f->kind=C_AST_VARIABLE_DECLARATION;f->data.variable.names=malloc(sizeof(char*));f->data.variable.names[0]=$1;f->data.variable.name_count=1;f->data.variable.type=$3;c_ast_list_append(&$$,f);} | full_fields ';' TOK_IDENTIFIER ':' full_type {$$=$1;CAstNode*f=calloc(1,sizeof(CAstNode));f->kind=C_AST_VARIABLE_DECLARATION;f->data.variable.names=malloc(sizeof(char*));f->data.variable.names[0]=$3;f->data.variable.name_count=1;f->data.variable.type=$5;c_ast_list_append(&$$,f);} ;
full_proc : TOK_PROCEDURE TOK_IDENTIFIER '(' full_parameters ')' ';' full_block {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_PROCEDURE_DECLARATION;$$->data.procedure.name=$2;$$->data.procedure.parameters=$4.items;$$->data.procedure.parameter_count=$4.count;$$->data.procedure.body=$7->data.program.statements;parser_set_location($$, @2.first_line, @2.first_column, @2.last_line, @2.last_column);free($7);} | TOK_PROCEDURE TOK_IDENTIFIER '(' ')' ';' full_block {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_PROCEDURE_DECLARATION;$$->data.procedure.name=$2;$$->data.procedure.body=$6->data.program.statements;parser_set_location($$, @2.first_line, @2.first_column, @2.last_line, @2.last_column);free($6);} ;
full_parameters : full_parameter_group {$$=$1;} | full_parameters ';' full_parameter_group {$$=$1;for(size_t i=0;i<$3.count;i++){CParameter*p=realloc($$.items,($$.count+1)*sizeof(CParameter));$$.items=p;$$.items[$$.count++]=$3.items[i];}free($3.items);} ;
full_parameter_group : TOK_BY_VALUE full_names ':' full_type {$$.items=NULL;$$.count=0;for(size_t i=0;i<$2.count;i++){CParameter*p=realloc($$.items,($$.count+1)*sizeof(CParameter));$$.items=p;$$.items[$$.count++]=(CParameter){.name=$2.items[i],.type=$4,.by_reference=0};}free($2.items);} | TOK_BY_REF full_names ':' full_type {$$.items=NULL;$$.count=0;for(size_t i=0;i<$2.count;i++){CParameter*p=realloc($$.items,($$.count+1)*sizeof(CParameter));$$.items=p;$$.items[$$.count++]=(CParameter){.name=$2.items[i],.type=$4,.by_reference=1};}free($2.items);} ;
full_statements : /* empty */ {$$.items=NULL;$$.count=0;} | full_statements full_statement ';' {$$=$1;c_ast_list_append(&$$,$2);} | full_statements full_if {$$=$1;c_ast_list_append(&$$,$2);} | full_statements full_if ';' {$$=$1;c_ast_list_append(&$$,$2);} ;
full_statement : full_assign {$$=$1;} | full_read {$$=$1;} | full_print {$$=$1;} | full_call {$$=$1;} | full_if {$$=$1;} | full_while {$$=$1;} | full_repeat {$$=$1;} | full_repeat_until {$$=$1;} | full_block {$$=$1;} ;
full_selectors : full_selector {$$.items=NULL;$$.count=0;c_ast_list_append(&$$,$1);} | full_selectors full_selector {$$=$1;c_ast_list_append(&$$,$2);} ;
full_selector : '[' full_expr ']' {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_VARIABLE_REFERENCE;$$->data.reference.name=parser_strdup("[]");c_ast_list_append(&$$->data.reference.selectors,$2);} | '.' TOK_IDENTIFIER {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_VARIABLE_REFERENCE;$$->data.reference.name=$2;} ;
full_access : TOK_IDENTIFIER {$$=c_ast_new_reference($1);parser_set_location($$, @1.first_line, @1.first_column, @1.last_line, @1.last_column);} | TOK_IDENTIFIER full_selectors {$$=c_ast_new_reference($1);$$->data.reference.selectors=$2;parser_set_location($$, (@$).first_line, (@$).first_column, (@$).last_line, (@$).last_column);} ;
full_assign : full_access '=' full_expr {$$=c_ast_new_assignment($1->data.reference.name,$3);$$->data.assignment.selectors=$1->data.reference.selectors;if($$)parser_set_location($$, @1.first_line, @1.first_column, @1.last_line, @1.last_column);free($1);} ;
full_read : TOK_READ '(' full_access ')' {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_READ;$$->data.access.name=$3->data.reference.name;$$->data.access.selectors=$3->data.reference.selectors;parser_set_location($$,@3.first_line,@3.first_column,@3.last_line,@3.last_column);free($3);} ;
full_arguments : /* empty */ {$$.items=NULL;$$.count=0;} | full_expr {$$.items=NULL;$$.count=0;c_ast_list_append(&$$,$1);} | full_arguments ',' full_expr {$$=$1;c_ast_list_append(&$$,$3);} ;
full_print : TOK_PRINT '(' full_arguments ')' {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_PRINT;$$->data.print.values=$3;} ;
full_call : TOK_IDENTIFIER '(' full_arguments ')' {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_CALL;$$->data.call.name=$1;$$->data.call.arguments=$3;parser_set_location($$,@1.first_line,@1.first_column,@1.last_line,@1.last_column);} ;
full_if : TOK_IF '(' full_expr ')' TOK_THEN full_statement ';' {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_IF;$$->data.conditional.condition=$3;c_ast_list_append(&$$->data.conditional.then_branch,$6);} | TOK_IF '(' full_expr ')' TOK_THEN full_statement ';' TOK_ELSE full_statement ';' {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_IF;$$->data.conditional.condition=$3;c_ast_list_append(&$$->data.conditional.then_branch,$6);c_ast_list_append(&$$->data.conditional.else_branch,$9);} | TOK_IF '(' full_expr ')' TOK_THEN full_statement ';' TOK_ELSE full_if {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_IF;$$->data.conditional.condition=$3;c_ast_list_append(&$$->data.conditional.then_branch,$6);c_ast_list_append(&$$->data.conditional.else_branch,$9);} | TOK_IF '(' full_expr ')' TOK_THEN full_statement TOK_ELSE full_statement ';' {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_IF;$$->data.conditional.condition=$3;c_ast_list_append(&$$->data.conditional.then_branch,$6);c_ast_list_append(&$$->data.conditional.else_branch,$8);} ;
full_while
  : TOK_WHILE '(' full_expr ')' TOK_DO full_statement {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_WHILE;
      $$->data.loop.condition = $3;
      c_ast_list_append(&$$->data.loop.body, $6);
    }
  | TOK_WHILE '(' full_expr ')' ';' TOK_DO full_statement {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_WHILE;
      $$->data.loop.condition = $3;
      c_ast_list_append(&$$->data.loop.body, $7);
    }
  | TOK_WHILE '(' full_expr ')' ';' '{' TOK_DO full_statements '}' {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_WHILE;
      $$->data.loop.condition = $3;
      $$->data.loop.body = $8;
    }
  ;
full_repeat : TOK_REPEAT '(' TOK_IDENTIFIER '=' full_expr TOK_TO full_expr repeat_step ')' full_statement {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_REPEAT;$$->data.repeat.variable=$3;$$->data.repeat.from=$5;$$->data.repeat.to=$7;$$->data.repeat.step=$8;c_ast_list_append(&$$->data.repeat.body,$10);} ;
full_repeat_until
  : TOK_AGAIN full_statement TOK_UNTIL '(' full_expr ')' {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_REPEAT_UNTIL;
      c_ast_list_append(&$$->data.repeat_until.body, $2);
      $$->data.repeat_until.condition = $5;
    }
  | TOK_AGAIN TOK_UNTIL '(' full_expr ')' {
      $$ = calloc(1, sizeof(CAstNode));
      $$->kind = C_AST_REPEAT_UNTIL;
      $$->data.repeat_until.condition = $4;
    }
  ;
full_expr : full_expr TOK_OR full_term {$$=c_ast_new_binary($1,"||",$3);} | full_expr TOK_AND full_term {$$=c_ast_new_binary($1,"&&",$3);} | full_expr TOK_EQ full_term {$$=c_ast_new_binary($1,"==",$3);} | full_expr TOK_NE full_term {$$=c_ast_new_binary($1,"!=",$3);} | full_expr TOK_LE full_term {$$=c_ast_new_binary($1,"<=",$3);} | full_expr TOK_GE full_term {$$=c_ast_new_binary($1,">=",$3);} | full_expr '<' full_term {$$=c_ast_new_binary($1,"<",$3);} | full_expr '>' full_term {$$=c_ast_new_binary($1,">",$3);} | full_expr '+' full_term {$$=c_ast_new_binary($1,"+",$3);} | full_expr '-' full_term {$$=c_ast_new_binary($1,"-",$3);} | full_term {$$=$1;} ;
full_term : full_term '*' full_factor {$$=c_ast_new_binary($1,"*",$3);} | full_term '/' full_factor {$$=c_ast_new_binary($1,"/",$3);} | full_term '%' full_factor {$$=c_ast_new_binary($1,"%",$3);} | full_term '\\' full_factor {$$=c_ast_new_binary($1,"\\",$3);} | full_term '^' full_factor {$$=c_ast_new_binary($1,"^",$3);} | full_factor {$$=$1;} ;
full_factor : TOK_INTEGER_LITERAL {$$=c_ast_new_integer($1);parser_set_location($$,@1.first_line,@1.first_column,@1.last_line,@1.last_column);} | TOK_REAL_LITERAL {$$=parser_literal($1,C_TOKEN_REAL);parser_set_location($$,@1.first_line,@1.first_column,@1.last_line,@1.last_column);} | TOK_STRING_LITERAL {$$=parser_literal($1,C_TOKEN_STRING);parser_set_location($$,@1.first_line,@1.first_column,@1.last_line,@1.last_column);} | TOK_CHAR_LITERAL {$$=parser_literal($1,C_TOKEN_CHARACTER);parser_set_location($$,@1.first_line,@1.first_column,@1.last_line,@1.last_column);} | TOK_TRUE {$$=parser_literal(parser_strdup("صح"),C_TOKEN_BOOLEAN);parser_set_location($$,@1.first_line,@1.first_column,@1.last_line,@1.last_column);} | TOK_FALSE {$$=parser_literal(parser_strdup("خطأ"),C_TOKEN_BOOLEAN);parser_set_location($$,@1.first_line,@1.first_column,@1.last_line,@1.last_column);} | full_access {$$=$1;} | '!' full_factor {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_UNARY;$$->data.unary.operator=parser_strdup("!");$$->data.unary.operand=$2;parser_set_location($$,(@$).first_line,(@$).first_column,(@$).last_line,(@$).last_column);} | '+' full_factor {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_UNARY;$$->data.unary.operator=parser_strdup("+");$$->data.unary.operand=$2;parser_set_location($$,(@$).first_line,(@$).first_column,(@$).last_line,(@$).last_column);} | '-' full_factor {$$=calloc(1,sizeof(CAstNode));$$->kind=C_AST_UNARY;$$->data.unary.operator=parser_strdup("-");$$->data.unary.operand=$2;parser_set_location($$,(@$).first_line,(@$).first_column,(@$).last_line,(@$).last_column);} | '(' full_expr ')' {$$=$2;} ;

program
  : full_program { $$ = $1; g_root_ast = $$; }
  | error { g_root_ast = NULL; $$ = NULL; }
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
      if ($$) {
        $$->offset = (size_t)yy_token_offset;
        $$->line = (size_t)yy_token_line;
        $$->column = (size_t)yy_token_column;
      }
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
  | TOK_REAL_LITERAL    { $$ = parser_literal($1, C_TOKEN_REAL); }
  | TOK_STRING_LITERAL  { $$ = parser_literal($1, C_TOKEN_STRING); }
  | TOK_TRUE            { $$ = parser_literal(parser_strdup("صح"), C_TOKEN_BOOLEAN); }
  | TOK_FALSE           { $$ = parser_literal(parser_strdup("خطأ"), C_TOKEN_BOOLEAN); }
  | TOK_IDENTIFIER      { $$ = c_ast_new_reference($1); }
  | '!' factor          { CAstNode *n = calloc(1, sizeof(CAstNode)); n->kind = C_AST_UNARY; n->data.unary.operator = parser_strdup("!"); n->data.unary.operand = $2; $$ = n; }
  | '-' factor          { CAstNode *n = calloc(1, sizeof(CAstNode)); n->kind = C_AST_UNARY; n->data.unary.operator = parser_strdup("-"); n->data.unary.operand = $2; $$ = n; }
  | '(' expr ')'        { $$ = $2; }
  ;

%%

static const char *parser_expected_spelling(const char *message) {
  if (strstr(message, "expecting ';'")) return "؛";
  if (strstr(message, "expecting ','")) return "،";
  if (strstr(message, "expecting '{'")) return "{";
  if (strstr(message, "expecting '}'")) return "}";
  if (strstr(message, "expecting '('")) return "(";
  if (strstr(message, "expecting ')'")) return ")";
  if (strstr(message, "expecting '['")) return "[";
  if (strstr(message, "expecting ']'")) return "]";
  if (strstr(message, "expecting '.'")) return ".";
  if (strstr(message, "expecting TOK_IDENTIFIER")) return "اسم";
  if (strstr(message, "expecting TOK_DO")) return "استمر";
  if (strstr(message, "expecting TOK_THEN")) return "فان";
  if (strstr(message, "expecting TOK_UNTIL")) return "حتى";
  return NULL;
}

void yyerror(const char *s) {
  int line = yy_token_line > 0 ? yy_token_line : 1;
  int col = yy_token_column > 0 ? yy_token_column : 1;
  fprintf(stderr, "خطأ نحوي عند السطر %d، العمود %d: %s\n", line, col, s);
  if (g_protocol_response) {
    const int at_end = yychar == YYEOF;
    const size_t offset = at_end && current_offset >= 0
        ? (size_t)current_offset : (size_t)yy_token_offset;
    const size_t len = at_end ? 0U :
        (yy_token_length > 0 ? (size_t)yy_token_length : 1U);
    ProtocolSpan span;
    span.source_path = (g_current_source_path && g_current_source_path[0] != '\0') ? g_current_source_path : NULL;
    span.offset = offset;
    span.line = (size_t)line;
    span.column = (size_t)col;
    span.length = len;

    char msg[256];
    const char *expected = parser_expected_spelling(s);
    if (expected != NULL && at_end) {
      snprintf(msg, sizeof(msg), "متوقع \"%s\" قبل نهاية المصدر", expected);
    } else if (expected != NULL) {
      snprintf(msg, sizeof(msg),
               "متوقع \"%s\" قبل الرمز غير المتوقع «%s»",
               expected, yytext && yytext[0] != '\0' ? yytext : "؟");
    } else if (at_end) {
      snprintf(msg, sizeof(msg), "انتهى المصدر قبل اكتمال التعليمة");
    } else if (yytext && yytext[0] != '\0') {
      snprintf(msg, sizeof(msg), "رمز غير متوقع «%s»", yytext);
    } else {
      snprintf(msg, sizeof(msg), "خطأ نحوي: متوقع تعليمة أو إغلاق القوس");
    }
    protocol_add_diagnostic(g_protocol_response, SEVERITY_ERROR, "syntax", "S001", msg, &span);
  }
}
