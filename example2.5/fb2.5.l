/* fb2-5.l - C cross-referencer (basic) */
%option noyywrap nodefault yylineno
%x COMMENT

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

struct ref {
    struct ref *next;
    char *filename;
    int lineno;
};

struct symbol {
    struct symbol *next;
    char *name;
    struct ref *reflist;
};

#define NHASH 20011
static struct symbol *symtab[NHASH];

static unsigned symhash(const char *s);
static struct symbol *lookup(const char *name);
static void addref(struct symbol *sym, const char *filename, int lineno);
static void dump(void);

static const char *curfilename = "<stdin>";
%}

/* patterns */
IDSTART     [A-Za-z_]
IDREST      [A-Za-z0-9_]
ID          {IDSTART}{IDREST}*

%%
/* ---- skip whitespace ---- */
[ \t\r]+                {}

/* ---- newlines ---- */
\n                      {}

/* ---- comments ---- */
"/*"                    { BEGIN(COMMENT); }
<COMMENT>"*/"           { BEGIN(INITIAL); }
<COMMENT>\n             {}
<COMMENT>.              {}

"//"[^\n]*              {}

/* ---- strings and chars (skip) ---- */
\"([^\\\n]|\\.)*\"      {}
\'([^\\\n]|\\.)*\'      {}

/* ---- preprocessor line (skip whole line) ---- */
^[ \t]*\#[^\n]*         {}

/* ---- identifiers ---- */
{ID}                    {
                            struct symbol *s = lookup(yytext);
                            addref(s, curfilename, yylineno);
                        }

/* ---- anything else ---- */
.                       {}
%%

int main(int argc, char **argv) {
    int i;

    if (argc < 2) {
        yylex();
        dump();
        return 0;
    }

    for (i = 1; i < argc; i++) {
        FILE *f = fopen(argv[i], "r");
        if (!f) { perror(argv[i]); return 1; }
        curfilename = argv[i];
        yyrestart(f);
        yylex();
        fclose(f);
    }

    dump();
    return 0;
}

/* ---- symbol table (chaining) ---- */
static unsigned symhash(const char *s) {
    unsigned h = 0;
    while (*s) {
        unsigned char c = (unsigned char)*s++;
        h = (h * 33u) ^ (unsigned)c;
    }
    return h % NHASH;
}

static struct symbol *lookup(const char *name) {
    unsigned h = symhash(name);
    struct symbol *sp = symtab[h];

    while (sp) {
        if (strcmp(sp->name, name) == 0) return sp;
        sp = sp->next;
    }

    sp = (struct symbol*)calloc(1, sizeof(*sp));
    if (!sp) { perror("calloc"); exit(1); }

    sp->name = strdup(name);
    if (!sp->name) { perror("strdup"); exit(1); }

    sp->next = symtab[h];
    symtab[h] = sp;
    return sp;
}

static void addref(struct symbol *sym, const char *filename, int lineno) {
    struct ref *r = (struct ref*)malloc(sizeof(*r));
    if (!r) { perror("malloc"); exit(1); }

    r->filename = strdup(filename);
    if (!r->filename) { perror("strdup"); exit(1); }

    r->lineno = lineno;
    r->next = sym->reflist;
    sym->reflist = r;
}

static int symcount(void) {
    int n = 0, i;
    for (i = 0; i < NHASH; i++) {
        struct symbol *sp = symtab[i];
        while (sp) { n++; sp = sp->next; }
    }
    return n;
}

static int cmp_sym_ptr(const void *a, const void *b) {
    const struct symbol *sa = *(const struct symbol * const *)a;
    const struct symbol *sb = *(const struct symbol * const *)b;
    return strcmp(sa->name, sb->name);
}

static void dump(void) {
    int n = symcount();
    int i, k = 0;
    struct symbol **arr = (struct symbol**)malloc(sizeof(*arr) * (size_t)n);
    if (!arr) { perror("malloc"); exit(1); }

    for (i = 0; i < NHASH; i++) {
        struct symbol *sp = symtab[i];
        while (sp) { arr[k++] = sp; sp = sp->next; }
    }

    qsort(arr, (size_t)n, sizeof(*arr), cmp_sym_ptr);

    for (i = 0; i < n; i++) {
        struct symbol *sp = arr[i];
        struct ref *r = sp->reflist;

        printf("%s:", sp->name);
        while (r) {
            printf(" %s:%d", r->filename, r->lineno);
            r = r->next;
        }
        printf("\n");
    }

    free(arr);
}