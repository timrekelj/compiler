package main

import "core:fmt"
import "core:os"

main :: proc() {
	if len(os.args) != 2 {
		print_help()
		os.exit(0)
	}

	tokens, err := lexer(os.args[1])
	defer cleanup_tokens(&tokens)

	print_tokens(&tokens)

	if err != nil {
	   printf(.ERROR, error_string(err))
	}

	ast := parse(tokens)
	if ast != nil {
		printf(.INFO, "Syntax analysis completed successfully")
		print_ast(ast)
	}

}

print_help :: proc() {
	fmt.println("This is a compiler for language called PINS")
	fmt.println("Usage:")
	fmt.println("\tcompiler [filename]")
}
