enum TokenType {
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
};

typedef struct {
    int start_line;
    int start_pos;
    int end_line;
    int end_pos;
} Location;

typedef struct {
    enum TokenType tokenType;
    Location loc;
    char* value;
} Token;

// lexer.c
void lexer(char* filename);

// logging.c
void logger_log(char* fmt, ...);
void logger_error(char* fmt, ...);
void logger_warn(char* fmt, ...);
void logger_logtok(Token token, char* fmt, ...);
void logger_errortok(Token token, char* fmt, ...);
void logger_warntok(Token token, char* fmt, ...);
