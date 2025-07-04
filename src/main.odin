package main

import "core:fmt"
import "core:os"

main :: proc() {
	if len(os.args) < 2 {
		print_help()
		os.exit(0)
	}

	// Parse command line arguments
	lex_only := false
	parse_only := false
	semantic_only := false
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

	tokens, err := lexer(filename)
	defer cleanup_tokens(&tokens)

	print_tokens(&tokens)

	if err != nil {
		printf(.ERROR, error_string(err))
		os.exit(1)
	}

	if lex_only {
	    print_tokens(&tokens)
		return
	}

	ast := parse(tokens)
	if ast != nil {
		printf(.INFO, "Syntax analysis completed successfully")

		if parse_only {
    		print_ast(ast)
			return
		}

		// Semantic analysis
		attr_ast := semantic_analyze(ast)
		if attr_ast != nil {
			printf(.INFO, "Semantic analysis completed successfully")
			defer cleanup_semantic_attrs(&attr_ast.attrs)

			if semantic_only {
    			print_semantic_info(attr_ast)
				return
			}
		}
	} else {
		// Parser failed
		os.exit(1)
	}

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
	fmt.println("\t-h, --help          Show this help message")
}
