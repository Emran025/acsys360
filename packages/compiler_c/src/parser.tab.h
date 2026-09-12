/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_SRC_PARSER_TAB_H_INCLUDED
# define YY_YY_SRC_PARSER_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    TOK_IDENTIFIER = 258,          /* TOK_IDENTIFIER  */
    TOK_STRING_LITERAL = 259,      /* TOK_STRING_LITERAL  */
    TOK_CHAR_LITERAL = 260,        /* TOK_CHAR_LITERAL  */
    TOK_INTEGER_LITERAL = 261,     /* TOK_INTEGER_LITERAL  */
    TOK_REAL_LITERAL = 262,        /* TOK_REAL_LITERAL  */
    TOK_PROGRAM = 263,             /* TOK_PROGRAM  */
    TOK_CONST = 264,               /* TOK_CONST  */
    TOK_TYPE = 265,                /* TOK_TYPE  */
    TOK_VAR = 266,                 /* TOK_VAR  */
    TOK_PROCEDURE = 267,           /* TOK_PROCEDURE  */
    TOK_BY_VALUE = 268,            /* TOK_BY_VALUE  */
    TOK_BY_REF = 269,              /* TOK_BY_REF  */
    TOK_PRINT = 270,               /* TOK_PRINT  */
    TOK_READ = 271,                /* TOK_READ  */
    TOK_IF = 272,                  /* TOK_IF  */
    TOK_THEN = 273,                /* TOK_THEN  */
    TOK_ELSE = 274,                /* TOK_ELSE  */
    TOK_REPEAT = 275,              /* TOK_REPEAT  */
    TOK_WHILE = 276,               /* TOK_WHILE  */
    TOK_DO = 277,                  /* TOK_DO  */
    TOK_AGAIN = 278,               /* TOK_AGAIN  */
    TOK_FROM = 279,                /* TOK_FROM  */
    TOK_TO = 280,                  /* TOK_TO  */
    TOK_STEP = 281,                /* TOK_STEP  */
    TOK_UNTIL = 282,               /* TOK_UNTIL  */
    TOK_TYPE_INT = 283,            /* TOK_TYPE_INT  */
    TOK_TYPE_REAL = 284,           /* TOK_TYPE_REAL  */
    TOK_TYPE_BOOL = 285,           /* TOK_TYPE_BOOL  */
    TOK_TYPE_CHAR = 286,           /* TOK_TYPE_CHAR  */
    TOK_TYPE_STRING = 287,         /* TOK_TYPE_STRING  */
    TOK_ARRAY = 288,               /* TOK_ARRAY  */
    TOK_RECORD = 289,              /* TOK_RECORD  */
    TOK_TRUE = 290,                /* TOK_TRUE  */
    TOK_FALSE = 291,               /* TOK_FALSE  */
    TOK_EQ = 292,                  /* TOK_EQ  */
    TOK_NE = 293,                  /* TOK_NE  */
    TOK_LE = 294,                  /* TOK_LE  */
    TOK_GE = 295,                  /* TOK_GE  */
    TOK_AND = 296,                 /* TOK_AND  */
    TOK_OR = 297,                  /* TOK_OR  */
    TOK_ASSIGN = 298               /* TOK_ASSIGN  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 22 "src/parser.y"

  char *str;
  CAstNode *node;
  CAstNodeList list;

#line 113 "src/parser.tab.h"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;


int yyparse (void);


#endif /* !YY_YY_SRC_PARSER_TAB_H_INCLUDED  */
