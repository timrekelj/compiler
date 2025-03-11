package main

import "core:fmt"
import "core:strings"
import "core:os"

LogType :: enum {
    ERROR,
    WARNING,
    INFO
}

@(private = "file")
print_type :: proc (type: LogType, flush: bool = true) {
    switch (type) {
        case .ERROR:
            fmt.fprintf(os.stdout, "\e[1;31m  ERROR\e[0m ", flush=flush)
        case .WARNING:
            fmt.fprintf(os.stdout, "\e[1;33mWARNING\e[0m ", flush=flush)
        case .INFO:
            fmt.fprintf(os.stdout, "\e[1;92m   INFO\e[0m ", flush=flush)
    }
}

printf :: proc(type: LogType, format: string, args: ..any, flush:bool = true) {
    print_type(type, flush)
    fmt.fprintf(os.stdout, format, ..args, flush=flush, newline=true)

    if type == .ERROR {
        os.exit(1)
    }
}

tok_printf :: proc(type: LogType, token: Token, format: string, args: ..any, flush:bool = true) {
    print_type(type, flush)
    fmt.fprintf(
        os.stdout,
        "\e[1;90m(\"%s\" %d:%d)\e[0m ",
        token.value,
        token.start_loc.line,
        token.start_loc.col,
        flush=flush
    )
    fmt.fprintf(os.stdout, format, ..args, flush=flush, newline=true)

    if type == .ERROR {
        os.exit(1)
    }
}

loc_printf :: proc(type: LogType, location: Location, format: string, args: ..any, flush:bool = true) {
    print_type(type, flush)
    fmt.fprintf(
        os.stdout,
        "\e[1;90m(%d:%d)\e[0m ",
        location.line,
        location.col,
        flush=flush
    )
    fmt.fprintf(os.stdout, format, ..args, flush=flush, newline=true)

    if type == .ERROR {
        os.exit(1)
    }
}
