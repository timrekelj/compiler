package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:os/os2"
import "core:slice"

main :: proc() {
	if len(os.args) < 2 {
		print_help()
		os.exit(0)
	}

	lex_only := false
	parse_only := false
	semantic_only := false
	memory_only := false
	codegen_only := false
	executable := false
	filename := ""

	for i := 1; i < len(os.args); i += 1 {
		arg := os.args[i]
		switch arg {
    		case "-l", "--lex-only":
    			lex_only = true
    		case "-p", "--parse-only":
    			parse_only = true
    		case "-s", "--semantic-only":
    			semantic_only = true
    		case "-m", "--memory-only":
    			memory_only = true
    		case "-c", "--codegen-only":
    			codegen_only = true
    		case "-e", "--executable":
    			executable = true
    		case "-h", "--help":
    			print_help()
    			os.exit(0)
    		case:
    			if filename == "" {
    				filename = arg
    			} else {
    				fmt.println("Error: Multiple filenames provided")
    				print_help()
    				os.exit(1)
    			}
  		}
	}

	if filename == "" {
		fmt.println("Error: No filename provided")
		print_help()
		os.exit(1)
	}

	// Lexer
	tokens, err := lexer(filename)
	defer cleanup_tokens(&tokens)

	if err != nil {
		printf(.ERROR, error_string(err))
		os.exit(1)
	}

	if lex_only {
	    print_tokens(&tokens)
		return
	}

	// Parser
	ast := parse(tokens)
	if ast == nil {
		printf(.ERROR, "Syntax analysis failed")
		os.exit(1)
	}

	if parse_only {
		print_ast(ast)
		return
	}

	// Semantic analysis
	attr_ast := semantic_analyze(ast)
	if attr_ast == nil {
		printf(.ERROR, "Semantic analysis failed")
		os.exit(1)
	}
	defer cleanup_semantic_attrs(&attr_ast.attrs)

	if semantic_only {
		print_semantic_info(attr_ast)
		return
	}

	// Memory organization
	memory_attr_ast := organize_memory(attr_ast)
	if memory_attr_ast == nil {
		printf(.ERROR, "Memory organization failed")
		os.exit(1)
	}
	defer cleanup_memory_attrs(&memory_attr_ast.memory_attrs)

	if memory_only {
		print_memory_info(memory_attr_ast)
		return
	}

	// Code generation
	codegen_attr_ast := generate_code(memory_attr_ast)
	if codegen_attr_ast == nil {
		printf(.ERROR, "Code generation failed")
		os.exit(1)
	}
	defer cleanup_codegen_attrs(&codegen_attr_ast.codegen_attrs)

	// Get QBE code from generated instructions
	qbe_code := ""
	if instructions, exists := codegen_attr_ast.codegen_attrs.instructions[rawptr(memory_attr_ast.ast)]; exists {
		qbe_code = qbe_to_string(instructions)
	} else {
		printf(.ERROR, "No instructions generated")
		os.exit(1)
	}

	if codegen_only {
		fmt.println(qbe_code)
		return
	}

	// Write QBE code to file
	output_filename := strings.concatenate([]string{filename[:len(filename)-5], ".ssa"})
	defer delete_string(output_filename)

	// Create file and write content
	file_handle, open_err := os.open(output_filename, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
	if open_err != nil {
		printf(.ERROR, "Failed to create QBE file: %s", output_filename)
		os.exit(1)
	}
	defer os.close(file_handle)

	bytes_written, write_err := os.write_string(file_handle, qbe_code)
	if write_err != nil {
		printf(.ERROR, "Failed to write QBE code to file: %s", output_filename)
		os.exit(1)
	}

	printf(.INFO, "QBE code written to: %s", output_filename)

	// Generate executable if requested
	if executable {
		generate_executable(output_filename, filename)
	}
}

// Helper function to execute a shell command
run_command :: proc(command: string) -> int {
	// Create a temporary shell script
	script_content := strings.concatenate([]string{"#!/bin/bash\n", command, "\n"})
	defer delete_string(script_content)

	script_name := "/tmp/pins_compiler_script.sh"

	// Write the script
	script_handle, script_err := os.open(script_name, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o755)
	if script_err != nil {
		return -1
	}
	defer os.close(script_handle)

	os.write_string(script_handle, script_content)
	os.close(script_handle)

	// Execute the script using os2
	result, _, _, _ := os2.process_exec({
		command = []string{"bash", script_name},
	}, context.allocator)

	// Cleanup
	os.remove(script_name)

	return result.exit_code
}

// Generate executable from QBE code
generate_executable :: proc(qbe_filename: string, source_filename: string) {
	// Determine output names
	base_name := source_filename[:len(source_filename)-5] // Remove .pins extension
	asm_filename := strings.concatenate([]string{base_name, ".s"})
	exe_filename := base_name

	// Step 1: QBE -> Assembly
	printf(.INFO, "Compiling QBE to assembly...")
	qbe_cmd := strings.concatenate([]string{"qbe -o ", asm_filename, " ", qbe_filename})
	defer delete_string(qbe_cmd)
	qbe_result := run_command(qbe_cmd)

	if qbe_result != 0 {
		printf(.ERROR, "QBE compilation failed")
		os.exit(1)
	}

	// Step 2: Assembly -> Executable
	printf(.INFO, "Assembling and linking...")

	// Link assembly file directly with cc to get proper C runtime
	link_cmd := strings.concatenate([]string{"cc -o ", exe_filename, " ", asm_filename})
	defer delete_string(link_cmd)

	link_result := run_command(link_cmd)
	if link_result != 0 {
		printf(.ERROR, "Assembly and linking failed")
		os.exit(1)
	}

	// Cleanup intermediate files
	cleanup_cmd := strings.concatenate([]string{"rm -f ", asm_filename})
	defer delete_string(cleanup_cmd)
	run_command(cleanup_cmd)

	printf(.INFO, "Executable created: %s", exe_filename)
}

print_help :: proc() {
	fmt.println("This is a compiler for language called PINS")
	fmt.println("Usage:")
	fmt.println("\tcompiler [options] [filename]")
	fmt.println()
	fmt.println("Options:")
	fmt.println("\t-l, --lex-only      Stop after lexical analysis")
	fmt.println("\t-p, --parse-only    Stop after syntax analysis")
	fmt.println("\t-s, --semantic-only Stop after semantic analysis")
	fmt.println("\t-m, --memory-only   Stop after memory organization")
	fmt.println("\t-c, --codegen-only  Stop after QBE code generation (print to stdout)")
	fmt.println("\t-e, --executable    Generate an executable file using QBE backend")
	fmt.println("\t-h, --help          Show this help message")
	fmt.println()
	fmt.println("Built-in functions:")
	fmt.println("\texit(code)          Exit program with given exit code")
	fmt.println("\tgetint()            Read an integer from stdin")
	fmt.println("\tputint(value)       Write an integer to stdout")
	fmt.println("\tgetstr(buffer)      Read a string from stdin into buffer")
	fmt.println("\tputstr(string)      Write a string to stdout")
	fmt.println("\tnew(size)           Allocate memory (returns pointer)")
	fmt.println("\tdel(pointer)        Free allocated memory")
	fmt.println()
	fmt.println("Examples:")
	fmt.println("\tcompiler -c program.pins    # Generate QBE code")
	fmt.println("\tcompiler -e program.pins    # Create executable")
	fmt.println("\t./program                   # Run the generated executable")
	fmt.println()
	fmt.println("Note: Built-in functions must be declared (but not defined) to use them:")
	fmt.println("\tfun exit(code)")
	fmt.println("\tfun getint()")
	fmt.println("\t# ... etc")
}
