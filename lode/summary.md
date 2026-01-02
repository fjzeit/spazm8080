# spazm8080 - Project Summary

spazm8080 is a self-hosted 8080/Z80 macro assembler written in Intel 8080 assembly, targeting CP/M 2.2 (specifically the lolos recreation). The assembler aims for zmac compatibility, supporting both Intel 8080 and Zilog Z80 mnemonics, including undocumented Z80 instructions.

## Current Status

**Phase**: Bootstrap Stage 0 - Hand-assembling minimal assembler

### Completed
- **Phase 1**: Lode and design documentation ✓
- **Phase 2**: MCP server added to heh8080 ✓
  - `Heh8080.Mcp` project with 9 tools (SendInput, ReadScreen, WaitForText, etc.)
  - Tested and verified working with LOLOS
- **Workflow**: cpmtools-based source file sync established ✓
- **LOLOS boot verified**: work.dsk boots, MCP console interaction works ✓

### Next Steps
1. Hand-assemble Stage 0 (~200-300 bytes) supporting ORG, DB, END only
2. Inject via PokeMemory, save as SPAZM0.COM
3. Write Stage 1 source using ORG/DB/END syntax
4. Assemble Stage 1 with SPAZM0
5. Iterate through stages until self-hosting

### Resume Prompt
"Continue spazm8080 development. Read lode/summary.md for current status."

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
| `lode/assembler/workflow.md` | cpmtools sync workflow |
| `lode/plans/bootstrap-plan.md` | Full implementation plan |
| `lode/terminology.md` | 8080/Z80/CP/M vocabulary |
| `lode/practices.md` | Assembly coding patterns |
