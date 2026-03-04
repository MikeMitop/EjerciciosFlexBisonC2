#include <stdio.h>

int global = 10;

int suma(int a, int b) {
    int x = a + b;
    return x;
}

int main() {
    int local = suma(global, 5);
    printf("%d\n", local);
    return 0;
}
