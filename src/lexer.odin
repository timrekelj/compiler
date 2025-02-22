package main

import "core:os"
import "core:c/libc"
import "core:strings"

File :: struct {
    fp: os.Handle,
    curr_loc: Location
}

tokens: [dynamic]Token

nextc :: proc(file: ^File) -> u8 {
    buf := make([]byte, 1)
    defer delete(buf)

    _, read_err := os.read(file.fp, buf)
    if read_err != nil {
        loc_printf(.ERROR, file.curr_loc, "LEX: Error trying to read next character in file")
    }

    if buf[0] == '\r' { buf[0] = '\n' }

    if buf[0] == '\n' {
        file.curr_loc.col = 0
        file.curr_loc.line += 1
    } else {
        file.curr_loc.col += 1
    }

    return buf[0]
}

peek :: proc(file: File) -> u8 {
    buf := make([]byte, 1)
    defer delete(buf)

    _, read_err := os.read(file.fp, buf)
    if read_err != nil {
        loc_printf(.ERROR, file.curr_loc, "LEX: Error trying to read next character in file")
    }

    // Do not go back if next character is EOF
    if buf[0] == 0 {
        return buf[0]
    }

    _, seek_err := os.seek(file.fp, -1, os.SEEK_CUR)
    if seek_err != nil {
        loc_printf(.ERROR, file.curr_loc, "LEX: Error trying to seek next character in file")
    }

    return buf[0]
}

read_number :: proc(last_char: u8, file: ^File) -> Token {
    start_loc: Location = file.curr_loc

    value_builder, builder_err := strings.builder_make()
    if builder_err != nil {
        loc_printf(.ERROR, start_loc, "LEX: Failed to init value builder")
    }

    strings.write_byte(&value_builder, last_char)
    curr_c := nextc(file)
    for curr_c >= '0' && curr_c <= '9'{
        strings.write_byte(&value_builder, curr_c)
        curr_c = nextc(file)
    }

    return {
        token_type = .NUMBER,
        value = strings.to_string(value_builder),
        start_loc = start_loc,
        end_loc = file.curr_loc
    }
}

read_string :: proc(file: ^File) -> Token {
    start_loc: Location = file.curr_loc

    value_builder, builder_err := strings.builder_make()
    if builder_err != nil {
        loc_printf(.ERROR, start_loc, "LEX: Failed to init value builder")
    }

    curr_c := nextc(file)
    for curr_c != '"' {
        if curr_c == 0 || curr_c == '\n' {
            loc_printf(.ERROR, file.curr_loc, "LEX: String does not have end")
        }

        strings.write_byte(&value_builder, curr_c)
        curr_c = nextc(file)
    }

    return {
        token_type = .STRING,
        value = strings.to_string(value_builder),
        start_loc = start_loc,
        end_loc = file.curr_loc
    }
}

lexer :: proc(filename: string) {
    fp, fp_err := os.open(filename)
    if fp_err != nil {
        printf(.ERROR, "LEX: File not found")
    }
    defer os.close(fp)

    file := File{
        fp = fp,
        curr_loc = { line = 1, col = 0 }
    }

    curr_c := nextc(&file)
    for curr_c != 0 {
        switch (curr_c) {
            // Whitespace
            case '\t', '\n', ' ':
                for curr_c != 0 && (curr_c == '\t' || curr_c == '\n' || curr_c == ' ') {
                    curr_c = nextc(&file)
                }
                continue
            case '0'..='9':
                append(&tokens, read_number(curr_c, &file))
            case '"':
                append(&tokens, read_string(&file))
        }
        curr_c = nextc(&file)
    }

    for token in tokens {
        printf(
            .INFO,
            "LEX: type: %s, value: %s, loc: (%d:%d - %d:%d)",
            token.token_type,
            token.value,
            token.start_loc.line,
            token.start_loc.col,
            token.end_loc.line,
            token.end_loc.col
        )
    }
}
