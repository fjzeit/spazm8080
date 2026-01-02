# spazm8080 - Project Summary

spazm8080 is a self-hosted 8080/Z80 macro assembler written in Intel 8080 assembly, targeting CP/M 2.2 (specifically the lolos recreation). The assembler aims for zmac compatibility, supporting both Intel 8080 and Zilog Z80 mnemonics, including undocumented Z80 instructions.

## Current Status

**Phase**: Bootstrap Stage 1 - Ready to proceed

### Stage 0 Complete ✓

SPAZM0.COM (430 bytes) - hex-to-COM converter working correctly.

**Bug fixed (2026-01-03)**: `CPI 1AH` in GETCHR was setting carry flag for chars < 0x1A (including LF, CR, TAB), causing MAIN's `JC DONE` to trigger premature EOF. Fixed by adding `ORA A` before RET to clear carry. See [assembler/stage0-newline-bug.md](assembler/stage0-newline-bug.md).

### Completed
- **Phase 1**: Lode and design documentation ✓
- **Phase 2**: MCP server added to heh8080 ✓
  - `Heh8080.Mcp` project with 9 tools (SendInput, ReadScreen, WaitForText, etc.)
  - Tested and verified working with LOLOS
- **Workflow**: cpmtools-based source file sync established ✓
- **LOLOS boot verified**: work.dsk boots, MCP console interaction works ✓
- **Stage 0 (SPAZM0.COM)**: 430-byte hex-to-COM converter ✓
  - Hand-assembled from `src/stage0.hex`
  - Converts `.HEX` files (hex bytes + `;` comments) to `.COM` binaries
  - Multi-line support verified working
- **Stage 1 source**: Written in `src/stage1.hex` (~870 lines)
  - Two-pass assembler with labels, ORG, END, EQU
  - Ready to assemble with SPAZM0

### Next Steps
1. Assemble Stage 1 with SPAZM0: `SPAZM0 STAGE1`
2. Test Stage 1 on simple test files
3. Add DB, DW, DS directives to Stage 1
4. Test and iterate through stages until self-hosting

### Resume Prompt
"Continue spazm8080 development. Stage 0 is complete. Next: assemble Stage 1 with SPAZM0 and test it."

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
| `lode/assembler/workflow.md` | cpmtools sync workflow |
| `lode/terminology.md` | 8080/Z80/CP/M vocabulary |
| `lode/practices.md` | Assembly coding patterns |
| `src/stage0.asm` | Stage 0 documented source |
| `src/stage0.hex` | Stage 0 hand-assembled bytes |
| `src/stage0.com` | Stage 0 binary (430 bytes) |
