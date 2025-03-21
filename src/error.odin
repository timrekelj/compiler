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
