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
void linfo(char* fmt, ...);
void lerror(char* fmt, ...);
void lwarn(char* fmt, ...);

void linfot(Token token, char* fmt, ...);
void lerrort(Token token, char* fmt, ...);
void lwarnt(Token token, char* fmt, ...);
