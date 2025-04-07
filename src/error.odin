package main

Error :: union #shared_nil {
    Lexer_Error,
    General_Error
}

General_Error :: enum u32 {
    None,

    Reading_File,
    Memory_Allocation,
}

Lexer_Error :: enum u32 {
    None,

    Escaped_Character,
    String,
    Incorrect_Token
}

error_string :: proc(err: Error) -> string {
    switch e in err {
        case Lexer_Error:
            switch e {
                case .Escaped_Character: return "Wrongly escaped character"
                case .String: return "Unfinished string error"
                case .Incorrect_Token: return "This token does not exists"
                case .None: return ""
            }
        case General_Error:
            switch e {
                case .Reading_File: return "Error reading file"
                case .Memory_Allocation: return "Error trying to allocate memory"
                case .None: return ""
            }
    }

    return ""
}
