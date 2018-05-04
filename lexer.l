%option noyywrap

D			[0-9]
L			[a-zA-Z_]
S			[0-9a-zA-Z_ ]
H			[a-fA-F0-9]
E			[Ee][+-]?{D}+
FS			(f|F|l|L)
IS			(u|U|l|L)*

%{
#include <stdio.h>
#include <string.h>
#include "parser.tab.h"
int getRegID(char*);
#define yyterminate() return token::END
%}

%%
[ \t]         ;          //detect string and return token to bison
<<EOF>>                 { return END_OF_FILE; }
"print"					{ return PRINT; }
"compare"				{ return COMPARE; }
"loop"					{ return LOOP; } 

"\\n"           { return NEWLINE; }
[\"]            { return '\"'; }
[,]             { return ','; }
[;]             { return ';'; }
[=]             { return '='; }
[+]             { return '+'; } 
[-]             { return '-'; }
[*]             { return '*'; }
[/]             { return '/'; }
[%]             { return '%'; }
[(]             { return '('; }
[)]             { return ')'; }
[{]             { return '{'; }
[}]             { return '}'; }
r[a-zA-Z]          { yylval.intval = (int)getRegID(yytext); return VAR; }

{D}+            { yylval.intval = atoi(yytext); return NUM; }
{H}+h           { yylval.intval = (int)strtol(yytext, NULL, 16); return NUM; }

L?\"(\\.|[^\\"])*\"     { yylval.strval = strdup(yytext); return STR; }

.                { }
%%

int getRegID(char *input){          //change input register from a-z to id (0-25)
    int result = 0;
    if(input[strlen(input)-1] >= 'A' && input[strlen(input)-1] <= 'Z')
        result = input[strlen(input)-1] - 'A';
    else if(input[strlen(input)-1] >= 'a' && input[strlen(input)-1] <= 'z')
        result = input[strlen(input)-1] - 'a';
    return result;
}
