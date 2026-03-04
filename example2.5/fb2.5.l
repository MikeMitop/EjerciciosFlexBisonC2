%option noyywrap nodefault yylineno

%x COMMENT
%x IFILE

UCN   (\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8})
EXP   ([Ee][-+]?[0-9]+)
ILEN  ([Uu](L|l|LL|ll)?|(L|l|LL|ll)[Uu]?)

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct ref {
    struct ref *next;
    char *filename;
    int flags;
    int lineno;
};

struct symbol {
    struct ref *reflist;
    char *name;
    struct symbol *next;
};

#define NHASH 9997
static struct symbol *symtab[NHASH];

static unsigned symhash(const char *sym);
static struct symbol *lookup(const char *sym);
static void addref(int lineno, char *filename, const char *word, int flags);

static int symcount(void);
static int symcompare(const void *xa, const void *xb);
static void printrefs(void);

static char *curfilename;

struct bufstack {
    struct bufstack *prev;
    YY_BUFFER_STATE bs;
    int lineno;
    char *filename;
    FILE *f;
} *curbs = 0;

static int newfile(char *fn);
static int popfile(void);

static int defining;
%}

%%
"/*"                      { BEGIN(COMMENT); }
<COMMENT>"*/"             { BEGIN(INITIAL); }
<COMMENT>([^*]|\n)+|.      { }
<COMMENT><<EOF>>           { printf("%s:%d: Unterminated comment\n", curfilename, yylineno); return 0; }

"//".*\n                   { }

_Bool |
_Complex |
_Imaginary |
auto |
char |
const |
double |
enum |
extern |
float |
inline |
int |
long |
register |
restrict |
short |
signed |
static |
struct |
typedef |
union |
unsigned |
void |
volatile                   { defining = 1; }

break |
case |
continue |
default |
do |
else |
for |
goto |
if |
return |
sizeof |
switch |
while                      { }

0[0-7]*{ILEN}?             { }
[1-9][0-9]*{ILEN}?         { }
0[Xx][0-9a-fA-F]+{ILEN}?   { }

([0-9]*\.[0-9]+|[0-9]+\.){EXP}?[flFL]?  { }
[0-9]+{EXP}[flFL]?                      { }

0[Xx]([0-9a-fA-F]*\.[0-9a-fA-F]+|[0-9a-fA-F]+\.?)[Pp][-+]?[0-9]+[flFL]?  { }

\'([^'\\]|\\['"?\\abfnrtv]|\\[0-7]{1,3}|\\[Xx][0-9a-fA-F]+|{UCN})+\'      { }

L?\"([^"\\]|\\['"?\\abfnrtv]|\\[0-7]{1,3}|\\[Xx][0-9a-fA-F]+|{UCN})*\"    { }

"{"|"<%"|";"               { defining = 0; }

"["|"]"|"("|")"|"{"|"}"|"."|"->"         { }
"++"|"--"|"&"|"*"|"+"|"-"|"~"|"!"        { }
"/"|"%"|"<<"|">>"                        { }
"<"|">"|"<="|">="                        { }
"=="|"!="                                { }
"^"|"|"|"&&"|"||"                        { }
"?"|":"|"..."
"="|"*="|"/="|"%="|"+="|"-="|"<<="|">>="|"&="|"^="|"|="  { }
","|"#"|"##"                             { }
"<:"|":>"|"%>"|"%:"|"%:%:"               { }

([_a-zA-Z]|{UCN})([_a-zA-Z0-9]|{UCN})*   { addref(yylineno, curfilename, yytext, defining); }

[ \t\n]+                  { }
\\$                        { }

"#"" "*if.*\n              { }
"#"" "*else.*\n            { }
"#"" "*endif.*\n           { }
"#"" "*define.*\n          { }
"#"" "*line.*\n            { }

^"#"[ \t]*include[ \t]*[\"<]   { BEGIN(IFILE); }

<IFILE>[^>\"]+ {
    int c;
    while ((c = input()) && c != '\n') ;
    newfile(strdup(yytext));
    BEGIN(INITIAL);
}

<IFILE>.|\n {
    fprintf(stderr, "%s:%d bad include line\n", curfilename, yylineno);
    BEGIN(INITIAL);
}

<<EOF>>                    { if (!popfile()) yyterminate(); }

. {
    printf("%s:%d: Mystery character '%s'\n", curfilename, yylineno, yytext);
}
%%

static unsigned
symhash(const char *sym)
{
    unsigned int hash = 0;
    unsigned c;
    while ((c = (unsigned char)*sym++)) hash = hash * 9u ^ c;
    return hash;
}

static struct symbol *
lookup(const char *sym)
{
    unsigned h = symhash(sym) % NHASH;
    struct symbol *sp;

    for (sp = symtab[h]; sp; sp = sp->next) {
        if (sp->name && strcmp(sp->name, sym) == 0) return sp;
    }

    sp = (struct symbol *)malloc(sizeof(*sp));
    if (!sp) { perror("malloc"); exit(1); }

    sp->name = strdup(sym);
    if (!sp->name) { perror("strdup"); exit(1); }

    sp->reflist = 0;
    sp->next = symtab[h];
    symtab[h] = sp;
    return sp;
}

static void
addref(int lineno, char *filename, const char *word, int flags)
{
    struct ref *r;
    struct symbol *sp = lookup(word);

    if (sp->reflist &&
        sp->reflist->lineno == lineno &&
        sp->reflist->filename == filename) return;

    r = (struct ref *)malloc(sizeof(*r));
    if (!r) { fputs("out of space\n", stderr); abort(); }

    r->next = sp->reflist;
    r->filename = filename;
    r->lineno = lineno;
    r->flags = flags;
    sp->reflist = r;
}

static int
symcount(void)
{
    int i, n = 0;
    for (i = 0; i < NHASH; i++) {
        struct symbol *sp;
        for (sp = symtab[i]; sp; sp = sp->next) n++;
    }
    return n;
}

static int
symcompare(const void *xa, const void *xb)
{
    const struct symbol *a = *(const struct symbol * const *)xa;
    const struct symbol *b = *(const struct symbol * const *)xb;
    return strcmp(a->name, b->name);
}

static void
printrefs(void)
{
    int i, n = symcount(), k = 0;
    struct symbol **arr;

    arr = (struct symbol **)malloc(sizeof(*arr) * (size_t)n);
    if (!arr) { perror("malloc"); exit(1); }

    for (i = 0; i < NHASH; i++) {
        struct symbol *sp;
        for (sp = symtab[i]; sp; sp = sp->next) arr[k++] = sp;
    }

    qsort(arr, (size_t)n, sizeof(*arr), symcompare);

    for (i = 0; i < n; i++) {
        char *prevfn = NULL;
        struct ref *rp = arr[i]->reflist;
        struct ref *rpp = 0;
        struct ref *rpn;

        while (rp) {
            rpn = rp->next;
            rp->next = rpp;
            rpp = rp;
            rp = rpn;
        }

        printf("%10s", arr[i]->name);
        for (rp = rpp; rp; rp = rp->next) {
            if (rp->filename == prevfn) {
                printf(" %d", rp->lineno);
            } else {
                printf(" %s:%d", rp->filename, rp->lineno);
                prevfn = rp->filename;
            }
            if (rp->flags & 01) printf("*");
        }
        printf("\n");
    }

    free(arr);
}

static int
newfile(char *fn)
{
    FILE *f = fopen(fn, "r");
    struct bufstack *bs;

    if (!f) { perror(fn); free(fn); return 0; }

    bs = (struct bufstack *)malloc(sizeof(*bs));
    if (!bs) { perror("malloc"); exit(1); }

    if (curbs) curbs->lineno = yylineno;

    bs->prev = curbs;
    bs->bs = yy_create_buffer(f, YY_BUF_SIZE);
    bs->f = f;
    bs->filename = fn;              /* <-- aquí ya NO strdup */
    yy_switch_to_buffer(bs->bs);
    curbs = bs;

    yylineno = 1;
    curfilename = bs->filename;     /* <-- como te dije */
    return 1;
}

static int
popfile(void)
{
    struct bufstack *bs = curbs;
    struct bufstack *prevbs;

    if (!bs) return 0;

    fclose(bs->f);
    yy_delete_buffer(bs->bs);

    prevbs = bs->prev;
    free(bs->filename);
    free(bs);

    if (!prevbs) return 0;

    yy_switch_to_buffer(prevbs->bs);
    curbs = prevbs;

    yylineno = curbs->lineno;
    curfilename = curbs->filename;
    return 1;
}

int
main(int argc, char **argv)
{
    int i;
    if (argc < 2) {
        fprintf(stderr, "need filename\n");
        return 1;
    }
    for (i = 1; i < argc; i++) {
        if (newfile(strdup(argv[i])))
            yylex();
    }
    printrefs();
    return 0;
}
