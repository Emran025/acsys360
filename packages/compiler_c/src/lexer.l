%{
#include "protocol.h"
#include "ast.h"
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int current_line = 1;
int current_column = 1;
int current_offset = 0;

int yy_token_offset = 0;
int yy_token_line = 1;
int yy_token_column = 1;
int yy_token_length = 0;

ProtocolResponse *g_protocol_response = NULL;
extern const char *g_current_source_path;

static char *duplicate_string(const char *source) {
  size_t length = strlen(source);
  char *copy = malloc(length + 1U);
  if (copy != NULL) {
    memcpy(copy, source, length + 1U);
  }
  return copy;
}

static size_t utf8_char_count(const char *s, size_t byte_len) {
  size_t chars = 0;
  for (size_t i = 0; i < byte_len; i++) {
    if (((unsigned char)s[i] & 0xC0) != 0x80) {
      chars++;
    }
  }
  return chars;
}

static void emit_token(const char *kind, const char *lexeme) {
  if (g_protocol_response) {
    ProtocolSpan span;
    span.source_path = (g_current_source_path && g_current_source_path[0] != '\0') ? g_current_source_path : NULL;
    span.offset = (size_t)yy_token_offset;
    span.line = (size_t)yy_token_line;
    span.column = (size_t)yy_token_column;
    span.length = (size_t)yy_token_length;
    protocol_add_token(g_protocol_response, kind, lexeme, span);
  }
}

#define YY_USER_ACTION \
  yy_token_offset = current_offset; \
  yy_token_line = current_line; \
  yy_token_column = current_column; \
  yy_token_length = (int)utf8_char_count(yytext, (size_t)yyleng); \
  current_column += yy_token_length; \
  current_offset += yy_token_length;
%}

%option noyywrap
%option yylineno
%option nounput
%option noinput

ARABIC_CHAR   (\xD8[\x80-\x8B\x8D-\x9A\x9C-\xBF]|\xD9[\x80-\xBF]|\xDA[\x80-\xBF]|\xDB[\x80-\xBF])
ID            ({ARABIC_CHAR}|[a-zA-Z_])({ARABIC_CHAR}|[a-zA-Z0-9_])*
DIGIT         [0-9]

%%

[ \t\r]+      { /* ignore whitespace */ }
\n            { current_line++; current_column = 1; }

"//"[^\n]*    { emit_token("comment", yytext); }

"برنامج"       { emit_token("keyword", yytext); return TOK_PROGRAM; }
"ثابت"         { emit_token("keyword", yytext); return TOK_CONST; }
"نوع"          { emit_token("keyword", yytext); return TOK_TYPE; }
"متغير"        { emit_token("keyword", yytext); return TOK_VAR; }
"اجراء"        { emit_token("keyword", yytext); return TOK_PROCEDURE; }
"بالقيمة"      { emit_token("keyword", yytext); return TOK_BY_VALUE; }
"بالمرجع"      { emit_token("keyword", yytext); return TOK_BY_REF; }
"اطبع"         { emit_token("keyword", yytext); return TOK_PRINT; }
"اقرا"         { emit_token("keyword", yytext); return TOK_READ; }
"اذا"          { emit_token("keyword", yytext); return TOK_IF; }
"فان"          { emit_token("keyword", yytext); return TOK_THEN; }
"والا"         { emit_token("keyword", yytext); return TOK_ELSE; }
"كرر"          { emit_token("keyword", yytext); return TOK_REPEAT; }
"طالما"        { emit_token("keyword", yytext); return TOK_WHILE; }
"استمر"        { emit_token("keyword", yytext); return TOK_DO; }
"اعد"          { emit_token("keyword", yytext); return TOK_AGAIN; }
"من"           { emit_token("keyword", yytext); return TOK_FROM; }
"الى"          { emit_token("keyword", yytext); return TOK_TO; }
"اضف"          { emit_token("keyword", yytext); return TOK_STEP; }
"حتى"          { emit_token("keyword", yytext); return TOK_UNTIL; }
"صحيح"         { emit_token("keyword", yytext); return TOK_TYPE_INT; }
"حقيقي"        { emit_token("keyword", yytext); return TOK_TYPE_REAL; }
"منطقي"        { emit_token("keyword", yytext); return TOK_TYPE_BOOL; }
"حرفي"         { emit_token("keyword", yytext); return TOK_TYPE_CHAR; }
"خيط_رمزي"     { emit_token("keyword", yytext); return TOK_TYPE_STRING; }
"قائمة"        { emit_token("keyword", yytext); return TOK_ARRAY; }
"سجل"          { emit_token("keyword", yytext); return TOK_RECORD; }
"صح"           { emit_token("boolean", yytext); return TOK_TRUE; }
"خطأ"          { emit_token("boolean", yytext); return TOK_FALSE; }

"؛"           { emit_token("punctuation", ";"); return ';'; }
"،"           { emit_token("punctuation", ","); return ','; }

"=="          { emit_token("operator", yytext); return TOK_EQ; }
"!="          { emit_token("operator", yytext); return TOK_NE; }
"<="          { emit_token("operator", yytext); return TOK_LE; }
"=<"          { emit_token("operator", yytext); return TOK_LE; }
">="          { emit_token("operator", yytext); return TOK_GE; }
"=>"          { emit_token("operator", yytext); return TOK_GE; }
"&&"          { emit_token("operator", yytext); return TOK_AND; }
"||"          { emit_token("operator", yytext); return TOK_OR; }

{DIGIT}+      {
  emit_token("integer", yytext);
  yylval.str = duplicate_string(yytext);
  return TOK_INTEGER_LITERAL;
}

{DIGIT}+\.{DIGIT}+ {
  emit_token("real", yytext);
  yylval.str = duplicate_string(yytext);
  return TOK_REAL_LITERAL;
}

\"([^\"\\]|\\.)*\" {
  emit_token("string", yytext);
  yylval.str = duplicate_string(yytext);
  return TOK_STRING_LITERAL;
}

{ID}          {
  emit_token("identifier", yytext);
  yylval.str = duplicate_string(yytext);
  return TOK_IDENTIFIER;
}

"+"           { emit_token("operator", yytext); return '+'; }
"-"           { emit_token("operator", yytext); return '-'; }
"*"           { emit_token("operator", yytext); return '*'; }
"/"           { emit_token("operator", yytext); return '/'; }
"%"           { emit_token("operator", yytext); return '%'; }
"^"           { emit_token("operator", yytext); return '^'; }
"!"           { emit_token("operator", yytext); return '!'; }
"="           { emit_token("operator", yytext); return '='; }
"<"           { emit_token("operator", yytext); return '<'; }
">"           { emit_token("operator", yytext); return '>'; }

";"           { emit_token("punctuation", yytext); return ';'; }
","           { emit_token("punctuation", yytext); return ','; }
"{"           { emit_token("punctuation", yytext); return '{'; }
"}"           { emit_token("punctuation", yytext); return '}'; }
"("           { emit_token("punctuation", yytext); return '('; }
")"           { emit_token("punctuation", yytext); return ')'; }
"["           { emit_token("punctuation", yytext); return '['; }
"]"           { emit_token("punctuation", yytext); return ']'; }
":"           { emit_token("punctuation", yytext); return ':'; }
"."           { emit_token("punctuation", yytext); return '.'; }

.             {
  if (g_protocol_response) {
    ProtocolSpan span;
    span.source_path = (g_current_source_path && g_current_source_path[0] != '\0') ? g_current_source_path : NULL;
    span.offset = (size_t)yy_token_offset;
    span.line = (size_t)yy_token_line;
    span.column = (size_t)yy_token_column;
    span.length = (size_t)yy_token_length;
    char msg[64];
    snprintf(msg, sizeof(msg), "رمز غير معروف «%s»", yytext);
    protocol_add_diagnostic(g_protocol_response, SEVERITY_ERROR, "lexical", "L001", msg, &span);
  }
}

%%
