# Stage 1 Assembler - Testing and Bug Fixes

## Overview

Stage 1 (STAGE1.COM) is a two-pass assembler built from hand-assembled hex code. It was tested on 2026-01-03 after fixing several critical bugs.

## Test Results Summary

| Test | Description | Expected | Result |
|------|-------------|----------|--------|
| Simple hex | `21 00 01; C9` | `21 00 01 C9` | PASS |
| Symbol refs | `C3 START` where START=0100 | `C3 00 01` | PASS |
| Low byte | `3E <TARGET` where TARGET=0100 | `3E 00` | PASS |
| High byte | `3E >TARGET` where TARGET=0100 | `3E 01` | PASS |
| ORG directive | `ORG 0200H` then label | Label at 0200 | PASS |
| Forward refs | `C3 LATER` before LATER defined | Correct address | PASS |

## Bugs Found and Fixed

### Bug 1: GETCHR trashes HL register (fixed)

**Symptom**: 0-byte output files. RDLINE filled input buffer (IBUF) instead of line buffer (LINBUF).

**Root cause**: GETCHR uses HL for input buffer pointer (LHLD IPTR, INX H, SHLD IPTR) but didn't preserve caller's HL. RDLINE uses HL to track position in LINBUF at 0x0680, but after GETCHR returned, HL pointed into IBUF at 0x0700+.

**Fix**: Added `PUSH H` at GETCHR entry and `POP H` at both exit points.

```
; GETCHR entry
C5; PUSH B
E5; PUSH H  <- Added

; Normal return
E1; POP H   <- Added
C1; POP B
C9; RET

; EOF return
E1; POP H   <- Added
C1; POP B
37; STC
C9; RET
```

### Bug 2: OUTPUT trashes HL register in Pass 2 (fixed)

**Symptom**: Symbol references output wrong addresses (e.g., 0x0700 instead of 0x0100).

**Root cause**: Pass 2 OUTPUT path does `LHLD OPTR` which overwrites HL. After HX_SYM called LOOKUP (returns value in HL), the first CALL OUTPUT trashed HL. The second byte output used the output buffer pointer instead of the symbol value.

**Fix**: Added `PUSH H` at Pass 2 entry and `POP H` before all returns.

```
; Pass 2 - output byte
E5; PUSH H  <- Added
F5; PUSH PSW
2A 85 05; LHLD OPTR
...
E1; POP H   <- Added before each RET
C9; RET
```

### Bug 3: HX_LO and HX_HI output both bytes (fixed)

**Symptom**: `<SYMBOL` and `>SYMBOL` output 2 bytes instead of 1.

**Root cause**: Both HX_LO and HX_HI called HX_SYM, which outputs BOTH low and high bytes. They should call LOOKUP directly and output only the appropriate byte.

**Fix**: Rewrote HX_LO and HX_HI to call LOOKUP directly:

```
; HX_LO - Low byte prefix (<SYMBOL)
23; INX H (skip '<')
22 8A 05; SHLD LNPTR
CD xx xx; CALL LOOKUP
7D; MOV A,L  <- Only output L
CD xx xx; CALL OUTPUT
C3 7C 02; JMP HEXLN

; HX_HI - High byte prefix (>SYMBOL)
23; INX H (skip '>')
22 8A 05; SHLD LNPTR
CD xx xx; CALL LOOKUP
7C; MOV A,H  <- Only output H
CD xx xx; CALL OUTPUT
C3 7C 02; JMP HEXLN
```

## Code Size History

| Version | Size | Changes |
|---------|------|---------|
| Initial | 1155 bytes | Hand-assembled |
| +GETCHR fix | 1158 bytes | +3 bytes (PUSH H, 2x POP H) |
| +OUTPUT fix | 1164 bytes | +6 bytes (PUSH H, restructured returns) |
| +HX_LO/HI fix | 1172 bytes | +8 bytes (separate LOOKUP calls) |

## Testing Workflow

1. Prepare fresh disk:
   ```bash
   cp lolos/drivea.dsk work.dsk
   cpmcp -f ibm-3740 work.dsk src/stage0.com 0:SPAZM0.COM
   cpmcp -f ibm-3740 work.dsk src/stage1.8hex 0:STAGE1.HEX
   ```

2. Mount and build in emulator:
   ```
   A>spazm0 stage1
   ```

3. Run test:
   ```
   A>stage1 testfile
   ```

4. Extract and verify:
   ```bash
   cpmcp -f ibm-3740 work.dsk 0:TESTFILE.COM /tmp/test.com
   xxd /tmp/test.com
   ```

## Key Lessons

1. **Register preservation is critical**: Any function that uses HL, BC, or DE must preserve caller's values if the caller depends on them.

2. **Two-pass assembler works**: Forward references are correctly resolved because Pass 1 collects all labels before Pass 2 generates output.

3. **Disk sync matters**: The emulator's disk image must be remounted after host-side modifications.

4. **Test incrementally**: Each feature (hex, labels, <, >, ORG, forward refs) should be tested separately.

## Resume Prompt

"Continue spazm8080 development. Stage 1 is fully tested and working. All core features verified: hex output, labels, symbol references, </>  operators, ORG directive, forward references. Next: add DB, DW, DS directives or test self-assembly."
