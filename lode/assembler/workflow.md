# Development Workflow

Source files are version-controlled as text in `src/`, synced to/from the CP/M disk image for development.

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

## Safety

- **Always sync-from-disk** before ending a session
- Disk image can be restored from lolos repo if corrupted
- Text sources in git provide full history and recovery
- Consider periodic `git stash` during long sessions
