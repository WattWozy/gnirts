# Base-127 Formal Language REPL

A high-precision arithmetic engine and formal language runtime for Base-127.

## Getting Started

To start the interactive Read-Eval-Print Loop (REPL), run:

```bash
mix run -e "Base127.REPL.start()"
```

## Features

### 1. Base-127 Arithmetic
Use standard operators `+`, `-`, `*`, `/` with Base-127 glyphs. Multiplication and division have higher precedence.

- **Example**: `3A + 7 * 2`
- **Parentheses**: `(1 + 2) * 3`

### 2. Exact Rationals
Division always yields exact rational numbers, never approximations.

- **Example**: `1 / 3` results in `1/3`

### 3. Variable Assignments
Store results in variables for later use.

- **Example**: `x = 42 + 7`
- **Usage**: `x * 2`

### 4. Special Commands
- `:approx N expression`: Renders the expression as a Base-127 decimal to `N` fractional digits.
    - **Example**: `:approx 5 1/3` -> `0.ggggg`
- `:clear`: Resets all variables in the current session.
- `:cls`: Clears the terminal screen.
- `:vars`: Lists all variables bound in the current session.
- **Exit**: Press `Ctrl+C` or `Ctrl+D` to quit.

## Alphabet
The system uses a 127-character alphabet:
- `0-9`, `A-Z`, `a-z` (Values 0-61)
- Greek letters, Math symbols, Geometric shapes (Values 62-126)
