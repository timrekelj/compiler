#include <stdio.h>
#include "compiler.h"

typedef struct {
    FILE* fp;
    int line;
    int pos;
} File;

File create_file(char* filename) {
    FILE* fp = fopen(filename, "r");

    if (!fp) {
        lerror("Error trying to open the file (%s)", filename);
    }

    return (File){ fp, 1, 1 };
}

char nextc(File f) {
    char c = getc(f.fp);
    if (c == '\r') { c = '\n'; }

    if (c == '\n') {
        f.line += 1;
        f.pos = 1;
    } else {
        f.pos += 1;
    }

    return c;
}

char peek(File f) {
    char c;
    c = fgetc(f.fp);
    ungetc(c, f.fp);
    return c;
}

void lexer(char* filename) {
    File file = create_file(filename);
    char curr_char;

    while (curr_char != EOF) {
        curr_char = nextc(file);

        if (curr_char == '\n') {
            linfo("Character is new line");
            linfo("Next character is: %c", peek(file));
        } else if (curr_char == EOF) {
            lwarn("Character is end of file.");
        } else {
            linfo("Char: %c", curr_char);
        }
    }

    fclose(file.fp);
}
