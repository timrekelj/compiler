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

	if err != nil {
	   printf(.ERROR, "Error: %s", error_string(err))
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
