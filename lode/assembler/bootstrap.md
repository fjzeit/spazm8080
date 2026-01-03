# Bootstrap Strategy

spazm8080 bootstraps from zero - no external assembler required.

## Cold Boot Pipeline (PROTECTED)

These files enable bootstrapping from nothing. **NEVER MODIFY** - they use raw hex with hardcoded addresses that Stage 0 can process.

| File | Format | Assembler | Output | Size |
|------|--------|-----------|--------|------|
| `src/stage0.8hex` | Raw hex | Hand/xxd | `stage0.com` | 432 bytes |
| `src/stage1.8hex` | Raw hex | Stage 0 | `stage1.com` | 1172 bytes |

### Why These Are Frozen

- **Stage 0 format**: Raw hex bytes + `;` comments only. No labels, no directives.
- **Stage 1.8hex** uses hardcoded addresses like `CA C4 03` (JMP 03C4H)
- If we add label references, Stage 0 can't assemble it → cold boot breaks
- These files are the "seed" - everything else grows from them

### Cold Boot Procedure

```bash
# From absolute zero (no binaries exist):
xxd -r -p stage0.8hex > stage0.com      # Or hand-assemble
cpmcp -f ibm-3740 work.dsk stage0.com 0:SPAZM0.COM

# Boot CP/M, then:
A>SPAZM0 STAGE1                          # Produces STAGE1.COM

# Now Stage 1 exists and can assemble Stage 2+
```

## Bootstrap Stages

```
COLD BOOT (frozen, raw hex):
┌─────────────────────────────────────────────────────────────┐
│  Stage 0: src/stage0.8hex → SPAZM0.COM                      │
│  Format: Raw hex bytes only                                  │
│  Capabilities: Hex pairs + semicolon comments               │
│  Status: COMPLETE (432 bytes)                               │
└─────────────────────────────────────────────────────────────┘
                              │ assembles
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: src/stage1.8hex → STAGE1.COM                      │
│  Format: Raw hex bytes only (Stage 0 input)                 │
│  Capabilities: Labels, ORG, END, symbol refs, </>           │
│  Status: COMPLETE (1172 bytes)                              │
└─────────────────────────────────────────────────────────────┘
                              │ assembles
                              ▼
FORWARD DEVELOPMENT (uses Stage 1 format):
┌─────────────────────────────────────────────────────────────┐
│  Stage 2: src/stage2.hex → STAGE2.COM                       │
│  Format: Stage 1 syntax (labels, symbols)                   │
│  New: DB, DW, DS, EQU directives                            │
│  Goal: Self-hosting (can reassemble itself)                 │
│  Status: NOT STARTED                                        │
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

### Memory Map (1172 bytes)
```
0100-057F: Code
0580-058F: Variables (PASS, ICNT, IPTR, OCNT, OPTR, SYMCNT, LOCTR, LNPTR)
0600-067F: Token buffer
0680-06FF: Line buffer
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

1. **Cold boot files are immutable** - `stage0.8hex` and `stage1.8hex` never change
2. **Each stage assembles the next** - Stage N produces Stage N+1
3. **Forward compatibility** - Higher stages accept lower stage formats
4. **Self-hosting goal** - Final stage reassembles itself identically

## Related

- [architecture.md](architecture.md) - Full assembler design
- [stage1-design.md](stage1-design.md) - Stage 1 syntax details
- [workflow.md](workflow.md) - cpmtools sync workflow
- [../practices.md](../practices.md) - 8080 coding patterns
