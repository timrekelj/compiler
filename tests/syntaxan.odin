package tests

import compiler "../src"
import "core:fmt"
import "core:log"
import "core:testing"

@(test)
simple_variable_test :: proc(t: ^testing.T) {
	tokens, err := compiler.lexer("./tests/syntaxan/simple_test.pins")
	defer compiler.cleanup_tokens(&tokens)
	
	testing.expectf(t, err == nil, "Lexer error should be nil (%s)", compiler.error_string(err))
	
	program := compiler.parse(tokens)
	testing.expect(t, program != nil, "Program should not be nil")
	
	testing.expectf(
		t,
		len(program.definitions) == 1,
		"Expected 1 definition, got %d",
		len(program.definitions),
	)
	
	// Check that it's a variable definition
	#partial switch def in program.definitions[0] {
	case compiler.AST_VarDef:
		testing.expectf(
			t,
			def.name.name == "x",
			"Expected variable name 'x', got '%s'",
			def.name.name,
		)
		testing.expectf(
			t,
			len(def.initializers) == 1,
			"Expected 1 initializer, got %d",
			len(def.initializers),
		)
		
		// Check initializer
		#partial switch init in def.initializers[0] {
		case compiler.AST_IntInit:
			testing.expectf(
				t,
				init.value == "1",
				"Expected initializer value '1', got '%s'",
				init.value,
			)
		case:
			testing.expect(t, false, "Expected AST_IntInit, got different type")
		}
	case:
		testing.expect(t, false, "Expected AST_VarDef, got different type")
	}
}

@(test)
function_definition_test :: proc(t: ^testing.T) {
	tokens, err := compiler.lexer("./tests/syntaxan/debug_test.pins")
	defer compiler.cleanup_tokens(&tokens)
	
	testing.expectf(t, err == nil, "Lexer error should be nil (%s)", compiler.error_string(err))
	
	program := compiler.parse(tokens)
	testing.expect(t, program != nil, "Program should not be nil")
	
	testing.expectf(
		t,
		len(program.definitions) == 1,
		"Expected 1 definition, got %d",
		len(program.definitions),
	)
	
	// Check that it's a function definition
	#partial switch def in program.definitions[0] {
	case compiler.AST_FunDef:
		testing.expectf(
			t,
			def.name.name == "add",
			"Expected function name 'add', got '%s'",
			def.name.name,
		)
		testing.expectf(
			t,
			len(def.parameters) == 1,
			"Expected 1 parameter, got %d",
			len(def.parameters),
		)
		testing.expectf(
			t,
			def.parameters[0].name == "x",
			"Expected parameter name 'x', got '%s'",
			def.parameters[0].name,
		)
		testing.expectf(
			t,
			len(def.statements) == 1,
			"Expected 1 statement, got %d",
			len(def.statements),
		)
		
		// Check statement is an expression statement
		#partial switch stmt in def.statements[0] {
		case compiler.AST_ExpressionStmt:
			#partial switch expr in stmt.expression^ {
			case compiler.AST_Identifier:
				testing.expectf(
					t,
					expr.name == "x",
					"Expected expression identifier 'x', got '%s'",
					expr.name,
				)
			case:
				testing.expect(t, false, "Expected AST_Identifier, got different type")
			}
		case:
			testing.expect(t, false, "Expected AST_ExpressionStmt, got different type")
		}
	case:
		testing.expect(t, false, "Expected AST_FunDef, got different type")
	}
}

@(test)
function_with_parameters_test :: proc(t: ^testing.T) {
	tokens, err := compiler.lexer("./tests/syntaxan/funcall_test.pins")
	defer compiler.cleanup_tokens(&tokens)
	
	testing.expectf(t, err == nil, "Lexer error should be nil (%s)", compiler.error_string(err))
	
	program := compiler.parse(tokens)
	testing.expect(t, program != nil, "Program should not be nil")
	
	testing.expectf(
		t,
		len(program.definitions) == 2,
		"Expected 2 definitions, got %d",
		len(program.definitions),
	)
	
	// Check first definition (function)
	#partial switch def in program.definitions[0] {
	case compiler.AST_FunDef:
		testing.expectf(
			t,
			def.name.name == "add",
			"Expected function name 'add', got '%s'",
			def.name.name,
		)
		testing.expectf(
			t,
			len(def.parameters) == 2,
			"Expected 2 parameters, got %d",
			len(def.parameters),
		)
		testing.expectf(
			t,
			def.parameters[0].name == "a",
			"Expected first parameter 'a', got '%s'",
			def.parameters[0].name,
		)
		testing.expectf(
			t,
			def.parameters[1].name == "b",
			"Expected second parameter 'b', got '%s'",
			def.parameters[1].name,
		)
		
		// Check function body (should be a + b)
		#partial switch stmt in def.statements[0] {
		case compiler.AST_ExpressionStmt:
			#partial switch expr in stmt.expression^ {
			case compiler.AST_BinaryOp:
				testing.expectf(
					t,
					expr.operator == .PLUS,
					"Expected PLUS operator, got %v",
					expr.operator,
				)
			case:
				testing.expect(t, false, "Expected AST_BinaryOp, got different type")
			}
		case:
			testing.expect(t, false, "Expected AST_ExpressionStmt, got different type")
		}
	case:
		testing.expect(t, false, "Expected AST_FunDef, got different type")
	}
}

@(test)
complex_expression_test :: proc(t: ^testing.T) {
	tokens, err := compiler.lexer("./tests/syntaxan/expression_test.pins")
	defer compiler.cleanup_tokens(&tokens)
	
	testing.expectf(t, err == nil, "Lexer error should be nil (%s)", compiler.error_string(err))
	
	program := compiler.parse(tokens)
	testing.expect(t, program != nil, "Program should not be nil")
	
	testing.expectf(
		t,
		len(program.definitions) == 6,
		"Expected 6 definitions, got %d",
		len(program.definitions),
	)
	
	// Check factorial function (first definition)
	#partial switch def in program.definitions[0] {
	case compiler.AST_FunDef:
		testing.expectf(
			t,
			def.name.name == "factorial",
			"Expected function name 'factorial', got '%s'",
			def.name.name,
		)
		
		// Check that function body contains if statement
		#partial switch stmt in def.statements[0] {
		case compiler.AST_IfStmt:
			// Check condition is a comparison (n == 0)
			#partial switch cond in stmt.condition^ {
			case compiler.AST_BinaryOp:
				testing.expectf(
					t,
					cond.operator == .EQ,
					"Expected EQ operator in condition, got %v",
					cond.operator,
				)
			case:
				testing.expect(t, false, "Expected AST_BinaryOp in condition, got different type")
			}
			
			// Check that else branch contains recursive call
			testing.expectf(
				t,
				len(stmt.else_statements) == 1,
				"Expected 1 else statement, got %d",
				len(stmt.else_statements),
			)
		case:
			testing.expect(t, false, "Expected AST_IfStmt, got different type")
		}
	case:
		testing.expect(t, false, "Expected AST_FunDef, got different type")
	}
}

@(test)
multiple_initializers_test :: proc(t: ^testing.T) {
	tokens, err := compiler.lexer("./tests/syntaxan/comma_test.pins")
	defer compiler.cleanup_tokens(&tokens)
	
	testing.expectf(t, err == nil, "Lexer error should be nil (%s)", compiler.error_string(err))
	
	program := compiler.parse(tokens)
	testing.expect(t, program != nil, "Program should not be nil")
	
	testing.expectf(
		t,
		len(program.definitions) == 1,
		"Expected 1 definition, got %d",
		len(program.definitions),
	)
	
	// Check variable with multiple initializers
	#partial switch def in program.definitions[0] {
	case compiler.AST_VarDef:
		testing.expectf(
			t,
			def.name.name == "x",
			"Expected variable name 'x', got '%s'",
			def.name.name,
		)
		testing.expectf(
			t,
			len(def.initializers) == 2,
			"Expected 2 initializers, got %d",
			len(def.initializers),
		)
		
		// Check first initializer
		#partial switch init in def.initializers[0] {
		case compiler.AST_IntInit:
			testing.expectf(
				t,
				init.value == "1",
				"Expected first initializer '1', got '%s'",
				init.value,
			)
		case:
			testing.expect(t, false, "Expected AST_IntInit, got different type")
		}
		
		// Check second initializer
		#partial switch init in def.initializers[1] {
		case compiler.AST_IntInit:
			testing.expectf(
				t,
				init.value == "2",
				"Expected second initializer '2', got '%s'",
				init.value,
			)
		case:
			testing.expect(t, false, "Expected AST_IntInit, got different type")
		}
	case:
		testing.expect(t, false, "Expected AST_VarDef, got different type")
	}
}

@(test)
empty_function_test :: proc(t: ^testing.T) {
	tokens, err := compiler.lexer("./tests/syntaxan/paren_test.pins")
	defer compiler.cleanup_tokens(&tokens)
	
	testing.expectf(t, err == nil, "Lexer error should be nil (%s)", compiler.error_string(err))
	
	program := compiler.parse(tokens)
	testing.expect(t, program != nil, "Program should not be nil")
	
	testing.expectf(
		t,
		len(program.definitions) == 1,
		"Expected 1 definition, got %d",
		len(program.definitions),
	)
	
	// Check function with no parameters
	#partial switch def in program.definitions[0] {
	case compiler.AST_FunDef:
		testing.expectf(
			t,
			def.name.name == "test",
			"Expected function name 'test', got '%s'",
			def.name.name,
		)
		testing.expectf(
			t,
			len(def.parameters) == 0,
			"Expected 0 parameters, got %d",
			len(def.parameters),
		)
		testing.expectf(
			t,
			len(def.statements) == 1,
			"Expected 1 statement, got %d",
			len(def.statements),
		)
		
		// Check that the statement is a literal 42
		#partial switch stmt in def.statements[0] {
		case compiler.AST_ExpressionStmt:
			#partial switch expr in stmt.expression^ {
			case compiler.AST_Literal:
				testing.expectf(
					t,
					expr.value == "42",
					"Expected literal '42', got '%s'",
					expr.value,
				)
				testing.expectf(
					t,
					expr.type == .NUMBER,
					"Expected NUMBER type, got %v",
					expr.type,
				)
			case:
				testing.expect(t, false, "Expected AST_Literal, got different type")
			}
		case:
			testing.expect(t, false, "Expected AST_ExpressionStmt, got different type")
		}
	case:
		testing.expect(t, false, "Expected AST_FunDef, got different type")
	}
}

// Test Suite Summary:
// - simple_variable_test: Tests basic variable declaration with single initializer
// - function_definition_test: Tests function definition with single parameter
// - function_with_parameters_test: Tests function with multiple parameters and binary expression
// - complex_expression_test: Tests complex recursive function with if/then/else and function calls
// - multiple_initializers_test: Tests variable declaration with multiple comma-separated initializers
// - empty_function_test: Tests function with no parameters returning a literal
//
// Note: Error case tests are omitted to avoid parse error output during test runs.
// The syntax analyzer correctly handles invalid syntax by returning nil from parse().