# spazm8080 - Project Summary

spazm8080 is a self-hosted 8080/Z80 macro assembler written in Intel 8080 assembly, targeting CP/M 2.2 (specifically the lolos recreation). The assembler aims for zmac compatibility, supporting both Intel 8080 and Zilog Z80 mnemonics, including undocumented Z80 instructions.

## Current Status

**Phase**: Design and lode initialization

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
