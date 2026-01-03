# Memory Layout

The assembler uses a **data-first** architecture: variables and buffers are placed at fixed low addresses, then code follows. This ensures addresses never change when code grows or new variables are added.

## Current Layout (Stage 3+)

```
0100-0102: JMP 0400 (skip data area)
0110-012F: Variables (32 bytes, 12 used + 20 free)
0130-01AF: TOKBUF (128 bytes)
01B0-01FF: LINBUF (80 bytes)
0200-027F: IBUF (128 bytes)
0280-02FF: OBUF (128 bytes)
0300-033F: OFCB (64 bytes)
0340-03FF: Reserved (192 bytes for future buffers)
0400+:     Code (grows freely)
2000+:     SYMTAB (fixed high address, grows toward BDOS)
```

## Variables (at 0110)

| Offset | Address | Size | Name   | Purpose |
|--------|---------|------|--------|---------|
| +0     | 0110    | 1    | PASS   | Pass number (0=pass1, 1=pass2) |
| +1     | 0111    | 1    | ICNT   | Input buffer bytes remaining |
| +2     | 0112    | 2    | IPTR   | Input buffer read pointer |
| +4     | 0114    | 1    | OCNT   | Output buffer bytes written |
| +5     | 0115    | 2    | OPTR   | Output buffer write pointer |
| +7     | 0117    | 1    | SYMCNT | Symbol table entry count |
| +8     | 0118    | 2    | LOCTR  | Location counter (current address) |
| +A     | 011A    | 2    | LNPTR  | Line parsing pointer |

20 bytes free (011C-012F) for future variables.

## Symbol Table Format

Each entry is 8 bytes:
- Bytes 0-5: Name (6 chars, uppercase, space-padded)
- Bytes 6-7: Value (16-bit, little-endian)

Located at fixed address 2000, giving code room to grow to ~7.5KB without conflicts.

## Why Data First?

**Problem with code-first layout:** When code grows, buffer addresses shift. Every address change requires updating all references - tedious and error-prone during bootstrap.

**Solution:** Put data at fixed addresses *before* code:
- Variables: 0110-012F (with room to grow)
- Buffers: 0130-033F
- Code: 0400+ (can grow freely)
- SYMTAB: 2000+ (fixed high address)

Benefits:
- Add new variables without moving existing ones
- Grow code without touching data addresses
- No more emergency address-shifting sessions

The 3-byte JMP at 0100 is a small price for stable addresses.
