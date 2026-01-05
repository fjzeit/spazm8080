# spazm8080

A self-hosting Intel 8080 assembler for CP/M, cold-bootstrapped from nothing using Claude Code and the [Lode Coding](https://fjzeit.github.io/lode) method.

## What This Project Is

spazm8080 is an experiment in AI-assisted software development. The goal was to answer a question: *Can an AI coding assistant, given the right tools and context management, build a working assembler from scratch—without using any existing assembler?*

The answer is yes. Over multiple sessions, Claude Code wrote an 8080 assembler in 8080 assembly language, starting from hand-assembled hex bytes and progressively building more sophisticated tools until the final assembler could assemble its own source code.

## What is a Cold Bootstrap Assembler?

A "cold bootstrap" means starting from absolute zero—no compilers, no assemblers, no development tools. Just a CPU that can execute machine code.

The chicken-and-egg problem: You need an assembler to write an assembler. But where does the first assembler come from?

The solution is staged bootstrapping:

1. **Stage 0**: Hand-write machine code in hexadecimal. This minimal program (432 bytes) can convert hex text files into binary executables. No assembler needed—just a hex editor and patience.

2. **Stage 1**: Using Stage 0, write a slightly better assembler that understands labels and symbols. Still written in hex, but now you don't need to calculate jump addresses by hand.

3. **Stage 2**: Using Stage 1, rewrite Stage 1's functionality but now using labels. The source is cleaner, and the assembler can assemble itself.

4. **Stage 3**: Add data directives (DEFB, DEFW, EQU). The assembler gains the ability to define constants and embed data.

5. **Stage 4**: Add full 8080 mnemonic parsing. Now instead of writing `C3 00 01` you can write `JMP 0100H`.

6. **Stage 5**: Rewrite Stage 4 using the mnemonics it now supports. The final assembler is written in standard 8080 assembly language and can assemble itself, producing a byte-identical binary.

When Stage 5 assembles its own source and produces an identical copy of itself, the bootstrap is complete. The assembler is fully self-hosting.

## The Development Environment

### heh8080 - The Emulator

[heh8080](https://github.com/fjzeit/heh8080) is an Intel 8080/Z80 emulator written in C#. It runs CP/M 2.2 and provides the execution environment for the assembler. Critically, heh8080 exposes an MCP (Model Context Protocol) server that allows external tools to interact with the running emulation.

### The MCP Server

The MCP server is the bridge between Claude Code and the emulated CP/M system. It provides:

**Console Interaction**
- `SendInput` - Type commands into CP/M
- `ReadScreen` - See what's displayed
- `WaitForText` - Wait for specific output (like `A>` prompt)

**Disk Operations**
- `MountDisk` - Attach disk images
- `RefreshDisk` - Reload disk contents after external changes

**Debugging Facilities**
- `SetBreakpoint` / `ClearBreakpoint` - Stop execution at specific addresses
- `Step` - Execute one instruction at a time
- `Continue` - Resume execution
- `GetCpuState` - Read registers (A, BC, DE, HL, SP, PC, flags)
- `PeekMemory` - Examine memory contents
- `EnableTrace` / `GetTrace` - Record executed instructions

These debugging tools proved essential. When the assembler crashed or produced incorrect output, Claude Code could set breakpoints, single-step through code, examine registers, and trace execution paths—just like a human developer using a debugger.

### lolos - The Target OS

[lolos](https://github.com/fjzeit/lolos) is a CP/M 2.2 compatible operating system, also written in 8080 assembly. It provides the BDOS (Basic Disk Operating System) calls that spazm8080 uses for file I/O and console interaction. The long-term goal is for spazm8080 to assemble lolos itself, though this requires additional features (expression arithmetic, string literals) not yet implemented.

## How Claude Code Found Bugs

Debugging was a constant activity throughout the project. Each stage introduced new parsing logic, new edge cases, and new ways for things to go wrong. The MCP server's debugging facilities made it possible for Claude Code to investigate failures systematically rather than guessing.

### The Debugging Workflow

When something went wrong—a crash, corrupted output, infinite loop—the typical investigation followed a pattern:

1. **Reproduce and observe**: Run the failing case, capture error messages or symptoms. Check `GetCpuState` to see where the CPU ended up. A program counter in the middle of a data table or a stack pointer in unexpected memory immediately suggests the nature of the problem.

2. **Isolate the trigger**: Use binary search on the input. If a 2000-line source file crashes, try 1000 lines. Then 500. Then 750. Narrow down to the specific line or instruction that triggers the failure.

3. **Set strategic breakpoints**: Place breakpoints at key decision points—the start of instruction parsing, the symbol table lookup, the output routines. Step through and watch the CPU state evolve.

4. **Trace execution**: Enable instruction tracing to capture the exact sequence of instructions executed. This reveals unexpected jumps, missed branches, or code falling through where it shouldn't.

5. **Examine memory**: Use `PeekMemory` to inspect the symbol table, output buffer, or generated code. Compare what's there against what should be there.

6. **Form and test hypotheses**: Based on observations, propose what's wrong. Make a targeted fix. Re-run. If it fails differently, that's still progress—it's new information.

### Types of Bugs Encountered

**Parsing errors**: Incorrect tokenization, mishandled edge cases in instruction formats, confusion between similar mnemonics (ORA vs ORG vs ORI vs OUT). These showed up as wrong opcodes in the output or "undefined symbol" errors for valid labels.

**Control flow bugs**: Jumps to wrong addresses, missing return statements, conditional branches with inverted logic. These often caused crashes or infinite loops. The trace facility was invaluable—watching the CPU execute unexpected instruction sequences made the problem obvious.

**Symbol table corruption**: Off-by-one errors in table indexing, incorrect symbol length handling, hash collisions. These caused labels to resolve to wrong addresses or not be found at all.

**Output buffer issues**: Sector boundaries, flush timing, file handle management. CP/M's 128-byte record-oriented I/O required careful buffer management.

**Forward reference limitations**: The two-pass architecture had subtle limitations. Labels defined at the very end of a file sometimes weren't properly resolved, causing truncated output. This required reordering source code to work around the assembler's constraints.

### Why This Matters

The ability to debug interactively transformed what would otherwise be impossible. Writing 8080 assembly is unforgiving—there's no type checker, no runtime errors, just a CPU that does exactly what you tell it, whether or not that's what you meant.

Without the MCP debugging facilities, each bug would require extensive manual analysis. With them, Claude Code could investigate failures the same way a human developer would: set a breakpoint, step through, look at registers, examine memory, form a hypothesis, test it. The feedback loop was tight enough to make iterative development practical.

## Project Structure

```
spazm8080/
├── src/
│   ├── stage0.8hx    # Hand-assembled hex (FROZEN)
│   ├── stage1.8hx    # Labels and symbols (FROZEN)
│   ├── stage2.8hx    # Self-hosting baseline (FROZEN)
│   ├── stage3.8hx    # Data directives (FROZEN)
│   ├── stage4.8hx    # Full mnemonics (FROZEN)
│   └── stage5.asm    # Final assembler (self-hosting)
├── scripts/
│   ├── sync-to-disk.sh   # Copy sources to CP/M disk
│   ├── sync-from-disk.sh # Copy binaries from disk
│   └── fixaddr.py        # Address recalculation tool
├── lode/                 # Project documentation
│   ├── summary.md
│   ├── assembler/
│   └── ...
└── work.dsk              # CP/M work disk image
```

## Building

The bootstrap is complete—all stages are frozen and the binaries exist. To rebuild from scratch:

```bash
# Create Stage 0 binary from hex
sed 's/;.*//' src/stage0.8hx | xxd -r -p > /tmp/spazm0.com

# Copy to disk and boot CP/M in heh8080
cpmcp -f ibm-3740 work.dsk /tmp/spazm0.com 0:SPAZM0.COM
cpmcp -f ibm-3740 work.dsk src/stage1.8hx 0:STAGE1.8HX

# In CP/M:
A>SPAZM0 STAGE1
A>STAGE1 STAGE2
A>STAGE2 STAGE3
A>STAGE3 STAGE4
A>STAGE4 STAGE5
A>STAGE5 STAGE5    ; Circular bootstrap - produces identical binary
```

## What's Next

The assembler works, but to assemble real-world code or experimental projects like lolos, it needs:

- Expression arithmetic (`LABEL+offset`, `SIZE*2`)
- DS directive (reserve uninitialized storage)
- String literals in DEFB (`DEFB 'Hello'`)
- DB/DW aliases for DEFB/DEFW

These are straightforward extensions to the existing architecture.

## Acknowledgments

This project was developed collaboratively between FJ Zeit (providing context, direction, testing, and domain knowledge) and Claude Code (writing assembly, debugging, and documenting). The Lode Coding method kept the AI oriented across multiple sessions, and the heh8080 MCP server made interactive debugging possible.

The cold bootstrap approach was inspired by the original development of early assemblers in the 1950s and 60s, when programmers really did hand-assemble their first tools.

## License

MIT
