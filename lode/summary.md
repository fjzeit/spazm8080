# spazm8080 - Project Summary

spazm8080 is a self-hosted 8080/Z80 macro assembler written in Intel 8080 assembly, targeting CP/M 2.2 (specifically the lolos recreation). The assembler aims for zmac compatibility, supporting both Intel 8080 and Zilog Z80 mnemonics, including undocumented Z80 instructions.

## Current Status

**Phase**: Bootstrap Stage 1 Complete - Ready for Stage 2

### Cold Boot Pipeline (PROTECTED)

These files are **frozen** - they enable bootstrapping from nothing:

| File | Format | Output | Status |
|------|--------|--------|--------|
| `src/stage0.8hex` | Raw hex | SPAZM0.COM (432 bytes) | FROZEN ✓ |
| `src/stage1.8hex` | Raw hex | STAGE1.COM (1172 bytes) | FROZEN ✓ |

**Never modify these files** - they use hardcoded addresses that Stage 0 can process.

### Stage 0 Complete ✓

SPAZM0.COM (432 bytes) - hex-to-COM converter. Reads raw hex bytes, writes `.COM`.

### Stage 1 Complete ✓

STAGE1.COM (1172 bytes) - two-pass assembler with:
- Labels (`LABEL:`)
- ORG, END directives
- Symbol references in hex (`C3 LABEL`)
- Low/high byte operators (`<LABEL`, `>LABEL`)

**Not yet implemented**: EQU, DB, DW, DS, expression arithmetic

### Next Steps
1. Create `stage2.hex` in Stage 1 format (labels, not hardcoded addresses)
2. Add DB, DW, DS, EQU directives to Stage 2
3. Achieve self-hosting: Stage 2 assembles itself

### Resume Prompt
"Continue spazm8080 development. Stage 1 is fully tested. Next: add Db, DW, DS directives or attempt self-assembly."

## Goals

1. **Primary**: Assemble lolos source code (CCP, BDOS, BIOS in Intel 8080 syntax)
2. **Secondary**: Full zmac macro compatibility (MACRO/ENDM, REPT, IRP, IRPC)
3. **Tertiary**: Z80 instruction support including undocumented opcodes

## Target Environment

- **CPU**: Intel 8080 (runs on Z80 in 8080 mode)
- **OS**: CP/M 2.2 (lolos)
- **Memory**: ~60KB TPA available
- **I/O**: BDOS function calls for console and disk

## Bootstrap Strategy

Development uses heh8080 emulator with MCP server integration, enabling Claude to directly interact with CP/M for iterative development and testing.

## Key Constraints

- Must fit in CP/M TPA (under 60KB)
- 8-bit arithmetic only (16-bit via register pairs)
- No dynamic memory allocation (fixed buffers)
- Single-file source input (with INCLUDE support)

## Related Projects

- [lolos](../lolos) - Target CP/M system and test source
- [heh8080](../heh8080) - Emulator with MCP integration

## Quick Reference

### MCP Server
Configured in `.claude/settings.json` - available as `cpm` MCP server with tools:
- `SendInput`, `ReadScreen`, `WaitForText` - console interaction
- `PeekMemory`, `PokeMemory` - memory access
- `Status`, `Reset`, `MountDisk`, `DiskInfo` - machine control
- `GetCpuState`, `Step`, `StopMachine`, `Continue` - execution control
- `EnableTrace`, `DisableTrace`, `GetTrace`, `ClearTrace` - instruction tracing
- `SetBreakpoint`, `ClearBreakpoint`, `ListBreakpoints` - breakpoints

### Sync Workflow
```bash
./scripts/sync-to-disk.sh    # Before: src/*.asm → disk
./scripts/sync-from-disk.sh  # After: disk → src/*.asm
```

### Key Files
| File | Purpose |
|------|---------|
| `lode/assembler/architecture.md` | Two-pass design, data structures, module APIs |
| `lode/assembler/bootstrap.md` | Stage 0-3 bootstrap strategy |
| `lode/assembler/workflow.md` | cpmtools sync workflow, fixaddr.py docs |
| `lode/terminology.md` | 8080/Z80/CP/M vocabulary |
| `lode/practices.md` | Assembly coding patterns |
| `scripts/fixaddr.py` | Address correction for hand-assembled hex |
| `src/stage0.asm` | Stage 0 documented source |
| `src/stage0.8hex` | Stage 0 hand-assembled bytes |
| `src/stage0.com` | Stage 0 binary (430 bytes) |
| `src/stage1.8hex` | Stage 1 hand-assembled source (1172 bytes) |
