#include <stdarg.h>
#include "compiler.h"
#include <stdio.h>
#include <stdlib.h>

enum {
    ERROR,
    WARNING,
    INFO
};

static void print_token(Token token, int type, char* fmt, va_list args) {
    switch (type) {
        case ERROR:
            fprintf(stderr, "\e[1;31m  ERROR\e[0m ");
            break;
        case WARNING:
            fprintf(stderr, "\e[1;33mWARNING\e[0m ");
            break;
        case INFO:
            fprintf(stderr, "\e[1;92m   INFO\e[0m ");
            break;
    }

    fprintf(stderr, "\e[1;90m(\"%s\" %d:%d)\e[0m ", token.value, token.loc.start_line, token.loc.start_pos);
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
}

static void print(int type, char* fmt, va_list args) {
    switch (type) {
        case ERROR:
            fprintf(stderr, "\e[1;31m  ERROR\e[0m ");
            break;
        case WARNING:
            fprintf(stderr, "\e[1;33mWARNING\e[0m ");
            break;
        case INFO:
            fprintf(stderr, "\e[1;92m   INFO\e[0m ");
            break;
    }

    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
}

void lerror(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print(ERROR, fmt, args);
    va_end(args);
    exit(1);
}

void lwarn(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print(WARNING, fmt, args);
    va_end(args);
}

void linfo(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print(INFO, fmt, args);
    va_end(args);
}

void lerrort(Token token, char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print_token(token, ERROR, fmt, args);
    va_end(args);
    exit(1);
}

void lwarnt(Token token, char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print_token(token, WARNING, fmt, args);
    va_end(args);
}

void linfot(Token token, char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print_token(token, INFO, fmt, args);
    va_end(args);
}
