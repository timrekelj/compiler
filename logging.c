#include <stdarg.h>
#include "compiler.h"
#include <stdio.h>
#include <stdlib.h>

enum {
    ERROR,
    WARNING,
    LOG
};

static void printtok(Token token, int type, char* fmt, va_list args) {
    switch (type) {
        case ERROR:
            fprintf(stderr, "\e[1;31mERROR\e[0m ");
            break;
        case WARNING:
            fprintf(stderr, "\e[1;33mWARNING\e[0m ");
            break;
        case LOG:
            fprintf(stderr, "\e[1;92mLOG\e[0m ");
            break;
    }

    fprintf(stderr, "Line: %d; Position: %d\n", token.loc.start_line, token.loc.start_pos);
    fprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
}

static void print(int type, char* fmt, va_list args) {
    switch (type) {
        case ERROR:
            fprintf(stderr, "\e[1;31mERROR\e[0m ");
            break;
        case WARNING:
            fprintf(stderr, "\e[1;33mWARNING\e[0m ");
            break;
        case LOG:
            fprintf(stderr, "\e[1;92mLOG\e[0m ");
            break;
    }

    fprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
}

void logger_error(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print(ERROR, fmt, args);
    va_end(args);
    exit(1);
}

void logger_warn(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print(WARNING, fmt, args);
    va_end(args);
}

void logger_log(char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    print(LOG, fmt, args);
    va_end(args);
}

void logger_errortok(Token token, char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    printtok(token, ERROR, fmt, args);
    va_end(args);
    exit(1);
}

void logger_warntok(Token token, char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    printtok(token, WARNING, fmt, args);
    va_end(args);
}

void logger_logtok(Token token, char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    printtok(token, LOG, fmt, args);
    va_end(args);
}
