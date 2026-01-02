# Stage 1 Design

Stage 1 extends Stage 0's hex format with labels, directives, and expressions. Two-pass assembly enables forward references.

## Input Format

```
; Comments still start with semicolon
BDOS    EQU 0005H           ; Define constant
        ORG 0100H           ; Set origin

START:                      ; Label at current address
        21 00 01            ; LXI H,0100H (raw hex still works)
        C3 LOOP             ; JMP LOOP - symbol in operand
LOOP:
        CD BDOS             ; CALL 0005H
        C3 START            ; JMP START

MSG:    DB 'Hello$'         ; String literal
COUNT:  DB 0AH, 10          ; Hex and decimal bytes
PTR:    DW START            ; 16-bit word (little-endian)
BUF:    DS 80H              ; Reserve 128 bytes

        END
```

## Syntax Rules

### Labels
- `LABEL:` - colon suffix defines label at current address
- Labels are case-insensitive (converted to uppercase)
- Max 8 characters (CP/M convention)

### Directives
| Directive | Syntax | Description |
|-----------|--------|-------------|
| EQU | `LABEL EQU expr` | Define constant (no colon) |
| ORG | `ORG expr` | Set location counter |
| DB | `DB expr, expr, 'str'` | Define bytes |
| DW | `DW expr, expr` | Define words (little-endian) |
| DS | `DS expr` | Reserve bytes (zero-filled) |
| END | `END` | End of source |

### Expressions
- Decimal: `255`, `0`
- Hex: `0FFH`, `0ffh`, `$FF`, `0xFF`
- Symbols: `LABEL`, `START`
- Operators: `+`, `-`, `<` (low byte), `>` (high byte)
- Parentheses: `(expr)`

Examples:
- `<START` → low byte of START
- `>START` → high byte of START
- `START+5` → START plus 5
- `BUF-MSG` → difference (length)

### Hex Bytes with Symbols
```
C3 LOOP         ; JMP LOOP - 3 bytes: C3 <LOOP >LOOP
21 BUF          ; LXI H,BUF - 3 bytes: 21 <BUF >BUF
3E 'A'          ; MVI A,'A' - 2 bytes: 3E 41
```

When a symbol appears where a byte is expected:
- Single token after opcode: emit low byte, then high byte (little-endian)
- This handles 16-bit operands naturally

## Two-Pass Architecture

```
┌─────────────────────────────────────────────────────┐
│  Pass 1: Symbol Collection                          │
│  - Parse labels, EQU, directives                    │
│  - Track location counter                           │
│  - Build symbol table                               │
│  - Don't generate output                            │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│  Pass 2: Code Generation                            │
│  - Rewind input file                                │
│  - Parse again, resolve all symbols                 │
│  - Generate output bytes                            │
│  - Report undefined symbols                         │
└─────────────────────────────────────────────────────┘
```

## Memory Layout

```
0100-03FF: Code (~768 bytes estimated)
0400-05FF: Symbol table (128 entries × 4 bytes = 512 bytes)
0600-067F: Line buffer (128 bytes)
0680-06FF: Token buffer (128 bytes)
0700-077F: Input buffer (128 bytes)
0780-07FF: Output buffer (128 bytes)
0800-083F: Input FCB (64 bytes with work area)
0840-087F: Output FCB (64 bytes with work area)
0880+: Available for larger programs
```

### Symbol Table Entry (4 bytes)
```
+0: Name hash (1 byte) - for fast lookup
+1: Value low (1 byte)
+2: Value high (1 byte)
+3: Flags (1 byte) - bit 0: defined, bit 7: in-use
```

Symbol names stored separately in name table:
```
0600-07FF: Name strings (512 bytes)
           Each entry: length byte + up to 8 chars
```

Revised layout with name table:
```
0100-04FF: Code (~1KB)
0500-05FF: Symbol entries (64 entries × 4 bytes = 256 bytes)
0600-07FF: Symbol names (64 entries × 8 bytes avg = 512 bytes)
0800-087F: Line buffer (128 bytes)
0880-08FF: Input buffer (128 bytes)
0900-097F: Output buffer (128 bytes)
0980-09BF: Input FCB (64 bytes)
09C0-09FF: Output FCB (64 bytes)
```

## Key Routines

### PARSE - Main parser
- Read line into buffer
- Identify: label, directive, hex bytes, comment
- Dispatch to appropriate handler

### EXPR - Expression evaluator
- Parse number, symbol, or parenthesized expression
- Handle operators: +, -, <, >
- Return 16-bit value in HL

### LOOKUP - Symbol table lookup
- Hash symbol name
- Linear probe for collision
- Return pointer to entry or NULL

### DEFINE - Add symbol to table
- Check for redefinition
- Add name to name table
- Create entry with value

### OUTPUT - Byte output (from Stage 0)
- Buffered write to output file
- Unchanged from Stage 0

## Error Handling

| Error | Message |
|-------|---------|
| Undefined symbol | `Undef: XXXX` |
| Duplicate symbol | `Redef: XXXX` |
| Syntax error | `Syntax` |
| Expression error | `Expr` |
| No file | `No file` |
| Disk full | `Disk full` |

## Test Cases

### test1.hex - Basic labels
```
        ORG 0100H
START:  C3 START        ; JMP START (infinite loop)
        END
```
Expected: `C3 00 01` (3 bytes)

### test2.hex - EQU and expressions
```
FIVE    EQU 5
TEN     EQU FIVE+FIVE
        ORG 0100H
        3E TEN          ; MVI A,10
        END
```
Expected: `3E 0A` (2 bytes)

### test3.hex - DB/DW/DS
```
        ORG 0100H
MSG:    DB 'Hi$'
PTR:    DW MSG
BUF:    DS 10
        END
```
Expected: `48 69 24 00 01 00 00 00 00 00 00 00 00` (13 bytes)

## Implementation Order

1. Skeleton: file handling, two-pass structure
2. Line parser: tokenize, identify labels/directives
3. Symbol table: LOOKUP, DEFINE
4. Directives: ORG, END, EQU
5. DB directive with literals
6. Expression evaluator: numbers, +, -
7. Symbol references in hex bytes
8. DW, DS directives
9. Expression operators: <, >
10. Testing and debugging

## Related

- [bootstrap.md](bootstrap.md) - Overall bootstrap strategy
- [../practices.md](../practices.md) - 8080 coding patterns
