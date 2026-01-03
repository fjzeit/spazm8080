# spazm8080 - Project Summary

spazm8080 is a self-hosted 8080/Z80 macro assembler written in Intel 8080 assembly, targeting CP/M 2.2 (specifically the lolos recreation). The assembler aims for zmac compatibility, supporting both Intel 8080 and Zilog Z80 mnemonics, including undocumented Z80 instructions.

## Current Status

**Phase**: Bootstrap Stage 1 - Complete ✓

### Stage 0 Complete ✓

SPAZM0.COM (432 bytes) - hex-to-COM converter working correctly.

**Bug fixed (2026-01-03)**: `CPI 1AH` in GETCHR was setting carry flag for chars < 0x1A (including LF, CR, TAB), causing MAIN's `JC DONE` to trigger premature EOF. Fixed by adding `ORA A` before RET to clear carry. See [assembler/stage0-newline-bug.md](assembler/stage0-newline-bug.md).

### Stage 1 Complete ✓

STAGE1.COM (1158 bytes) - two-pass assembler with labels, ORG, END.

**Bug fixed (2026-01-03)**: GETCHR was not preserving HL register, which RDLINE uses to track position in LINBUF. After each GETCHR call, HL pointed into IBUF instead of LINBUF, causing characters to be stored in the wrong buffer. Fixed by adding `PUSH H`/`POP H` in GETCHR.

### Completed
- **Phase 1**: Lode and design documentation ✓
- **Phase 2**: MCP server added to heh8080 ✓
  - `Heh8080.Mcp` project with 20 tools (console, memory, disk, debug)
  - Debug tools: trace logging, breakpoints, single-step, register access
  - Tested and verified working with LOLOS
- **Workflow**: cpmtools-based source file sync established ✓
- **LOLOS boot verified**: work.dsk boots, MCP console interaction works ✓
- **Stage 0 (SPAZM0.COM)**: 432-byte hex-to-COM converter ✓
  - Hand-assembled from `src/stage0.8hex`
  - Converts `.HEX` files (hex bytes + `;` comments) to `.COM` binaries
  - Multi-line support verified working
- **Stage 1 (STAGE1.COM)**: 1158-byte two-pass assembler ✓
  - Hand-assembled from `src/stage1.8hex` (~880 lines)
  - Two-pass assembler with labels, ORG, END
  - Addresses corrected with `fixaddr.py` (89 labels, 139 branches)
  - Tested: correctly outputs `21 00 01 C9` for simple test file

### Next Steps
1. Add DB, DW, DS directives to Stage 1
2. Add EQU directive support
3. Test Stage 1 self-assembly capability
4. Iterate toward self-hosting

### Resume Prompt
"Continue spazm8080 development. Stage 1 is complete and tested. Next: add DB, DW, DS directives."

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
| `src/stage1.8hex` | Stage 1 hand-assembled source (1158 bytes) |
