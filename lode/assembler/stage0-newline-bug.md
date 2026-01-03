# CPI Carry Flag Behavior

**Key Lesson**: The 8080 `CPI` instruction sets the carry flag when `A < immediate`. This affects all control flow after the comparison.

## The Pattern

When checking for a specific value and then returning:

```asm
; WRONG - Carry flag may be set unexpectedly
        CPI     1AH             ; Check for Ctrl-Z
        JZ      EOF_HANDLER     ; Jump if match
        RET                     ; CY=1 if A < 0x1A!

; CORRECT - Clear carry before returning
        CPI     1AH             ; Check for Ctrl-Z
        JZ      EOF_HANDLER     ; Jump if match
        ORA     A               ; Clear CY (A|A=A, but CY=0)
        RET                     ; Safe: CY=0
```

## Why It Matters

Characters like LF (0x0A), CR (0x0D), and TAB (0x09) are all less than 0x1A. After `CPI 1AH`, the carry flag is set for these values. If the caller uses `JC` to detect EOF (indicated by CY=1), it will incorrectly interpret normal whitespace as EOF.

## General Rule

After any `CPI` comparison where you're checking for a specific value and want to continue normally on non-match, consider whether the carry flag state matters to callers. If returning to a caller that checks CY, either:
1. Use `ORA A` to explicitly clear carry before `RET`
2. Use `STC` to explicitly set carry if indicating an error condition
3. Document the carry flag state in the subroutine's output contract

## Related

- [practices.md](../practices.md) - Return value conventions
- [bootstrap.md](bootstrap.md) - Stage 0 implementation details
