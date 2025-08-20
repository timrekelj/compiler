package main

import "core:fmt"
import "core:strings"

// QBE Instruction wrapper for the expected architecture
QBEInstr :: struct {
    content: string,
}

// Codegen attributes for AST nodes
CodegenAttr :: struct {
    // Map from AST nodes to their generated QBE code
    instructions: map[rawptr][]QBEInstr,
    // Generated QBE code as string
    qbe_code: string,
}

// Extended AST with codegen attributes
CodegenAttrAST :: struct {
    using memory_attr_ast: MemoryAttrAST,
    codegen_attrs: CodegenAttr,
}

// Initialize codegen attributes
init_codegen_attrs :: proc(attrs: ^CodegenAttr) {
    attrs.instructions = make(map[rawptr][]QBEInstr)
    attrs.qbe_code = ""
}

// Cleanup codegen attributes
cleanup_codegen_attrs :: proc(attrs: ^CodegenAttr) {
    // Simple cleanup - just clear the map
    clear(&attrs.instructions)
}

// Main code generation procedure that integrates with existing QBE generator
generate_code :: proc(memory_attr_ast: ^MemoryAttrAST) -> ^CodegenAttrAST {
    codegen_attr_ast := new(CodegenAttrAST)
    codegen_attr_ast.memory_attr_ast = memory_attr_ast^
    init_codegen_attrs(&codegen_attr_ast.codegen_attrs)
    
    // Create a simple AttrAST for the QBE generator
    attr_ast := AttrAST{
        ast = memory_attr_ast.ast,
        attrs = memory_attr_ast.attrs,
    }
    
    // Use existing QBE generator
    qbe_code := generate_qbe_code(&attr_ast)
    codegen_attr_ast.codegen_attrs.qbe_code = qbe_code
    
    // Store the QBE code as instructions for the expected interface
    instructions := make([]QBEInstr, 1)
    instructions[0] = QBEInstr{content = qbe_code}
    codegen_attr_ast.codegen_attrs.instructions[rawptr(memory_attr_ast.ast)] = instructions
    
    return codegen_attr_ast
}

// Convert instructions to QBE string (expected by main.odin)
qbe_to_string :: proc(instructions: []QBEInstr) -> string {
    if len(instructions) == 0 do return ""
    return instructions[0].content
}