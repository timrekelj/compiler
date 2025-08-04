package main

import "core:os"
import "core:fmt"
import "core:c/libc"
import "core:strings"

File :: struct {
    fp: os.Handle,
    curr_loc: Location,
    last_was_cr: bool
}

@(private="file")
nextc :: proc(file: ^File) -> (c: u8, err: Error) {
    buf := make([]byte, 1)
    defer delete(buf)

    _, read_err := os.read(file.fp, buf)
    if read_err != nil {
        err = General_Error.Reading_File
        return
    }

    c = buf[0]

    // Handle Windows line endings (\r\n) properly
    if c == '\r' {
        c = '\n'
        file.last_was_cr = true
    } else if c == '\n' && file.last_was_cr {
        // This is the \n part of \r\n, skip line increment
        file.last_was_cr = false
        file.curr_loc.col += 1
        return
    } else {
        file.last_was_cr = false
    }

    if c == '\n' {
        file.curr_loc.col = 0
        file.curr_loc.line += 1
    } else {
        file.curr_loc.col += 1
    }

    defer if err != nil {
        c = 0
    }

    return
}

@(private="file")
peek :: proc(file: File) -> (c: u8, err: Error) {
    buf := make([]byte, 1)
    defer delete(buf)

    _, read_err := os.read(file.fp, buf)
    if read_err != nil {
        err = General_Error.Reading_File
        return
    }

    c = buf[0]

    // Do not go back if next character is EOF
    if c == 0 {
        return
    }

    _, seek_err := os.seek(file.fp, -1, os.SEEK_CUR)
    if seek_err != nil {
        err = General_Error.Reading_File
        return
    }

    return
}

@(private="file")
read_number :: proc(last_char: u8, file: ^File) -> (token: Token, err: Error) {
    start_loc: Location = file.curr_loc
    end_loc: Location = file.curr_loc

    value_builder, builder_err := strings.builder_make()
    defer strings.builder_destroy(&value_builder)
    if builder_err != nil {
        err = General_Error.Memory_Allocation
        return
    }

    strings.write_byte(&value_builder, last_char)
    end_loc = file.curr_loc

    // Read additional digits if they exist
    for {
        next_char := peek(file^) or_return
        if next_char < '0' || next_char > '9' {
            break
        }
        curr_c := nextc(file) or_return
        end_loc = file.curr_loc
        strings.write_byte(&value_builder, curr_c)
    }

    token = Token{
        token_type = .NUMBER,
        value = strings.clone(strings.to_string(value_builder)),
        start_loc = start_loc,
        end_loc = end_loc
    }
    return
}

@(private="file")
read_char :: proc(file: ^File) -> (token: Token, err: Error) {
    start_loc: Location = file.curr_loc

    value_builder, builder_err := strings.builder_make()
    defer strings.builder_destroy(&value_builder)
    if builder_err != nil {
        err = General_Error.Memory_Allocation
        return
    }

    curr_c := nextc(file) or_return // the character or \
    strings.write_byte(&value_builder, curr_c)

    if curr_c == '\\' {
        curr_c = nextc(file) or_return // escaped character
        if (curr_c >= '0' && curr_c <= '9') || (curr_c >= 'A' && curr_c <= 'F') {
            strings.write_byte(&value_builder, curr_c)
            curr_c = nextc(file) or_return // second escaped character if it is hex

            if !((curr_c >= '0' && curr_c <= '9') || (curr_c >= 'A' && curr_c <= 'F')) {
                err = Lexer_Error.Escaped_Character
                return
            }
        } else if curr_c != '\'' && curr_c != '\\' && curr_c != 't' && curr_c != 'n' {
            err = Lexer_Error.Escaped_Character
            return
        }

        strings.write_byte(&value_builder, curr_c)
    }


    curr_c = nextc(file) or_return
    if curr_c != '\'' {
        err = Lexer_Error.Escaped_Character
        return
    }

    token = Token{
        token_type = .CHAR,
        value = strings.clone(strings.to_string(value_builder)),
        start_loc = start_loc,
        end_loc = file.curr_loc
    }

    return
}

@(private="file")
read_string :: proc(file: ^File) -> (token: Token, err: Error) {
    start_loc: Location = file.curr_loc

    value_builder, builder_err := strings.builder_make()
    defer strings.builder_destroy(&value_builder)
    if builder_err != nil {
        err = General_Error.Memory_Allocation
        return
    }

    curr_c := nextc(file) or_return

    for curr_c != '"' {
        if curr_c == 0 || curr_c == '\n' {
            err = Lexer_Error.String
            return
        }

        if curr_c == '\\' {
            curr_c = nextc(file) or_return // escaped character
            
            if curr_c == 0 {
                err = Lexer_Error.String
                return
            }
            
            // Handle escape sequences
            switch curr_c {
            case 'n':
                strings.write_byte(&value_builder, '\n')
            case 't':
                strings.write_byte(&value_builder, '\t')
            case '\\':
                strings.write_byte(&value_builder, '\\')
            case '"':
                strings.write_byte(&value_builder, '"')
            case '0'..='9', 'A'..='F':
                // Handle hex escape sequences \XX
                first_digit := curr_c
                curr_c = nextc(file) or_return // second hex character
                
                if curr_c == 0 {
                    err = Lexer_Error.String
                    return
                }
                
                if !((curr_c >= '0' && curr_c <= '9') || (curr_c >= 'A' && curr_c <= 'F')) {
                    err = Lexer_Error.Escaped_Character
                    return
                }
                
                // Convert hex digits to byte value
                first_val: u8
                second_val: u8
                
                if first_digit >= '0' && first_digit <= '9' {
                    first_val = u8(first_digit - '0')
                } else {
                    first_val = u8(first_digit - 'A' + 10)
                }
                
                if curr_c >= '0' && curr_c <= '9' {
                    second_val = u8(curr_c - '0')
                } else {
                    second_val = u8(curr_c - 'A' + 10)
                }
                
                byte_val := first_val * 16 + second_val
                strings.write_byte(&value_builder, byte_val)
            case:
                err = Lexer_Error.Escaped_Character
                return
            }
        } else {
            strings.write_byte(&value_builder, curr_c)
        }
        curr_c = nextc(file) or_return
    }

    token = Token{
        token_type = .STRING,
        value = strings.clone(strings.to_string(value_builder)),
        start_loc = start_loc,
        end_loc = file.curr_loc
    }

    return
}

lexer :: proc(filename: string) -> (tokens: [dynamic]Token, err: Error) {
    fp, fp_err := os.open(filename)
    if fp_err != nil {
        err = General_Error.Reading_File
        return
    }
    defer os.close(fp)

    file := File{
        fp = fp,
        curr_loc = { line = 1, col = 0 },
        last_was_cr = false
    }

    curr_c: u8
    for {
        curr_c = nextc(&file) or_return

        if curr_c == 0 { break }

        // Keywords and identifiers
        if (curr_c >= 'a' && curr_c <= 'z') ||
            (curr_c >= 'A' && curr_c <= 'Z') ||
            (curr_c == '_') {

            start_loc := file.curr_loc
            end_loc := file.curr_loc
            name_builder, builder_err := strings.builder_make()
            defer strings.builder_destroy(&name_builder)

            if builder_err != nil {
                err = General_Error.Memory_Allocation
                return
            }

            for (curr_c >= 'a' && curr_c <= 'z') ||
                (curr_c >= 'A' && curr_c <= 'Z') ||
                (curr_c >= '0' && curr_c <= '9') ||
                (curr_c == '_') {
                strings.write_byte(&name_builder, curr_c)
                end_loc = file.curr_loc
                curr_c = nextc(&file) or_return
            }

            name, to_lower_err := strings.clone(strings.to_string(name_builder))
            defer delete_string(name)
            if to_lower_err != nil {
                err = General_Error.Memory_Allocation
                return
            }

            switch name {
                case "fun":
                    append(&tokens, Token {
                        token_type=.FUN,
                        value="fun",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
                case "var":
                    append(&tokens, Token {
                        token_type=.VAR,
                        value="var",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "if":
                    append(&tokens, Token {
                        token_type=.IF,
                        value="if",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "then":
                    append(&tokens, Token {
                        token_type=.THEN,
                        value="then",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "else":
                    append(&tokens, Token {
                        token_type=.ELSE,
                        value="else",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "while":
                    append(&tokens, Token {
                        token_type=.WHILE,
                        value="while",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "do":
                    append(&tokens, Token {
                        token_type=.DO,
                        value="do",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "let":
                    append(&tokens, Token {
                        token_type=.LET,
                        value="let",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "in":
                    append(&tokens, Token {
                        token_type=.IN,
                        value="in",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "end":
                    append(&tokens, Token {
                        token_type=.END,
                        value="end",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
                case:
                    append(&tokens, Token {
                        token_type=.IDENTIFIER,
                        value=strings.clone(name),
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
            }
            // Don't continue here - process the character that terminated the identifier
            
            // Check for EOF after identifier processing
            if curr_c == 0 { break }
        }

        switch curr_c {
            case '\t', '\n', ' ': // Whitespace
                next_c := peek(file) or_return
                for next_c != 0 && (next_c == '\t' || next_c == '\n' || next_c == ' ') {
                    nextc(&file) or_return
                    next_c = peek(file) or_return
                }
                continue
            case '0'..='9':
                num := read_number(curr_c, &file) or_return
                append(&tokens, num)
                continue
            case '"':
                str := read_string(&file) or_return
                append(&tokens, str)
            case '\'':
                c := read_char(&file) or_return
                append(&tokens, c)
            case '=':
                next_char := peek(file) or_return

                switch next_char {
                    case '=':
                        append(&tokens, Token {
                            token_type=.EQ,
                            value="==",
                            start_loc=file.curr_loc,
                            end_loc={
                                col=file.curr_loc.col + 1,
                                line=file.curr_loc.line
                            }
                        })
                        nextc(&file) or_return
                    case:
                        append(&tokens, Token {
                            token_type=.ASSIGN,
                            value="=",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '!':
                next_char := peek(file) or_return

                switch next_char {
                    case '=':
                        append(&tokens, Token {
                            token_type=.NEQ,
                            value="!=",
                            start_loc=file.curr_loc,
                            end_loc={
                                col=file.curr_loc.col + 1,
                                line=file.curr_loc.line
                            }
                        })
                        nextc(&file) or_return
                    case:
                        append(&tokens, Token {
                            token_type=.NOT,
                            value="!",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '>':
                next_char := peek(file) or_return

                switch next_char {
                    case '=':
                        append(&tokens, Token {
                            token_type=.GEQ,
                            value=">=",
                            start_loc=file.curr_loc,
                            end_loc={
                                col=file.curr_loc.col + 1,
                                line=file.curr_loc.line
                            }
                        })
                        nextc(&file) or_return
                    case:
                        append(&tokens, Token {
                            token_type=.GT,
                            value=">",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '<':
                next_char := peek(file) or_return

                switch next_char {
                    case '=':
                        append(&tokens, Token {
                            token_type=.LEQ,
                            value="<=",
                            start_loc=file.curr_loc,
                            end_loc={
                                col=file.curr_loc.col + 1,
                                line=file.curr_loc.line
                            }
                        })
                        nextc(&file) or_return
                    case:
                        append(&tokens, Token {
                            token_type=.LT,
                            value="<",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '|':
                next_char := peek(file) or_return

                if (next_char == '|') {
                    append(&tokens, Token {
                        token_type=.OR,
                        value="||",
                        start_loc=file.curr_loc,
                        end_loc={
                            col=file.curr_loc.col + 1,
                            line=file.curr_loc.line
                        }
                    })
                    nextc(&file) or_return
                } else {
                    err = Lexer_Error.Incorrect_Token
                    return
                }
            case '&':
                next_char := peek(file) or_return

                if (next_char == '&') {
                    append(&tokens, Token {
                        token_type=.AND,
                        value="&&",
                        start_loc=file.curr_loc,
                        end_loc={
                            col=file.curr_loc.col + 1,
                            line=file.curr_loc.line
                        }
                    })
                    nextc(&file) or_return
                } else {
                    err = Lexer_Error.Incorrect_Token
                    return
                }
            case ',':
                append(&tokens, Token {
                    token_type=.COMMA,
                    value=",",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '(':
                append(&tokens, Token {
                    token_type=.LBRACKET,
                    value="(",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case ')':
                append(&tokens, Token {
                    token_type=.RBRACKET,
                    value=")",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '+':
                append(&tokens, Token {
                    token_type=.PLUS,
                    value="+",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '-':
                append(&tokens, Token {
                    token_type=.MINUS,
                    value="-",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '*':
                append(&tokens, Token {
                    token_type=.ASTERISK,
                    value="*",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '/':
                append(&tokens, Token {
                    token_type=.SLASH,
                    value="/",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '^':
                append(&tokens, Token {
                    token_type=.CARET,
                    value="^",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '%':
                append(&tokens, Token {
                    token_type=.PERCENT,
                    value="%",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '#':
                // Skip comment until end of line
                for {
                    next_char := peek(file) or_return
                    if next_char == '\n' || next_char == 0 {
                        break
                    }
                    nextc(&file) or_return
                }
            case:
                err = Lexer_Error.Incorrect_Token
        }
    }

    return
}

cleanup_tokens :: proc(tokens: ^[dynamic]Token) {
    for token in tokens {
        if token.token_type == .IDENTIFIER ||
           token.token_type == .STRING ||
           token.token_type == .CHAR ||
           token.token_type == .NUMBER {
            delete(token.value)
        }
    }
    delete(tokens^)
}

print_tokens :: proc(tokens: ^[dynamic]Token) {
    for token in tokens {
		printf(
			.INFO,
			"%s: %s (%d:%d - %d:%d)",
			token.token_type,
			token.value,
			token.start_loc.line,
			token.start_loc.col,
			token.end_loc.line,
			token.end_loc.col,
		)
	}
}
