package main

import "core:fmt"
import "core:strings"
import "core:slice"

// Semantic attributes for AST nodes
SemanticAttr :: struct {
    // Map from expression pointers to their definitions
    name_defs: map[rawptr]rawptr, // ^AST_Expression -> ^AST_Definition or ^AST_Identifier
    // Map from expression pointers to whether they are l-values
    lval_map: map[rawptr]bool,    // ^AST_Expression -> bool
}

// Extended AST with semantic attributes
AttrAST :: struct {
    ast: ^AST_Program,
    attrs: SemanticAttr,
}

// Definition type enum
DefinitionType :: enum {
    VAR_DEF,
    FUN_DEF,
    PARAM_DEF,
}

// Symbol table entry
ScopedDef :: struct {
    depth: int,
    def: rawptr, // Points to AST_Definition or AST_Identifier for parameters
    def_type: DefinitionType,
}

// Symbol table for name resolution
SymbolTable :: struct {
    // Map from name to list of definitions at different scopes
    name_to_defs: map[string][dynamic]ScopedDef,
    // Stack of scopes - each scope contains names defined at that level
    scopes: [dynamic][dynamic]string,
    // Current scope depth
    depth: int,
}

// Initialize symbol table
init_symbol_table :: proc(st: ^SymbolTable) {
    st.name_to_defs = make(map[string][dynamic]ScopedDef)
    st.scopes = make([dynamic][dynamic]string)
    st.depth = -1
    new_scope(st)
}

// Enter new scope
new_scope :: proc(st: ^SymbolTable) {
    st.depth += 1
    append(&st.scopes, make([dynamic]string))
}

// Exit current scope
old_scope :: proc(st: ^SymbolTable) {
    if st.depth < 0 do return
    
    // Remove all definitions from current scope
    current_scope := &st.scopes[st.depth]
    for name in current_scope {
        defs := &st.name_to_defs[name]
        if len(defs) == 1 {
            delete_key(&st.name_to_defs, name)
            delete(defs^)
        } else {
            ordered_remove(defs, 0)
        }
    }
    
    delete(current_scope^)
    ordered_remove(&st.scopes, st.depth)
    st.depth -= 1
}

// Insert definition into current scope
insert_def :: proc(st: ^SymbolTable, name: string, def: rawptr, def_type: DefinitionType) -> bool {
    if st.depth < 0 do return false
    
    // Check if already defined in current scope
    if name in st.name_to_defs {
        defs := st.name_to_defs[name]
        if len(defs) > 0 && defs[0].depth == st.depth {
            return false // Already defined in current scope
        }
    }
    
    // Add to symbol table
    if name not_in st.name_to_defs {
        st.name_to_defs[name] = make([dynamic]ScopedDef)
    }
    inject_at(&st.name_to_defs[name], 0, ScopedDef{st.depth, def, def_type})
    
    // Add to current scope
    append(&st.scopes[st.depth], name)
    return true
}

// Find definition of name
find_def :: proc(st: ^SymbolTable, name: string) -> (rawptr, DefinitionType) {
    if name in st.name_to_defs {
        defs := st.name_to_defs[name]
        if len(defs) > 0 {
            return defs[0].def, defs[0].def_type
        }
    }
    return nil, DefinitionType.VAR_DEF
}

// Cleanup symbol table
cleanup_symbol_table :: proc(st: ^SymbolTable) {
    for name, defs in st.name_to_defs {
        delete(defs)
    }
    delete(st.name_to_defs)
    
    for scope in st.scopes {
        delete(scope)
    }
    delete(st.scopes)
}

// Name resolver
NameResolver :: struct {
    attr_ast: ^AttrAST,
    symbol_table: SymbolTable,
}

// Type resolver  
TypeResolver :: struct {
    attr_ast: ^AttrAST,
}

// L-value resolver
LValResolver :: struct {
    attr_ast: ^AttrAST,
}

// Error tracking for semantic analysis
ErrorTracker :: struct {
    error_count: int,
}

// Main semantic analysis entry point
semantic_analyze :: proc(ast: ^AST_Program) -> ^AttrAST {
    attr_ast := new(AttrAST)
    attr_ast.ast = ast
    attr_ast.attrs.name_defs = make(map[rawptr]rawptr)
    attr_ast.attrs.lval_map = make(map[rawptr]bool)
    
    error_tracker := ErrorTracker{0}
    
    // Phase 1: Name resolution
    name_resolver := NameResolver{attr_ast, {}}
    init_symbol_table(&name_resolver.symbol_table)
    defer cleanup_symbol_table(&name_resolver.symbol_table)
    
    resolve_names(&name_resolver, ast, &error_tracker)
    
    // Phase 2: Type checking
    type_resolver := TypeResolver{attr_ast}
    resolve_types(&type_resolver, ast, &error_tracker)
    
    // Phase 3: L-value resolution
    lval_resolver := LValResolver{attr_ast}
    resolve_lvals(&lval_resolver, ast, &error_tracker)
    
    // If there were errors, exit with error code
    if error_tracker.error_count > 0 {
        printf(.ERROR, "Semantic analysis failed with %d error(s)", error_tracker.error_count)
    }
    
    return attr_ast
}

// Check if a function name is a built-in function
is_builtin_function :: proc(name: string) -> bool {
    switch name {
    case "exit", "getint", "putint", "getstr", "putstr", "new", "del":
        return true
    case:
        return false
    }
}

// Validate built-in function calls
validate_builtin_function :: proc(call: AST_FunctionCall, error_tracker: ^ErrorTracker) {
    switch call.function.name {
    case "exit":
        if len(call.arguments) != 1 {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "exit() expects exactly 1 argument, got %d", len(call.arguments))
            error_tracker.error_count += 1
        }
    case "getint":
        if len(call.arguments) != 0 {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "getint() expects no arguments, got %d", len(call.arguments))
            error_tracker.error_count += 1
        }
    case "putint":
        if len(call.arguments) != 1 {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "putint() expects exactly 1 argument, got %d", len(call.arguments))
            error_tracker.error_count += 1
        }
    case "getstr":
        if len(call.arguments) != 1 {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "getstr() expects exactly 1 argument, got %d", len(call.arguments))
            error_tracker.error_count += 1
        }
    case "putstr":
        if len(call.arguments) != 1 {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "putstr() expects exactly 1 argument, got %d", len(call.arguments))
            error_tracker.error_count += 1
        }
    case "new":
        if len(call.arguments) != 1 {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "new() expects exactly 1 argument, got %d", len(call.arguments))
            error_tracker.error_count += 1
        }
    case "del":
        if len(call.arguments) != 1 {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "del() expects exactly 1 argument, got %d", len(call.arguments))
            error_tracker.error_count += 1
        }
    }
}

// Name resolution implementation
resolve_names :: proc(resolver: ^NameResolver, program: ^AST_Program, error_tracker: ^ErrorTracker) {
    // Two-pass resolution: first pass for definitions, second for everything else
    
    // First pass: collect function and variable definitions
    for &def in program.definitions {
        switch &d in def {
        case AST_VarDef:
            if !insert_def(&resolver.symbol_table, d.name.name, &d, DefinitionType.VAR_DEF) {
                loc_printf(.ERROR, Location{0, 0}, "Illegal definition of variable '%s'", d.name.name)
            }
            // Process initializers
            for init in d.initializers {
                resolve_names_initializer(resolver, init, error_tracker)
            }
        case AST_FunDef:
            if !insert_def(&resolver.symbol_table, d.name.name, &d, DefinitionType.FUN_DEF) {
                loc_printf(.ERROR, Location{0, 0}, "Illegal definition of function '%s'", d.name.name)
            }
        }
    }
    
    // Second pass: process function bodies
    for &def in program.definitions {
        switch &d in def {
        case AST_FunDef:
            new_scope(&resolver.symbol_table)
            
            // Add parameters to scope with redefinition checking
            for &param in d.parameters {
                if !insert_def(&resolver.symbol_table, param.name, &param, DefinitionType.PARAM_DEF) {
                    loc_printf_nofatal(.ERROR, Location{0, 0}, "Illegal definition of parameter '%s'", param.name)
                    error_tracker.error_count += 1
                }
            }
            
            // Process statements
            for stmt in d.statements {
                resolve_names_statement(resolver, stmt, error_tracker)
            }
            
            old_scope(&resolver.symbol_table)
        case AST_VarDef:
            // Already processed in first pass
        }
    }
}

resolve_names_statement :: proc(resolver: ^NameResolver, stmt: AST_Statement, error_tracker: ^ErrorTracker) {
    switch s in stmt {
    case AST_ExpressionStmt:
        resolve_names_expression(resolver, s.expression, error_tracker)
    case AST_AssignmentStmt:
        resolve_names_expression(resolver, s.expression, error_tracker)
        resolve_names_expression(resolver, s.value, error_tracker)
    case AST_IfStmt:
        resolve_names_expression(resolver, s.condition, error_tracker)
        for then_stmt in s.then_statements {
            resolve_names_statement(resolver, then_stmt, error_tracker)
        }
        for else_stmt in s.else_statements {
            resolve_names_statement(resolver, else_stmt, error_tracker)
        }
    case AST_WhileStmt:
        resolve_names_expression(resolver, s.condition, error_tracker)
        for loop_stmt in s.statements {
            resolve_names_statement(resolver, loop_stmt, error_tracker)
        }
    case AST_LetStmt:
        new_scope(&resolver.symbol_table)
        
        // First pass: collect definitions
        for &def in s.definitions {
            switch &d in def {
            case AST_VarDef:
                if !insert_def(&resolver.symbol_table, d.name.name, &d, DefinitionType.VAR_DEF) {
                    loc_printf_nofatal(.ERROR, Location{0, 0}, "Illegal definition of variable '%s'", d.name.name)
                    error_tracker.error_count += 1
                }
                for init in d.initializers {
                    resolve_names_initializer(resolver, init, error_tracker)
                }
            case AST_FunDef:
                if !insert_def(&resolver.symbol_table, d.name.name, &d, DefinitionType.FUN_DEF) {
                    loc_printf_nofatal(.ERROR, Location{0, 0}, "Illegal definition of function '%s'", d.name.name)
                    error_tracker.error_count += 1
                }
            }
        }
        
        // Second pass: process function bodies
        for &def in s.definitions {
            switch &d in def {
            case AST_FunDef:
                new_scope(&resolver.symbol_table)
                for &param in d.parameters {
                    if !insert_def(&resolver.symbol_table, param.name, &param, DefinitionType.PARAM_DEF) {
                        loc_printf_nofatal(.ERROR, Location{0, 0}, "Illegal definition of parameter '%s'", param.name)
                        error_tracker.error_count += 1
                    }
                }
                for fun_stmt in d.statements {
                    resolve_names_statement(resolver, fun_stmt, error_tracker)
                }
                old_scope(&resolver.symbol_table)
            case AST_VarDef:
                // Already processed
            }
        }
        
        // Process let body statements
        for let_stmt in s.statements {
            resolve_names_statement(resolver, let_stmt, error_tracker)
        }
        
        old_scope(&resolver.symbol_table)
    }
}

resolve_names_expression :: proc(resolver: ^NameResolver, expr: ^AST_Expression, error_tracker: ^ErrorTracker) {
    switch &e in expr^ {
    case AST_BinaryOp:
        resolve_names_expression(resolver, e.left, error_tracker)
        resolve_names_expression(resolver, e.right, error_tracker)
    case AST_UnaryOp:
        resolve_names_expression(resolver, e.operand, error_tracker)
    case AST_FunctionCall:
        // Check for built-in functions first
        if is_builtin_function(e.function.name) {
            // Mark as a built-in function by setting name_defs to a special marker
            resolver.attr_ast.attrs.name_defs[rawptr(expr)] = rawptr(uintptr(1)) // Non-null marker for built-ins
        } else {
            def, def_type := find_def(&resolver.symbol_table, e.function.name)
            if def == nil {
                loc_printf_nofatal(.ERROR, Location{0, 0}, "Undefined name '%s'", e.function.name)
                error_tracker.error_count += 1
            } else {
                resolver.attr_ast.attrs.name_defs[rawptr(expr)] = def
            }
        }
        
        for arg in e.arguments {
            resolve_names_expression(resolver, arg, error_tracker)
        }
    case AST_Identifier:
        def, def_type := find_def(&resolver.symbol_table, e.name)
        if def == nil {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "Undefined name '%s'", e.name)
            error_tracker.error_count += 1
        } else {
            resolver.attr_ast.attrs.name_defs[rawptr(expr)] = def
        }
    case AST_Literal:
        // Literals don't need name resolution
    }
}

resolve_names_initializer :: proc(resolver: ^NameResolver, init: AST_Initializer, error_tracker: ^ErrorTracker) {
    // Initializers typically don't contain names to resolve in this simple language
    // This would be extended for more complex initialization expressions
}

// Type resolution implementation
resolve_types :: proc(resolver: ^TypeResolver, program: ^AST_Program, error_tracker: ^ErrorTracker) {
    for def in program.definitions {
        switch d in def {
        case AST_FunDef:
            resolve_types_function(resolver, d, error_tracker)
        case AST_VarDef:
            // Variable type checking if needed
        }
    }
}

resolve_types_function :: proc(resolver: ^TypeResolver, fun_def: AST_FunDef, error_tracker: ^ErrorTracker) {
    // Check that function has a return value (last statement must be expression)
    if len(fun_def.statements) == 0 {
        return
    }
    
    last_stmt := fun_def.statements[len(fun_def.statements) - 1]
    check_return_stmt(resolver, last_stmt, fun_def.name.name, error_tracker)
    
    for stmt in fun_def.statements {
        resolve_types_statement(resolver, stmt, error_tracker)
    }
}

check_return_stmt :: proc(resolver: ^TypeResolver, stmt: AST_Statement, fun_name: string, error_tracker: ^ErrorTracker) {
    switch s in stmt {
    case AST_ExpressionStmt:
        // This is good - function returns expression value
        return
    case AST_AssignmentStmt:
        loc_printf_nofatal(.ERROR, Location{0, 0}, "Function '%s' does not return any value", fun_name)
        error_tracker.error_count += 1
    case AST_IfStmt:
        loc_printf_nofatal(.ERROR, Location{0, 0}, "Function '%s' does not return any value", fun_name)
        error_tracker.error_count += 1
    case AST_WhileStmt:
        loc_printf_nofatal(.ERROR, Location{0, 0}, "Function '%s' does not return any value", fun_name)
        error_tracker.error_count += 1
    case AST_LetStmt:
        if len(s.statements) > 0 {
            check_return_stmt(resolver, s.statements[len(s.statements) - 1], fun_name, error_tracker)
        } else {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "Function '%s' does not return any value", fun_name)
            error_tracker.error_count += 1
        }
    }
}

resolve_types_statement :: proc(resolver: ^TypeResolver, stmt: AST_Statement, error_tracker: ^ErrorTracker) {
    switch s in stmt {
    case AST_ExpressionStmt:
        resolve_types_expression(resolver, s.expression, error_tracker)
    case AST_AssignmentStmt:
        resolve_types_expression(resolver, s.expression, error_tracker)
        resolve_types_expression(resolver, s.value, error_tracker)
    case AST_IfStmt:
        resolve_types_expression(resolver, s.condition, error_tracker)
        for then_stmt in s.then_statements {
            resolve_types_statement(resolver, then_stmt, error_tracker)
        }
        for else_stmt in s.else_statements {
            resolve_types_statement(resolver, else_stmt, error_tracker)
        }
    case AST_WhileStmt:
        resolve_types_expression(resolver, s.condition, error_tracker)
        for loop_stmt in s.statements {
            resolve_types_statement(resolver, loop_stmt, error_tracker)
        }
    case AST_LetStmt:
        for def in s.definitions {
            switch d in def {
            case AST_FunDef:
                resolve_types_function(resolver, d, error_tracker)
            case AST_VarDef:
                // Variable type checking
            }
        }
        for let_stmt in s.statements {
            resolve_types_statement(resolver, let_stmt, error_tracker)
        }
    }
}

resolve_types_expression :: proc(resolver: ^TypeResolver, expr: ^AST_Expression, error_tracker: ^ErrorTracker) {
    switch e in expr^ {
    case AST_BinaryOp:
        resolve_types_expression(resolver, e.left, error_tracker)
        resolve_types_expression(resolver, e.right, error_tracker)
    case AST_UnaryOp:
        resolve_types_expression(resolver, e.operand, error_tracker)
    case AST_FunctionCall:
        // Check if it's actually a function - look up by name
        def := resolver.attr_ast.attrs.name_defs[rawptr(expr)]
        if def != nil {
            // Check if it's a built-in function
            if is_builtin_function(e.function.name) {
                // Built-in functions have special handling
                validate_builtin_function(e, error_tracker)
            } else {
                // Check if definition is a function
                if fun_def := cast(^AST_FunDef)def; fun_def != nil {
                    // Check argument count
                    if len(fun_def.parameters) != len(e.arguments) {
                        loc_printf_nofatal(.ERROR, Location{0, 0}, "Illegal number of arguments in a call of function '%s'", e.function.name)
                        error_tracker.error_count += 1
                    }
                } else {
                    // Not a function definition - must be variable or parameter
                    loc_printf_nofatal(.ERROR, Location{0, 0}, "'%s' is not a function", e.function.name)
                    error_tracker.error_count += 1
                }
            }
        }
        
        for arg in e.arguments {
            resolve_types_expression(resolver, arg, error_tracker)
        }
    case AST_Identifier:
        // Check if it's a variable or parameter
        def := resolver.attr_ast.attrs.name_defs[rawptr(expr)]
        if def != nil {
            // For identifiers, we need to check if they refer to variables/parameters
            if var_def := cast(^AST_VarDef)def; var_def != nil {
                // This is a variable - OK
            } else if param := cast(^AST_Identifier)def; param != nil {
                // This is a parameter - OK
            } else {
                // Must be a function definition - error when used as variable
                loc_printf_nofatal(.ERROR, Location{0, 0}, "'%s' is not a variable or a parameter", e.name)
                error_tracker.error_count += 1
            }
        }
    case AST_Literal:
        // Literals are always valid
    }
}

// L-value resolution implementation
resolve_lvals :: proc(resolver: ^LValResolver, program: ^AST_Program, error_tracker: ^ErrorTracker) {
    for def in program.definitions {
        switch d in def {
        case AST_FunDef:
            for stmt in d.statements {
                resolve_lvals_statement(resolver, stmt, error_tracker)
            }
        case AST_VarDef:
            // Variables don't need l-value resolution at definition
        }
    }
}

resolve_lvals_statement :: proc(resolver: ^LValResolver, stmt: AST_Statement, error_tracker: ^ErrorTracker) {
    switch s in stmt {
    case AST_ExpressionStmt:
        resolve_lvals_expression(resolver, s.expression, error_tracker)
    case AST_AssignmentStmt:
        resolve_lvals_expression(resolver, s.expression, error_tracker)
        resolve_lvals_expression(resolver, s.value, error_tracker)
        
        // Check that left side is an l-value
        if lval, ok := resolver.attr_ast.attrs.lval_map[rawptr(s.expression)]; ok && !lval {
            loc_printf_nofatal(.ERROR, Location{0, 0}, "Left-hand side of an assignment must be a variable or expression with VALUEAT operator (postfix ^)")
            error_tracker.error_count += 1
        } else if !ok {
            // If not in map, it means it wasn't processed as an l-value, so it's invalid
            loc_printf_nofatal(.ERROR, Location{0, 0}, "Left-hand side of an assignment must be a variable or expression with VALUEAT operator (postfix ^)")
            error_tracker.error_count += 1
        }
    case AST_IfStmt:
        resolve_lvals_expression(resolver, s.condition, error_tracker)
        for then_stmt in s.then_statements {
            resolve_lvals_statement(resolver, then_stmt, error_tracker)
        }
        for else_stmt in s.else_statements {
            resolve_lvals_statement(resolver, else_stmt, error_tracker)
        }
    case AST_WhileStmt:
        resolve_lvals_expression(resolver, s.condition, error_tracker)
        for loop_stmt in s.statements {
            resolve_lvals_statement(resolver, loop_stmt, error_tracker)
        }
    case AST_LetStmt:
        for def in s.definitions {
            switch d in def {
            case AST_FunDef:
                for fun_stmt in d.statements {
                    resolve_lvals_statement(resolver, fun_stmt, error_tracker)
                }
            case AST_VarDef:
                // Variables don't need l-value resolution at definition
            }
        }
        for let_stmt in s.statements {
            resolve_lvals_statement(resolver, let_stmt, error_tracker)
        }
    }
}

resolve_lvals_expression :: proc(resolver: ^LValResolver, expr: ^AST_Expression, error_tracker: ^ErrorTracker) {
    switch e in expr^ {
    case AST_BinaryOp:
        resolve_lvals_expression(resolver, e.left, error_tracker)
        resolve_lvals_expression(resolver, e.right, error_tracker)
        resolver.attr_ast.attrs.lval_map[rawptr(expr)] = false
    case AST_UnaryOp:
        resolve_lvals_expression(resolver, e.operand, error_tracker)
        
        if e.operator == .CARET {
            // Note: In this simple implementation, we assume ^ is always VALUEAT (postfix)
            // A more sophisticated parser would distinguish between prefix and postfix
            switch operand in e.operand^ {
            case AST_Identifier:
                // Could be MEMADDR (prefix ^) - check if operand is a variable
                resolver.attr_ast.attrs.lval_map[rawptr(expr)] = false // MEMADDR is not l-value
            case AST_BinaryOp, AST_UnaryOp, AST_FunctionCall, AST_Literal:
                // Assume VALUEAT (postfix ^) - this is an l-value
                resolver.attr_ast.attrs.lval_map[rawptr(expr)] = true
            }
        } else {
            resolver.attr_ast.attrs.lval_map[rawptr(expr)] = false
        }
    case AST_FunctionCall:
        for arg in e.arguments {
            resolve_lvals_expression(resolver, arg, error_tracker)
        }
        resolver.attr_ast.attrs.lval_map[rawptr(expr)] = false
    case AST_Identifier:
        resolver.attr_ast.attrs.lval_map[rawptr(expr)] = true // Variables are l-values
    case AST_Literal:
        resolver.attr_ast.attrs.lval_map[rawptr(expr)] = false // Literals are not l-values
    }
}

// Cleanup semantic attributes
cleanup_semantic_attrs :: proc(attrs: ^SemanticAttr) {
    delete(attrs.name_defs)
    delete(attrs.lval_map)
}

// Print semantic analysis results
print_semantic_info :: proc(attr_ast: ^AttrAST) {
    printf(.INFO, "=== Semantic Analysis Results ===")
    
    printf(.INFO, "Name definitions found: %d", len(attr_ast.attrs.name_defs))
    for expr_ptr, def_ptr in attr_ast.attrs.name_defs {
        // This would need more sophisticated printing based on the actual expression types
        printf(.INFO, "  Name expression -> Definition")
    }
    
    printf(.INFO, "L-value expressions: %d", len(attr_ast.attrs.lval_map))
    lval_count := 0
    for expr_ptr, is_lval in attr_ast.attrs.lval_map {
        if is_lval {
            lval_count += 1
        }
    }
    printf(.INFO, "  Found %d l-value expressions", lval_count)
}