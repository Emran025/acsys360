%{
#include "protocol.h"
#include "ast.h"
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int current_line = 1;
int current_column = 1;
ProtocolResponse *g_protocol_response = NULL;
const char *g_current_source_path = "";

#define YY_USER_ACTION current_column += yyleng;
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

"//"[^\n]*    { /* ignore comment */ }

"برنامج"       { return TOK_PROGRAM; }
"ثابت"         { return TOK_CONST; }
"نوع"          { return TOK_TYPE; }
"متغير"        { return TOK_VAR; }
"اجراء"        { return TOK_PROCEDURE; }
"بالقيمة"      { return TOK_BY_VALUE; }
"بالمرجع"      { return TOK_BY_REF; }
"اطبع"         { return TOK_PRINT; }
"اقرا"         { return TOK_READ; }
"اذا"          { return TOK_IF; }
"فان"          { return TOK_THEN; }
"والا"         { return TOK_ELSE; }
"كرر"          { return TOK_REPEAT; }
"طالما"        { return TOK_WHILE; }
"استمر"        { return TOK_DO; }
"اعد"          { return TOK_AGAIN; }
"من"           { return TOK_FROM; }
"الى"          { return TOK_TO; }
"اضف"          { return TOK_STEP; }
"حتى"          { return TOK_UNTIL; }
"صحيح"         { return TOK_TYPE_INT; }
"حقيقي"        { return TOK_TYPE_REAL; }
"منطقي"        { return TOK_TYPE_BOOL; }
"حرفي"         { return TOK_TYPE_CHAR; }
"خيط_رمزي"     { return TOK_TYPE_STRING; }
"قائمة"        { return TOK_ARRAY; }
"سجل"          { return TOK_RECORD; }
"صح"           { return TOK_TRUE; }
"خطأ"          { return TOK_FALSE; }

"؛"           { return ';'; }
"،"           { return ','; }

"=="          { return TOK_EQ; }
"!="          { return TOK_NE; }
"<="          { return TOK_LE; }
"=<"          { return TOK_LE; }
">="          { return TOK_GE; }
"=>"          { return TOK_GE; }
"&&"          { return TOK_AND; }
"||"          { return TOK_OR; }

{DIGIT}+      {
  yylval.str = strdup(yytext);
  return TOK_INTEGER_LITERAL;
}

{DIGIT}+\.{DIGIT}+ {
  yylval.str = strdup(yytext);
  return TOK_REAL_LITERAL;
}

\"([^\"\\]|\\.)*\" {
  yylval.str = strdup(yytext);
  return TOK_STRING_LITERAL;
}

{ID}          {
  yylval.str = strdup(yytext);
  return TOK_IDENTIFIER;
}

"+"           { return '+'; }
"-"           { return '-'; }
"*"           { return '*'; }
"/"           { return '/'; }
"%"           { return '%'; }
"^"           { return '^'; }
"!"           { return '!'; }
"="           { return '='; }
"<"           { return '<'; }
">"           { return '>'; }

";"           { return ';'; }
","           { return ','; }
"{"           { return '{'; }
"}"           { return '}'; }
"("           { return '('; }
")"           { return ')'; }
"["           { return '['; }
"]"           { return ']'; }
":"           { return ':'; }
"."           { return '.'; }

.             {
  if (g_protocol_response) {
    ProtocolSpan span = {g_current_source_path, 0, (size_t)current_line, (size_t)current_column, 1};
    protocol_add_diagnostic(g_protocol_response, SEVERITY_ERROR, "lexical", "L001", "رمز غير معروف", &span);
  }
}

%%