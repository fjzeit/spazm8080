# Development Workflow

Source files are version-controlled as text in `src/`, synced to/from the CP/M disk image for development.

## Critical Tool: fixaddr.py

**When modifying hand-assembled `.8hx` files, ALWAYS use `fixaddr.py` after making changes.**

This tool automatically recalculates all addresses when bytes are added or removed. Without it, all jump/call targets after the modification point will be wrong.

```bash
# After editing stage1.8hx, run:
python3 scripts/fixaddr.py src/stage1.8hx src/stage1.8hx
```

See [Tools](#fixaddrpy---address-correction-tool) section for details.

## Directory Structure

```
spazm8080/
├── src/                    # Canonical sources (git tracked)
│   ├── spazm.asm
│   ├── lexer.asm
│   └── ...
├── scripts/
│   ├── sync-to-disk.sh     # Host → CP/M
│   └── sync-from-disk.sh   # CP/M → Host
├── work.dsk                # Working disk (.gitignored)
└── lode/
```

To restore work.dsk if corrupted: `cp ../lolos/drivea.dsk work.dsk`

## Workflow

### Before Development Session

```bash
# Inject latest sources into disk
./scripts/sync-to-disk.sh
```

### During Session (via MCP)

```
SendInput("ASM SPAZM\r")    # Assemble
ReadScreen()                 # Check output
SendInput("SPAZM TEST\r")   # Test
```

### After Session

```bash
# Extract any changes back to repo
./scripts/sync-from-disk.sh

# Review and commit
git diff src/
git add src/*.asm
git commit -m "Update assembler sources"
```

## Tools

### cpmtools

Uses `cpmtools` package with `ibm-3740` format (standard 8" SSSD):

| Command | Purpose |
|---------|---------|
| `cpmls -f ibm-3740 disk.dsk` | List files |
| `cpmcp -f ibm-3740 disk.dsk file.asm 0:FILE.ASM` | Copy to disk |
| `cpmcp -f ibm-3740 disk.dsk 0:FILE.ASM file.asm` | Copy from disk |
| `cpmrm -f ibm-3740 disk.dsk 0:FILE.ASM` | Delete from disk |

**Warning**: `cpmcp` does NOT overwrite existing files! It silently fails with "file already exists" error. Always delete first:
```bash
cpmrm -f ibm-3740 disk.dsk "0:FILE.8HX" 2>/dev/null
cpmcp -f ibm-3740 disk.dsk file.8hx "0:FILE.8HX"
```

### fixaddr.py - Address Correction Tool

When hand-assembled hex files like `stage1.hex` are modified (bytes added/removed), all subsequent addresses shift, breaking jump/call targets. The `fixaddr.py` tool automatically fixes these:

```bash
# Show what would change (dry-run)
python3 scripts/fixaddr.py src/stage1.hex --dry-run

# Fix addresses in place
python3 scripts/fixaddr.py src/stage1.hex src/stage1.fixed.hex

# Show label table only
python3 scripts/fixaddr.py src/stage1.hex --show-labels
```

**How it works:**

1. **First pass**: Counts hex bytes to calculate actual addresses, collects label definitions from `; XXXX: LABELNAME` comments
2. **Second pass**: Finds jump/call instructions, identifies target labels from comment annotations (e.g., `; JZ NOFILE`)
3. **Third pass**: Updates instruction address bytes and label declaration comments

**Label resolution priority:**
1. Comment annotation (e.g., `; CALL RDLINE` → targets RDLINE)
2. Address match to declared label addresses
3. Address match to actual label addresses

The tool is idempotent - running it twice produces no additional changes.

## Disk Refresh After External Changes

**The CP/M emulator keeps disk file handles open.** When external tools (cpmcp, cpmrm) modify the disk image file, the running emulator still sees the OLD cached content.

**Use RefreshDisk after cpmtools modifications:**

```bash
# Modify disk externally
./scripts/sync-to-disk.sh

# Refresh emulator's view of the disk (no reboot needed!)
mcp__cpm__RefreshDisk(0)   # Refresh drive A:
```

Or use Reset if you prefer a clean slate:
```bash
mcp__cpm__Reset()   # Full reboot - slower but guaranteed clean
```

Symptoms of stale cache:
- "No file" errors when file definitely exists
- Assembler produces wrong/old output
- Changes don't appear in DIR listing
- Assembled binaries contain old code

**RefreshDisk is preferred** - it reopens the file handle without losing emulator state.

## Hex-Format Source Rules

### CRITICAL: Label Names Must Contain Non-Hex Characters

**Labels in `.8hx` files MUST contain at least one non-hex character (G-Z, underscore, etc.).**

The hex-format assembler (Stage 1-3) parses tokens and treats 4-character all-hex strings as 16-bit word literals. If a label consists entirely of hex digits (0-9, A-F), it will be interpreted as a hex value instead of a symbol reference.

**Bug example (Stage 3 DEFB handler):**
```asm
        CA CDDB         ; JZ CDDB - WRONG: interpreted as JZ 0xCDDB (BIOS space!)
        ...
CDDB:                   ; Label never reached
```

The label `CDDB` contains only hex digits (C, D, D, B), so `CA CDDB` was assembled as `CA DB CD` (JZ to address 0xCDDB) instead of jumping to the label.

**Fix: Use non-hex characters in label names:**
```asm
        CA GODEF        ; JZ GODEF - Correct: G and O are not hex digits
        ...
GODEF:                  ; Label correctly resolved
```

**Safe label patterns:**
- `SKIPWS` - S, K, P, W not hex ✓
- `OUTPUT` - O, U, T not hex ✓
- `PARB` - P, R not hex ✓
- `GODEF` - G, O not hex ✓
- `DO_DB` - O, underscore not hex ✓

**Unsafe label patterns (avoid!):**
- `CDDB` - all hex (C, D, D, B) ✗
- `ABCD` - all hex ✗
- `DEAD` - all hex ✗
- `FACE` - all hex ✗
- `CAFE` - all hex ✗
- `BEAD` - all hex ✗

This rule applies to **all stages that use hex-format assembly** (Stage 0-3 and any future stages that parse hex tokens).

### Numeric Literals Are Hex-Only

In the bootstrap stages (0-3), **all numeric literals are interpreted as hexadecimal**. The `H` suffix is optional and serves only as human documentation.

| Input | Value | Notes |
|-------|-------|-------|
| `41H` | 0x41 | Explicit hex suffix |
| `41` | 0x41 | Same result, no suffix |
| `0100H` | 0x0100 | 4-digit word |
| `0100` | 0x0100 | Same result |
| `$FF` | 0xFF | $ prefix also works |

**Rationale**: The bootstrap stages assemble raw hex bytes. Hex-only keeps the parser simple and matches the format's nature. Decimal support can be added in later mnemonic-based stages for zmac compatibility.

**User responsibility**: `DEFB 65` produces 0x65 (101 decimal, 'e'), not decimal 65 ('A'). In a hex assembler, this is expected.

## Safety

- **Always sync-from-disk** before ending a session
- **Always reset machine** after sync-to-disk
- Disk image can be restored from lolos repo if corrupted
- Text sources in git provide full history and recovery
- Consider periodic `git stash` during long sessions
