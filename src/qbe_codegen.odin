package main

import "core:fmt"
import "core:strings"
import "core:os"

// QBE Code Generator
QBE_Generator :: struct {
    output: strings.Builder,
    temp_counter: int,
    label_counter: int,
    attr_ast: ^AttrAST,
    string_literals: map[string]string, // Map from string value to global name
    current_function: string,
    used_builtins: map[string]bool, // Track which built-in functions are actually used
    global_vars: map[string]string, // Track global variables (name -> global_name)
    pointer_temps: map[string]bool, // Track temporaries that are pointers
}

// Initialize QBE generator
init_qbe_generator :: proc(attr_ast: ^AttrAST) -> QBE_Generator {
    gen := QBE_Generator{
        output = strings.builder_make(),
        temp_counter = 0,
        label_counter = 0,
        attr_ast = attr_ast,
        string_literals = make(map[string]string),
        current_function = "",
        used_builtins = make(map[string]bool),
        global_vars = make(map[string]string),
        pointer_temps = nil,
    }
    return gen
}

generate_qbe_code :: proc(attr_ast: ^AttrAST) -> string {
    gen := init_qbe_generator(attr_ast)

    generate_data_definitions(&gen)

    // Generate function definitions
    for def in attr_ast.ast.definitions {
        switch d in def {
        case AST_FunDef:
            if !is_builtin_function(d.name.name) {
                // Generate user-defined main function as export
                if d.name.name == "main" {
                    generate_function_with_name(&gen, d, "main")
                } else {
                    generate_function(&gen, d)
                }
            }
        case AST_VarDef:
            generate_global_variable(&gen, d)
        }
    }

    if len(attr_ast.ast.statements) > 0 {
        generate_main_function(&gen, attr_ast.ast.statements)
    }

    generate_runtime_helpers(&gen)

    result := strings.clone(strings.to_string(gen.output))

    cleanup_qbe_generator(&gen)

    return result
}

// Generate data definitions for string literals
generate_data_definitions :: proc(gen: ^QBE_Generator) {
    collect_string_literals(gen, gen.attr_ast.ast)

    for value, name in gen.string_literals {
        strings.write_string(&gen.output, "data ")
        strings.write_string(&gen.output, name)
        strings.write_string(&gen.output, " = { ")

        // Write string bytes
        for i := 0; i < len(value); i += 1 {
            if i > 0 {
                strings.write_string(&gen.output, ", ")
            }
            strings.write_string(&gen.output, fmt.tprintf("b %d", value[i]))
        }

        // Null terminator
        if len(value) > 0 {
            strings.write_string(&gen.output, ", ")
        }
        strings.write_string(&gen.output, "b 0 }\n")
    }

    if len(gen.string_literals) > 0 {
        strings.write_string(&gen.output, "\n")
    }
}

// Collect all string literals in the AST
collect_string_literals :: proc(gen: ^QBE_Generator, program: ^AST_Program) {
    for def in program.definitions {
        switch d in def {
        case AST_FunDef:
            for stmt in d.statements {
                collect_string_literals_stmt(gen, stmt)
            }
        case AST_VarDef:
            for init in d.initializers {
                collect_string_literals_init(gen, init)
            }
        }
    }

    for stmt in program.statements {
        collect_string_literals_stmt(gen, stmt)
    }
}

collect_string_literals_stmt :: proc(gen: ^QBE_Generator, stmt: AST_Statement) {
    switch s in stmt {
    case AST_ExpressionStmt:
        collect_string_literals_expr(gen, s.expression)
    case AST_AssignmentStmt:
        collect_string_literals_expr(gen, s.expression)
        collect_string_literals_expr(gen, s.value)
    case AST_IfStmt:
        collect_string_literals_expr(gen, s.condition)
        for then_stmt in s.then_statements {
            collect_string_literals_stmt(gen, then_stmt)
        }
        for else_stmt in s.else_statements {
            collect_string_literals_stmt(gen, else_stmt)
        }
    case AST_WhileStmt:
        collect_string_literals_expr(gen, s.condition)
        for loop_stmt in s.statements {
            collect_string_literals_stmt(gen, loop_stmt)
        }
    case AST_LetStmt:
        for def in s.definitions {
            switch d in def {
            case AST_FunDef:
                for fun_stmt in d.statements {
                    collect_string_literals_stmt(gen, fun_stmt)
                }
            case AST_VarDef:
                for init in d.initializers {
                    collect_string_literals_init(gen, init)
                }
            }
        }
        for let_stmt in s.statements {
            collect_string_literals_stmt(gen, let_stmt)
        }
    }
}

collect_string_literals_expr :: proc(gen: ^QBE_Generator, expr: ^AST_Expression) {
    switch e in expr^ {
    case AST_BinaryOp:
        collect_string_literals_expr(gen, e.left)
        collect_string_literals_expr(gen, e.right)
    case AST_UnaryOp:
        collect_string_literals_expr(gen, e.operand)
    case AST_FunctionCall:
        for arg in e.arguments {
            collect_string_literals_expr(gen, arg)
        }
    case AST_Identifier:
        // No string literals in identifiers
    case AST_Literal:
        if e.type == .STRING {
            if e.value not_in gen.string_literals {
                global_name := fmt.tprintf("$str%d", len(gen.string_literals))
                gen.string_literals[e.value] = global_name
            }
        }
    }
}

collect_string_literals_init :: proc(gen: ^QBE_Generator, init: AST_Initializer) {
    switch i in init {
    case AST_StringInit:
        if i.value not_in gen.string_literals {
            global_name := fmt.tprintf("$str%d", len(gen.string_literals))
            gen.string_literals[i.value] = global_name
        }
    case AST_ExprInit:
        collect_string_literals_expr(gen, i.expression)
    case AST_IntInit, AST_CharInit:
        // No string literals in these
    }
}

// Generate a function definition
generate_function :: proc(gen: ^QBE_Generator, fun_def: AST_FunDef) {
    gen.current_function = fun_def.name.name

    // Function signature
    strings.write_string(&gen.output, "export\n")
    strings.write_string(&gen.output, "function w ")
    strings.write_string(&gen.output, fmt.tprintf("$%s", fun_def.name.name))
    strings.write_string(&gen.output, "(")

    // Parameters
    for param, i in fun_def.parameters {
        if i > 0 {
            strings.write_string(&gen.output, ", ")
        }
        // Determine parameter type based on name heuristics
        param_type := "w"  // Default to word
        if strings.contains(param.name, "arr") || strings.contains(param.name, "addr") ||
           strings.contains(param.name, "ptr") || strings.contains(param.name, "buffer") {
            param_type = "l"  // Use long for pointer parameters
        }
        strings.write_string(&gen.output, fmt.tprintf("%s %%%s", param_type, param.name))
    }

    strings.write_string(&gen.output, ") {\n")

    // Function body
    strings.write_string(&gen.output, "@start\n")

    // Generate statements
    if len(fun_def.statements) == 0 {
        // Empty function (declaration only) - add a default return
        strings.write_string(&gen.output, "    ret 0\n")
    } else {
        for stmt, i in fun_def.statements {
            if i == len(fun_def.statements) - 1 {
                // Last statement should be a return
                generate_return_statement(gen, stmt)
            } else {
                generate_statement(gen, stmt)
            }
        }
    }

    strings.write_string(&gen.output, "}\n\n")
}

// Generate a function definition with custom name
generate_function_with_name :: proc(gen: ^QBE_Generator, fun_def: AST_FunDef, custom_name: string) {
    gen.current_function = custom_name

    // Function signature
    strings.write_string(&gen.output, "export\n")
    strings.write_string(&gen.output, "function w ")
    strings.write_string(&gen.output, fmt.tprintf("$%s", custom_name))
    strings.write_string(&gen.output, "(")

    // Parameters
    for param, i in fun_def.parameters {
        if i > 0 {
            strings.write_string(&gen.output, ", ")
        }
        // Determine parameter type based on name heuristics
        param_type := "w"  // Default to word
        if strings.contains(param.name, "arr") || strings.contains(param.name, "addr") ||
           strings.contains(param.name, "ptr") || strings.contains(param.name, "buffer") {
            param_type = "l"  // Use long for pointer parameters
        }
        strings.write_string(&gen.output, fmt.tprintf("%s %%%s", param_type, param.name))
    }

    strings.write_string(&gen.output, ") {\n")

    // Function body
    strings.write_string(&gen.output, "@start\n")

    // Generate statements
    if len(fun_def.statements) == 0 {
        // Empty function (declaration only) - add a default return
        strings.write_string(&gen.output, "    ret 0\n")
    } else {
        for stmt, i in fun_def.statements {
            if i == len(fun_def.statements) - 1 {
                // Last statement should be a return
                generate_return_statement(gen, stmt)
            } else {
                generate_statement(gen, stmt)
            }
        }
    }

    strings.write_string(&gen.output, "}\n\n")
}

// Generate main function from program statements
generate_main_function :: proc(gen: ^QBE_Generator, statements: [dynamic]AST_Statement) {
    gen.current_function = "main"

    strings.write_string(&gen.output, "export\n")
    strings.write_string(&gen.output, "function w $main() {\n")
    strings.write_string(&gen.output, "@start\n")

    has_return := false
    for stmt, i in statements {
        if i == len(statements) - 1 {
            // Last statement should be a return
            generate_return_statement(gen, stmt)
            has_return = true
        } else {
            generate_statement(gen, stmt)
        }
    }

    // If no explicit return, return 0
    if !has_return {
        strings.write_string(&gen.output, "    ret 0\n")
    }
    strings.write_string(&gen.output, "}\n")
}

// Generate a statement
generate_statement :: proc(gen: ^QBE_Generator, stmt: AST_Statement) {
    switch s in stmt {
    case AST_ExpressionStmt:
        generate_expression(gen, s.expression)
    case AST_AssignmentStmt:
        rhs_temp := generate_expression(gen, s.value)
        generate_assignment(gen, s.expression, rhs_temp)
    case AST_IfStmt:
        generate_if_statement(gen, s)
    case AST_WhileStmt:
        generate_while_statement(gen, s)
    case AST_LetStmt:
        _ = generate_let_statement(gen, s)
    }
}

// Generate a return statement
generate_return_statement :: proc(gen: ^QBE_Generator, stmt: AST_Statement) {
    switch s in stmt {
    case AST_ExpressionStmt:
        temp := generate_expression(gen, s.expression)
        strings.write_string(&gen.output, fmt.tprintf("    ret %s\n", temp))
    case AST_AssignmentStmt:
        rhs_temp := generate_expression(gen, s.value)
        generate_assignment(gen, s.expression, rhs_temp)
        strings.write_string(&gen.output, fmt.tprintf("    ret %s\n", rhs_temp))
    case AST_LetStmt:
        // Generate the let statement and return the value of the last statement
        last_temp := generate_let_statement(gen, s)
        strings.write_string(&gen.output, fmt.tprintf("    ret %s\n", last_temp))
    case AST_IfStmt, AST_WhileStmt:
        // These should return a value - generate them normally then return 0
        generate_statement(gen, stmt)
        strings.write_string(&gen.output, "    ret 0\n")
    }
}

// Generate an if statement
generate_if_statement :: proc(gen: ^QBE_Generator, if_stmt: AST_IfStmt) {
    cond_temp := generate_expression(gen, if_stmt.condition)

    then_label := get_next_label(gen)
    else_label := get_next_label(gen)
    end_label := get_next_label(gen)

    strings.write_string(&gen.output, fmt.tprintf("    jnz %s, %s, %s\n", cond_temp, then_label, else_label))

    // Then branch
    strings.write_string(&gen.output, fmt.tprintf("%s\n", then_label))
    for stmt in if_stmt.then_statements {
        generate_statement(gen, stmt)
    }
    strings.write_string(&gen.output, fmt.tprintf("    jmp %s\n", end_label))

    // Else branch
    strings.write_string(&gen.output, fmt.tprintf("%s\n", else_label))
    for stmt in if_stmt.else_statements {
        generate_statement(gen, stmt)
    }

    // End label
    strings.write_string(&gen.output, fmt.tprintf("%s\n", end_label))
}

// Generate a while statement
generate_while_statement :: proc(gen: ^QBE_Generator, while_stmt: AST_WhileStmt) {
    loop_label := get_next_label(gen)
    body_label := get_next_label(gen)
    end_label := get_next_label(gen)

    strings.write_string(&gen.output, fmt.tprintf("    jmp %s\n", loop_label))

    // Loop condition check
    strings.write_string(&gen.output, fmt.tprintf("%s\n", loop_label))
    cond_temp := generate_expression(gen, while_stmt.condition)
    strings.write_string(&gen.output, fmt.tprintf("    jnz %s, %s, %s\n", cond_temp, body_label, end_label))

    // Loop body
    strings.write_string(&gen.output, fmt.tprintf("%s\n", body_label))
    for stmt in while_stmt.statements {
        generate_statement(gen, stmt)
    }
    strings.write_string(&gen.output, fmt.tprintf("    jmp %s\n", loop_label))

    // End label
    strings.write_string(&gen.output, fmt.tprintf("%s\n", end_label))
}

// Generate a let statement and return the temp of the last expression
generate_let_statement :: proc(gen: ^QBE_Generator, let_stmt: AST_LetStmt) -> string {
    // Generate local definitions first
    for def in let_stmt.definitions {
        switch d in def {
        case AST_FunDef:
            // Local functions - for now skip, would need nested function support
        case AST_VarDef:
            // Generate local variable initialization
            for init in d.initializers {
                generate_initializer(gen, init, d.name.name)
            }
        }
    }

    // Generate let body statements and capture the last expression result
    last_temp := "0"  // Default return value
    for stmt, i in let_stmt.statements {
        if i == len(let_stmt.statements) - 1 {
            // Last statement - capture its value
            switch s in stmt {
            case AST_ExpressionStmt:
                last_temp = generate_expression(gen, s.expression)
            case AST_AssignmentStmt:
                last_temp = generate_expression(gen, s.value)
                generate_assignment(gen, s.expression, last_temp)
            case AST_IfStmt:
                generate_statement(gen, stmt)
                last_temp = "0"
            case AST_WhileStmt:
                generate_statement(gen, stmt)
                last_temp = "0"
            case AST_LetStmt:
                last_temp = generate_let_statement(gen, s)
            case:
                generate_statement(gen, stmt)
                last_temp = "0"
            }
        } else {
            generate_statement(gen, stmt)
        }
    }

    return last_temp
}

// Generate an assignment
generate_assignment :: proc(gen: ^QBE_Generator, lhs: ^AST_Expression, rhs_temp: string) {
    #partial switch lhs_expr in lhs^ {
    case AST_Identifier:
        // Check if this is a global variable
        if global_name, is_global := gen.global_vars[lhs_expr.name]; is_global {
            // Global variable assignment - use explicit store with memory barrier
            strings.write_string(&gen.output, fmt.tprintf("    storew %s, %s\n", rhs_temp, global_name))
            // Force memory synchronization by adding a dummy load
            dummy_temp := get_next_temp(gen)
            strings.write_string(&gen.output, fmt.tprintf("    %s =w loadw %s\n", dummy_temp, global_name))
        } else {
            // Local variable assignment - determine type based on rhs temp
            assign_type := "w"  // Default to word

            // Check if the RHS temp comes from a pointer operation
            // This is a simple heuristic - in a full implementation, we'd track types properly
            if strings.contains(rhs_temp, "malloc") || strings.contains(rhs_temp, "new") ||
               temp_is_pointer(gen, rhs_temp) ||
               (strings.contains(lhs_expr.name, "arr") || strings.contains(lhs_expr.name, "ptr") ||
                strings.contains(lhs_expr.name, "addr") || strings.contains(lhs_expr.name, "buffer")) {
                assign_type = "l"  // Use long for pointer assignments
            }

            strings.write_string(&gen.output, fmt.tprintf("    %%%s =%s copy %s\n", lhs_expr.name, assign_type, rhs_temp))
        }
    case AST_UnaryOp:
        if lhs_expr.operator == .CARET {
            // Pointer dereference assignment
            ptr_temp := generate_expression(gen, lhs_expr.operand)
            strings.write_string(&gen.output, fmt.tprintf("    storew %s, %s\n", rhs_temp, ptr_temp))
        }
    case AST_BinaryOp, AST_FunctionCall, AST_Literal:
        // These shouldn't be valid lvalues
        printf(.ERROR, "Invalid lvalue in assignment")
    }
}

// Generate an expression and return the temporary holding the result
generate_expression :: proc(gen: ^QBE_Generator, expr: ^AST_Expression) -> string {
    switch e in expr^ {
    case AST_BinaryOp:
        return generate_binary_op(gen, e)
    case AST_UnaryOp:
        return generate_unary_op(gen, e)
    case AST_FunctionCall:
        return generate_function_call(gen, e)
    case AST_Identifier:
        return generate_identifier(gen, e)
    case AST_Literal:
        return generate_literal(gen, e)
    }
    return ""
}

// Generate binary operation
generate_binary_op :: proc(gen: ^QBE_Generator, binop: AST_BinaryOp) -> string {
    left_temp := generate_expression(gen, binop.left)
    right_temp := generate_expression(gen, binop.right)
    result_temp := get_next_temp(gen)

    op_str := ""
    result_type := "w"  // Default to word type

    #partial switch binop.operator {
    case .PLUS:
        op_str = "add"
        // Check if this is pointer arithmetic (address + offset)
        if is_pointer_expression(gen, binop.left) || is_pointer_expression(gen, binop.right) {
            result_type = "l"  // Result is a pointer
            // For pointer arithmetic, we need to extend the integer offset to long
            if is_pointer_expression(gen, binop.left) && !is_pointer_expression(gen, binop.right) {
                // left is pointer, right is offset - extend right to long
                extend_temp := get_next_temp(gen)
                strings.write_string(&gen.output, fmt.tprintf("    %s =l extsw %s\n", extend_temp, right_temp))
                right_temp = extend_temp
            } else if is_pointer_expression(gen, binop.right) && !is_pointer_expression(gen, binop.left) {
                // right is pointer, left is offset - extend left to long
                extend_temp := get_next_temp(gen)
                strings.write_string(&gen.output, fmt.tprintf("    %s =l extsw %s\n", extend_temp, left_temp))
                left_temp = extend_temp
            }
        }
    case .MINUS:
        op_str = "sub"
        // Check if this is pointer arithmetic (address - offset)
        if is_pointer_expression(gen, binop.left) {
            result_type = "l"  // Result is a pointer
            // For pointer - offset, extend the offset to long
            if !is_pointer_expression(gen, binop.right) {
                extend_temp := get_next_temp(gen)
                strings.write_string(&gen.output, fmt.tprintf("    %s =l extsw %s\n", extend_temp, right_temp))
                right_temp = extend_temp
            }
        }
    case .ASTERISK:
        op_str = "mul"
    case .SLASH:
        op_str = "div"
    case .PERCENT:
        op_str = "rem"
    case .EQ:
        op_str = "ceqw"
    case .NEQ:
        op_str = "cnew"
    case .LT:
        op_str = "csltw"
    case .GT:
        op_str = "csgtw"
    case .LEQ:
        op_str = "cslew"
    case .GEQ:
        op_str = "csgew"
    case .AND:
        op_str = "and"
    case .OR:
        op_str = "or"
    case:
        printf(.ERROR, "Unsupported binary operator: %v", binop.operator)
    }

    strings.write_string(&gen.output, fmt.tprintf("    %s =%s %s %s, %s\n",
                                                   result_temp, result_type, op_str, left_temp, right_temp))

    // Mark result as pointer if it's a pointer type
    if result_type == "l" {
        mark_temp_as_pointer(gen, result_temp)
    }

    return result_temp
}

// Generate unary operation
generate_unary_op :: proc(gen: ^QBE_Generator, unop: AST_UnaryOp) -> string {
    operand_temp := generate_expression(gen, unop.operand)
    result_temp := get_next_temp(gen)

    #partial switch unop.operator {
    case .MINUS:
        strings.write_string(&gen.output, fmt.tprintf("    %s =w neg %s\n", result_temp, operand_temp))
    case .NOT:
        strings.write_string(&gen.output, fmt.tprintf("    %s =w ceqw %s, 0\n", result_temp, operand_temp))
    case .CARET:
        // This could be either address-of or dereference
        // For dereference: ^ptr (operand is ptr, we load from it)
        // For address-of: ^var (operand is var, we get its address)
        // We need to check if this is being used in an assignment context
        if is_pointer_expression(gen, unop.operand) {
            // Operand is a pointer, so ^ means dereference - load value from pointer
            strings.write_string(&gen.output, fmt.tprintf("    %s =w loadw %s\n", result_temp, operand_temp))
        } else {
            // Operand is a variable, so ^ means address-of - get address of operand
            strings.write_string(&gen.output, fmt.tprintf("    %s =l copy %s\n", result_temp, operand_temp))
        }
    case .PLUS:
        // Unary plus is a no-op
        strings.write_string(&gen.output, fmt.tprintf("    %s =w copy %s\n", result_temp, operand_temp))
    case:
        printf(.ERROR, "Unsupported unary operator: %v", unop.operator)
    }

    return result_temp
}

// Generate function call
generate_function_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    // Check if this is a built-in function
    if is_builtin_function(call.function.name) {
        return generate_builtin_call(gen, call)
    }

    result_temp := get_next_temp(gen)

    // Generate arguments
    arg_temps := make([dynamic]string)
    defer delete(arg_temps)

    for arg in call.arguments {
        arg_temp := generate_expression(gen, arg)
        append(&arg_temps, arg_temp)
    }

    // Generate call
    strings.write_string(&gen.output, fmt.tprintf("    %s =w call $%s(", result_temp, call.function.name))

    for arg_temp, i in arg_temps {
        if i > 0 {
            strings.write_string(&gen.output, ", ")
        }
        strings.write_string(&gen.output, fmt.tprintf("w %s", arg_temp))
    }

    strings.write_string(&gen.output, ")\n")
    return result_temp
}

// Generate identifier reference
generate_identifier :: proc(gen: ^QBE_Generator, ident: AST_Identifier) -> string {
    // Check if this is a global variable
    if global_name, is_global := gen.global_vars[ident.name]; is_global {
        // For global variables, we need to load the value
        result_temp := get_next_temp(gen)
        strings.write_string(&gen.output, fmt.tprintf("    %s =w loadw %s\n", result_temp, global_name))
        return result_temp
    }
    // Local variable
    return fmt.tprintf("%%%s", ident.name)
}

// Generate literal
generate_literal :: proc(gen: ^QBE_Generator, literal: AST_Literal) -> string {
    #partial switch literal.type {
    case .NUMBER:
        return literal.value
    case .CHAR:
        // Convert char to ASCII value
        if len(literal.value) > 0 {
            return fmt.tprintf("%d", literal.value[0])
        }
        return "0"
    case .STRING:
        // Return pointer to string literal
        result_temp := get_next_temp(gen)
        global_name := gen.string_literals[literal.value]
        strings.write_string(&gen.output, fmt.tprintf("    %s =l copy %s\n", result_temp, global_name))
        return result_temp
    case .LBRACKET:
        // Unit type - return 0
        return "0"
    case:
        printf(.ERROR, "Unsupported literal type: %v", literal.type)
        return "0"
    }
}

// Generate initializer
generate_initializer :: proc(gen: ^QBE_Generator, init: AST_Initializer, var_name: string) {
    switch i in init {
    case AST_IntInit:
        // Check if this should be a pointer variable based on name
        init_type := "w"
        if strings.contains(var_name, "arr") || strings.contains(var_name, "ptr") ||
           strings.contains(var_name, "addr") || strings.contains(var_name, "buffer") {
            init_type = "l"
        }
        strings.write_string(&gen.output, fmt.tprintf("    %%%s =%s copy %s\n", var_name, init_type, i.value))
    case AST_CharInit:
        if len(i.value) > 0 {
            strings.write_string(&gen.output, fmt.tprintf("    %%%s =w copy %d\n", var_name, i.value[0]))
        } else {
            // Check if this should be a pointer variable
            init_type := "w"
            if strings.contains(var_name, "arr") || strings.contains(var_name, "ptr") ||
               strings.contains(var_name, "addr") || strings.contains(var_name, "buffer") {
                init_type = "l"
            }
            strings.write_string(&gen.output, fmt.tprintf("    %%%s =%s copy 0\n", var_name, init_type))
        }
    case AST_StringInit:
        global_name := gen.string_literals[i.value]
        strings.write_string(&gen.output, fmt.tprintf("    %%%s =l copy %s\n", var_name, global_name))
    case AST_ExprInit:
        expr_temp := generate_expression(gen, i.expression)

        // Determine type based on expression result and variable name heuristics
        assign_type := "w"  // Default to word
        if temp_is_pointer(gen, expr_temp) ||
           (strings.contains(var_name, "arr") || strings.contains(var_name, "ptr") ||
            strings.contains(var_name, "addr") || strings.contains(var_name, "buffer")) {
            assign_type = "l"  // Use long for pointer assignments
        }

        strings.write_string(&gen.output, fmt.tprintf("    %%%s =%s copy %s\n", var_name, assign_type, expr_temp))
    }
}

// Generate a built-in function call
generate_builtin_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    // Track usage of this built-in function
    gen.used_builtins[call.function.name] = true

    switch call.function.name {
    case "exit":
        return generate_exit_call(gen, call)
    case "getint":
        return generate_getint_call(gen, call)
    case "putint":
        return generate_putint_call(gen, call)
    case "getstr":
        return generate_getstr_call(gen, call)
    case "putstr":
        return generate_putstr_call(gen, call)
    case "new":
        return generate_new_call(gen, call)
    case "del":
        return generate_del_call(gen, call)
    case:
        printf(.ERROR, "Unknown built-in function: %s", call.function.name)
        return "0"
    }
}

// Generate exit() call - exits the program with given code
generate_exit_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    if len(call.arguments) != 1 {
        printf(.ERROR, "exit() expects exactly 1 argument")
        return "0"
    }

    exit_code_temp := generate_expression(gen, call.arguments[0])

    // Call C library exit() function
    strings.write_string(&gen.output, fmt.tprintf("    call $exit(w %s)\n", exit_code_temp))

    // This function doesn't return, but we need to return something for type consistency
    return "0"
}

// Generate getint() call - reads an integer from stdin
generate_getint_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    result_temp := get_next_temp(gen)

    // Call scanf to read an integer
    strings.write_string(&gen.output, fmt.tprintf("    %s =w call $scanf_int()\n", result_temp))

    return result_temp
}

// Generate putint() call - writes an integer to stdout
generate_putint_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    if len(call.arguments) != 1 {
        printf(.ERROR, "putint() expects exactly 1 argument")
        return "0"
    }

    int_temp := generate_expression(gen, call.arguments[0])
    result_temp := get_next_temp(gen)

    // Call printf to write an integer
    strings.write_string(&gen.output, fmt.tprintf("    %s =w call $printf_int(w %s)\n", result_temp, int_temp))

    return result_temp
}

// Generate getstr() call - reads a string from stdin into buffer
generate_getstr_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    if len(call.arguments) != 1 {
        printf(.ERROR, "getstr() expects exactly 1 argument")
        return "0"
    }

    buffer_temp := generate_expression(gen, call.arguments[0])
    result_temp := get_next_temp(gen)

    // Call fgets to read a string
    strings.write_string(&gen.output, fmt.tprintf("    %s =l call $fgets_str(l %s)\n", result_temp, buffer_temp))

    return result_temp
}

// Generate putstr() call - writes a string to stdout
generate_putstr_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    if len(call.arguments) != 1 {
        printf(.ERROR, "putstr() expects exactly 1 argument")
        return "0"
    }

    str_temp := generate_expression(gen, call.arguments[0])
    result_temp := get_next_temp(gen)

    // Call printf to write a string
    strings.write_string(&gen.output, fmt.tprintf("    %s =w call $printf_str(l %s)\n", result_temp, str_temp))

    return result_temp
}

// Generate new() call - allocate memory
generate_new_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    if len(call.arguments) != 1 {
        printf(.ERROR, "new() expects exactly 1 argument")
        return "0"
    }

    size_temp := generate_expression(gen, call.arguments[0])
    result_temp := get_next_temp(gen)

    // Call malloc to allocate memory
    strings.write_string(&gen.output, fmt.tprintf("    %s =l call $malloc(w %s)\n", result_temp, size_temp))

    // Mark result as pointer
    mark_temp_as_pointer(gen, result_temp)

    return result_temp
}

// Generate del() call - free memory
generate_del_call :: proc(gen: ^QBE_Generator, call: AST_FunctionCall) -> string {
    if len(call.arguments) != 1 {
        printf(.ERROR, "del() expects exactly 1 argument")
        return "0"
    }

    addr_temp := generate_expression(gen, call.arguments[0])

    // Call free to deallocate memory
    strings.write_string(&gen.output, fmt.tprintf("    call $free(l %s)\n", addr_temp))

    // Return 0 for consistency
    return "0"
}

// Generate a global variable definition
generate_global_variable :: proc(gen: ^QBE_Generator, var_def: AST_VarDef) {
    // Create global name
    global_name := fmt.tprintf("$%s", var_def.name.name)
    gen.global_vars[var_def.name.name] = global_name

    // Generate data section for the global variable
    // For now, assume single initializer with integer value
    if len(var_def.initializers) > 0 {
        switch init in var_def.initializers[0] {
        case AST_IntInit:
            strings.write_string(&gen.output, fmt.tprintf("data %s = {{ w %s }}\n", global_name, init.value))
        case AST_CharInit:
            if len(init.value) > 0 {
                strings.write_string(&gen.output, fmt.tprintf("data %s = {{ w %d }}\n", global_name, init.value[0]))
            } else {
                strings.write_string(&gen.output, fmt.tprintf("data %s = {{ w 0 }}\n", global_name))
            }
        case AST_StringInit:
            // Handle string global variables
            if init.value not_in gen.string_literals {
                str_global_name := fmt.tprintf("$str%d", len(gen.string_literals))
                gen.string_literals[init.value] = str_global_name
            }
            str_global_name := gen.string_literals[init.value]
            strings.write_string(&gen.output, fmt.tprintf("data %s = {{ l %s }}\n", global_name, str_global_name))
        case AST_ExprInit:
            // For expression initializers, we need to evaluate the expression
            // For now, assume it's a simple literal
            switch expr in init.expression^ {
            case AST_Literal:
                if expr.type == .NUMBER {
                    strings.write_string(&gen.output, fmt.tprintf("data %s = {{ w %s }}\n", global_name, expr.value))
                } else {
                    strings.write_string(&gen.output, fmt.tprintf("data %s = {{ w 0 }}\n", global_name))
                }
            case AST_BinaryOp, AST_UnaryOp, AST_FunctionCall, AST_Identifier:
                // Default to 0 for complex expressions
                strings.write_string(&gen.output, fmt.tprintf("data %s = {{ w 0 }}\n", global_name))
            }
        }
    } else {
        // No initializer, default to 0
        strings.write_string(&gen.output, fmt.tprintf("data %s = {{ w 0 }}\n", global_name))
    }
    strings.write_string(&gen.output, "\n")
}

// Generate runtime helper functions for built-ins
generate_runtime_helpers :: proc(gen: ^QBE_Generator) {
    // Only generate helpers for built-ins that are actually used

    if gen.used_builtins["getint"] {
        // Generate scanf_int helper for reading integers
        strings.write_string(&gen.output, "function w $scanf_int() {\n")
        strings.write_string(&gen.output, "@start\n")
        strings.write_string(&gen.output, "    %result =l alloc8 8\n")
        strings.write_string(&gen.output, "    call $scanf(l $int_format, l %result)\n")
        strings.write_string(&gen.output, "    %value =w loadw %result\n")
        strings.write_string(&gen.output, "    ret %value\n")
        strings.write_string(&gen.output, "}\n\n")
    }

    if gen.used_builtins["putint"] {
        // Generate printf_int helper for writing integers
        strings.write_string(&gen.output, "function w $printf_int(w %value) {\n")
        strings.write_string(&gen.output, "@start\n")
        strings.write_string(&gen.output, "    %result =w call $printf(l $int_format, w %value)\n")
        strings.write_string(&gen.output, "    ret %result\n")
        strings.write_string(&gen.output, "}\n\n")
    }

    if gen.used_builtins["getstr"] {
        // Generate fgets_str helper for reading strings
        strings.write_string(&gen.output, "function l $fgets_str(l %buffer) {\n")
        strings.write_string(&gen.output, "@start\n")
        strings.write_string(&gen.output, "    %result =l call $fgets(l %buffer, w 1024, l $stdin)\n")
        strings.write_string(&gen.output, "    ret %result\n")
        strings.write_string(&gen.output, "}\n\n")
    }

    if gen.used_builtins["putstr"] {
        // Generate printf_str helper for writing strings
        strings.write_string(&gen.output, "function w $printf_str(l %str) {\n")
        strings.write_string(&gen.output, "@start\n")
        strings.write_string(&gen.output, "    %result =w call $printf(l %str)\n")
        strings.write_string(&gen.output, "    ret %result\n")
        strings.write_string(&gen.output, "}\n\n")
    }

    // Add format string data only if integer functions are used
    if gen.used_builtins["getint"] || gen.used_builtins["putint"] {
        strings.write_string(&gen.output, "data $int_format = { b 37, b 100, b 0 }  # \"%d\"\n")
        strings.write_string(&gen.output, "data $long_format = { b 37, b 108, b 100, b 0 }  # \"%ld\"\n")
        strings.write_string(&gen.output, "data $number_str = { b 78, b 85, b 77, b 0 }  # \"NUM\"\n")
    }
}

// Helper functions
get_next_temp :: proc(gen: ^QBE_Generator) -> string {
    temp_name := fmt.tprintf("%%t%d", gen.temp_counter)
    gen.temp_counter += 1
    return temp_name
}

get_next_label :: proc(gen: ^QBE_Generator) -> string {
    label_name := fmt.tprintf("@L%d", gen.label_counter)
    gen.label_counter += 1
    return label_name
}

is_lvalue :: proc(gen: ^QBE_Generator, expr: ^AST_Expression) -> bool {
    if lval, ok := gen.attr_ast.attrs.lval_map[rawptr(expr)]; ok {
        return lval
    }
    return false
}

// Helper function to determine if an expression represents a pointer
is_pointer_expression :: proc(gen: ^QBE_Generator, expr: ^AST_Expression) -> bool {
    #partial switch e in expr^ {
    case AST_Identifier:
        // Check if this identifier is a parameter (likely a pointer)
        // or if it's a variable that holds a pointer
        // For now, we'll use a simple heuristic: if the name suggests an array/pointer
        return strings.contains(e.name, "arr") || strings.contains(e.name, "addr") ||
               strings.contains(e.name, "ptr") || strings.contains(e.name, "buffer")
    case AST_FunctionCall:
        // Function calls like malloc() return pointers
        return e.function.name == "malloc" || e.function.name == "new"
    case AST_UnaryOp:
        // Address-of operations result in pointers
        return e.operator == .CARET && !is_lvalue(gen, e.operand)
    case AST_BinaryOp:
        // Addition/subtraction with pointers results in pointers
        return (e.operator == .PLUS || e.operator == .MINUS) &&
               (is_pointer_expression(gen, e.left) || is_pointer_expression(gen, e.right))
    }
    return false
}

// Helper function to check if a temporary variable represents a pointer
temp_is_pointer :: proc(gen: ^QBE_Generator, temp: string) -> bool {
    // Check if this temp was marked as a pointer result
    // For now, we'll use a simple heuristic based on recent operations
    // In a full implementation, we'd maintain a type map for temporaries
    return temp in gen.pointer_temps || false
}

// Helper to track that a temporary is a pointer
mark_temp_as_pointer :: proc(gen: ^QBE_Generator, temp: string) {
    // Lazily initialize the map
    if gen.pointer_temps == nil {
        gen.pointer_temps = make(map[string]bool)
    }
    gen.pointer_temps[temp] = true
}

// Cleanup
cleanup_qbe_generator :: proc(gen: ^QBE_Generator) {
    strings.builder_destroy(&gen.output)
    delete(gen.string_literals)
    delete(gen.used_builtins)
    delete(gen.global_vars)
}
