#!/usr/bin/env python3
"""
fixaddr.py - Fix stale addresses in hand-assembled hex files

This tool corrects address references in stage1.hex files where bytes have
been added or removed, causing addresses to shift. It:

1. Parses hex bytes to calculate actual addresses
2. Collects label definitions from ; XXXX: LABELNAME comments
3. Updates jump/call target addresses to match actual label positions
4. Updates label declaration comments to show correct addresses

Usage: python3 fixaddr.py [input.hex] [output.hex] [--base XXXX]
       Default base address is 0100 (CP/M .COM file)
"""

import re
import sys
from dataclasses import dataclass
from typing import Optional

# 8080 jump/call opcodes (3-byte instructions with 16-bit address)
JUMP_OPCODES = {
    0xC3: 'JMP',  0xCA: 'JZ',   0xC2: 'JNZ', 0xDA: 'JC',
    0xD2: 'JNC', 0xF2: 'JP',   0xFA: 'JM',  0xEA: 'JPE', 0xE2: 'JPO',
}
CALL_OPCODES = {
    0xCD: 'CALL', 0xCC: 'CZ',  0xC4: 'CNZ', 0xDC: 'CC',
    0xD4: 'CNC', 0xF4: 'CP',   0xFC: 'CM',  0xEC: 'CPE', 0xE4: 'CPO',
}
BRANCH_OPCODES = {**JUMP_OPCODES, **CALL_OPCODES}


@dataclass
class Label:
    """A label definition found in the source"""
    name: str
    declared_addr: int  # Address in the comment
    actual_addr: int    # Calculated actual address
    line_num: int       # Line number where defined


@dataclass
class Reference:
    """A jump/call that references an address"""
    line_num: int
    opcode: int
    target_addr: int    # Current target address in the code
    byte_offset: int    # Offset of the address bytes within the line
    label: Optional[str] = None          # Label name from comment (e.g., "; CALL RDLINE")
    addr_match_label: Optional[str] = None  # Label matched by address


def parse_hex_bytes(line: str) -> list[int]:
    """Extract hex bytes from a line, stopping at semicolon"""
    # Get content before semicolon
    if ';' in line:
        content = line.split(';')[0]
    else:
        content = line

    content = content.strip()
    if not content:
        return []

    # Parse space-separated hex bytes
    bytes_out = []
    for token in content.split():
        token = token.strip()
        if token and all(c in '0123456789ABCDEFabcdef' for c in token) and len(token) == 2:
            bytes_out.append(int(token, 16))
    return bytes_out


def parse_label_def(line: str) -> Optional[tuple[str, int]]:
    """
    Parse a label definition from a comment line.
    Format: ; XXXX: LABELNAME [optional description]
    Returns (label_name, declared_address) or None
    """
    # Match pattern: ; followed by hex address, colon, label name
    # Label is alphanumeric+underscore, terminated by space, colon, or EOL
    match = re.match(r';\s*([0-9A-Fa-f]{4}):\s*([A-Za-z_][A-Za-z0-9_]*)', line)
    if match:
        addr = int(match.group(1), 16)
        name = match.group(2).upper()
        return (name, addr)
    return None


def update_label_comment(line: str, old_addr: int, new_addr: int) -> str:
    """Update address in a label definition comment"""
    old_hex = f'{old_addr:04X}'
    new_hex = f'{new_addr:04X}'
    # Replace the address in the comment
    return re.sub(
        r';\s*' + old_hex + r':',
        f'; {new_hex}:',
        line,
        flags=re.IGNORECASE
    )


def update_paren_address(line: str, old_addr: int, new_addr: int) -> str:
    """Update (XXXX) address references in comments"""
    old_hex = f'{old_addr:04X}'
    new_hex = f'{new_addr:04X}'
    # Replace address in parentheses
    pattern = r'\(' + old_hex + r'\)'
    return re.sub(pattern, f'({new_hex})', line, flags=re.IGNORECASE)


def parse_comment_target(line: str) -> Optional[str]:
    """
    Extract target label from a branch instruction comment.
    Examples:
      "; JZ NOFILE" -> "NOFILE"
      "; CALL RDLINE (01B0)" -> "RDLINE"
      "; JNZ RL1" -> "RL1"
    """
    # Get comment part
    if ';' not in line:
        return None
    comment = line.split(';', 1)[1].strip()

    # Match: JMP/CALL/etc followed by label name
    # Branch mnemonics followed by whitespace and a label
    branch_pattern = r'^(JMP|JZ|JNZ|JC|JNC|JP|JM|JPE|JPO|CALL|CZ|CNZ|CC|CNC|CP|CM|CPE|CPO)\s+([A-Za-z_][A-Za-z0-9_]*)'
    match = re.match(branch_pattern, comment, re.IGNORECASE)
    if match:
        return match.group(2).upper()
    return None


def format_addr_bytes(addr: int) -> str:
    """Format a 16-bit address as little-endian hex bytes"""
    lo = addr & 0xFF
    hi = (addr >> 8) & 0xFF
    return f'{lo:02X} {hi:02X}'


def parse_addr_from_bytes(lo: int, hi: int) -> int:
    """Parse little-endian address from two bytes"""
    return lo | (hi << 8)


class AddressFixer:
    def __init__(self, base_addr: int = 0x0100):
        self.base_addr = base_addr
        self.labels: dict[str, Label] = {}      # name -> Label
        self.addr_to_label: dict[int, str] = {} # declared_addr -> name
        self.references: list[Reference] = []
        self.lines: list[str] = []
        self.changes: list[str] = []

    def load(self, filepath: str):
        """Load the hex file"""
        with open(filepath, 'r') as f:
            self.lines = f.readlines()

    def first_pass(self):
        """
        First pass: Calculate actual addresses and collect label definitions.

        Note: Label definitions that appear BEFORE any code bytes are treated
        as variable/constant declarations and not recalculated.
        """
        current_addr = self.base_addr
        seen_code = False  # Have we seen any code bytes yet?

        for line_num, line in enumerate(self.lines, 1):
            # Count bytes in this line FIRST to determine if this line has code
            hex_bytes = parse_hex_bytes(line)

            # Check for label definition in comment-only lines
            label_def = parse_label_def(line.strip())
            if label_def:
                name, declared_addr = label_def

                # Skip variable declarations in header (before any code)
                # These have addresses >= 0x0500 typically (data area)
                if not seen_code and declared_addr >= 0x0500:
                    continue  # Skip variable declarations

                if name in self.labels:
                    print(f"Warning: Duplicate label '{name}' at line {line_num}")
                else:
                    self.labels[name] = Label(
                        name=name,
                        declared_addr=declared_addr,
                        actual_addr=current_addr,
                        line_num=line_num
                    )
                    self.addr_to_label[declared_addr] = name

            # Track if we've seen actual code
            if hex_bytes:
                seen_code = True
                current_addr += len(hex_bytes)

        print(f"First pass complete: {len(self.labels)} labels found")
        print(f"Code size: {current_addr - self.base_addr} bytes (ends at {current_addr:04X})")

    def second_pass(self):
        """
        Second pass: Find all jump/call instructions and their targets.
        Uses comment annotations (e.g., "; CALL RDLINE") to identify target labels.
        """
        current_addr = self.base_addr

        for line_num, line in enumerate(self.lines, 1):
            hex_bytes = parse_hex_bytes(line)
            if not hex_bytes:
                continue

            # Check if first byte is a branch opcode
            if hex_bytes[0] in BRANCH_OPCODES and len(hex_bytes) >= 3:
                opcode = hex_bytes[0]
                target = parse_addr_from_bytes(hex_bytes[1], hex_bytes[2])

                # Primary: Get label from comment annotation
                comment_label = parse_comment_target(line)

                # Fallback: Try to match by declared address
                addr_label = self.addr_to_label.get(target)

                # Also try actual addresses (for already-fixed references)
                if addr_label is None:
                    for name, label in self.labels.items():
                        if label.actual_addr == target:
                            addr_label = name
                            break

                self.references.append(Reference(
                    line_num=line_num,
                    opcode=opcode,
                    target_addr=target,
                    byte_offset=1,  # Address bytes start at position 1
                    label=comment_label,
                    addr_match_label=addr_label
                ))

            current_addr += len(hex_bytes)

        # Count how many we can resolve
        resolved = sum(1 for r in self.references if r.label or r.addr_match_label)
        print(f"Second pass complete: {len(self.references)} branch instructions, {resolved} with labels")

    def third_pass(self) -> list[str]:
        """
        Third pass: Update addresses in the file.
        Returns the modified lines.

        Priority for determining target label:
        1. Comment annotation (e.g., "; CALL RDLINE")
        2. Address match to declared label address
        3. Address match to actual label address
        """
        modified_lines = self.lines.copy()

        # First, update jump/call target addresses
        for ref in self.references:
            # Determine which label this reference targets
            target_label_name = ref.label  # From comment
            if target_label_name is None:
                target_label_name = ref.addr_match_label  # From address match

            if target_label_name is None:
                # Check if target is a system address (BDOS, BOOT, etc.)
                if ref.target_addr < self.base_addr:
                    continue  # System call, don't modify
                # Warn about unresolved references
                op_name = BRANCH_OPCODES[ref.opcode]
                print(f"Warning: Line {ref.line_num}: {op_name} to {ref.target_addr:04X} - no label found")
                continue

            # Ensure the label exists
            if target_label_name not in self.labels:
                # Known system labels - silently skip
                if target_label_name in ('BDOS', 'BOOT', 'FCB', 'DMA'):
                    continue
                op_name = BRANCH_OPCODES[ref.opcode]
                print(f"Warning: Line {ref.line_num}: {op_name} references unknown label '{target_label_name}'")
                continue

            label = self.labels[target_label_name]
            if ref.target_addr == label.actual_addr:
                continue  # Already correct

            # Update the instruction bytes
            line = modified_lines[ref.line_num - 1]
            old_addr_bytes = format_addr_bytes(ref.target_addr)
            new_addr_bytes = format_addr_bytes(label.actual_addr)

            # Replace the address bytes in the line
            new_line = line.replace(old_addr_bytes, new_addr_bytes, 1)

            # Also update any (XXXX) reference in the comment
            new_line = update_paren_address(new_line, ref.target_addr, label.actual_addr)

            if new_line != line:
                modified_lines[ref.line_num - 1] = new_line
                op_name = BRANCH_OPCODES[ref.opcode]
                self.changes.append(
                    f"Line {ref.line_num}: {op_name} {target_label_name}: "
                    f"{ref.target_addr:04X} -> {label.actual_addr:04X}"
                )

        # Then, update label declaration comments
        for name, label in self.labels.items():
            if label.declared_addr == label.actual_addr:
                continue  # Already correct

            line = modified_lines[label.line_num - 1]
            new_line = update_label_comment(line, label.declared_addr, label.actual_addr)

            if new_line != line:
                modified_lines[label.line_num - 1] = new_line
                self.changes.append(
                    f"Line {label.line_num}: Label {name}: "
                    f"{label.declared_addr:04X} -> {label.actual_addr:04X}"
                )

        return modified_lines

    def fix(self, input_path: str, output_path: str):
        """Run all passes and write output"""
        self.load(input_path)
        self.first_pass()
        self.second_pass()
        modified = self.third_pass()

        with open(output_path, 'w') as f:
            f.writelines(modified)

        print(f"\n{'='*60}")
        print(f"Changes made: {len(self.changes)}")
        for change in self.changes:
            print(f"  {change}")
        print(f"{'='*60}")
        print(f"Output written to: {output_path}")

    def show_labels(self):
        """Display all labels with their addresses"""
        print("\nLabel Table:")
        print(f"{'Name':<12} {'Declared':>8} {'Actual':>8} {'Delta':>6}")
        print("-" * 40)
        for name, label in sorted(self.labels.items(), key=lambda x: x[1].actual_addr):
            delta = label.actual_addr - label.declared_addr
            delta_str = f"+{delta}" if delta > 0 else str(delta) if delta < 0 else "0"
            match = "OK" if delta == 0 else "SHIFT"
            print(f"{name:<12} {label.declared_addr:04X}     {label.actual_addr:04X}     {delta_str:>4} {match}")


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description='Fix stale addresses in hand-assembled hex files'
    )
    parser.add_argument('input', nargs='?', default='src/stage1.hex',
                        help='Input hex file (default: src/stage1.hex)')
    parser.add_argument('output', nargs='?',
                        help='Output hex file (default: input with .fixed.hex)')
    parser.add_argument('--base', type=lambda x: int(x, 16), default=0x0100,
                        help='Base address in hex (default: 0100)')
    parser.add_argument('--show-labels', action='store_true',
                        help='Show label table and exit')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show changes without writing output')

    args = parser.parse_args()

    if args.output is None:
        args.output = args.input.replace('.hex', '.fixed.hex')

    fixer = AddressFixer(base_addr=args.base)

    if args.show_labels:
        fixer.load(args.input)
        fixer.first_pass()
        fixer.show_labels()
        return

    if args.dry_run:
        fixer.load(args.input)
        fixer.first_pass()
        fixer.second_pass()
        fixer.third_pass()
        print(f"\nDry run - no output written")
        print(f"Would make {len(fixer.changes)} changes:")
        for change in fixer.changes:
            print(f"  {change}")
        fixer.show_labels()
    else:
        fixer.fix(args.input, args.output)
        fixer.show_labels()


if __name__ == '__main__':
    main()
