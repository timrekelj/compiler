package main

import "core:fmt"
import "core:os"

main :: proc() {
    args := os.args

    if len(args) != 2 {
        print_help()
        os.exit(0)
    }

    lexer(args[1])
}

print_help :: proc() {
    fmt.println("This is a compiler for language called PINS")
    fmt.println("Usage:")
    fmt.println("\tcompiler [filename]")
}
