# Plan: Adding DB/DW/DS/EQU Directives via Stage 3

## Goal

Add data directives by creating Stage 3. Stage 2 remains frozen as the self-hosting baseline.

## Bootstrap Chain

```
STAGE1.COM (labels, ORG, END, </>)
     │
     └── assembles stage2.8hx (Stage 1 format)
              │
              └── STAGE2.COM (same capabilities, self-hosting) [FROZEN]
                       │
                       └── assembles stage3.8hx (Stage 2 format)
                                │
                                └── STAGE3.COM (adds DB/DW/DS/EQU)
                                         │
                                         └── can assemble files USING new directives
```

## Cold Bootstrap Constraint

**stage3.8hx must NOT use DB/DW/DS/EQU** - it only adds code to handle them.
STAGE2.COM doesn't understand these directives, so stage3.8hx stays in Stage 2 format.

## Files

| File | Format | Assembled By | Produces |
|------|--------|--------------|----------|
| `src/stage2.8hx` | Stage 1 | STAGE1.COM | STAGE2.COM (1408 bytes) - **FROZEN** |
| `src/stage3.8hx` | Stage 2 | STAGE2.COM | STAGE3.COM (~1620 bytes) |

## Implementation Order

### 1. EQU - Define Constant ✓ COMPLETE
**Syntax**: `LABEL EQU expr` (no colon!)
**Behavior**: Define symbol with value, doesn't advance LOCTR

**Implementation**: Modified CHKLBL to detect EQU pattern:
- CLNO: When whitespace found (not colon), save position, check for "EQU"
- CHEQU: Case-insensitive check for 'E','Q','U' keyword
- CLEQU: Parse expression, call DEFEQU with value in DE
- DEFEQU: Like DEFSYM but terminates on whitespace (not colon), uses passed value

**Test**: `FIVE EQU 5` + `3E FIVE` → outputs `3E 05` ✓

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

Stage 2 code ends around 0x580 (1408 bytes). Adding directives:
- EQU: ~50 bytes
- DB: ~100 bytes (string parsing is complex)
- DW: ~30 bytes
- DS: ~30 bytes

Estimated Stage 3 size: ~1620 bytes (still fits before TOKBUF at 0x620)

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
START:  C3 ENDLBL
        DS 5
ENDLBL: C9
```
Expected: `C3 08 01 00 00 00 00 00 C9` (START=0100, ENDLBL=0108)

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

## Creating stage3.8hx

1. Copy stage2.8hx to stage3.8hx
2. Add directive handling code
3. Assemble with STAGE2: `STAGE2 STAGE3`
4. Test each new directive with simple test files
5. Eventually: Stage 3 self-hosts using its own new features

## Verification

After each change:
1. `STAGE2 STAGE3` → new STAGE3.COM
2. Test new directive with simple file
3. Once all directives work: `STAGE3 STAGE3` → verify self-hosting
