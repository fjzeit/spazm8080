# Plan: Adding DB/DW/DS/EQU Directives to Stage 2

## Goal
Add data directives to STAGE2.COM while preserving cold bootstrap.

## Cold Bootstrap Constraint

**stage2.8hx must NOT use DB/DW/DS/EQU** - only adds code to handle them.
STAGE1.COM doesn't understand these directives, so stage2.8hx stays in Stage 1 format.

```
STAGE1.COM (understands: labels, ORG, END, hex bytes, </>)
     │
     └── assembles stage2.8hx (uses only Stage 1 features)
              │
              └── produces STAGE2.COM (now understands DB/DW/DS/EQU)
                       │
                       └── can assemble files USING DB/DW/DS/EQU
```

## Implementation Order

### 1. EQU - Define Constant
**Syntax**: `LABEL EQU expr` (no colon!)
**Behavior**: Define symbol with value, doesn't advance LOCTR

**Detection**: After label check fails, check if next token is "EQU"
**Parsing**:
```
; In PARSE, after CHKLBL returns:
; Check if current token is "EQU"
2A FA 06        ; LHLD LNPTR
7E              ; MOV A,M - get first char
FE 45           ; CPI 'E'
C2 xxxx         ; JNZ not_equ
23              ; INX H
7E              ; MOV A,M
FE 51           ; CPI 'Q'
C2 xxxx         ; JNZ not_equ
; ... etc
```

**Note**: EQU doesn't use DEFSYM directly - needs separate path since no colon.

### 2. DB - Define Bytes
**Syntax**: `DB expr, expr, 'string'`
**Behavior**: Emit bytes, advance LOCTR

**Cases**:
- Numeric: `DB 0AH` → emit 0x0A
- Multiple: `DB 10, 20, 30` → emit 3 bytes
- String: `DB 'Hello'` → emit 48 65 6C 6C 6F
- Mixed: `DB 'A', 0DH, 0AH`

**Parsing**:
```
DB_LOOP:
  call SKIPWS
  check for quote → DB_STRING
  call EXPR → get value in HL
  MOV A,L
  call OUTPUT
  check for comma → continue
  done

DB_STRING:
  skip quote
  for each char until closing quote:
    output char
  skip quote
  check comma
```

### 3. DW - Define Word
**Syntax**: `DW expr, expr`
**Behavior**: Emit 16-bit values little-endian

**Parsing**: Like DB but output both L and H.

### 4. DS - Define Space
**Syntax**: `DS expr`
**Behavior**: Reserve space (output zeros or just advance LOCTR)

**Parsing**:
```
call EXPR → count in HL
; In pass 1: just add to LOCTR
; In pass 2: output zeros (or skip?)
```

## Memory Impact

Current code ends around 0x580 (1408 bytes). Adding directives:
- EQU: ~50 bytes
- DB: ~100 bytes (string parsing is complex)
- DW: ~30 bytes
- DS: ~30 bytes

Estimated new size: ~1620 bytes (still fits before TOKBUF at 0x620)

## Testing Strategy

### Test 1: EQU
```
FIVE    EQU 5
        ORG 0100H
        3E FIVE         ; MVI A,5
        END
```
Expected: `3E 05`

### Test 2: DB
```
        ORG 0100H
        DB 41H          ; 'A'
        DB 'BC'
        END
```
Expected: `41 42 43`

### Test 3: DW
```
        ORG 0100H
        DW 1234H
        END
```
Expected: `34 12`

### Test 4: DS
```
        ORG 0100H
START:  C3 END
        DS 5
END:    C9
```
Expected: `C3 08 01 00 00 00 00 00 C9` (START=0100, END=0108)

## Implementation Notes

### CHKDIR Modification
Current CHKDIR checks for ORG and END. Extend to check DB, DW, DS:
- 'D' → check for 'B' (DB), 'W' (DW), 'S' (DS)
- 'E' → check for 'N' (END), 'Q' (EQU - but this is different!)

### EQU is Special
EQU appears BEFORE a label-like identifier: `NAME EQU value`
Unlike other directives, it's detected during label scanning, not CHKDIR.

Approach: In CHKLBL, if no colon found, check if next token is "EQU".
If yes, parse value and call DEFSYM with the name.

## Files to Modify

- `src/stage2.8hx`: Add directive handling code
- Test after each directive to ensure self-hosting still works

## Verification

After each change:
1. `STAGE1 STAGE2` → new STAGE2.COM
2. `STAGE2 STAGE2` → should produce identical binary
3. Test new directive with simple file
