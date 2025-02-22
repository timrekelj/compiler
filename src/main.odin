package main

import "core:fmt"

token: Token = {
    token_type = TokenType.STRING,
    value = "value",
    position = {
        start = { line = 1, col = 1 },
        end = { line = 1, col = 1 }
    }
}

main :: proc() {
    print(.INFO, "this is %s log", "INFO")
    print(.WARNING, "this is %s log", "WARNING")
    print(.ERROR, "this is %s log", "ERROR")

    fmt.println()

    print_token(.INFO, token, "this is %s log", "INFO")
    print_token(.WARNING, token, "this is %s log", "WARNING")
    print_token(.ERROR, token, "this is %s log", "ERROR")
}
