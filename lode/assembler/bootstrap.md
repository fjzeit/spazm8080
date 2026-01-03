# Bootstrap Strategy

spazm8080 bootstraps from zero - no external assembler required.

## Cold Boot Pipeline (PROTECTED)

| File | Format | Assembler | Output | Size | Status |
|------|--------|-----------|--------|------|--------|
| `src/stage0.8hx` | Raw hex | Hand/xxd | `stage0.com` | 432 bytes | **FROZEN** |
| `src/stage1.8hx` | Raw hex | Stage 0 | `stage1.com` | 1280 bytes | Editable* |

### What's FROZEN vs Editable

- **stage0.8hx is FROZEN**: Cannot use any assembler features - just raw hex. Never modify.
- **stage1.8hx is EDITABLE**: Can be modified, but **must remain in Stage 0 format** (raw hex bytes + comments). After edits, run `python3 scripts/fixaddr.py` to recalculate addresses.

### Why Stage 0 Format Matters

- Stage 0 only understands: hex byte pairs + `;` comments
- stage1.8hx uses hardcoded addresses like `CA C5 03` (JZ 03C5H)
- If we add label references, Stage 0 can't assemble it → cold boot breaks
- stage0.8hx is the true "seed" - everything else grows from it

### Cold Boot Procedure

```bash
# From absolute zero (no binaries exist):

# 1. Create fresh disk from lolos base
cp path/to/lolos.dsk work.dsk

# 2. Convert stage0.8hx to binary (strip comments, then hex-to-binary)
sed 's/;.*//' src/stage0.8hx | xxd -r -p > /tmp/spazm0.com

# 3. Copy Stage 0 and Stage 1 source to disk
cpmcp -f ibm-3740 work.dsk /tmp/spazm0.com 0:SPAZM0.COM
cpmcp -f ibm-3740 work.dsk src/stage1.8hx 0:STAGE1.HEX

# 4. Boot CP/M and assemble Stage 1
A>SPAZM0 STAGE1                          # Produces STAGE1.COM

# 5. Now Stage 1 exists and can assemble Stage 2+
A>STAGE1 STAGE2                          # Produces STAGE2.COM
```

**Note**: The `sed 's/;.*//'` strips comments before `xxd -r -p` converts hex to binary.

## Bootstrap Stages

```
COLD BOOT (frozen, raw hex):
┌─────────────────────────────────────────────────────────────┐
│  Stage 0: src/stage0.8hx → SPAZM0.COM                      │
│  Format: Raw hex bytes only                                  │
│  Capabilities: Hex pairs + semicolon comments               │
│  Status: COMPLETE (432 bytes)                               │
└─────────────────────────────────────────────────────────────┘
                              │ assembles
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: src/stage1.8hx → STAGE1.COM                      │
│  Format: Raw hex bytes only (Stage 0 input)                 │
│  Capabilities: Labels, ORG, END, symbol refs, </>           │
│  Status: COMPLETE (1280 bytes, 7 bugs fixed)                │
└─────────────────────────────────────────────────────────────┘
                              │ assembles
                              ▼
FORWARD DEVELOPMENT (uses Stage 1 format):
┌─────────────────────────────────────────────────────────────┐
│  Stage 2: src/stage2.8hx → STAGE2.COM                      │
│  Format: Stage 1 syntax (labels, symbols)                   │
│  New: DB, DW, DS, EQU directives                            │
│  Goal: Self-hosting (can reassemble itself)                 │
│  Status: IN PROGRESS (source exists, ready to assemble)     │
└─────────────────────────────────────────────────────────────┘
                              │ assembles
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 3+: Full spazm8080                                   │
│  Format: Stage 2 syntax                                     │
│  New: Full 8080 mnemonics, macros, conditionals             │
│  Goal: Assemble lolos source                                │
│  Status: NOT STARTED                                        │
└─────────────────────────────────────────────────────────────┘
```

## Format Comparison

### Stage 0 Format (raw hex)
```
; This is a comment
21 00 01        ; LXI H,0100H - just hex bytes
C3 00 01        ; JMP 0100H - hardcoded address
4E 6F 24        ; "No$" - even strings are raw hex
```

### Stage 1 Format (labels + symbols)
```
        ORG 0100H
START:
        21 00 01        ; LXI H,0100H
        C3 START        ; JMP START - symbolic reference
        3E <START       ; MVI A,low(START)
        3E >START       ; MVI A,high(START)
MSG:    4E 6F 24        ; "No$" - still raw hex for now
        END
```

### Stage 2 Format (planned: adds data directives)
```
        ORG 0100H
BDOS    EQU 0005H
START:
        21 00 01        ; LXI H,0100H
        C3 START        ; JMP START
MSG:    DB 'No$'        ; String literal
COUNT:  DB 10, 0AH      ; Multiple bytes
PTR:    DW START        ; 16-bit word
BUF:    DS 128          ; Reserve space
        END
```

## Stage 0 Details (COMPLETE)

Minimal hex-to-COM converter. Reads `.HEX`, writes `.COM`.

### Input Rules
- Hex byte pairs separated by whitespace (space, tab, CR, LF)
- `;` starts comment until end of line
- Case-insensitive (accepts `FF` or `ff`)
- LOLOS-aware: Handles 0x00 padding as EOF

### Memory Map (432 bytes)
```
0100-011E: Startup (open input, copy FCB, set .COM extension)
011F-0134: FCB copy loop, zero loop
0135-015C: Delete old/Create new output file
015D-019A: MAIN loop - parse hex pairs
019A-01A7: SKIPCMT - skip to newline
01A8-01BD: DONE - flush, close, exit
01BE-0200: GETCHR - buffered input
0201-0229: HEXVAL - hex char to nibble
022A-0265: OUTPUT - buffered output
0266-0276: WRSEC - write sector
0277-028D: Error handlers
028E-02A6: Error messages
02A7+: Buffers and FCB
```

## Stage 1 Details (COMPLETE)

Two-pass assembler with labels. Reads `.HEX`, writes `.COM`.

### Capabilities
- Labels with colon suffix: `LABEL:`
- ORG directive: `ORG 0100H`
- END directive: `END`
- Symbol references in hex: `C3 LABEL` → `C3 lo hi`
- Low/high byte operators: `<LABEL`, `>LABEL`
- Hex numbers: `0FFH`, `$FF`, decimal: `255`
- Two-pass: forward references resolved

### Memory Map (1280 bytes)
```
0100-05FF: Code (ends ~0x0600)
0600-067F: Token buffer
0680-06EF: Line buffer
06F0-06FB: Variables (PASS, ICNT, IPTR, OCNT, OPTR, SYMCNT, LOCTR, LNPTR)
0700-077F: Input buffer
0780-07FF: Output buffer
0800-083F: Output FCB
0840-0A3F: Symbol table (64 entries × 8 bytes)
```

### NOT YET IMPLEMENTED
- EQU directive
- DB, DW, DS directives
- Expression arithmetic (+, -)
- Character literals in hex context ('A')

## Stage 2 Plan

Port Stage 1 functionality to Stage 1 format, then extend:

1. **Verify bootstrap**: Write `stage2.hex` using Stage 1 syntax
2. **Match output**: `STAGE1 STAGE2` should work (same logic, different format)
3. **Add DB**: `DB expr, expr, 'string'`
4. **Add DW**: `DW expr, expr` (little-endian)
5. **Add DS**: `DS expr` (reserve bytes)
6. **Add EQU**: `LABEL EQU expr`
7. **Self-host**: Stage 2 assembles itself

## Key Invariants

1. **stage0.8hx is immutable** - The true seed file; never modify
2. **stage1.8hx must stay in Stage 0 format** - Editable, but only raw hex bytes
3. **Each stage assembles the next** - Stage N produces Stage N+1
4. **Forward compatibility** - Higher stages accept lower stage formats
5. **Self-hosting goal** - Final stage reassembles itself identically
6. **Use fixaddr.py after editing stage1.8hx** - Recalculates all addresses automatically

## Related

- [architecture.md](architecture.md) - Full assembler design
- [stage1-design.md](stage1-design.md) - Stage 1 syntax details
- [workflow.md](workflow.md) - cpmtools sync workflow
- [../practices.md](../practices.md) - 8080 coding patterns
