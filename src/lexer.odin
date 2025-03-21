package main

import "core:os"
import "core:fmt"
import "core:c/libc"
import "core:strings"

File :: struct {
    fp: os.Handle,
    curr_loc: Location
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

    if c == '\r' { c = '\n' }

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

    value_builder, builder_err := strings.builder_make()
    defer strings.builder_destroy(&value_builder)
    if builder_err != nil {
        err = General_Error.Memory_Allocation
        return
    }

    strings.write_byte(&value_builder, last_char)
    curr_c := nextc(file) or_return

    for curr_c >= '0' && curr_c <= '9'{
        strings.write_byte(&value_builder, curr_c)
        curr_c = nextc(file) or_return
    }

    token = Token{
        token_type = .NUMBER,
        value = strings.clone(strings.to_string(value_builder)),
        start_loc = start_loc,
        end_loc = file.curr_loc
    }

    printf(.INFO, "token: %s", token.value)
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
        if curr_c >= '0' && curr_c <= '9' {
            strings.write_byte(&value_builder, curr_c)
            curr_c = nextc(file) or_return // second escaped character if it is hex

            if curr_c < '0' || curr_c > '9' {
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

    token = {
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

        strings.write_byte(&value_builder, curr_c)
        curr_c = nextc(file) or_return
    }

    token = {
        token_type = .STRING,
        value = strings.clone(strings.to_string(value_builder)),
        start_loc = start_loc,
        end_loc = file.curr_loc
    }

    return
}

lexer :: proc(filename: string) -> (tokens: []Token, err: Error) {
    dyn_tokens: [dynamic]Token
    defer delete(dyn_tokens)

    fp, fp_err := os.open(filename)
    if fp_err != nil {
        err = General_Error.Reading_File
        return
    }
    defer os.close(fp)

    file := File{
        fp = fp,
        curr_loc = { line = 1, col = 0 }
    }

    curr_c := nextc(&file) or_return
    for curr_c != 0 {
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
            if to_lower_err != nil {
                err = General_Error.Memory_Allocation
                return
            }
            defer delete_string(name)

            switch name {
                case "fun":
                    append(&dyn_tokens, Token {
                        token_type=.FUN,
                        value="fun",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
                case "var":
                    append(&dyn_tokens, Token {
                        token_type=.VAR,
                        value="var",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "if":
                    append(&dyn_tokens, Token {
                        token_type=.IF,
                        value="if",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "then":
                    append(&dyn_tokens, Token {
                        token_type=.THEN,
                        value="then",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "else":
                    append(&dyn_tokens, Token {
                        token_type=.ELSE,
                        value="else",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "while":
                    append(&dyn_tokens, Token {
                        token_type=.WHILE,
                        value="while",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "do":
                    append(&dyn_tokens, Token {
                        token_type=.DO,
                        value="do",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "let":
                    append(&dyn_tokens, Token {
                        token_type=.LET,
                        value="let",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "in":
                    append(&dyn_tokens, Token {
                        token_type=.IN,
                        value="in",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
               	case "end":
                    append(&dyn_tokens, Token {
                        token_type=.END,
                        value="end",
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
                case:
                    append(&dyn_tokens, Token {
                        token_type=.IDENTIFIER,
                        value=name,
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
            }
        }

        switch curr_c {
            case '\t', '\n', ' ': // Whitespace
                for curr_c != 0 && (curr_c == '\t' || curr_c == '\n' || curr_c == ' ') {
                    curr_c = nextc(&file) or_return
                }
                continue
            case '0'..='9':
                num := read_number(curr_c, &file) or_return
                printf(.INFO, "num: %s", num.value)
                append(&dyn_tokens, num)
            case '"':
                str := read_string(&file) or_return
                append(&dyn_tokens, str)
            case '\'':
                c := read_char(&file) or_return
                append(&dyn_tokens, c)
            case '=':
                next_char := peek(file) or_return

                switch next_char {
                    case '=':
                        append(&dyn_tokens, Token {
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
                        append(&dyn_tokens, Token {
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
                        append(&dyn_tokens, Token {
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
                        append(&dyn_tokens, Token {
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
                        append(&dyn_tokens, Token {
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
                        append(&dyn_tokens, Token {
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
                        append(&dyn_tokens, Token {
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
                        append(&dyn_tokens, Token {
                            token_type=.LT,
                            value="<",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '|':
                next_char := peek(file) or_return

                if (next_char == '|') {
                    append(&dyn_tokens, Token {
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
                    append(&dyn_tokens, Token {
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
                append(&dyn_tokens, Token {
                    token_type=.COMMA,
                    value=",",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '(':
                append(&dyn_tokens, Token {
                    token_type=.LBRACKET,
                    value="(",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case ')':
                append(&dyn_tokens, Token {
                    token_type=.RBRACKET,
                    value=")",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '+':
                append(&dyn_tokens, Token {
                    token_type=.PLUS,
                    value="+",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '-':
                append(&dyn_tokens, Token {
                    token_type=.MINUS,
                    value="-",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '*':
                append(&dyn_tokens, Token {
                    token_type=.ASTERISK,
                    value="*",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '/':
                append(&dyn_tokens, Token {
                    token_type=.SLASH,
                    value="/",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '^':
                append(&dyn_tokens, Token {
                    token_type=.CARET,
                    value="^",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
            case '%':
                append(&dyn_tokens, Token {
                    token_type=.PERCENT,
                    value="%",
                    start_loc=file.curr_loc,
                    end_loc=file.curr_loc,
                })
        }
        curr_c = nextc(&file) or_return
    }

    tokens = dyn_tokens[:]

    return
}
