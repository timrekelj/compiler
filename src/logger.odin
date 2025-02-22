package main

import "core:fmt"
import "core:strings"
import "core:os"

LogType :: enum {
    ERROR,
    WARNING,
    INFO
}

print_token :: proc(type: LogType, token: Token, format: string, args: ..any, flush:bool = true) {
    switch (type) {
        case .ERROR:
            fmt.fprintf(os.stdout, "\e[1;31m  ERROR\e[0m ", flush=flush)
        case .WARNING:
            fmt.fprintf(os.stdout, "\e[1;33mWARNING\e[0m ", flush=flush)
        case .INFO:
            fmt.fprintf(os.stdout, "\e[1;92m   INFO\e[0m ", flush=flush)
    }

    fmt.fprintf(
        os.stdout,
        "\e[1;90m(\"%s\" %d:%d)\e[0m ",
        token.value,
        token.position.start.line,
        token.position.start.col,
        flush=flush
    )
    fmt.fprintf(os.stdout, format, ..args, flush=flush, newline=true)
}

print :: proc(type: LogType, format: string, args: ..any, flush:bool = true) {
    switch (type) {
        case .ERROR:
            fmt.fprintf(os.stdout, "\e[1;31m  ERROR\e[0m ", flush=flush)
        case .WARNING:
            fmt.fprintf(os.stdout, "\e[1;33mWARNING\e[0m ", flush=flush)
        case .INFO:
            fmt.fprintf(os.stdout, "\e[1;92m   INFO\e[0m ", flush=flush)
    }

    fmt.fprintf(os.stdout, format, ..args, flush=flush, newline=true)
}
