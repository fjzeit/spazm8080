# spazm8080 - Project Summary

spazm8080 is a self-hosted 8080/Z80 macro assembler written in Intel 8080 assembly, targeting CP/M 2.2 (specifically the lolos recreation). The assembler aims for zmac compatibility, supporting both Intel 8080 and Zilog Z80 mnemonics, including undocumented Z80 instructions.

## Current Status

**Phase**: Bootstrap Stage 4 COMPLETE - Full mnemonic parsing

### Cold Boot Pipeline (PROTECTED)

| File | Format | Assembler | Output | Size | Status |
|------|--------|-----------|--------|------|--------|
| `src/stage0.8hx` | Raw hex | Hand/xxd | SPAZM0.COM | 432 bytes | FROZEN |
| `src/stage1.8hx` | Raw hex | SPAZM0 | STAGE1.COM | 1296 bytes | Complete |
| `src/stage2.8hx` | Stage 1 | STAGE1 | STAGE2.COM | 1408 bytes | FROZEN |
| `src/stage3.8hx` | Stage 2 | STAGE2 | STAGE3.COM | ~1800 bytes | FROZEN |
| `src/stage4.8hx` | Stage 3 | STAGE3 | STAGE4.COM | 2816 bytes | **Complete** |

All stages now read `.8HX` extension (cold bootstrap updated).

*stage1.8hx can be modified but **must remain in Stage 0 format** (raw hex bytes). Use `fixaddr.py` after edits.

### Implemented Features

- **Two-pass assembly**: Forward references resolved via symbol table
- **Labels**: `LABEL:` defines symbol at current address (max 6 chars)
- **Directives**: ORG, END, EQU, DEFB, DEFW, DEFS
- **Symbol references**: `C3 LABEL` emits address bytes
- **Low/high byte operators**: `<LABEL`, `>LABEL`
- **Token-length parsing**: 2 chars=byte, 4 chars=word, else=label
- **Self-hosting**: All stages assemble themselves identically (circular bootstrap)
- **EQU directive**: `NAME EQU value` defines constant (no colon, value-based)
- **DEFB directive**: `DEFB expr, expr, 'string'` emits bytes and strings
- **DEFW directive**: `DEFW expr, expr` emits 16-bit words (little-endian)
- **DEFS directive**: `DEFS count` reserves bytes (outputs zeros)
- **Full 8080 mnemonics** (Stage 4): All instruction types supported

### Stage 4 Mnemonic Support

| Format | Instructions |
|--------|--------------|
| No operand | NOP, HLT, RET, Rcc, XCHG, STC, CMC, CMA, DAA, EI, DI, SPHL, PCHL, XTHL, rotates |
| Register | INR, DCR, ADD, ADC, SUB, SBB, ANA, XRA, ORA, CMP, MOV |
| Immediate | MVI, ADI, ACI, SUI, SBI, ANI, XRI, ORI, CPI, IN, OUT |
| Reg pair | INX, DCX, DAD, LXI, PUSH, POP, LDAX, STAX |
| Address | JMP, Jcc, CALL, Ccc, LDA, STA, LHLD, SHLD |

### Not Yet Implemented

- Expression arithmetic (+, -)
- RST instruction (needs special format)

### Next Steps

**Stage 5**: Rewrite stage4.8hx using proper mnemonics instead of hex bytes.

See `lode/tmp/handover-stage5.md` for detailed handover.

### Critical Rule: Hex Label Names

**Labels in `.8hx` files must contain at least one non-hex character (G-Z, underscore).**

The token parser treats 4-char all-hex strings as word literals. A label like `CDDB` will be interpreted as the hex value `0xCDDB` instead of a symbol. Use names like `GODEF` (G, O not hex) instead. See [workflow.md](assembler/workflow.md#hex-format-source-rules) for details.

### Resume Prompt

"Continue spazm8080 development. Stage 4 is complete with full 8080 mnemonic support. Next: Stage 5 - rewrite stage4.8hx using mnemonics instead of hex bytes. See lode/tmp/handover-stage5.md for details."

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
Configured in `.mcp.json` - available as `cpm` MCP server with tools:
- `SendInput`, `ReadScreen`, `WaitForText` - console interaction
- `PeekMemory`, `PokeMemory` - memory access
- `Status`, `Reset`, `MountDisk`, `DiskInfo`, `RefreshDisk` - machine control
- `GetCpuState`, `Step`, `StopMachine`, `Continue` - execution control
- `EnableTrace`, `DisableTrace`, `GetTrace`, `ClearTrace` - instruction tracing
- `SetBreakpoint`, `ClearBreakpoint`, `ListBreakpoints` - breakpoints

**Important:** After `sync-to-disk.sh`, call `RefreshDisk(0)` to see changes without rebooting.

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
| `src/stage2.8hx` | Stage 2 source (1408 bytes) - self-hosting, FROZEN |
| `src/stage3.8hx` | Stage 3 source - adds DEFB/DEFW, FROZEN |
| `src/stage4.8hx` | Stage 4 source (2816 bytes) - full mnemonic support |
| `lode/tmp/handover-stage5.md` | Stage 5 handover document |
