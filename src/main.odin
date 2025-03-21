package main

import "core:fmt"
import "core:os"

main :: proc() {
	args := os.args

	if len(args) != 2 {
		print_help()
		os.exit(0)
	}

	tokens, err := lexer(args[1])

	if err != nil {
	   printf(.ERROR, "Error!") // TODO: Implement error to string
	}

	for token in tokens {
		printf(
			.INFO,
			"%s: %s (%d:%d - %d:%d)",
			token.token_type,
			token.value,
			token.start_loc.line,
			token.start_loc.col,
			token.end_loc.line,
			token.end_loc.col,
		)
	}
}

print_help :: proc() {
	fmt.println("This is a compiler for language called PINS")
	fmt.println("Usage:")
	fmt.println("\tcompiler [filename]")
}
