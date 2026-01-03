# spazm8080 - Project Summary

spazm8080 is a self-hosted 8080/Z80 macro assembler written in Intel 8080 assembly, targeting CP/M 2.2 (specifically the lolos recreation). The assembler aims for zmac compatibility, supporting both Intel 8080 and Zilog Z80 mnemonics, including undocumented Z80 instructions.

## Current Status

**Phase**: Bootstrap Stage 2 - SELF-HOSTING ACHIEVED

### Cold Boot Pipeline (PROTECTED)

| File | Format | Assembler | Output | Size |
|------|--------|-----------|--------|------|
| `src/stage0.8hx` | Raw hex only | Hand/xxd | SPAZM0.COM | 432 bytes |
| `src/stage1.8hx` | Raw hex + comments | SPAZM0 | STAGE1.COM | 1296 bytes |
| `src/stage2.8hx` | Labels + directives | STAGE1 | STAGE2.COM | 1408 bytes |

*stage1.8hx can be modified but **must remain in Stage 0 format** (raw hex bytes). Use `fixaddr.py` after edits.

### Implemented Features

- **Two-pass assembly**: Forward references resolved via symbol table
- **Labels**: `LABEL:` defines symbol at current address
- **Directives**: ORG, END
- **Symbol references**: `C3 LABEL` emits address bytes
- **Low/high byte operators**: `<LABEL`, `>LABEL`
- **Token-length parsing**: 2 chars=byte, 4 chars=word, else=label
- **Self-hosting**: Stage 2 assembles itself identically

### Not Yet Implemented

- EQU directive
- DB, DW, DS directives
- Expression arithmetic (+, -)

### Next Steps

See [plans/directive-impl.md](plans/directive-impl.md) for implementation plan:
1. Add EQU directive (simplest, no output)
2. Add DB directive (strings and bytes)
3. Add DW directive (16-bit words)
4. Add DS directive (reserve space)

### Resume Prompt

"Continue spazm8080 development. Stage 2 is self-hosting. Next: add EQU directive to stage2 following plans/directive-impl.md."

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
- Single-file source input (with INCLUDE support planned)

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
| `lode/assembler/workflow.md` | cpmtools sync, **fixaddr.py** (critical for .8hx edits) |
| `lode/assembler/stage1-testing.md` | Design lessons from Stage 1/2 development |
| `lode/terminology.md` | 8080/Z80/CP/M vocabulary |
| `lode/practices.md` | Assembly coding patterns |
| `scripts/fixaddr.py` | **Critical**: Address correction after .8hx edits |
| `src/stage0.8hx` | Stage 0 source - FROZEN |
| `src/stage1.8hx` | Stage 1 source (1296 bytes) - raw hex format |
| `src/stage2.8hx` | Stage 2 source (1408 bytes) - self-hosting |
