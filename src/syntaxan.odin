package main

import "core:fmt"
import "core:strings"

// AST Node Types
AST_Node :: union {
    ^AST_Program,
    ^AST_Definition,
    ^AST_VarDef,
    ^AST_FunDef,
    ^AST_Statement,
    ^AST_Expression,
    ^AST_Identifier,
    ^AST_Literal,
}

AST_Program :: struct {
    definitions: [dynamic]AST_Definition,
    statements: [dynamic]AST_Statement,
}

AST_Definition :: union {
    AST_VarDef,
    AST_FunDef,
}

AST_VarDef :: struct {
    name: AST_Identifier,
    initializers: [dynamic]AST_Initializer,
}

AST_FunDef :: struct {
    name: AST_Identifier,
    parameters: [dynamic]AST_Identifier,
    statements: [dynamic]AST_Statement,
}

AST_Statement :: union {
    AST_ExpressionStmt,
    AST_AssignmentStmt,
    AST_IfStmt,
    AST_WhileStmt,
    AST_LetStmt,
}

AST_ExpressionStmt :: struct {
    expression: ^AST_Expression,
}

AST_AssignmentStmt :: struct {
    expression: ^AST_Expression,
    value: ^AST_Expression,
}

AST_IfStmt :: struct {
    condition: ^AST_Expression,
    then_statements: [dynamic]AST_Statement,
    else_statements: [dynamic]AST_Statement,
}

AST_WhileStmt :: struct {
    condition: ^AST_Expression,
    statements: [dynamic]AST_Statement,
}

AST_LetStmt :: struct {
    definitions: [dynamic]AST_Definition,
    statements: [dynamic]AST_Statement,
}

AST_Expression :: union {
    AST_BinaryOp,
    AST_UnaryOp,
    AST_FunctionCall,
    AST_Identifier,
    AST_Literal,
}

AST_BinaryOp :: struct {
    operator: TokenType,
    left: ^AST_Expression,
    right: ^AST_Expression,
}

AST_UnaryOp :: struct {
    operator: TokenType,
    operand: ^AST_Expression,
}

AST_FunctionCall :: struct {
    function: AST_Identifier,
    arguments: [dynamic]^AST_Expression,
}

AST_Identifier :: struct {
    name: string,
}

AST_Literal :: struct {
    value: string,
    type: TokenType,
}

AST_Initializer :: union {
    AST_IntInit,
    AST_CharInit,
    AST_StringInit,
    AST_ExprInit,
}

AST_IntInit :: struct {
    value: string,
    array_size: string, // optional
    element_value: string, // optional
}

AST_CharInit :: struct {
    value: string,
}

AST_StringInit :: struct {
    value: string,
}

AST_ExprInit :: struct {
    expression: ^AST_Expression,
}

// Parser state
Parser :: struct {
    tokens: [dynamic]Token,
    current: int,
    had_error: bool,
}

// Main parsing function
parse :: proc(tokens: [dynamic]Token) -> ^AST_Program {
    parser := Parser{
        tokens = tokens,
        current = 0,
        had_error = false,
    }
    
    program := parse_program(&parser)
    
    if parser.had_error {
        return nil
    }
    
    return program
}

// Grammar: program -> definition program2
parse_program :: proc(parser: ^Parser) -> ^AST_Program {
    program := new(AST_Program)
    program.definitions = make([dynamic]AST_Definition)
    program.statements = make([dynamic]AST_Statement)
    
    for !is_at_end(parser) {
        // Try to parse a definition first
        if def, ok := parse_definition(parser); ok {
            append(&program.definitions, def)
        } else if stmt, ok := parse_statement(parser); ok {
            // If definition parsing fails, try to parse a statement
            append(&program.statements, stmt)
        } else {
            // If both fail, we have an unexpected token
            error_at_current(parser, "Unexpected token")
            break
        }
    }
    
    // Check for empty program
    if len(program.definitions) == 0 && len(program.statements) == 0 {
        error_at_current(parser, "Empty program not allowed")
    }
    
    return program
}

// Grammar: definition -> fun IDENTIFIER op parameters cp definition2 | var IDENTIFIER eq initializers
parse_definition :: proc(parser: ^Parser) -> (AST_Definition, bool) {
    token := peek(parser)
    
    #partial switch token.token_type {
    case .VAR:
        return parse_var_definition(parser)
    case .FUN:
        return parse_fun_definition(parser)
    case:
        return {}, false
    }
}

// Grammar: var IDENTIFIER eq initializers
parse_var_definition :: proc(parser: ^Parser) -> (AST_Definition, bool) {
    consume(parser, .VAR, "Expected 'var'")
    
    name_token := consume(parser, .IDENTIFIER, "Expected variable name")
    name := AST_Identifier{name = name_token.value}
    
    consume(parser, .ASSIGN, "Expected '='")
    
    initializers := parse_initializers(parser)
    
    // Check if we have an equals sign but no initializers
    if len(initializers) == 0 {
        error_at_current(parser, "Expected initializer after '='")
        return {}, false
    }
    
    var_def := AST_VarDef{
        name = name,
        initializers = initializers,
    }
    
    return var_def, true
}

// Grammar: fun IDENTIFIER op parameters cp definition2
parse_fun_definition :: proc(parser: ^Parser) -> (AST_Definition, bool) {
    consume(parser, .FUN, "Expected 'fun'")
    
    name_token := consume(parser, .IDENTIFIER, "Expected function name")
    name := AST_Identifier{name = name_token.value}
    
    consume(parser, .LBRACKET, "Expected '('")
    parameters := parse_parameters(parser)
    consume(parser, .RBRACKET, "Expected ')'")
    
    fun_def := AST_FunDef{
        name = name,
        parameters = parameters,
        statements = make([dynamic]AST_Statement),
    }
    
    // Check for function body (assignment followed by statements)
    if check(parser, .ASSIGN) {
        advance(parser)
        fun_def.statements = parse_statements(parser)
    }
    
    return fun_def, true
}

// Grammar: parameters -> IDENTIFIER parameters2 | (empty)
parse_parameters :: proc(parser: ^Parser) -> [dynamic]AST_Identifier {
    parameters := make([dynamic]AST_Identifier)
    
    if !check(parser, .IDENTIFIER) {
        return parameters
    }
    
    // First parameter
    name_token := advance(parser)
    param := AST_Identifier{name = name_token.value}
    append(&parameters, param)
    
    // Additional parameters (comma separated)
    for check(parser, .COMMA) {
        advance(parser) // consume comma
        name_token = consume(parser, .IDENTIFIER, "Expected parameter name")
        param = AST_Identifier{name = name_token.value}
        append(&parameters, param)
    }
    
    return parameters
}

// Grammar: statements -> statement statements2
parse_statements :: proc(parser: ^Parser) -> [dynamic]AST_Statement {
    statements := make([dynamic]AST_Statement)
    
    if stmt, ok := parse_statement(parser); ok {
        append(&statements, stmt)
        
        // Parse additional statements (comma separated)
        for check(parser, .COMMA) {
            advance(parser) // consume comma
            if stmt, stmt_ok := parse_statement(parser); stmt_ok {
                append(&statements, stmt)
            }
        }
    }
    
    return statements
}

// Grammar: statement -> expression statement2 | if expression then statements statementIfElse | while expression do statements end | let statementDef in statements end
parse_statement :: proc(parser: ^Parser) -> (AST_Statement, bool) {
    #partial switch peek(parser).token_type {
    case .IF:
        return parse_if_statement(parser)
    case .WHILE:
        return parse_while_statement(parser)
    case .LET:
        return parse_let_statement(parser)
    case:
        return parse_expression_statement(parser)
    }
}

parse_if_statement :: proc(parser: ^Parser) -> (AST_Statement, bool) {
    consume(parser, .IF, "Expected 'if'")
    condition := parse_expression(parser)
    consume(parser, .THEN, "Expected 'then'")
    then_statements := parse_statements(parser)
    
    condition_ptr := new(AST_Expression)
    condition_ptr^ = condition
    if_stmt := AST_IfStmt{
        condition = condition_ptr,
        then_statements = then_statements,
        else_statements = make([dynamic]AST_Statement),
    }
    
    if check(parser, .ELSE) {
        advance(parser)
        if_stmt.else_statements = parse_statements(parser)
    }
    
    consume(parser, .END, "Expected 'end'")
    return if_stmt, true
}

parse_while_statement :: proc(parser: ^Parser) -> (AST_Statement, bool) {
    consume(parser, .WHILE, "Expected 'while'")
    condition := parse_expression(parser)
    consume(parser, .DO, "Expected 'do'")
    statements := parse_statements(parser)
    consume(parser, .END, "Expected 'end'")
    
    condition_ptr := new(AST_Expression)
    condition_ptr^ = condition
    while_stmt := AST_WhileStmt{
        condition = condition_ptr,
        statements = statements,
    }
    
    return while_stmt, true
}

parse_let_statement :: proc(parser: ^Parser) -> (AST_Statement, bool) {
    consume(parser, .LET, "Expected 'let'")
    definitions := make([dynamic]AST_Definition)
    
    // Parse definitions
    for def, ok := parse_definition(parser); ok; def, ok = parse_definition(parser) {
        append(&definitions, def)
    }
    
    consume(parser, .IN, "Expected 'in'")
    statements := parse_statements(parser)
    consume(parser, .END, "Expected 'end'")
    
    let_stmt := AST_LetStmt{
        definitions = definitions,
        statements = statements,
    }
    
    return let_stmt, true
}

parse_expression_statement :: proc(parser: ^Parser) -> (AST_Statement, bool) {
    expr := parse_expression(parser)
    
    if check(parser, .ASSIGN) {
        advance(parser) // consume '='
        value := parse_expression(parser)
        
        expr_ptr := new(AST_Expression)
        expr_ptr^ = expr
        value_ptr := new(AST_Expression)
        value_ptr^ = value
        assign_stmt := AST_AssignmentStmt{
            expression = expr_ptr,
            value = value_ptr,
        }
        return assign_stmt, true
    }
    
    expr_ptr := new(AST_Expression)
    expr_ptr^ = expr
    expr_stmt := AST_ExpressionStmt{expression = expr_ptr}
    return expr_stmt, true
}

// Grammar: expression -> orExpression
parse_expression :: proc(parser: ^Parser) -> AST_Expression {
    return parse_or_expression(parser)
}

// Grammar: orExpression -> andExpression orExpression2
parse_or_expression :: proc(parser: ^Parser) -> AST_Expression {
    expr := parse_and_expression(parser)
    
    for check(parser, .OR) {
        operator := advance(parser)
        right := parse_or_expression(parser)
        
        left_expr := new(AST_Expression)
        left_expr^ = expr
        right_expr := new(AST_Expression)
        right_expr^ = right
        binary_op := AST_BinaryOp{
            operator = operator.token_type,
            left = left_expr,
            right = right_expr,
        }
        expr = binary_op
    }
    
    return expr
}

// Grammar: andExpression -> compExpression andExpression2
parse_and_expression :: proc(parser: ^Parser) -> AST_Expression {
    expr := parse_comp_expression(parser)
    
    for check(parser, .AND) {
        operator := advance(parser)
        right := parse_and_expression(parser)
        
        left_expr := new(AST_Expression)
        left_expr^ = expr
        right_expr := new(AST_Expression)
        right_expr^ = right
        binary_op := AST_BinaryOp{
            operator = operator.token_type,
            left = left_expr,
            right = right_expr,
        }
        expr = binary_op
    }
    
    return expr
}

// Grammar: compExpression -> addExpression compExpression2
parse_comp_expression :: proc(parser: ^Parser) -> AST_Expression {
    expr := parse_add_expression(parser)
    
    if match(parser, .EQ, .NEQ, .LT, .GT, .LEQ, .GEQ) {
        operator := previous(parser)
        right := parse_add_expression(parser)
        
        left_expr := new(AST_Expression)
        left_expr^ = expr
        right_expr := new(AST_Expression)
        right_expr^ = right
        binary_op := AST_BinaryOp{
            operator = operator.token_type,
            left = left_expr,
            right = right_expr,
        }
        expr = binary_op
    }
    
    return expr
}

// Grammar: addExpression -> mulExpression addExpression2
parse_add_expression :: proc(parser: ^Parser) -> AST_Expression {
    expr := parse_mul_expression(parser)
    
    for match(parser, .PLUS, .MINUS) {
        operator := previous(parser)
        right := parse_mul_expression(parser)
        
        left_expr := new(AST_Expression)
        left_expr^ = expr
        right_expr := new(AST_Expression)
        right_expr^ = right
        binary_op := AST_BinaryOp{
            operator = operator.token_type,
            left = left_expr,
            right = right_expr,
        }
        expr = binary_op
    }
    
    return expr
}

// Grammar: mulExpression -> prefixExpression mulExpression2
parse_mul_expression :: proc(parser: ^Parser) -> AST_Expression {
    expr := parse_prefix_expression(parser)
    
    for match(parser, .ASTERISK, .SLASH, .PERCENT) {
        operator := previous(parser)
        right := parse_prefix_expression(parser)
        
        left_expr := new(AST_Expression)
        left_expr^ = expr
        right_expr := new(AST_Expression)
        right_expr^ = right
        binary_op := AST_BinaryOp{
            operator = operator.token_type,
            left = left_expr,
            right = right_expr,
        }
        expr = binary_op
    }
    
    return expr
}

// Grammar: prefixExpression -> postfixExpression | NOT prefixExpression | SUB prefixExpression | ADD prefixExpression | PTR prefixExpression
parse_prefix_expression :: proc(parser: ^Parser) -> AST_Expression {
    if match(parser, .NOT, .MINUS, .PLUS, .CARET) {
        operator := previous(parser)
        expr := parse_prefix_expression(parser)
        
        operand_expr := new(AST_Expression)
        operand_expr^ = expr
        unary_op := AST_UnaryOp{
            operator = operator.token_type,
            operand = operand_expr,
        }
        return unary_op
    }
    
    return parse_postfix_expression(parser)
}

// Grammar: postfixExpression -> primaryExpression postfixExpression2
parse_postfix_expression :: proc(parser: ^Parser) -> AST_Expression {
    expr := parse_primary_expression(parser)
    
    for check(parser, .CARET) {
        advance(parser) // consume '^'
        
        operand_expr := new(AST_Expression)
        operand_expr^ = expr
        unary_op := AST_UnaryOp{
            operator = .CARET,
            operand = operand_expr,
        }
        expr = unary_op
    }
    
    return expr
}

// Grammar: primaryExpr -> INTCONST | CHARCONST | STRINGCONST | IDENTIFIER primaryExpr2 | OP expression CP
parse_primary_expression :: proc(parser: ^Parser) -> AST_Expression {
    #partial switch peek(parser).token_type {
    case .NUMBER:
        token := advance(parser)
        literal := AST_Literal{
            value = token.value,
            type = token.token_type,
        }
        return literal
        
    case .CHAR:
        token := advance(parser)
        literal := AST_Literal{
            value = token.value,
            type = token.token_type,
        }
        return literal
        
    case .STRING:
        token := advance(parser)
        literal := AST_Literal{
            value = token.value,
            type = token.token_type,
        }
        return literal
        
    case .IDENTIFIER:
        token := advance(parser)
        identifier := AST_Identifier{name = token.value}
        
        // Check for function call
        if check(parser, .LBRACKET) {
            advance(parser) // consume '('
            arguments := parse_arguments(parser)
            consume(parser, .RBRACKET, "Expected ')'")
            
            func_call := AST_FunctionCall{
                function = identifier,
                arguments = arguments,
            }
            return func_call
        }
        
        return identifier
        
    case .LBRACKET:
        advance(parser) // consume '('
        
        // Handle empty parentheses as unit expression
        if check(parser, .RBRACKET) {
            advance(parser) // consume ')'
            unit_literal := AST_Literal{
                value = "()",
                type = .LBRACKET, // Use LBRACKET as marker for unit type
            }
            return unit_literal
        }
        
        expr := parse_expression(parser)
        consume(parser, .RBRACKET, "Expected ')' after expression")
        return expr
        
    case .EOF:
        error_at_current(parser, "Unexpected end of file")
        return AST_Literal{} // Return empty literal as fallback
        
    case:
        error_at_current(parser, "Expected expression")
        return AST_Literal{} // Return empty literal as fallback
    }
}

// Grammar: arguments -> expression arguments2 | (empty)
parse_arguments :: proc(parser: ^Parser) -> [dynamic]^AST_Expression {
    arguments := make([dynamic]^AST_Expression)
    
    if check(parser, .RBRACKET) {
        return arguments
    }
    
    expr := parse_expression(parser)
    expr_ptr := new(AST_Expression)
    expr_ptr^ = expr
    append(&arguments, expr_ptr)
    
    for check(parser, .COMMA) {
        advance(parser) // consume comma
        expr = parse_expression(parser)
        expr_ptr = new(AST_Expression)
        expr_ptr^ = expr
        append(&arguments, expr_ptr)
    }
    
    return arguments
}

// Grammar: initializers -> initializer initializers2 | (empty)
parse_initializers :: proc(parser: ^Parser) -> [dynamic]AST_Initializer {
    initializers := make([dynamic]AST_Initializer)
    
    if init, ok := parse_initializer(parser); ok {
        append(&initializers, init)
        
        for check(parser, .COMMA) {
            advance(parser) // consume comma
            if init, init_ok := parse_initializer(parser); init_ok {
                append(&initializers, init)
            }
        }
    }
    
    return initializers
}

// Grammar: initializer -> INTCONST initializer2 | CHARCONST | STRINGCONST
parse_initializer :: proc(parser: ^Parser) -> (AST_Initializer, bool) {
    // Try to parse as expression first
    current_pos := parser.current
    expr := parse_expression(parser)
    
    // Check if we successfully parsed an expression (advanced the parser position)
    if parser.current > current_pos {
        expr_ptr := new(AST_Expression)
        expr_ptr^ = expr
        expr_init := AST_ExprInit{expression = expr_ptr}
        return expr_init, true
    }
    
    // If expression parsing didn't advance, try literal parsing
    #partial switch peek(parser).token_type {
    case .NUMBER:
        token := advance(parser)
        int_init := AST_IntInit{value = token.value}
        
        // Check for array initialization
        if check(parser, .ASTERISK) {
            advance(parser) // consume '*'
            
            if check(parser, .NUMBER) || check(parser, .CHAR) || check(parser, .STRING) {
                size_token := advance(parser)
                int_init.array_size = size_token.value
            }
        }
        
        return int_init, true
        
    case .CHAR:
        token := advance(parser)
        char_init := AST_CharInit{value = token.value}
        return char_init, true
        
    case .STRING:
        token := advance(parser)
        string_init := AST_StringInit{value = token.value}
        return string_init, true
        
    case:
        return {}, false
    }
}

// Helper functions
is_at_end :: proc(parser: ^Parser) -> bool {
    return parser.current >= len(parser.tokens)
}

peek :: proc(parser: ^Parser) -> Token {
    if is_at_end(parser) {
        // Return a dummy EOF token
        return Token{token_type = .EOF, value = "", start_loc = Location{}, end_loc = Location{}}
    }
    return parser.tokens[parser.current]
}

previous :: proc(parser: ^Parser) -> Token {
    return parser.tokens[parser.current - 1]
}

advance :: proc(parser: ^Parser) -> Token {
    if !is_at_end(parser) {
        parser.current += 1
    }
    return previous(parser)
}

check :: proc(parser: ^Parser, type: TokenType) -> bool {
    if is_at_end(parser) {
        return false
    }
    return peek(parser).token_type == type
}

match :: proc(parser: ^Parser, types: ..TokenType) -> bool {
    for type in types {
        if check(parser, type) {
            advance(parser)
            return true
        }
    }
    return false
}

consume :: proc(parser: ^Parser, type: TokenType, message: string) -> Token {
    if check(parser, type) {
        return advance(parser)
    }
    
    error_at_current(parser, message)
    return Token{}
}

error_at_current :: proc(parser: ^Parser, message: string) {
    token := peek(parser)
    printf(.ERROR, "Parse error at line %d, col %d: %s. Got '%s'", 
           token.start_loc.line, token.start_loc.col, message, token.value)
    parser.had_error = true
}

// AST Printing function for debugging
print_ast :: proc(program: ^AST_Program) {
    if program == nil {
        printf(.INFO, "AST: (null)")
        return
    }
    
    printf(.INFO, "AST Program:")
    printf(.INFO, "  Total definitions: %d", len(program.definitions))
    for def, i in program.definitions {
        printf(.INFO, "  Definition %d:", i)
        if def == nil {
            printf(.INFO, "    (null definition)")
        } else {
            print_definition(def, 4)
        }
    }
    
    printf(.INFO, "  Total statements: %d", len(program.statements))
    for stmt, i in program.statements {
        printf(.INFO, "  Statement %d:", i)
        print_statement(stmt, 4)
    }
}

print_definition :: proc(def: AST_Definition, indent: int) {
    spaces := strings.repeat(" ", indent)
    defer delete(spaces)
    
    switch d in def {
    case AST_VarDef:
        printf(.INFO, "%sVariable: %s", spaces, d.name.name)
        printf(.INFO, "%s  Initializers (%d):", spaces, len(d.initializers))
        for init, i in d.initializers {
            printf(.INFO, "%s    [%d]:", spaces, i)
            print_initializer(init, indent + 6)
        }
        
    case AST_FunDef:
        printf(.INFO, "%sFunction: %s", spaces, d.name.name)
        printf(.INFO, "%s  Parameters (%d):", spaces, len(d.parameters))
        for param, i in d.parameters {
            printf(.INFO, "%s    [%d]: %s", spaces, i, param.name)
        }
        printf(.INFO, "%s  Statements (%d):", spaces, len(d.statements))
        for stmt, i in d.statements {
            printf(.INFO, "%s    [%d]:", spaces, i)
            print_statement(stmt, indent + 6)
        }
    }
}

print_initializer :: proc(init: AST_Initializer, indent: int) {
    spaces := strings.repeat(" ", indent)
    defer delete(spaces)
    
    switch i in init {
    case AST_IntInit:
        printf(.INFO, "%sInt: %s", spaces, i.value)
        if i.array_size != "" {
            printf(.INFO, "%s  Array size: %s", spaces, i.array_size)
        }
        if i.element_value != "" {
            printf(.INFO, "%s  Element value: %s", spaces, i.element_value)
        }
        
    case AST_CharInit:
        printf(.INFO, "%sChar: %s", spaces, i.value)
        
    case AST_StringInit:
        printf(.INFO, "%sString: %s", spaces, i.value)
        
    case AST_ExprInit:
        printf(.INFO, "%sExpression:", spaces)
        print_expression(i.expression^, indent + 2)
    }
}

print_statement :: proc(stmt: AST_Statement, indent: int) {
    spaces := strings.repeat(" ", indent)
    defer delete(spaces)
    
    switch s in stmt {
    case AST_ExpressionStmt:
        printf(.INFO, "%sExpression Statement", spaces)
        print_expression(s.expression^, indent + 2)
        
    case AST_AssignmentStmt:
        printf(.INFO, "%sAssignment Statement", spaces)
        printf(.INFO, "%s  Left:", spaces)
        print_expression(s.expression^, indent + 4)
        printf(.INFO, "%s  Right:", spaces)
        print_expression(s.value^, indent + 4)
        
    case AST_IfStmt:
        printf(.INFO, "%sIf Statement", spaces)
        printf(.INFO, "%s  Condition:", spaces)
        print_expression(s.condition^, indent + 4)
        printf(.INFO, "%s  Then (%d statements):", spaces, len(s.then_statements))
        for stmt_item in s.then_statements {
            print_statement(stmt_item, indent + 4)
        }
        if len(s.else_statements) > 0 {
            printf(.INFO, "%s  Else (%d statements):", spaces, len(s.else_statements))
            for stmt_item in s.else_statements {
                print_statement(stmt_item, indent + 4)
            }
        }
        
    case AST_WhileStmt:
        printf(.INFO, "%sWhile Statement", spaces)
        printf(.INFO, "%s  Condition:", spaces)
        print_expression(s.condition^, indent + 4)
        printf(.INFO, "%s  Body (%d statements):", spaces, len(s.statements))
        for stmt_item in s.statements {
            print_statement(stmt_item, indent + 4)
        }
        
    case AST_LetStmt:
        printf(.INFO, "%sLet Statement", spaces)
        printf(.INFO, "%s  Definitions (%d):", spaces, len(s.definitions))
        for def in s.definitions {
            print_definition(def, indent + 4)
        }
        printf(.INFO, "%s  Statements (%d):", spaces, len(s.statements))
        for stmt_item in s.statements {
            print_statement(stmt_item, indent + 4)
        }
    }
}

print_expression :: proc(expr: AST_Expression, indent: int) {
    spaces := strings.repeat(" ", indent)
    defer delete(spaces)
    
    switch e in expr {
    case AST_BinaryOp:
        printf(.INFO, "%sBinary Op: %v", spaces, e.operator)
        printf(.INFO, "%s  Left:", spaces)
        print_expression(e.left^, indent + 4)
        printf(.INFO, "%s  Right:", spaces)
        print_expression(e.right^, indent + 4)
        
    case AST_UnaryOp:
        printf(.INFO, "%sUnary Op: %v", spaces, e.operator)
        printf(.INFO, "%s  Operand:", spaces)
        print_expression(e.operand^, indent + 4)
        
    case AST_FunctionCall:
        printf(.INFO, "%sFunction Call: %s", spaces, e.function.name)
        printf(.INFO, "%s  Arguments (%d):", spaces, len(e.arguments))
        for arg, i in e.arguments {
            printf(.INFO, "%s    [%d]:", spaces, i)
            print_expression(arg^, indent + 6)
        }
        
    case AST_Identifier:
        printf(.INFO, "%sIdentifier: %s", spaces, e.name)
        
    case AST_Literal:
        printf(.INFO, "%sLiteral: %s (%v)", spaces, e.value, e.type)
    }
}