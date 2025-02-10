#include <stdio.h>
#include "compiler.h"

void lexer(char* filename) {
    FILE *fp = fopen(filename, "r");

    linfo("Filename: %s", filename);
}
