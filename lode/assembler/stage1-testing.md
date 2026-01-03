# Assembler Design Lessons (Stages 1-3)

Lessons learned building Stage 1 (raw hex), Stage 2 (self-hosting), and Stage 3 (EQU directive) assemblers.

## Core Architecture

Stage 1/2 implements a two-pass assembler that processes hex bytes with symbolic labels:
- **Pass 1**: Collect labels, calculate addresses, don't emit code
- **Pass 2**: Resolve references, emit bytes

Current sizes: Stage 1 = 1296 bytes, Stage 2 = 1408 bytes (self-hosting).

## Critical Design Patterns

### Register Preservation

**Lesson**: Any function that modifies HL, BC, or DE must preserve caller's values if caller depends on them.

Functions like GETCHR (buffered input) and OUTPUT (buffered output) use HL internally. Callers like RDLINE depend on HL for line buffer position. Solution: PUSH/POP at function boundaries.

```asm
GETCHR:
    PUSH B
    PUSH H          ; Critical: preserve caller's HL
    ; ... internal work using HL ...
    POP H
    POP B
    RET
```

### Token-Length Parsing

**Lesson**: Distinguishing hex bytes from labels by character count is simpler than requiring syntax markers.

Rules:
- 2 hex chars = byte (`C3` → 0xC3)
- 4 hex chars = word, little-endian (`0100` → 0x00, 0x01)
- Other = label reference (lookup in symbol table)

This eliminates need for special prefixes while remaining unambiguous.

### Directive Detection

**Lesson**: Single-character prefix detection fails when hex bytes share that prefix.

Problem: `E5` (PUSH H opcode) starts with 'E', same as `END`. Checking only first char causes E5 to be interpreted as END directive.

Solution: After matching 'E', verify second char is 'N' before treating as END. 'O' can immediately match ORG since no hex byte starts with O.

### CP/M File Rewind

**Lesson**: In CP/M 2.2, resetting FCB extent/record fields is NOT sufficient to rewind a file.

The FCB contains allocation block pointers (FCB+16..+31) that map logical records to physical disk blocks. These are loaded from the directory entry only during OPEN. Simply setting EX=0 and CR=0 leaves stale allocation pointers from the last extent accessed.

**Solution**: Re-open the file to reload extent 0's allocation map:
```asm
P1END:
    XRA A
    STA FCB+32      ; Reset current record
    STA FCB+12      ; Reset extent
    LXI D, FCB
    MVI C, 15       ; BDOS Open
    CALL 5          ; Reloads allocation from directory
```

Single-extent files (<16KB) work without re-open since extent 0 is already loaded.

### Memory Layout Discipline

**Lesson**: Code growth must not overlap data areas.

Original layout put variables at 0x0580, but code grew beyond that. Solution: Place variables after code with margin (0x06F0), and use explicit address constants.

Current layout:
```
0100-061F: Code
0620-069F: Token buffer (TOKBUF)
06A0-06EF: Line buffer
06F0-06FB: Variables (PASS, ICNT, IPTR, OCNT, OPTR, SYMCNT, LOCTR, LNPTR)
0700-077F: Input buffer
0780-07FF: Output buffer
0800-083F: Output FCB
0840+:     Symbol table (8 bytes/entry: 6 name + 2 value)
```

### Two-Pass Symbol Resolution

**Lesson**: Pass 1 defines symbols, Pass 2 resolves them. Keep them separate.

In Pass 1, OUTPUT only increments LOCTR (no disk writes). In Pass 2, OUTPUT writes bytes. The PASS variable controls behavior:
```asm
OUTPUT:
    PUSH PSW
    LDA PASS
    ORA A
    JZ OUT_P1       ; Pass 1: just count
    ; Pass 2: actually write
```

Forward references work because all symbols exist by Pass 2.

## Symbol Table Design

Simple linear table with 8-byte entries:
- Bytes 0-5: Name (uppercase, space-padded)
- Bytes 6-7: Value (16-bit little-endian)

Linear search via SYMCNT counter. Adequate for ~100 symbols; hash table for larger codebases.

LOOKUP extracts symbol from input, searches table, returns value in HL.
DEFSYM copies name to table, stores current LOCTR as value.

## Error Handling

Minimal error messages (save code space):
- "No file" - input file not found
- "Disk full" - output write failed
- "Undef" - undefined symbol in Pass 2

Print message, jump to CP/M warm boot (0x0000).

## Testing Approach

1. Start with simplest case (hex bytes only)
2. Add one feature at a time (labels, ORG, END)
3. Verify self-assembly: `STAGE2 STAGE2` must produce identical binary
4. Use binary comparison (`cmp`) to verify byte-for-byte match

## Cold Bootstrap Verification

The bootstrap chain must always work from raw hex:
```
stage0.8hx → xxd → SPAZM0.COM (raw hex only)
stage1.8hx → SPAZM0 → STAGE1.COM (raw hex format)
stage2.8hx → STAGE1 → STAGE2.COM (labels allowed)
stage2.8hx → STAGE2 → STAGE2.COM (self-hosting verified)
```

Any change to stage1.8hx requires `fixaddr.py` to recalculate jump targets.
Stage2.8hx must NOT use features that STAGE1 doesn't understand.

## Stage 3 Lessons (EQU Implementation)

### Memory Layout Expansion

**Lesson**: When adding significant code, buffers must move to avoid overlap.

Stage 3 added ~300 bytes for EQU support. Original layout had TOKBUF at 0x0620, but code grew past that. When LOOKUP copied to TOKBUF, it corrupted the new CHEQU routine.

**Solution**: Shift all buffers by 0x80 bytes:
```
Stage 2 Layout:              Stage 3 Layout:
TOKBUF: 0620                 TOKBUF: 06A0
LINBUF: 0680                 LINBUF: 0720
Vars:   06F0                 Vars:   0770
IBUF:   0700                 IBUF:   0780
OBUF:   0780                 OBUF:   0800
OFCB:   0800                 OFCB:   0880
SYMTAB: 0840                 SYMTAB: 08C0
```

**Better approach** (for future): Put variables at a fixed low address right after max expected code size. Code growth then only pushes labels (which the assembler recalculates). Buffers stay safe.

### .8HX Extension Standardization

**Lesson**: When changing input file extension, the ENTIRE bootstrap chain must be rebuilt from cold.

All stages (stage0, stage1, stage2, stage3) were updated to read `.8HX` instead of `.HEX`. This required:
1. Rebuild SPAZM0.COM from stage0.8hx using `sed 's/;.*//' | xxd -r -p`
2. SPAZM0 STAGE1 (builds new STAGE1 reading .8HX)
3. STAGE1 STAGE2 (builds new STAGE2 reading .8HX)
4. STAGE2 STAGE3 (builds new STAGE3 reading .8HX)

Attempting to use an old stage binary to build new sources fails silently - wrong extension means "No file" error.

### Sync Script Gotcha

**Lesson**: cpmcp with "file already exists" error means files don't update.

The sync-to-disk.sh script showed errors like `cpmcp: can not create 00STAGE3.8HX: file already exists`. Files weren't being replaced!

**Solution**: Delete files before re-syncing:
```bash
cpmrm -f ibm-3740 work.dsk "0:STAGE3.8HX"
cpmcp -f ibm-3740 work.dsk src/stage3.8hx "0:STAGE3.8HX"
```

Or fix the sync script to delete before copy.

### CP/M 8.3 Filename Limits

**Lesson**: Keep filenames short. CP/M uses 8.3 format.

`TEST-SIMPLE.8HX` truncates unpredictably. Use names like `TESTEQU.8HX` instead of `TEST-EQU.8HX` to avoid confusion.

### LOLOS Environment

**Lesson**: LOLOS CP/M doesn't have DDT (debugger).

Can't use DDT to examine loaded programs. Instead:
- Use cpmcp to extract files from disk image
- Use xxd to examine binary contents
- Use PeekMemory MCP tool during runtime

### EQU Implementation Pattern

**Lesson**: EQU requires a different parsing path than colon-labels.

Syntax `NAME EQU value` (no colon) means CHKLBL's colon scan fails. Solution:

1. **CLNO branch**: When CHKLBL finds whitespace (not colon) after potential label, save position and check for "EQU"
2. **CHEQU routine**: Case-insensitive check for 'E','Q','U' - returns A=1 if found
3. **CLEQU handler**: Skip EQU, parse expression to HL, XCHG to DE, call DEFEQU
4. **DEFEQU routine**: Like DEFSYM but:
   - Terminates name copy on whitespace (not colon)
   - Takes value from DE register (not LOCTR)

```
CHKLBL flow:
  Scan for colon
  ├── Found colon → CLYES → call DEFSYM (uses LOCTR)
  └── Found whitespace → CLNO → check for EQU
                          ├── EQU found → CLEQU → parse expr → DEFEQU (uses expr value)
                          └── Not EQU → restore LNPTR, return
```

### Dead File Cleanup

**Lesson**: Keep source files minimal. Delete duplicates.

`stage0.asm` was a dead file - the real source is `stage0.8hx`. Deleted to avoid confusion. The .8hx format can include assembly-style comments after semicolons.

## Related Files

- [bootstrap.md](bootstrap.md) - Cold boot pipeline, stage progression
- [stage1-design.md](stage1-design.md) - Syntax specification
- [../practices.md](../practices.md) - 8080 coding patterns including file rewind
- [../plans/directive-impl.md](../plans/directive-impl.md) - Next: DB/DW/DS
