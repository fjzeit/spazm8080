# Coding Practices

Patterns and conventions for spazm8080 development, following lolos style.

## Code Organization

### File Header
Every source file begins with a comment block:
```asm
;===============================================================================
; Module Name - Brief Description
;===============================================================================
```

### Subroutine Documentation
```asm
;-------------------------------------------------------------------------------
; SUBNAME - Brief description
;-------------------------------------------------------------------------------
; Description:
;   Detailed explanation of what the subroutine does.
;
; Input:
;   A       - [REQ] Description of required input
;   HL      - [OPT] Description of optional input
;
; Output:
;   A       - Description of output
;   Flags   - Z set if condition, CY set if error
;
; Clobbers:
;   BC, DE
;-------------------------------------------------------------------------------
```

## Register Conventions

### Preserved Registers
Subroutines should preserve BC, DE, HL unless documented as clobbered.

### Parameter Passing
- **A** - Primary 8-bit parameter/result
- **HL** - Primary 16-bit parameter/pointer
- **DE** - Secondary 16-bit parameter
- **BC** - Counter or tertiary parameter

### Return Values
- **A** - 8-bit result
- **HL** - 16-bit result or pointer
- **CY** - Error flag (set = error)
- **Z** - Boolean result (Z = true/success)

## Common Patterns

### Compare HL to DE
```asm
; Set CY if HL < DE, Z if HL == DE
        MOV     A, H
        CMP     D
        RNZ                     ; H != D, flags set
        MOV     A, L
        CMP     E               ; L vs E determines result
```

### 16-bit Increment with Test
```asm
        INX     H
        MOV     A, H
        ORA     L               ; Z set if HL == 0 (wrapped)
```

### Multiply by Constant
```asm
; HL = HL * 3
        MOV     D, H
        MOV     E, L            ; DE = HL
        DAD     H               ; HL = HL * 2
        DAD     D               ; HL = HL + DE = HL * 3
```

### Table Lookup (Byte)
```asm
        LXI     H, TABLE
        MVI     D, 0
        MOV     E, A            ; Index in A
        DAD     D               ; HL = TABLE + index
        MOV     A, M            ; A = TABLE[index]
```

### Table Lookup (Word)
```asm
        LXI     H, TABLE
        MOV     E, A
        MVI     D, 0
        DAD     D
        DAD     D               ; HL = TABLE + index*2
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = TABLE[index]
```

### String Output (BDOS)
```asm
        LXI     D, MESSAGE
        MVI     C, 9            ; BDOS print string
        CALL    5
        ...
MESSAGE: DB     'Hello$'        ; $ terminated
```

## Memory Layout

### Buffer Allocation
Place buffers at end of program with DS:
```asm
        ORG     0100H
        ; ... code ...

        ; Data area
BUFFER: DS      128             ; 128-byte buffer
SYMTAB: DS      1024            ; Symbol table
```

### Page Alignment
For performance-critical tables:
```asm
        ORG     ($ + 255) AND 0FF00H  ; Align to page
TABLE:  DB      ...
```

## Error Handling

### Return Codes
- CY clear = success
- CY set = error, A contains error code

### Error Recovery
```asm
        CALL    OPERATION
        JC      ERROR           ; Handle error
        ; Continue on success
```

## BDOS Conventions

### Console Output
```asm
        MVI     C, 2            ; BDOS console output
        MVI     E, 'A'          ; Character
        CALL    5
```

### File Operations
```asm
        LXI     D, FCB          ; File Control Block
        MVI     C, 15           ; BDOS open file
        CALL    5
        ORA     A               ; 0 = success, FF = not found
```

## Assembler-Specific Patterns

### Symbol Table Entry
Fixed-size entries for predictable addressing:
```asm
; Entry: 8 bytes name + 2 bytes value + 1 byte flags = 11 bytes
SYMSIZE EQU     11
```

### Hash Function
Simple multiplicative hash for symbol lookup:
```asm
; Hash name pointed to by HL, result in A
HASH:   XRA     A
HASHLP: MOV     B, M
        ORA     B
        RZ                      ; End of name
        ADD     A               ; A = A * 2
        ADD     B               ; A = A + char
        INX     H
        JMP     HASHLP
```

### Two-Pass Coordination
```asm
PASS:   DB      1               ; Current pass (1 or 2)
        ...
        LDA     PASS
        CPI     2
        JNZ     SKIP_EMIT       ; Only emit on pass 2
```

### File Rewind for Multi-Pass (CP/M 2.2)

**Critical**: For multi-extent files (>16KB), you must RE-OPEN to rewind:

```asm
; Rewind input file for pass 2
        XRA     A
        STA     FCB+32          ; Reset CR (current record)
        STA     FCB+12          ; Reset EX (extent)
        LXI     D, FCB
        MVI     C, 15           ; BDOS Open File
        CALL    5               ; Reloads extent 0 allocation
```

**Why**: CP/M's Read Sequential uses allocation blocks (FCB+16..+31) directly. Open copies the directory entry's allocation map into the FCB. Simply resetting EX/CR doesn't reload the allocation - the FCB still points to the last extent's disk blocks.

**Exception**: Single-extent files (<16KB) work with just CR reset since extent 0 is already loaded.

See `lode/assembler/stage1-testing.md` Bug 7 for verification against CP/M internals.
