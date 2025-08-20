package main

import "core:fmt"
import "core:strings"
import "core:slice"

// Memory access types
MemoryAccess :: union {
    AbsoluteAccess,
    RelativeAccess,
}

// Absolute memory access (global variables)
AbsoluteAccess :: struct {
    name: string,
    size: int,
    inits: []int,
}

// Relative memory access (stack variables, parameters)
RelativeAccess :: struct {
    offset: int,
    depth: int,
    size: int,
    inits: []int,
    debug_name: string,
}

// Function frame information
Frame :: struct {
    name: string,           // Function name (with nesting)
    depth: int,             // Static nesting depth
    params_size: int,       // Total size of parameters (including static link)
    vars_size: int,         // Total size of local variables (including FP and return address)
    debug_params: []RelativeAccess,  // Parameter access info
    debug_vars: []RelativeAccess,    // Local variable access info
}

// Memory attributes for AST nodes
MemoryAttr :: struct {
    // Function frames
    frames: map[rawptr]Frame,                    // ^AST_FunDef -> Frame
    // Parameter access
    param_access: map[rawptr]RelativeAccess,     // ^AST_Identifier (param) -> RelativeAccess
    // Variable access
    var_access: map[rawptr]MemoryAccess,         // ^AST_VarDef -> MemoryAccess
}

// Extended AST with memory attributes
MemoryAttrAST :: struct {
    using attr_ast: AttrAST,
    memory_attrs: MemoryAttr,
}

// Memory organizer state (equivalent to Java's MemoryVisitor)
MemoryOrganizer :: struct {
    attr_ast: ^MemoryAttrAST,
    depth: int,
    var_offset_stack: [dynamic]int,      // Stack for variable offsets
    param_offset_stack: [dynamic]int,    // Stack for parameter offsets  
    function_names_stack: [dynamic]string, // Stack for nested function names
}

// Initialize memory attributes
init_memory_attrs :: proc(attrs: ^MemoryAttr) {
    attrs.frames = make(map[rawptr]Frame)
    attrs.param_access = make(map[rawptr]RelativeAccess)
    attrs.var_access = make(map[rawptr]MemoryAccess)
}

// Cleanup memory attributes
cleanup_memory_attrs :: proc(attrs: ^MemoryAttr) {
    // Cleanup frames
    for key, frame in attrs.frames {
        delete(frame.debug_params)
        delete(frame.debug_vars)
    }
    delete(attrs.frames)
    
    // Cleanup access maps
    for key, access in attrs.var_access {
        switch a in access {
        case AbsoluteAccess:
            if a.inits != nil do delete(a.inits)
        case RelativeAccess:
            if a.inits != nil do delete(a.inits)
        }
    }
    delete(attrs.param_access)
    delete(attrs.var_access)
}

// Main memory organization procedure (equivalent to Java's Memory.organize)
organize_memory :: proc(attr_ast: ^AttrAST) -> ^MemoryAttrAST {
    memory_attr_ast := new(MemoryAttrAST)
    memory_attr_ast.attr_ast = attr_ast^
    init_memory_attrs(&memory_attr_ast.memory_attrs)
    
    organizer := MemoryOrganizer{
        attr_ast = memory_attr_ast,
        depth = 0,
        var_offset_stack = make([dynamic]int),
        param_offset_stack = make([dynamic]int),
        function_names_stack = make([dynamic]string),
    }
    
    // Visit the AST (equivalent to Java's ast.accept(new MemoryVisitor(), null))
    visit_program(&organizer, attr_ast.ast)
    
    // Cleanup organizer
    delete(organizer.var_offset_stack)
    delete(organizer.param_offset_stack)
    delete(organizer.function_names_stack)
    
    return memory_attr_ast
}

// Visit program (top-level AST node)
visit_program :: proc(org: ^MemoryOrganizer, program: ^AST_Program) {
    // Process global definitions (depth 0)
    for &def in program.definitions {
        visit_definition(org, &def)
    }
    
    // Process global statements if any
    for stmt in program.statements {
        visit_statement(org, stmt)
    }
}

// Visit definition (variable or function definition)
visit_definition :: proc(org: ^MemoryOrganizer, def: ^AST_Definition) {
    switch d in def {
    case AST_VarDef:
        visit_var_def(org, def)
    case AST_FunDef:
        visit_fun_def(org, def)
    }
}

// Visit function definition (equivalent to Java's visit(AST.FunDef funDef, Object arg))
visit_fun_def :: proc(org: ^MemoryOrganizer, def: ^AST_Definition) {
    fun_def := def.(AST_FunDef)
    
    // Increase depth and push new offsets
    org.depth += 1
    append(&org.var_offset_stack, -8)      // Start after saved FP and return address
    append(&org.param_offset_stack, 4)     // Start after static link
    append(&org.function_names_stack, fun_def.name.name)
    
    // Visit parameters
    for &param in fun_def.parameters {
        visit_param_def(org, &param)
    }
    
    // Visit function body statements
    for stmt in fun_def.statements {
        visit_statement(org, stmt)
    }
    
    // Define function frame before cleaning up (with current state)
    define_function_frame(org, def)
    
    // Clean up stacks
    pop(&org.var_offset_stack)
    pop(&org.param_offset_stack)
    pop(&org.function_names_stack)
    
    org.depth -= 1
}

// Visit parameter definition (equivalent to Java's visit(AST.ParDef parDef, Object arg))
visit_param_def :: proc(org: ^MemoryOrganizer, param: ^AST_Identifier) {
    current_offset := org.param_offset_stack[len(org.param_offset_stack) - 1]
    
    access := RelativeAccess{
        offset = current_offset,
        depth = org.depth,
        size = 4,  // All parameters are 4 bytes
        inits = nil,
        debug_name = param.name,
    }
    
    org.attr_ast.memory_attrs.param_access[rawptr(param)] = access
    org.param_offset_stack[len(org.param_offset_stack) - 1] = current_offset + 4
}

// Visit variable definition (equivalent to Java's visit(AST.VarDef varDef, Object arg))
visit_var_def :: proc(org: ^MemoryOrganizer, def: ^AST_Definition) {
    var_def := def.(AST_VarDef)
    name := var_def.name.name
    inits := get_variable_inits(var_def)
    size := calculate_size_from_inits(inits)
    
    if org.depth == 0 {
        // Global variable - absolute access
        access := AbsoluteAccess{
            name = name,
            size = size,
            inits = inits,
        }
        org.attr_ast.memory_attrs.var_access[rawptr(def)] = access
    } else {
        // This should not happen here as local variables are handled in let statements
        // But we handle it for completeness
        current_offset := org.var_offset_stack[len(org.var_offset_stack) - 1]
        new_offset := current_offset - size
        org.var_offset_stack[len(org.var_offset_stack) - 1] = new_offset
        
        access := RelativeAccess{
            offset = new_offset,
            depth = org.depth,
            size = size,
            inits = inits,
            debug_name = name,
        }
        org.attr_ast.memory_attrs.var_access[rawptr(def)] = access
    }
}

// Visit statement (handles let statements specially, others recursively)
visit_statement :: proc(org: ^MemoryOrganizer, stmt: AST_Statement) {
    switch &s in stmt {
    case AST_LetStmt:
        visit_let_statement(org, &s)
    case AST_AssignmentStmt:
        // No memory organization needed for assignments
    case AST_IfStmt:
        // Recursively visit nested statements
        for nested_stmt in s.then_statements {
            visit_statement(org, nested_stmt)
        }
        for nested_stmt in s.else_statements {
            visit_statement(org, nested_stmt)
        }
    case AST_WhileStmt:
        // Recursively visit nested statements
        for nested_stmt in s.statements {
            visit_statement(org, nested_stmt)
        }
    case AST_ExpressionStmt:
        // No memory organization needed for expression statements
    }
}

// Visit let statement (equivalent to Java's visit(AST.LetStmt letStmt, Object arg))
visit_let_statement :: proc(org: ^MemoryOrganizer, let_stmt: ^AST_LetStmt) {
    // First, visit all definitions to set up their memory access
    for &def in let_stmt.definitions {
        visit_definition(org, &def)
    }
    
    // For local variable definitions in let statements, update their access to be relative
    for &def in let_stmt.definitions {
        if var_def, is_var := def.(AST_VarDef); is_var {
            name := var_def.name.name
            inits := get_variable_inits(var_def)
            size := calculate_size_from_inits(inits)
            
            // Update the offset for this variable
            if len(org.var_offset_stack) > 0 {
                current_offset := org.var_offset_stack[len(org.var_offset_stack) - 1]
                new_offset := current_offset - size
                org.var_offset_stack[len(org.var_offset_stack) - 1] = new_offset
                
                access := RelativeAccess{
                    offset = new_offset,
                    depth = org.depth,
                    size = size,
                    inits = inits,
                    debug_name = name,
                }
                org.attr_ast.memory_attrs.var_access[rawptr(&def)] = access
            }
        }
    }
    
    // Increase depth for nested scope
    org.depth += 1
    
    // Visit statements in the let body
    for stmt in let_stmt.statements {
        visit_statement(org, stmt)
    }
    
    // Decrease depth when leaving scope
    org.depth -= 1
}

// Define function frame (equivalent to Java's defineFun method)
define_function_frame :: proc(org: ^MemoryOrganizer, def: ^AST_Definition) {
    fun_def := def.(AST_FunDef)
    
    // Collect parameter access information
    params := make([dynamic]RelativeAccess)
    for &param in fun_def.parameters {
        if access, ok := org.attr_ast.memory_attrs.param_access[rawptr(&param)]; ok {
            append(&params, access)
        }
    }
    
    // Collect local variable access information
    vars := make([dynamic]RelativeAccess)
    for stmt in fun_def.statements {
        collect_local_vars_from_statement(org, stmt, &vars)
    }
    
    // Construct full function name with nesting
    frame_name := construct_frame_name(org.function_names_stack[:], fun_def.name.name)
    
    // Calculate sizes
    params_size := len(fun_def.parameters) * 4 + 4  // +4 for static link
    vars_size := 8  // Base size for saved FP and return address
    for var_access in vars {
        vars_size += var_access.size
    }
    
    frame := Frame{
        name = frame_name,
        depth = org.depth, // Current depth when defining frame
        params_size = params_size,
        vars_size = vars_size,
        debug_params = params[:],
        debug_vars = vars[:],
    }
    
    org.attr_ast.memory_attrs.frames[rawptr(def)] = frame
}

// Collect local variables from statement recursively
collect_local_vars_from_statement :: proc(org: ^MemoryOrganizer, stmt: AST_Statement, vars: ^[dynamic]RelativeAccess) {
    switch &s in stmt {
    case AST_LetStmt:
        // Only collect variables defined directly in this let statement
        for &def in s.definitions {
            if var_def, is_var := def.(AST_VarDef); is_var {
                if access, ok := org.attr_ast.memory_attrs.var_access[rawptr(&def)]; ok {
                    if rel_access, is_rel := access.(RelativeAccess); is_rel {
                        append(vars, rel_access)
                    }
                }
            }
        }
        // Don't recurse into nested statements for variable collection in function frames
        // Nested functions will have their own frames
    case AST_ExpressionStmt:
        // Expression statements don't define variables
    case AST_AssignmentStmt:
        // Assignment statements don't define variables
    case AST_IfStmt:
        // If statements don't define variables directly
    case AST_WhileStmt:
        // While statements don't define variables directly
    case:
        // Other statement types don't define variables directly
    }
}

// Get variable initializers (equivalent to Java's getInits method)
get_variable_inits :: proc(var_def: AST_VarDef) -> []int {
    if len(var_def.initializers) == 0 do return nil
    
    result := make([dynamic]int)
    append(&result, len(var_def.initializers))  // Number of initializers
    
    for init in var_def.initializers {
        switch i in init {
        case AST_IntInit:
            // Handle repetition count if specified
            count := 1
            if i.array_size != "" {
                count = decode_int_const(i.array_size)
            }
            append(&result, count)  // Number of repetitions
            append(&result, 1)  // Length of one init (INT)
            append(&result, decode_int_const(i.value))
        case AST_CharInit:
            append(&result, 1)  // Number of repetitions
            append(&result, 1)  // Length of one init (CHAR)
            append(&result, decode_char_const(i.value))
        case AST_StringInit:
            append(&result, 1)  // Number of repetitions
            values := decode_string_const(i.value)
            append(&result, len(values))  // Length of one init (STRING)
            for val in values {
                append(&result, val)
            }
        case AST_ExprInit:
            // Simple expression initialization
            append(&result, 1)  // Number of repetitions
            append(&result, 1)  // Length of one init
            append(&result, 0)  // Default value
        }
    }
    
    return result[:]
}

// Calculate total size from initializers (equivalent to Java's getSize method)
calculate_size_from_inits :: proc(inits: []int) -> int {
    if len(inits) == 0 do return 4  // Default size
    
    size := 0
    i := 1
    for init_idx := 0; init_idx < inits[0]; init_idx += 1 {
        count := inits[i]
        length := inits[i + 1]
        size += count * length * 4  // 4 bytes per value
        i += length + 2
    }
    return size
}

// Decode integer constant (equivalent to Java's decodeIntConst)
decode_int_const :: proc(value: string) -> int {
    if len(value) == 0 do return 0
    
    // Handle hexadecimal (0x prefix)
    if len(value) >= 2 && value[0] == '0' && (value[1] == 'x' || value[1] == 'X') {
        result := 0
        for i := 2; i < len(value); i += 1 {
            c := value[i]
            digit := 0
            if c >= '0' && c <= '9' {
                digit = int(c - '0')
            } else if c >= 'a' && c <= 'f' {
                digit = int(c - 'a' + 10)
            } else if c >= 'A' && c <= 'F' {
                digit = int(c - 'A' + 10)
            }
            result = result * 16 + digit
        }
        return result
    } else {
        // Handle decimal
        result := 0
        negative := false
        start := 0
        if len(value) > 0 && value[0] == '-' {
            negative = true
            start = 1
        }
        for i := start; i < len(value); i += 1 {
            if value[i] >= '0' && value[i] <= '9' {
                result = result * 10 + int(value[i] - '0')
            }
        }
        return negative ? -result : result
    }
}

// Decode character constant (equivalent to Java's decodeChrConst)
decode_char_const :: proc(value: string) -> int {
    if len(value) < 3 do return 0  // Invalid char literal
    
    c := value[1]  // Character inside quotes
    if c == '\\' && len(value) >= 4 {
        // Escape sequence
        switch value[2] {
        case 'n': return 10
        case '\'': return int('\'')
        case '\\': return int('\\')
        case:
            // Hex escape sequence (e.g., '\2A' for '*')
            if len(value) >= 5 {
                d1 := hex_digit_value(value[2])
                d2 := hex_digit_value(value[3])
                return d1 * 16 + d2
            }
            return int(value[2])
        }
    }
    return int(c)
}

// Decode string constant (equivalent to Java's decodeStrConst)
decode_string_const :: proc(value: string) -> []int {
    if len(value) < 2 do return nil  // Invalid string literal
    
    result := make([dynamic]int)
    
    for i := 1; i < len(value) - 1; i += 1 {  // Skip quotes
        c := value[i]
        if c == '\\' && i + 1 < len(value) - 1 {
            // Escape sequence
            i += 1
            switch value[i] {
            case 'n': append(&result, 10)
            case '"': append(&result, int('"'))
            case '\\': append(&result, int('\\'))
            case:
                // Hex escape sequence
                if i + 1 < len(value) - 1 {
                    d1 := hex_digit_value(value[i])
                    i += 1
                    d2 := hex_digit_value(value[i])
                    append(&result, d1 * 16 + d2)
                } else {
                    append(&result, int(value[i]))
                }
            }
        } else {
            append(&result, int(c))
        }
    }
    
    return result[:]
}

// Helper function to convert hex digit to integer
hex_digit_value :: proc(c: u8) -> int {
    if c >= '0' && c <= '9' do return int(c - '0')
    if c >= 'a' && c <= 'f' do return int(c - 'a' + 10)
    if c >= 'A' && c <= 'F' do return int(c - 'A' + 10)
    return 0
}

// Construct full frame name with nesting (equivalent to Java's frame name construction)
construct_frame_name :: proc(names: []string, current_name: string) -> string {
    if len(names) == 0 do return current_name
    
    // The current function name is already in the names stack, so don't add it again
    result := strings.join(names, ".")
    return result
}

// Print memory information for debugging
print_memory_info :: proc(memory_attr_ast: ^MemoryAttrAST) {
    fmt.println("=== Memory Organization ===")
    
    // Print frames
    fmt.println("Function Frames:")
    for ptr, frame in memory_attr_ast.memory_attrs.frames {
        fmt.printf("  %s: depth=%d, params_size=%d, vars_size=%d\n", 
                  frame.name, frame.depth, frame.params_size, frame.vars_size)
        
        fmt.println("    Parameters:")
        for param in frame.debug_params {
            fmt.printf("      %s: offset=%d, size=%d\n", 
                      param.debug_name, param.offset, param.size)
        }
        
        fmt.println("    Variables:")
        for var in frame.debug_vars {
            fmt.printf("      %s: offset=%d, size=%d\n", 
                      var.debug_name, var.offset, var.size)
        }
    }
    
    // Print variable access
    fmt.println("Variable Access:")
    for ptr, access in memory_attr_ast.memory_attrs.var_access {
        switch a in access {
        case AbsoluteAccess:
            fmt.printf("  %s: global, size=%d\n", a.name, a.size)
        case RelativeAccess:
            fmt.printf("  %s: local, offset=%d, size=%d, depth=%d\n", 
                      a.debug_name, a.offset, a.size, a.depth)
        }
    }
}