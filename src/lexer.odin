package main

import "core:os"
import "core:c/libc"
import "core:strings"

File :: struct {
    fp: os.Handle,
    curr_loc: Location
}

@(private="file")
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

@(private="file")
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

@(private="file")
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

@(private="file")
read_char :: proc(file: ^File) -> Token {
    start_loc: Location = file.curr_loc

    value_builder, builder_err := strings.builder_make()
    if builder_err != nil {
        loc_printf(.ERROR, start_loc, "LEX: Failed to init value builder")
    }

    curr_c := nextc(file) // the character or \
    strings.write_byte(&value_builder, curr_c)

    if curr_c == '\\' {
        curr_c = nextc(file) // escaped character
        if curr_c >= '0' && curr_c <= '9' {
            strings.write_byte(&value_builder, curr_c)
            curr_c = nextc(file) // second escaped character if it is hex

            if curr_c < '0' || curr_c > '9' {
                loc_printf(.ERROR, file.curr_loc, "LEX: The escaped HEX character is incorrect")
            }
        } else if curr_c != '\'' && curr_c != '\\' && curr_c != 't' && curr_c != 'n' {
            loc_printf(.ERROR, file.curr_loc, "LEX: The escaped character is incorrect")
        }

        strings.write_byte(&value_builder, curr_c)
    }

    curr_c = nextc(file)
    if curr_c != '\'' {
        loc_printf(.ERROR, file.curr_loc, "LEX: Character should have and end here but does not")
    }

    return {
        token_type = .CHAR,
        value = strings.to_string(value_builder),
        start_loc = start_loc,
        end_loc = file.curr_loc
    }
}

@(private="file")
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

lexer :: proc(filename: string) -> []Token {
    fp, fp_err := os.open(filename)
    if fp_err != nil {
        printf(.ERROR, "LEX: File not found")
    }
    defer os.close(fp)

    file := File{
        fp = fp,
        curr_loc = { line = 1, col = 0 }
    }

    tokens: [dynamic]Token

    curr_c := nextc(&file)
    for curr_c != 0 {
        // Keywords and identifiers
        if (curr_c >= 'a' && curr_c <= 'z') ||
            (curr_c >= 'A' && curr_c <= 'Z') ||
            (curr_c == '_') {

            start_loc := file.curr_loc
            end_loc := file.curr_loc
            name_builder, err := strings.builder_make()

            if err != nil {
                printf(.ERROR, "Error trying to make new string builder in lexer")

            }

            for (curr_c >= 'a' && curr_c <= 'z') ||
                (curr_c >= 'A' && curr_c <= 'Z') ||
                (curr_c >= '0' && curr_c <= '9') ||
                (curr_c == '_') {
                strings.write_byte(&name_builder, curr_c)
                end_loc = file.curr_loc
                curr_c = nextc(&file)
            }

            name := strings.to_string(name_builder)
            name = strings.to_lower(name)

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
                        value=name,
                        start_loc=start_loc,
                        end_loc=end_loc
                    })
            }
        }


        switch curr_c {
            case '\t', '\n', ' ': // Whitespace
                for curr_c != 0 && (curr_c == '\t' || curr_c == '\n' || curr_c == ' ') {
                    curr_c = nextc(&file)
                }
                continue
            case '0'..='9':
                append(&tokens, read_number(curr_c, &file))
            case '"':
                append(&tokens, read_string(&file))
            case '\'':
                append(&tokens, read_char(&file))
            case '=':
                next_char := peek(file)
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
                        nextc(&file)
                    case:
                        append(&tokens, Token {
                            token_type=.ASSIGN,
                            value="=",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '!':
                next_char := peek(file)
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
                        nextc(&file)
                    case:
                        append(&tokens, Token {
                            token_type=.NOT,
                            value="!",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '>':
                next_char := peek(file)
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
                        nextc(&file)
                    case:
                        append(&tokens, Token {
                            token_type=.GT,
                            value=">",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '<':
                next_char := peek(file)
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
                        nextc(&file)
                    case:
                        append(&tokens, Token {
                            token_type=.LT,
                            value="<",
                            start_loc=file.curr_loc,
                            end_loc=file.curr_loc,
                        })
                }
            case '|':
                next_char := peek(file)
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
                    nextc(&file)
                } else {
                    loc_printf(.ERROR, file.curr_loc, "Only 1 character | is an incorrect token")
                }
            case '&':
                next_char := peek(file)
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
                    nextc(&file)
                } else {
                    loc_printf(.ERROR, file.curr_loc, "Only 1 character & is an incorrect token")
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
        }
        curr_c = nextc(&file)
    }

    return tokens[:]
}
