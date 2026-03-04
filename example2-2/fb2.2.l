/* fb2-2.l - word count, reading many files */
%option noyywrap

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int chars = 0, words = 0, lines = 0;
int totchars = 0, totwords = 0, totlines = 0;
%}

%%
[a-zA-Z]+    { words++; chars += (int)strlen(yytext); }
\n           { chars++; lines++; }
.            { chars++; }
%%

int main(int argc, char **argv) {
    int i;

    if (argc < 2) { /* read stdin */
        yylex();
        printf("%8d%8d%8d\n", lines, words, chars);
        return 0;
    }

    for (i = 1; i < argc; i++) {
        FILE *f = fopen(argv[i], "r");
        if (!f) {
            perror(argv[i]);
            return 1;
        }

        yyrestart(f);
        yylex();
        fclose(f);

        printf("%8d%8d%8d %s\n", lines, words, chars, argv[i]);

        totchars += chars; chars = 0;
        totwords += words; words = 0;
        totlines += lines; lines = 0;
    }

    if (argc > 2) { /* total only if more than one file */
        printf("%8d%8d%8d total\n", totlines, totwords, totchars);
    }

    return 0;
}