/* fb2-1.l - word count, reading one file (like Unix wc) */
%option noyywrap

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int chars = 0;
int words = 0;
int lines = 0;
%}

%%
[a-zA-Z]+    { words++; chars += (int)strlen(yytext); }
\n           { chars++; lines++; }
.            { chars++; }
%%

int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            perror(argv[1]);
            return 1;
        }
    }

    yylex();
    printf("%8d%8d%8d\n", lines, words, chars);
    return 0;
}