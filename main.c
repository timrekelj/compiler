#include <stdio.h>
#include <stdlib.h>
#include "compiler.h"

void usage(int exitcode) {
    // TODO: Write documentation for the compiler
    printf("Wrong command usage.\n");
    exit(exitcode);
}

int main(int argc, char** argv) {
    if (argc != 2) {
        usage(1);
        return 1;
    }

    char* filename = argv[1];

    lexer(filename);
}
