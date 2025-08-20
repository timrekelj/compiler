# Memory Phase Implementation Tests

This directory contains test files for the memory organization phase of the PINS compiler, implemented in Odin based on the original Java implementation.

## Overview

The memory phase calculates memory layout for functions and variables, including:
- Function frames with parameter and variable offsets
- Global variable absolute addresses
- Local variable stack offsets
- Parameter stack offsets
- Static nesting depth tracking

## Implementation Details

The Odin implementation closely follows the Java Memory.java implementation:

### Memory Access Types
- **AbsoluteAccess**: For global variables with static addresses
- **RelativeAccess**: For stack-based variables and parameters with frame-relative offsets

### Function Frames
Each function gets a frame containing:
- Function name with nesting (e.g., `main.inc.f`)
- Static depth (nesting level)
- Parameter size (including 4-byte static link)
- Variable size (including 8-byte frame pointer and return address)
- Debug information for parameters and variables

### Offset Calculation
- **Parameters**: Start at offset +4 (after static link), increment by 4 bytes each
- **Local Variables**: Start at offset -8 (after saved FP/return address), decrement by variable size
- **Global Variables**: Use absolute addressing with variable names

## Test Files

### `minimal_test.pins`
Basic test with one global variable and one function with local variable.
Expected output:
- `simple` function: depth=1, 1 local variable at offset -12
- `main` function: depth=1, no local variables

### `param_test.pins`
Tests parameter offset calculation with functions having different numbers of parameters.
Expected output:
- `add(x, y)`: parameters at offsets 4, 8
- `multiply(a, b, c)`: parameters at offsets 4, 8, 12

### `simple_test.pins`
Tests nested function definitions within let statements.
Expected output:
- `main` function with local variables `x`, `y`
- `main.add` nested function with parameters `a`, `b`

### `nested_test.pins`
Complex nesting test with multiple levels of function definitions.
Expected output:
- Proper nesting names like `main.inc.f` and `outer.inner.deepest`
- Correct depth calculations for each nesting level

### `initializers_test.pins`
Tests various types of variable initializers (int, char, string, arrays).
Expected output:
- Correct size calculations for multi-element initializers
- Proper handling of different literal types

## Running Tests

To test the memory phase on any file:

```bash
./compiler -m <test_file.pins>
```

This will output the memory organization information including:
- Function frames with their properties
- Variable access information (global vs local)
- Parameter and variable offsets

## Memory Layout

### Function Frame Layout
```
Higher addresses (parameters)
+--------+
| param3 | offset +12
+--------+
| param2 | offset +8  
+--------+
| param1 | offset +4
+--------+
| static | offset +0 (frame pointer points here)
| link   |
+--------+
| return | offset -4
| addr   |
+--------+
| saved  | offset -8
| FP     |
+--------+
| local1 | offset -12
+--------+
| local2 | offset -16
+--------+
Lower addresses (local variables)
```

## Validation

The implementation has been validated against the original Java tests:
- `tests/memory/test.pins24`
- `tests/memory/varDefs.pins24`
- `tests/memory/letStmts.pins24`

All tests produce equivalent memory layouts to the Java implementation.