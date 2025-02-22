package main

TokenType :: enum {
    NUMBER,
    CHAR,
    STRING,
    EQ,
    NEQ,
    GT,
    LT,
    GEQ,
    LEQ,
    COMMA,
    AND,
    OR,
    ASSIGN,
    NOT,
    PLUS,
    MINUS,
    ASTERIX,
    SLASH,
    PERCENT,
    CARET,
    LBRACKET,
    RBRACKET
}

Location :: struct {
    line: i32,
    col: i32
}

Position :: struct {
    start: Location,
    end: Location
}

Token :: struct {
    token_type: TokenType,
    position: Position,
    value: string
}
