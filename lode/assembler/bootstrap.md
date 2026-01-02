# Bootstrap Strategy

spazm8080 bootstraps from zero - no external assembler. We hand-assemble stage 0 in hex, inject via MCP's `PokeMemory`, then iterate.

## Bootstrap Stages

```
┌─────────────────────────────────────────────────────────────┐
│  Stage 0: Hand-assembled hex bytes                          │
│  - Injected via PokeMemory at 0100H                         │
│  - Saved to disk via CP/M SAVE command                      │
│  - Capabilities: ORG, DB, END only                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: Assembled by Stage 0                              │
│  - Adds: EQU, DS, DW, labels, expressions                   │
│  - Adds: Basic instructions (MOV, LXI, JMP, CALL, RET)      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 2: Assembled by Stage 1                              │
│  - Full 8080 instruction set                                │
│  - Intel HEX output                                         │
│  - Error messages                                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 3: Full spazm8080                                    │
│  - Macros, conditionals                                     │
│  - Self-hosting complete                                    │
└─────────────────────────────────────────────────────────────┘
```

## Stage 0 Design

Minimal assembler supporting only:
- `ORG addr` - Set location counter
- `DB n,n,...` - Define bytes (hex or decimal)
- `END` - Stop assembly, output binary

No labels, no expressions, no instructions. Just a glorified hex loader that outputs a raw .COM file.

### Input Format

```
ORG 0100H
DB 21H,00H,01H    ; LXI H,0100H
DB C3H,00H,00H    ; JMP 0000H
END
```

### Stage 0 Algorithm

```
1. Open input file (FCB at 005CH)
2. Open output file (change extension to .COM)
3. Set location counter = 0
4. For each line:
   a. Skip whitespace
   b. If "ORG": parse hex number, set LC
   c. If "DB": parse comma-separated bytes, write to output
   d. If "END": close files, exit
   e. If ";": skip comment
5. Flush and close output
```

### Size Estimate

Stage 0 should be ~200-300 bytes:
- File I/O setup: ~50 bytes
- Line reader: ~40 bytes
- ORG parser: ~30 bytes
- DB parser: ~60 bytes
- Hex output: ~40 bytes
- Main loop: ~30 bytes

## MCP Bootstrap Workflow

```
1. Hand-assemble stage 0 to hex bytes (documented in src/stage0.hex)
2. PokeMemory(0x0100, stage0_bytes)
3. SendInput("SAVE nn SPAZM0.COM\r")  ; nn = pages needed
4. Write stage 1 source (using ORG/DB/END only)
5. SendInput("SPAZM0 STAGE1\r")
6. Test STAGE1.COM
7. Repeat for higher stages
```

## Key Constraints

- Stage 0 must be small enough to hand-assemble reliably
- Each stage must be able to assemble the next stage
- Final stage must be able to re-assemble itself (self-hosting)

## Related

- [architecture.md](architecture.md) - Full assembler design
- [../practices.md](../practices.md) - 8080 coding patterns
