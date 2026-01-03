# Stage 1 Design

Stage 1 extends Stage 0's hex format with labels, directives, and expressions. Two-pass assembly enables forward references.

## Implementation Status

| Feature | Status |
|---------|--------|
| Labels (LABEL:) | Implemented |
| ORG directive | Implemented |
| END directive | Implemented |
| Symbol refs (C3 LABEL) | Implemented |
| Low/high byte (<, >) | Implemented |
| Token-length parsing | Implemented |
| EQU directive | **Not implemented** |
| DB/DW/DS directives | **Not implemented** |
| String literals | **Not implemented** |
| Expression arithmetic (+, -) | **Not implemented** |

See [stage1-testing.md](stage1-testing.md) for bug fixes and milestones.

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
3E <ADDR        ; MVI A,low(ADDR) - 2 bytes: 3E lowbyte
3E >ADDR        ; MVI A,high(ADDR) - 2 bytes: 3E highbyte
```

Symbol reference rules:
- Bare `LABEL` → emit low byte, then high byte (16-bit little-endian)
- `<LABEL` or `<expr` → emit only low byte
- `>LABEL` or `>expr` → emit only high byte
- `'c'` → emit ASCII value of character

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

## Memory Layout (Actual Stage 1/2 Implementation)

```
0100-061F: Code (~1296-1408 bytes)
0620-069F: Token buffer (128 bytes)
06A0-06EF: Line buffer (80 bytes)
06F0-06FB: Variables (12 bytes):
           06F0: PASS    (1 byte)
           06F1: ICNT    (1 byte)
           06F2: IPTR    (2 bytes)
           06F4: OCNT    (1 byte)
           06F5: OPTR    (2 bytes)
           06F7: SYMCNT  (1 byte)
           06F8: LOCTR   (2 bytes)
           06FA: LNPTR   (2 bytes)
0700-077F: Input buffer (128 bytes)
0780-07FF: Output buffer (128 bytes)
0800-083F: Output FCB (64 bytes)
0840+:     Symbol table (8 bytes per entry)
```

### Symbol Table Entry (8 bytes)
```
+0-5: Name (6 chars, uppercase, space-padded)
+6:   Value low byte
+7:   Value high byte
```

Simple linear search with SYMCNT entries. No hash, no flags in current implementation.

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
