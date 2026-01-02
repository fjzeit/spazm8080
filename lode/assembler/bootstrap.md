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

## Stage 0 Design (COMPLETED)

Minimal hex-to-COM converter. Even simpler than originally planned - just raw hex bytes.

### Input Format (.HEX)

```
; Comment lines start with semicolon
21 65 00        ; LXI H,0065H - bytes separated by whitespace
36 48 23        ; MVI M,'H'; INX H
C3 00 00        ; JMP 0000H
```

### Features
- Hex byte pairs separated by whitespace (space, tab, CR, LF)
- `;` starts comment until end of line
- Outputs raw binary `.COM` file
- **LOLOS-aware**: Handles 0x00 padding as EOF (not just 0x1A)

### Stage 0 Memory Map (429 bytes)

```
0100-011E: Startup (open input, copy FCB, set .COM extension)
011F-0134: COPY loop, ZERO loop
0135-015C: Delete old/Create new output file
015D-019A: MAIN loop - read char, skip whitespace, parse hex pairs
019A-01A7: SKIPCMT - skip until newline
01A8-01BD: DONE - flush buffer, close files, exit
01BE-0200: GETCHR - buffered file reader
0201-0229: HEXVAL - convert ASCII hex to nibble
022A-0265: OUTPUT - buffered file writer
0266-0276: WRSEC - write 128-byte sector
0277-028D: Error handlers (No file, Disk full, Syntax)
028E-02A6: Error message strings
02A7-02AC: Variables (IPTR, ICNT, OPTR, OCNT)
02AD-032C: Input buffer (128 bytes)
032D-03AC: Output buffer (128 bytes)
03AD-03CC: Output FCB (32 bytes)
```

### Key Symbols (v3 corrected addresses)

```
COPY=011F  ZERO=0135  MAIN=015D  SKIPCMT=019A  DONE=01A8
GETCHR=01BE  GC1=01E4  GC2=01FF  HEXVAL=0201  HV1=0222
HV2=0225  HVERR=0228  OUTPUT=022A  FLUSH=024C  FL1=0254
WRSEC=0266  NOFILE=0277  DSKFUL=027D  SYNERR=0283  ERROR=0286
```

### Lessons Learned

1. **LOLOS EOF**: LOLOS pads files with 0x00, not 0x1A (CP/M standard). Must check both.
2. **Address calculation**: Hand-assembly requires meticulous byte counting. Off-by-one errors cascade.
3. **CP/M SAVE**: Failed on LOLOS. Used `cpmcp` from host instead.

## MCP Bootstrap Workflow (Updated)

```
1. Hand-assemble stage 0 in src/stage0.hex
2. Convert to binary: parse hex, write to src/stage0.com
3. Copy to disk: cpmcp -f ibmpc-sssd work.dsk src/stage0.com 0:SPAZM0.COM
4. Test: SPAZM0 MIN → should produce MIN.COM
5. Write stage 1 source in .HEX format
6. Assemble: SPAZM0 STAGE1
7. Repeat for higher stages
```

## Key Constraints

- Stage 0 must be small enough to hand-assemble reliably
- Each stage must be able to assemble the next stage
- Final stage must be able to re-assemble itself (self-hosting)

## Related

- [architecture.md](architecture.md) - Full assembler design
- [../practices.md](../practices.md) - 8080 coding patterns
