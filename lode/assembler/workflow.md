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

Uses `cpmtools` package with `ibm-3740` format (standard 8" SSSD):

| Command | Purpose |
|---------|---------|
| `cpmls -f ibm-3740 disk.dsk` | List files |
| `cpmcp -f ibm-3740 disk.dsk file.asm 0:FILE.ASM` | Copy to disk |
| `cpmcp -f ibm-3740 disk.dsk 0:FILE.ASM file.asm` | Copy from disk |
| `cpmrm -f ibm-3740 disk.dsk 0:FILE.ASM` | Delete from disk |

## Safety

- **Always sync-from-disk** before ending a session
- Disk image can be restored from lolos repo if corrupted
- Text sources in git provide full history and recovery
- Consider periodic `git stash` during long sessions
