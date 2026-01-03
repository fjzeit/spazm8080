# spazm8080 Architecture

## Implementation Status

This document describes the **target architecture** for the full spazm8080 assembler. Current implementation is simpler:

| Feature | Stage 1/2 (Current) | Final Target |
|---------|---------------------|--------------|
| Symbol table entry | 8 bytes (6 name + 2 value) | 16 bytes (with flags) |
| Output format | Raw .COM binary | Intel HEX or .COM |
| Lexer | Inline parsing | Separate module |
| Macros | Not implemented | Full MACRO/ENDM |
| Conditionals | Not implemented | IF/ELSE/ENDIF |
| Expressions | +, -, <, > only | Full operator set |
| Instructions | Raw hex bytes | 8080 mnemonics |

Current Stage 2: 1408 bytes, self-hosting, hex bytes + labels.

See [bootstrap.md](bootstrap.md) for current stage details.

## Target Overview

spazm8080 is a two-pass macro assembler. Pass 1 builds the symbol table and calculates addresses. Pass 2 generates code and writes output.

```
┌─────────────────────────────────────────────────────────────┐
│                        INPUT                                │
│  Source file (.ASM) read line-by-line via BDOS              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        LEXER                                │
│  Tokenize line into: label, mnemonic, operands, comment     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       PARSER                                │
│  Identify instruction/directive, parse operands             │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────────┐
│      PASS 1             │     │         PASS 2              │
│  - Define symbols       │     │  - Resolve expressions      │
│  - Calculate sizes      │     │  - Emit opcodes             │
│  - Expand macros        │     │  - Write output             │
└─────────────────────────┘     └─────────────────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────────┐
│     SYMBOL TABLE        │     │       OUTPUT                │
│  Name → Value, Flags    │     │  Intel HEX / Binary         │
└─────────────────────────┘     └─────────────────────────────┘
```

## Memory Map

```
0000H ┌─────────────────────┐
      │  CP/M Page Zero     │
0100H ├─────────────────────┤ ◄── TPA Start
      │  spazm8080 Code     │
      │  (~8-12KB)          │
      ├─────────────────────┤
      │  Static Data        │
      │  - Opcode tables    │
      │  - Error messages   │
      ├─────────────────────┤
      │  Buffers            │
      │  - Line buffer 128B │
      │  - Token buffer     │
      │  - HEX output buf   │
      ├─────────────────────┤
      │  Symbol Table       │
      │  (grows upward)     │
      │        ↓            │
      │                     │
      │        ↑            │
      │  Stack (grows down) │
      ├─────────────────────┤
BDOS  │  BDOS/BIOS          │
      └─────────────────────┘
```

## Data Structures

### Symbol Table Entry (16 bytes)

```
Offset  Size  Description
------  ----  -----------
  0       8   Name (space-padded, uppercase)
  8       2   Value (16-bit)
 10       1   Flags (see below)
 11       1   Reserved
 12       4   Reserved for future (macro ptr, etc.)
```

**Flags byte:**
- Bit 0: Defined (1 = symbol has value)
- Bit 1: Referenced (1 = symbol was used)
- Bit 2: Equate (1 = EQU, 0 = label)
- Bit 3: External (1 = EXTRN)
- Bit 4: Public (1 = PUBLIC)
- Bit 5: Set (1 = reassignable via SET)
- Bit 6-7: Reserved

### Token Types

```
TK_EOF      0   End of line
TK_LABEL    1   Label (with or without colon)
TK_IDENT    2   Identifier (mnemonic, symbol)
TK_NUMBER   3   Numeric literal
TK_STRING   4   String literal
TK_COMMA    5   Comma separator
TK_LPAREN   6   Left parenthesis
TK_RPAREN   7   Right parenthesis
TK_PLUS     8   Addition operator
TK_MINUS    9   Subtraction operator
TK_STAR    10   Multiplication operator
TK_SLASH   11   Division operator
TK_MOD     12   Modulo operator
TK_AND     13   Bitwise AND
TK_OR      14   Bitwise OR
TK_XOR     15   Bitwise XOR
TK_NOT     16   Bitwise NOT
TK_SHL     17   Shift left
TK_SHR     18   Shift right
TK_EQ      19   Equals (for EQU)
TK_DOLLAR  20   Location counter ($)
```

### Line Buffer Layout

```
LINEBUF:  DS  128    ; Raw input line from BDOS
LINELEN:  DS  1      ; Length of line
LINENUM:  DS  2      ; Current line number
```

## Module Interface

### Lexer (lexer.asm)

```
LEXINIT     Initialize lexer for new line
            Input:  HL = pointer to line buffer
            Output: None

LEXNEXT     Get next token
            Input:  None
            Output: A = token type
                    HL = pointer to token text
                    DE = numeric value (if TK_NUMBER)
                    CY set if error

LEXPEEK     Peek at next token without consuming
            Output: A = token type
```

### Parser (parser.asm)

```
PARSE       Parse current line
            Input:  None (uses lexer)
            Output: A = statement type
                    CY set if error

GETOPER     Parse operand
            Input:  A = operand number (0, 1)
            Output: A = operand type
                    HL = operand value
```

### Symbol Table (symtab.asm)

```
SYMINIT     Initialize symbol table
            Input:  None
            Output: None

SYMLOOK     Look up symbol
            Input:  HL = pointer to name (8 chars, padded)
            Output: HL = pointer to entry, or 0 if not found
                    Z set if found

SYMDEF      Define symbol
            Input:  HL = pointer to name
                    DE = value
                    A = flags
            Output: CY set if duplicate (and not SET)

SYMREF      Mark symbol as referenced
            Input:  HL = pointer to entry
            Output: None
```

### Expression Evaluator (expr.asm)

```
EXPR        Evaluate expression
            Input:  None (uses lexer)
            Output: HL = result value
                    CY set if error

EXPRATOM    Evaluate atomic expression (number, symbol, $)
            Output: HL = value
```

### Code Emitter (emit.asm)

```
EMITINIT    Initialize emitter for new pass
            Input:  None
            Output: None

EMITBYTE    Emit one byte
            Input:  A = byte value
            Output: None

EMITWORD    Emit 16-bit word (little-endian)
            Input:  HL = word value
            Output: None

SETORG      Set origin address
            Input:  HL = new address
            Output: None
```

### Output (output.asm)

```
OUTINIT     Initialize output file
            Input:  None
            Output: CY set if error

OUTFLUSH    Flush output buffer
            Input:  None
            Output: CY set if error

OUTCLOSE    Close output file, write final record
            Input:  None
            Output: None
```

## Assembly Algorithm

### Pass 1

```
1. Initialize symbol table, location counter = 0
2. For each line:
   a. Tokenize line
   b. If label present, define symbol with current LC
   c. Parse statement:
      - ORG: Set LC to value
      - EQU: Define symbol with expression value
      - DS: Add expression value to LC
      - DB/DW: Add data size to LC
      - Instruction: Add instruction size to LC
      - MACRO: Store macro definition
      - IF: Evaluate condition, set skip flag
   d. Handle INCLUDE by pushing current file state
3. Check for undefined symbols (referenced but not defined)
```

### Pass 2

```
1. Rewind source file, reset LC = 0
2. For each line:
   a. Tokenize line (same as pass 1)
   b. Skip label definition (already done)
   c. Parse statement:
      - ORG: Set LC, flush output buffer
      - EQU: Skip (already defined)
      - DS: Output zeros or skip, advance LC
      - DB: Evaluate expressions, emit bytes
      - DW: Evaluate expressions, emit words
      - Instruction: Emit opcode and operands
   d. Handle INCLUDE recursively
3. Write final HEX record, close file
```

## Instruction Encoding

### Opcode Table Structure

Each entry is 4 bytes:
```
Offset  Size  Description
------  ----  -----------
  0       3   Mnemonic (uppercase, space-padded)
  1       1   Opcode base byte
  2       1   Operand format code
  3       1   Instruction size (1-3 bytes)
```

**Operand format codes:**
```
FMT_NONE    0   No operands (NOP, HLT, etc.)
FMT_REG     1   Single register (INR B, DCR A)
FMT_RP      2   Register pair (PUSH BC, POP HL)
FMT_IMM8    3   8-bit immediate (MVI A,nn)
FMT_IMM16   4   16-bit immediate (LXI H,nnnn)
FMT_ADDR    5   16-bit address (JMP, CALL)
FMT_RST     6   Restart number 0-7 (RST n)
FMT_MOV     7   MOV r,r format
FMT_ARITH   8   Arithmetic r (ADD, SUB, etc.)
FMT_PORT    9   Port number (IN, OUT)
```

## Error Handling

Errors are collected and displayed after each pass. Assembly continues when possible to report multiple errors.

**Error codes:**
```
E_SYNTAX    1   Syntax error
E_UNDEF     2   Undefined symbol
E_DUPDEF    3   Duplicate symbol definition
E_PHASE     4   Phase error (value changed between passes)
E_RANGE     5   Value out of range
E_BADOP     6   Invalid operand
E_NOFILE    7   File not found
E_DISKFULL  8   Disk full
E_NOMEM     9   Out of memory (symbol table full)
```

## File I/O

Uses CP/M BDOS functions:
- Function 15 (0FH): Open file
- Function 16 (10H): Close file
- Function 20 (14H): Read sequential
- Function 21 (15H): Write sequential
- Function 22 (16H): Make file
- Function 26 (1AH): Set DMA address

Input files read 128 bytes at a time into line buffer. Lines terminated by CR/LF or LF. Output written via 128-byte sector buffer.

## Intel HEX Format

Each record:
```
:LLAAAATT[DD...]CC
```
- `:` - Start code
- `LL` - Byte count (hex)
- `AAAA` - Address (hex, big-endian)
- `TT` - Record type (00=data, 01=EOF)
- `DD` - Data bytes (hex)
- `CC` - Checksum (two's complement of sum)

Maximum 16 data bytes per record for compatibility.
