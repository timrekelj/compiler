package main

import "core:os"
import "core:c/libc"

File :: struct {
    fp: os.Handle,
    curr_loc: Location
}

nextc :: proc(file: ^File) -> u8 {
    buf := make([]byte, 1)
    defer delete(buf)

    _, read_err := os.read(file.fp, buf)
    if read_err != nil {
        loc_printf(.ERROR, file.curr_loc, "READ: Error trying to read next character in file")
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
        loc_printf(.ERROR, file.curr_loc, "SEEK: Error trying to read next character in file")
    }

    // Do not go back if next character is EOF
    if buf[0] == 0 {
        return buf[0]
    }

    _, seek_err := os.seek(file.fp, -1, os.SEEK_CUR)
    if seek_err != nil {
        loc_printf(.ERROR, file.curr_loc, "SEEK: Error trying to seek next character in file")
    }

    return buf[0]
}

lexer :: proc(filename: string) {
    fp, fp_err := os.open(filename)
    if fp_err != nil {
        printf(.ERROR, "File not found")
    }
    defer os.close(fp)

    file := File{
        fp = fp,
        curr_loc = { line = 1, col = 0 }
    }

    curr_c := nextc(&file)
    for curr_c != 0 {
        if curr_c == 10 {
            printf(.WARNING, "Char is new line, next char is [%c]", peek(file))
        } else {
            loc_printf(.INFO, file.curr_loc, "Char: %c", curr_c)
        }
        curr_c = nextc(&file)
    }
}
