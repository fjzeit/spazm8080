# spazm8080 - Project Summary

spazm8080 is a self-hosted 8080/Z80 macro assembler written in Intel 8080 assembly, targeting CP/M 2.2 (specifically the lolos recreation). The assembler aims for zmac compatibility, supporting both Intel 8080 and Zilog Z80 mnemonics, including undocumented Z80 instructions.

## Current Status

**Phase**: Bootstrap Stage 1 Complete - Ready for Stage 2

### Cold Boot Pipeline (PROTECTED)

| File | Format | Assembler | Output | Status |
|------|--------|-----------|--------|--------|
| `src/stage0.8hex` | Raw hex only | Hand/trivial | SPAZM0.COM (432 bytes) | FROZEN |
| `src/stage1.8hex` | Raw hex + comments | SPAZM0 | STAGE1.COM (1173 bytes) | Editable* |
| `src/stage2.8hex` | Labels + directives | STAGE1 | STAGE2.COM | In progress |

*stage1.8hex can be modified but **must remain in Stage 0 format** (raw hex bytes). Use `fixaddr.py` after edits.

### Stage 0 Complete ✓

SPAZM0.COM (432 bytes) - hex-to-COM converter. Reads raw hex bytes, writes `.COM`.

### Stage 1 Complete ✓

STAGE1.COM (1173 bytes) - two-pass assembler with:
- Labels (`LABEL:`)
- ORG, END directives
- Symbol references in hex (`C3 LABEL`)
- Low/high byte operators (`<LABEL`, `>LABEL`)

**Known bugs fixed**: GETCHR/OUTPUT register preservation, HX_LO/HX_HI double output, CD_END LNPTR update. See `lode/assembler/stage1-testing.md`.

**Not yet implemented**: EQU, DB, DW, DS, expression arithmetic

### Stage 2 In Progress

`src/stage2.8hex` exists - Stage 1 logic rewritten in Stage 1 format (with labels instead of hardcoded addresses). Ready to test assembly.

### Next Steps
1. Assemble stage2.8hex with Stage 1 → STAGE2.COM
2. Verify STAGE2.COM works identically to STAGE1.COM
3. Add DB, DW, DS, EQU directives to Stage 2
4. Achieve self-hosting: Stage 2 assembles itself

### Resume Prompt
"Continue spazm8080 Stage 2 development. Stage 1 is complete and tested (1173 bytes). stage2.8hex exists - need to assemble and verify it works. Then add DB/DW/DS/EQU directives."

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
| `lode/assembler/bootstrap.md` | Stage 0-3 bootstrap strategy, cold boot protection |
| `lode/assembler/workflow.md` | cpmtools sync, **fixaddr.py** (critical for .8hex edits) |
| `lode/assembler/stage1-testing.md` | Bug fixes and test results |
| `lode/terminology.md` | 8080/Z80/CP/M vocabulary |
| `lode/practices.md` | Assembly coding patterns |
| `scripts/fixaddr.py` | **Critical**: Address correction after .8hex edits |
| `src/stage0.8hex` | Stage 0 source - FROZEN |
| `src/stage1.8hex` | Stage 1 source (1173 bytes) - raw hex format |
| `src/stage2.8hex` | Stage 2 source - Stage 1 format with labels |
