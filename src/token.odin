package main

TokenType :: enum u32 {
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
    ASTERISK,
    SLASH,
    PERCENT,
    CARET,
    LBRACKET,
    RBRACKET,

    IDENTIFIER,

    // Keywords
	FUN,
	VAR,
	IF,
	THEN,
	ELSE,
	WHILE,
	DO,
	LET,
	IN,
	END,
	
	// Special
	EOF,
}

Location :: struct {
    line: i32,
    col: i32
}

Token :: struct {
    token_type: TokenType,
    start_loc: Location,
    end_loc: Location,
    value: string
}
