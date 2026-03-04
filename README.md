Miguel Ángel Celis López

Taller: Primeros Pasos en Flex y Bison

Joaquin Fernando Sanchez Cifuentes

Lenguajes de Programación

Universidad Sergio Arboleda

2026, Bogotá D.C



**Objetivo General:**

Desarrollar y validar un conjunto de analizadores léxicos con Flex que repliquen los ejemplos 2-1 a 2-5 del capítulo número 2, aplicando técnicas de lectura de archivos, estados de inicio (start states), manejo de archivos anidados con \#include, generación de concordancias y referencias cruzadas.

**Objetivos Específicos:**

1. Implementar con Flex los analizadores léxicos de los ejemplos 2-1 a 2-5, verificando su funcionamiento con archivos de prueba.  
2. Manejar correctamente la lectura de múltiples archivos y archivos anidados (\#include) usando estados y una pila de buffers.  
3. Generar salidas claras que muestren conteos, concordancias y referencias cruzadas (archivo y número de línea) según el objetivo de cada ejemplo.

**Desarrollo:** 

***Ejercicios:***

1\. El Ejemplo 2-3 compara caracteres de uno en uno. ¿Por qué no los compara línea por línea con un patrón como ^.\*\\\\n? Sugiera un patrón o una combinación de patrones que coincida con fragmentos de texto más grandes, teniendo en cuenta la razón por la que ^.\* no funcionará.

***Respuesta:***

En este caso, dentro del ejemplo no se usa un patrón como ^.\*\\ \\n dado a que:

- Al intentar usar (^) de manera normal, este solo funciona cuando el escáner está al inicio de una línea. Para el resto del tiempo, el patrón no aplica y acaba solicitando/necesitando reglas extras. En resumen, este restringe el inicio de la línea.  
    
- (.\*) Resulta que puede tener un comportamiento diferente y/o erroneo, este patrón se llevaría lineas y el programa termina teniendo un comportamiento distinto al planeado, por ejemplo, en este caso, dentro del código se detecta un \#include, que se encarga de activar el estado de IFILE, si la línea no termina con \\n, el patrón se comporta de forma distinta.

# ***Implementación:***

En este caso, la idea es dejar la regla de \#include en vez de usar , o echo al pasar por cada carácter.

***Por ejemplo:***

- Una regla que capture toda la información que no inicie con \# para evitar problemas con el \#include  
- Una regla para capturar el último tramo si el archivo termina en un salto de línea  
- Una regla para \\n si lo que se quiere es contar o mostrar la salida de forma correcta.

En resumen, lo que se busca con este ejercicio es hacer menos reglas pequeñas o cortas para pasar a reglas que tengan la opción y la capacidad de leer trozos más grandes, sin romper el manejo que se le da en el ejemplo al \#Include.

## **Código Fuente:** 

``` 
/\* fb2-3 skeleton for include files \*/  
%option noyywrap  
%x IFILE  
%{  
 struct bufstack {  
 struct bufstack \*prev; /\* previous entry \*/  
 YY\_BUFFER\_STATE bs; /\* saved buffer \*/  
 int lineno; /\* saved line number \*/  
 char \*filename; /\* name of this file \*/  
 FILE \*f; /\* current file \*/  
 } \*curbs \= 0;  
 char \*curfilename; /\* name of current input file \*/  
 int newfile(char \*fn);  
 int popfile(void);  
%}  
%%  
 /\* match \#include statement up through the quote or \< \*/  
^"\#"\[ \\t\]\*include\[ \\t\]\*\[\\"\<\] { BEGIN IFILE; }

 /\* handle filename up to the closing quote, \>, or end of line \*/  
\<IFILE\>\[^ \\t\\n\\"\>\]+ {   
 { int c;  
 while((c \= input()) && c \!= '\\n') ;  
 }  
 yylineno++;  
 if(\!newfile(yytext))  
 yyterminate(); /\* no such file \*/  
 BEGIN INITIAL;  
 }

 /\* handle bad input in IFILE state \*/  
\<IFILE\>.|\\n { fprintf(stderr, "%4d bad include line\\n", yylineno);  
 yyterminate();  
 }

 /\* pop the file stack at end of file, terminate if it's the outermost file \*/  
\<\<EOF\>\> { if(\!popfile()) yyterminate(); }

 /\* print the line number at the beginning of each line   
    and bump the line number each time a \\n is read \*/  
^\[^\#\\n\]+ { fprintf(yyout, "%4d %s", yylineno, yytext); }  
^.       { fprintf(yyout, "%4d %s", yylineno, yytext); }  
^\\n      { fprintf(yyout, "%4d %s", yylineno++, yytext); }  
\\n       { ECHO; yylineno++; }  
\[^\#\\n\]+  { ECHO; }  
.        { ECHO; }  
%%  
int main(int argc, char \*\*argv)  
{  
 if(argc \< 2\) {  
 fprintf(stderr, "need filename\\n");  
 return 1;  
 }  
 if(newfile(argv\[1\]))  
 yylex();  
}

int newfile(char \*fn)  
{  
 FILE \*f \= fopen(fn, "r");  
 struct bufstack \*bs \= malloc(sizeof(struct bufstack));  
 /\* die if no file or no room \*/  
 if(\!f) { perror(fn); return 0; }  
 if(\!bs) { perror("malloc"); exit(1); }  
 /\* remember state \*/  
 if(curbs)curbs-\>lineno \= yylineno;  
 bs-\>prev \= curbs;  
 /\* set up current entry \*/  
 bs-\>bs \= yy\_create\_buffer(f, YY\_BUF\_SIZE);  
 bs-\>f \= f;  
 bs-\>filename \= fn;  
 yy\_switch\_to\_buffer(bs-\>bs);  
 curbs \= bs;  
 yylineno \= 1;  
 curfilename \= fn;  
 return 1;  
}

int popfile(void)  
{  
 struct bufstack \*bs \= curbs;  
 struct bufstack \*prevbs;  
 if(\!bs) return 0;  
 /\* get rid of current entry \*/  
 fclose(bs-\>f);  
 yy\_delete\_buffer(bs-\>bs);  
 /\* switch back to previous \*/  
 prevbs \= bs-\>prev;  
 free(bs);  
 if(\!prevbs) return 0;  
 yy\_switch\_to\_buffer(prevbs-\>bs);  
 curbs \= prevbs;  
 yylineno \= curbs-\>lineno;  
 curfilename \= curbs-\>filename;  
 return 1;   
}  
```

### **Salida Esperada:**

**main.txt**  
![Salida 1](img/Captura%20desde%202026-03-04%2000-38-58.png)
**main\_erroneo.txt**  
![Salida 2](img/Captura%20desde%202026-03-04%2000-39-44.png)

### **Cómo Compilar:**

```bash  
flex fb2.3.l  
```  
```bash  
gcc [lex.yy](http://lex.yy).c \-lfl  
```  
```bash  
./a.out main.txt o ./a.out main\_erroneo.txt  
```

2\. El programa de concordancia trata el texto en mayúsculas y minúsculas por separado. Modifíquelo para que los maneje juntos. En symhash(), use tolower para aplicar el *hash* a las versiones en minúsculas de los caracteres, y use strcasecmp() para comparar palabras.

### ***Respuesta:***

Dentro del ejemplo, el cual es el 2-4. Aunque Flex puede ignorar las mayusculas y las minúsculas, usando *case-insensitive*, la tabla de simbolos permite diferenciar las palabras si el hash y la comparación son sensibles a las mayúsculas, por ejemplo. “Hello” y “hello” terminaron reconociendose como entradas distintas.

Para que se traten de la misma palabra, sin duplicar strings, lo que se hace es:

- Hash (symhash): Aplicar tolower() a cada carácter antes de que se junte con el hash, así las variantes caen a la misma posición lógica (bucket)  
- Comparación (lookup): Se remplazó el strcmp() por strcasecmp() para que este reconozca que dos palabras son la misma aunque su capitalización sea distinta.

### ***Implementación:*** 

El código utilizado fue el mismo del ejemplo 2-4 del libro de Flex y Bison. Sin embargo, para cumplir con las normativas indicadas dentro de los ejercicios, se hicieron distintos cambios, en hashing y el lookup, estos son:

1. Dentro de symhash(char \*sym):  
- Antes: hash \= hash\*9 ^ c;  
- Cambio: hash \= hash\*9 ^ tolower(c);  
2. Dentro de lookup(char \*sym):  
- Antes: \!strcmp(sp-\>name, sym)  
- Cambio: \!strcasecmp(sp-\>name, sym)


Gracias a estos cambios, el programa permite guardar una entrada para la palabra y no realiza copias adicionales del strdup(). 

### **Código Fuente:**

***El código completo se encuentra referenciado dentro del Repositorio, en este apartado solo se mencionarán los cambios realizados al programa original del libro***

- ***Symhash***:

```
static unsigned  
symhash(char \*sym)  
{  
  unsigned int hash \= 0;  
  unsigned c;  
  while((c \= (unsigned char)\*sym++))  
    hash \= hash\*9 ^ (unsigned)tolower((int)c);  
  return hash;  
}  
```

- ***Lookup:***

```
struct symbol \*  
lookup(char\* sym)  
{  
  struct symbol \*sp \= \&symtab\[symhash(sym)%NHASH\];  
  int scount \= NHASH; /\* how many have we looked at \*/  
  while(--scount \>= 0\) {  
    if(sp-\>name && \!strcasecmp(sp-\>name, sym)) return sp;  
    if(\!sp-\>name) { /\* new entry \*/  
      sp-\>name \= strdup(sym);  
      sp-\>reflist \= 0;  
      return sp;  
    }  
    if(++sp \>= symtab+NHASH) sp \= symtab; /\* try the next entry \*/  
  }  
  fputs("symbol table overflow\\n", stderr);  
  abort(); /\* tried them all, table is full \*/  
}  
```
**Salida Esperada**  
![Salida 3](img/Captura%20desde%202026-03-04%2000-40-19.png)

### **Cómo Compilar:**

```bash  
flex fb2.4.l  
```
```bash  
gcc [lex.yy](http://lex.yy).c \-lfl  
```
```bash  
./a.out salida.txt  
```

3\. La rutina de la tabla de símbolos en los programas de concordancia y referencia cruzada utiliza una tabla de símbolos de tamaño fijo y falla si se llena. Modifique la rutina para que no haga eso. Las dos técnicas estándar para permitir tablas hash de tamaño variable son el encadenamiento (*chaining*) y el *rehashing*. El encadenamiento convierte la tabla hash en una tabla de punteros a una lista de entradas de símbolos. Las búsquedas recorren la cadena para encontrar el símbolo y, si no se encuentra, asignan una nueva entrada con malloc() y la agregan a la cadena. El *rehashing* crea una tabla de símbolos inicial de tamaño fijo, nuevamente usando malloc(). Cuando la tabla de símbolos se llena, crea una nueva tabla de símbolos más grande y copia todas las entradas en ella, usando la función *hash* para decidir dónde va cada entrada en la nueva tabla. Ambas técnicas funcionan, pero una haría mucho más complicado producir la referencia cruzada. ¿Cuál? ¿Por qué?

### Respuesta: 

**¿Por qué rehashing lo hace mas complicado para el cross-reference?**

Esto es debido a que rehashing implica mover todas las entrada a una tabla nueva cuando crece. Esto trae dos problemas prácticos dentro del ejemplo 2-5.

- En los rehashing, se crean tablas nuevas y se reinsertan simbolos, si el programa guarda punteros a entradas, al reinsertarlo se puede terminar con punteros invalidos o con una lógica frágil.  
- Dentro del cross-reference del libro, al final se hace qsort(), y luego recorre o imprime. Si se usara rehashing se tendría que:  
* Llevar el control del tamaño actual, cuando crecer  
* Reinsertar todas las entradas cada vez que crece  
* Asegurar que no se pierdan ni se dupliquen listas de referencias durante el move.

En cambio, con chaining, nunca se mueven simbolos existentes, solo se agregan nodos al inicio o al final de la lista del bucket. De la misma forma, la tabla resulta ser un array de struct symbol\* (punteros) y cada simbolo resulta ser un nodo dinámico (malloc)

Para imprimir el cross reference usando chaining, simplemente se realiza:

- Se recorren los buckets  
- Se recolectan punteros a los simbolos en un arreglo  
- qsort() es el arreglo que se indica  
- Se imprimen igual que antes

En resumen, el chaining encaja con guardar referencias por simbolo y luego ordenar y imprimir. Por lo tanto, es mas complejo el rehashing dado a que se requiere reubicar o reinsertar las entradas al crecer la tabla. Mientras que al usar chaining, se mantienen entradas estables y es más directo para recolectar y ordenar al imprimir.

