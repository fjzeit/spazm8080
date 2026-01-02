# Stage 0 Newline Bug - RESOLVED

## Root Cause

**The `CPI 1AH` instruction in GETCHR sets the carry flag when A < 0x1A.**

In GETCHR, after checking for Ctrl-Z EOF marker:
```asm
        CPI     1AH             ; Compare A with 0x1A
        JZ      GC2             ; Jump if Ctrl-Z (EOF)
        RET                     ; Return - BUT CY IS SET IF A < 0x1A!
```

When reading LF (0x0A), CR (0x0D), or TAB (0x09):
- `CPI 1AH` does: A - 0x1A = negative → **CY=1**
- RET returns with CY=1
- MAIN's `JC DONE` sees CY=1 and interprets it as EOF!

**Fix:** Add `ORA A` before RET to clear carry:
```asm
        CPI     1AH             ; Check for Ctrl-Z
        JZ      GC2             ; EOF if 0x1A
        ORA     A               ; Clear CY (A|A=A, but CY=0)
        RET                     ; Return with char, CY=0
```

---

## Verification

After fix, tested:
- `LF.HEX` ("21\n36\n") → Output: `21 36` ✓
- `MULTI.HEX` ("21 00 01\r\nC3 00 00\r\n") → Output: `21 00 01 C3 00 00` ✓

---

## Original Symptoms

| Test File | Content | Expected Output | Actual Output |
|-----------|---------|-----------------|---------------|
| `21 65` (no newline) | 5 bytes | 0x21 0x65 | 0x21 0x65 ✓ |
| `21 65 36` (no newline) | 8 bytes | 0x21 0x65 0x36 | 0x21 0x65 0x36 ✓ |
| `21\r\n` | 4 bytes | 0x21 | 0x21 ✓ |
| `21\r\n36\r\n` | 8 bytes | 0x21 0x36 | 0x21 only ✗ |
| `21\n36\n` | 6 bytes | 0x21 0x36 | 0x21 only ✗ |
| `21 65\r\n36` | 9 bytes | 0x21 0x65 0x36 | 0x21 0x65 only ✗ |
| s1min.hex (12 lines) | 72+ bytes | ~20 bytes | 3 bytes (first line) ✗ |

**Pattern**: Single-line files work correctly. Multi-line files only process the first line. The bug affects both CR-LF and LF-only line endings.

## Binary Analysis

SPAZM0.COM is 429 bytes, matching the expected size from stage0.hex.

### MAIN Loop (address 015D, file offset 0x5D)

```
015D: CD BE 01    CALL GETCHR
0160: DA A8 01    JC DONE
0163: FE 3B       CPI ';'
0165: CA 9A 01    JZ SKIPCMT
0168: FE 20       CPI ' '
016A: CA 5D 01    JZ MAIN     ; skip space
016D: FE 09       CPI 09H
016F: CA 5D 01    JZ MAIN     ; skip tab
0172: FE 0D       CPI 0DH
0174: CA 5D 01    JZ MAIN     ; skip CR
0177: FE 0A       CPI 0AH
0179: CA 5D 01    JZ MAIN     ; skip LF
017C: CD 01 02    CALL HEXVAL
...
```

The binary code appears correct:
- All `JZ MAIN` instructions jump to 015D (verified)
- Whitespace checks (space, tab, CR, LF) all loop back to MAIN
- After hex byte output, `JMP MAIN` also goes to 015D

### GETCHR (address 01BE)

```
01BE: 3A A9 02    LDA ICNT
01C1: B7          ORA A
01C2: C2 E4 01    JNZ GC1     ; if count > 0, read from buffer
... (buffer fill from disk) ...
01E4: 2A A7 02    LHLD IPTR   ; GC1: get buffer pointer
01E7: 7E          MOV A,M     ; read char
01E8: 23          INX H
01E9: 22 A7 02    SHLD IPTR   ; advance pointer
01EC: F5          PUSH PSW
01ED: 3A A9 02    LDA ICNT
01F0: 3D          DCR A
01F1: 32 A9 02    STA ICNT
01F4: F1          POP PSW
01F5: B7          ORA A       ; check for NULL
01F6: CA FF 01    JZ GC2      ; NULL = EOF
01F9: FE 1A       CPI 1AH     ; check for Ctrl-Z
01FB: CA FF 01    JZ GC2      ; Ctrl-Z = EOF
01FE: C9          RET
01FF: 37          STC         ; GC2: set carry (EOF)
0200: C9          RET
```

This also appears correct - NULL (0x00) and Ctrl-Z (0x1A) are treated as EOF.

## Expected Execution Trace (for `21\n36\n`)

```
File content in IBUF at 02AD: 32 31 0A 33 36 0A 00 00 00...
                               '2' '1' LF '3' '6' LF NULL...

1. MAIN: GETCHR reads '2' (0x32)
2. Not whitespace -> HEXVAL -> high nibble = 2
3. GETCHR reads '1' (0x31)
4. HEXVAL -> low nibble = 1
5. OUTPUT 0x21
6. JMP MAIN
7. MAIN: GETCHR reads LF (0x0A)
8. CPI 0AH matches -> JZ MAIN
9. MAIN: GETCHR reads '3' (0x33)   <-- THIS SHOULD HAPPEN
10. Not whitespace -> HEXVAL -> high nibble = 3
11. GETCHR reads '6' (0x36)
12. HEXVAL -> low nibble = 6
13. OUTPUT 0x36
14. JMP MAIN
15. MAIN: GETCHR reads LF (0x0A)
16. JZ MAIN
17. MAIN: GETCHR reads NULL (0x00)
18. GETCHR returns EOF (carry set)
19. JC DONE
20. FLUSH, close, exit
```

Expected output: 0x21 0x36 (2 bytes)
Actual output: 0x21 (1 byte)

## Theories (Broad Scope)

The bug could be anywhere in the stack. Be open-minded.

### In SPAZM0 Code

**1. Memory Corruption**
Something overwrites IPTR or ICNT after processing the first newline. Variables at 02A7-02AC are right before IBUF at 02AD - buffer overflow from input could corrupt them.

**2. Address Calculation Error**
The hand-assembled binary might have an error that only manifests on certain code paths. The MAIN loop JZ instructions look correct (all go to 015D), but maybe something subtle happens during actual execution.

**3. Register Clobbering**
A subroutine might modify a register that the caller expects preserved. For example, if OUTPUT corrupts something that MAIN needs.

### In LOLOS (CP/M)

**4. BDOS Sequential Read Bug**
LOLOS's FUNC20 (sequential read) might have a quirk. Maybe it doesn't fill the full 128-byte buffer, or corrupts something after reading.

**5. FCB State Issue**
The FCB's current record pointer (CR at FCB+32) might not be handled correctly. CP/M spec says application must set CR=0 before first read - SPAZM0 doesn't do this explicitly.

**6. DMA Buffer Handling**
LOLOS might have issues with DMA buffer addresses or buffer contents after reads.

### In heh8080 Emulator

**7. CPU Emulation Bug**
A subtle 8080 instruction emulation bug - maybe affecting flags, conditional jumps, or stack operations after certain sequences.

**8. Timing/Interrupt Issue**
Something related to how the emulator handles instruction execution that manifests after processing certain characters.

### In MCP/Test Framework

**9. Disk Image Sync**
File might not be on disk correctly despite cpmcp verification. Maybe timing issue with how Reset reloads disk.

**10. Test File Corruption**
Files might be getting corrupted during copy to CP/M disk in ways not visible in round-trip verification.

## My Opinion

The most likely causes, in order:

1. **SPAZM0 code bug** (60% confidence) - Despite the binary analysis looking correct, hand-assembled code is error-prone. There might be a subtle issue I'm missing in the address calculations or control flow.

2. **LOLOS BDOS issue** (25% confidence) - The BDOS/BIOS in LOLOS is relatively new and might have edge cases. The fact that single-line files work but multi-line don't suggests something in the I/O path.

3. **Emulator bug** (10% confidence) - heh8080 is well-tested, but complex CPU emulation can have subtle bugs.

4. **MCP/tooling issue** (5% confidence) - Unlikely since file verification shows correct content, but can't rule out.

The key mystery is: **the binary code analysis shows correct newline handling, but execution proves otherwise**. This disconnect suggests either:
- The analysis is missing something
- The code being analyzed isn't what's actually running
- Something external is interfering

Fresh debugging approach recommended: Use PokeMemory to inject a minimal test program that reads a file character by character and outputs each one. This would isolate whether the issue is in SPAZM0's logic or in the underlying file I/O.

## Verification Steps Completed

1. ✓ Verified file content on disk matches expected (via cpmcp round-trip)
2. ✓ Verified SPAZM0.COM is 429 bytes
3. ✓ Verified MAIN loop binary matches expected addresses
4. ✓ Verified JZ MAIN instructions all jump to 015D
5. ✓ Verified GETCHR binary code looks correct
6. ✓ Tested CR-LF vs LF-only - both fail
7. ✓ Tested trailing newline only - works
8. ✓ Reviewed LOLOS BDOS/BIOS source - looks standard

## Suggested Next Steps

1. **Memory dump during execution**: Run SPAZM0, break after first line, dump IPTR/ICNT/IBUF to see actual state

2. **Instruction trace**: If emulator supports it, trace execution to see where control flow diverges from expected

3. **Minimal reproducer**: Create simplest failing case and step through manually

4. **Rebuild SPAZM0**: Re-generate stage0.com from stage0.hex using an external tool to rule out disk corruption

5. **Compare with known-good assembler**: Test same hex files with a different assembler to verify file format isn't the issue

## Files

- `/home/fj/workspace/spazm8080/src/stage0.hex` - Source with byte-by-byte listing
- `/home/fj/workspace/spazm8080/src/stage0.asm` - Annotated assembly source
- `work.dsk:SPAZM0.COM` - Binary on CP/M disk (429 bytes)

## Related

- [bootstrap.md](bootstrap.md) - Stage 0 design and memory map
- [stage1-design.md](stage1-design.md) - Stage 1 blocked on this bug
