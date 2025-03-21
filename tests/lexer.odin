package tests

import "core:testing"
import compiler "../src"
import "core:fmt"
import "core:log"

@(test)
everything_test :: proc(t: ^testing.T) {
    tokens, err := compiler.lexer("./tests/lexer/example.pins")

    testing.expect(t, err == nil, "Error should be nil")

    expected := []compiler.Token{{
        token_type = .NUMBER,
        start_loc = compiler.Location{line = 1, col = 1},
        end_loc = compiler.Location{line = 2, col = 0},
        value = "10"
    }, {
        token_type = .CHAR,
        start_loc = compiler.Location{line = 2, col = 1},
        end_loc = compiler.Location{line = 2, col = 3},
        value = "a"
    }, {
        token_type = .CHAR,
        start_loc = compiler.Location{line = 3, col = 1},
        end_loc = compiler.Location{line = 3, col = 4},
        value = "\\\\"
    }, {
        token_type = .CHAR,
        start_loc = compiler.Location{line = 4, col = 1},
        end_loc = compiler.Location{line = 4, col = 4},
        value = "\\'"
    }, {
        token_type = .CHAR,
        start_loc = compiler.Location{line = 5, col = 1},
        end_loc = compiler.Location{line = 5, col = 4},
        value = "\\n"
    }, {
        token_type = .CHAR,
        start_loc = compiler.Location{line = 6, col = 1},
        end_loc = compiler.Location{line = 6, col = 5},
        value = "\\12"
    }, {
        token_type = .STRING,
        start_loc = compiler.Location{line = 7, col = 1},
        end_loc = compiler.Location{line = 7, col = 13},
        value = "test_string"
    }, {
        token_type = .EQ,
        start_loc = compiler.Location{line = 8, col = 1},
        end_loc = compiler.Location{line = 8, col = 2},
        value = "=="
    }, {
        token_type = .NEQ,
        start_loc = compiler.Location{line = 9, col = 1},
        end_loc = compiler.Location{line = 9, col = 2},
        value = "!="
    }, {
        token_type = .GT,
        start_loc = compiler.Location{line = 10, col = 1},
        end_loc = compiler.Location{line = 10, col = 1},
        value = ">"
    }, {
        token_type = .LT,
        start_loc = compiler.Location{line = 11, col = 1},
        end_loc = compiler.Location{line = 11, col = 1},
        value = "<"
    }, {
        token_type = .GEQ,
        start_loc = compiler.Location{line = 12, col = 1},
        end_loc = compiler.Location{line = 12, col = 2},
        value = ">="
    }, {
        token_type = .LEQ,
        start_loc = compiler.Location{line = 13, col = 1},
        end_loc = compiler.Location{line = 13, col = 2},
        value = "<="
    }, {
        token_type = .COMMA,
        start_loc = compiler.Location{line = 14, col = 1},
        end_loc = compiler.Location{line = 14, col = 1},
        value = ","
    }, {
        token_type = .AND,
        start_loc = compiler.Location{line = 15, col = 1},
        end_loc = compiler.Location{line = 15, col = 2},
        value = "&&"
    }, {
        token_type = .OR,
        start_loc = compiler.Location{line = 16, col = 1},
        end_loc = compiler.Location{line = 16, col = 2},
        value = "||"
    }, {
        token_type = .ASSIGN,
        start_loc = compiler.Location{line = 17, col = 1},
        end_loc = compiler.Location{line = 17, col = 1},
        value = "="
    }, {
        token_type = .NOT,
        start_loc = compiler.Location{line = 18, col = 1},
        end_loc = compiler.Location{line = 18, col = 1},
        value = "!"
    }, {
        token_type = .PLUS,
        start_loc = compiler.Location{line = 19, col = 1},
        end_loc = compiler.Location{line = 19, col = 1},
        value = "+"
    }, {
        token_type = .MINUS,
        start_loc = compiler.Location{line = 20, col = 1},
        end_loc = compiler.Location{line = 20, col = 1},
        value = "-"
    }, {
        token_type = .ASTERISK,
        start_loc = compiler.Location{line = 21, col = 1},
        end_loc = compiler.Location{line = 21, col = 1},
        value = "*"
    }, {
        token_type = .SLASH,
        start_loc = compiler.Location{line = 22, col = 1},
        end_loc = compiler.Location{line = 22, col = 1},
        value = "/"
    }, {
        token_type = .PERCENT,
        start_loc = compiler.Location{line = 23, col = 1},
        end_loc = compiler.Location{line = 23, col = 1},
        value = "%"
    }, {
        token_type = .CARET,
        start_loc = compiler.Location{line = 24, col = 1},
        end_loc = compiler.Location{line = 24, col = 1},
        value = "^"
    }, {
        token_type = .LBRACKET,
        start_loc = compiler.Location{line = 25, col = 1},
        end_loc = compiler.Location{line = 25, col = 1},
        value = "("
    }, {
        token_type = .RBRACKET,
        start_loc = compiler.Location{line = 26, col = 1},
        end_loc = compiler.Location{line = 26, col = 1},
        value = ")"
    }, {
        token_type = .IDENTIFIER,
        start_loc = compiler.Location{line = 27, col = 1},
        end_loc = compiler.Location{line = 27, col = 10},
        value = "identifier"
    }, {
        token_type = .FUN,
        start_loc = compiler.Location{line = 28, col = 1},
        end_loc = compiler.Location{line = 28, col = 3},
        value = "fun"
    }, {
        token_type = .VAR,
        start_loc = compiler.Location{line = 29, col = 1},
        end_loc = compiler.Location{line = 29, col = 3},
        value = "var"
    }, {
        token_type = .IF,
        start_loc = compiler.Location{line = 30, col = 1},
        end_loc = compiler.Location{line = 30, col = 2},
        value = "if"
    }, {
        token_type = .THEN,
        start_loc = compiler.Location{line = 31, col = 1},
        end_loc = compiler.Location{line = 31, col = 4},
        value = "then"
    }, {
        token_type = .ELSE,
        start_loc = compiler.Location{line = 32, col = 1},
        end_loc = compiler.Location{line = 32, col = 4},
        value = "else"
    }, {
        token_type = .WHILE,
        start_loc = compiler.Location{line = 33, col = 1},
        end_loc = compiler.Location{line = 33, col = 5},
        value = "while"
    }, {
        token_type = .DO,
        start_loc = compiler.Location{line = 34, col = 1},
        end_loc = compiler.Location{line = 34, col = 2},
        value = "do"
    }, {
        token_type = .LET,
        start_loc = compiler.Location{line = 35, col = 1},
        end_loc = compiler.Location{line = 35, col = 3},
        value = "let"
    }, {
        token_type = .IN,
        start_loc = compiler.Location{line = 36, col = 1},
        end_loc = compiler.Location{line = 36, col = 2},
        value = "in"
    }, {
        token_type = .END,
        start_loc = compiler.Location{line = 37, col = 1},
        end_loc = compiler.Location{line = 37, col = 3},
        value = "end"
    }}

    testing.expectf(t, len(tokens) == len(expected), "Wrong length of tokens (expected %d, got %d)", len(expected), len(tokens))
    for token, i in tokens {
        testing.expectf(t, tokens[i] == expected[i], "Wrong token (expected '%s', got '%s')", expected[i].value, tokens[i].value)
    }
}
