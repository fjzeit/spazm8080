# SPAZM Stage 1 Address Fix Tool Specification

## Problem Statement

The `stage1.hex` file contains hand-assembled 8080 code with:
- Hex bytes representing instructions
- Comments indicating intended addresses (e.g., `; 01BB: RL1`)
- Jump/call instructions that reference labels by their addresses

When bytes are added or removed (e.g., fixing GETCHR with PUSH B/POP B), all addresses after that point shift, requiring updates to:
1. Jump targets (JMP, JZ, JNZ, JC, JNC, JP, JM, JPE, JPO)
2. Call targets (CALL, CZ, CNZ, CC, CNC, CP, CM, CPE, CPO)
3. Address comments

Currently this is done manually, which is error-prone and has left the codebase in an inconsistent state.

## File Format

The `stage1.hex` file format:
```
; comment line
XX; instruction comment
XX XX; instruction with operand
XX XX XX; instruction with 16-bit operand (little-endian)

; 01BB: LABELNAME
XX XX XX; CALL/JMP to LABELNAME
```

### Key Patterns
- Label definitions: `; XXXX: LABELNAME` where XXXX is hex address
- Instructions are hex bytes separated by spaces
- Everything after `;` is a comment
- Blank lines are preserved

## Proposed Tool: `fixaddr.py`

### Input
- `stage1.hex` file path
- Base address (default: 0x0100 for CP/M .COM files)

### Processing Steps

1. **First Pass - Collect Labels and Calculate Actual Addresses**
   - Parse each line, extracting hex bytes
   - Track cumulative byte offset from base address
   - When encountering `; XXXX: LABELNAME`, record:
     - Label name
     - Declared address (XXXX)
     - Actual address (base + current offset)
   - Build a mapping: `{label_name: actual_address}`

2. **Second Pass - Identify Address References**
   - Detect 3-byte instructions that are jumps/calls:
     - JMP: C3, JZ: CA, JNZ: C2, JC: DA, JNC: D2, JP: F2, JM: FA, JPE: EA, JPO: E2
     - CALL: CD, CZ: CC, CNZ: C4, CC: DC, CNC: D4, CP: F4, CM: FC, CPE: EC, CPO: E4
   - Extract the target address (little-endian: low byte first)
   - Find if this address corresponds to any label (using declared addresses)
   - Record: `{line_number: (instruction, old_target, label_name)}`

3. **Third Pass - Update Addresses**
   - For each recorded reference:
     - Look up the label's actual address
     - Update the instruction bytes
   - Update label declaration comments to show actual addresses

### Output
- Modified `stage1.hex` with corrected addresses
- Summary of changes made

### Example

Before (with stale addresses):
```
; 01BB: RL1
CD D8 02; CALL GETCHR
DA E0 01; JC RL_EOF  <- if RL_EOF moved, this needs update
```

After (with corrected addresses):
```
; 01BD: RL1           <- actual address updated
CD DA 02; CALL GETCHR <- GETCHR address updated
DA E4 01; JC RL_EOF   <- RL_EOF address updated
```

## Labels to Track (from stage1.hex)

Core routines:
- PASS1, PASS2, REWIND, DONE
- RDLINE, RL1, RL_TRUNC, RL_EOL, RL_EOF
- SKIPWS, SKW1, SKW2, SKW3
- PARSE, CHKLBL, CHKDIR, HEXLN
- GETCHR, GC1, GC_EOF
- ISHEX, HEXVAL, OUTPUT, OUT_P1, FLUSH, WRSEC
- DEFSYM, LOOKUP, SYMTBL

Directive handlers:
- CD_ORG, CD_END, CD_EQU (if present)

Symbol reference handlers:
- HX_LO, HX_HI, HX_SYM

## Error Handling

- Warn if a referenced address doesn't match any known label
- Warn if a label is defined but never referenced
- Error if duplicate label names

## Testing

After running the tool:
1. Reassemble stage1.hex with SPAZM0
2. Run STAGE1 on a test file
3. Verify output is correct (non-zero bytes, matches expected output)

## Future Enhancements

- Support for EQU-style symbol definitions (constants, not code labels)
- Automatic comment generation for CALL/JMP targets
- Integration with SPAZM1 (if it learns symbolic labels)

---

## Implementation Outcome (2026-01-03)

### Tool Implemented

`scripts/fixaddr.py` was created following this specification with one key enhancement:

**Comment-based label resolution**: The tool uses comment annotations (e.g., `; CALL RDLINE`) as the primary method for identifying which label a branch targets, rather than relying solely on address matching. This handles the case where the file is in an inconsistent state with some addresses already partially updated.

### Results

```
First pass:  89 code labels found (8 variable declarations filtered)
Second pass: 139 branch instructions, all resolved to labels
Third pass:  106 changes applied
Code size:   1155 bytes (0100-0583)
```

All 89 labels now show `Declared == Actual` (delta 0). The tool is idempotent - running it again produces zero changes.

### Files Modified

| File | Change |
|------|--------|
| `scripts/fixaddr.py` | New tool (367 lines) |
| `src/stage1.hex` | All addresses corrected |
| `src/stage1.8hx` | Stage 1 source (renamed from .hex) |
| `lode/assembler/workflow.md` | Tool documentation added |
| `lode/summary.md` | Status updated |

### Usage

```bash
# Dry-run to see changes without modifying
python3 scripts/fixaddr.py src/stage1.8hx --dry-run

# Apply fixes to new file
python3 scripts/fixaddr.py src/stage1.8hx src/stage1.fixed.8hx

# Show label table only
python3 scripts/fixaddr.py src/stage1.8hx --show-labels
```

---

## Resuming Development

Stage 1 addresses are now correct. To continue:

### Immediate Next Steps

1. **Assemble Stage 1**:
   ```
   # Sync stage1.8hx to disk
   cpmcp -f ibm-3740 work.dsk src/stage1.8hx 0:STAGE1.HEX

   # Boot CP/M and run SPAZM0
   SPAZM0 STAGE1
   ```

2. **Test the resulting STAGE1.COM** on a simple test file to verify it works.

3. **If you modify stage1.8hx** (add/remove bytes), run `fixaddr.py` again before assembling:
   ```bash
   python3 scripts/fixaddr.py src/stage1.8hx src/stage1.8hx
   ```

### Key Points for Future Edits

- **Always add comment annotations** to new branches: `CD XX XX; CALL LABELNAME`
- **Always add label declarations** for new labels: `; XXXX: LABELNAME`
- The tool relies on these annotations to resolve targets correctly
- Run `--dry-run` first to verify changes look reasonable
- The tool skips system calls (BDOS at 0005, BOOT at 0000) automatically

### Resume Prompt

> "Continue spazm8080 development. Stage 1 addresses have been fixed with fixaddr.py. Next: assemble Stage 1 with SPAZM0 (`SPAZM0 STAGE1`) and test it on a simple input file."
