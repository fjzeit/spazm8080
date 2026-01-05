#!/usr/bin/env python3
"""Convert stage4.8hx (hex format) to stage5.asm (mnemonic format)"""

import re
import sys

def extract_label_from_hex(hex_part):
    """Extract label reference from hex code section.
    e.g., 'CA GODEF' returns 'GODEF', 'CD 05 00' returns None"""
    tokens = hex_part.split()
    for tok in tokens[1:]:  # Skip opcode
        # If token has letters G-Z or underscore, it's a label
        if re.search(r'[G-Zg-z_]', tok):
            return tok
    return None

def extract_mnemonic_and_operand(comment):
    """Parse comment to extract mnemonic and operand.
    e.g., 'MOV A,M' -> ('MOV A,M', None)
    e.g., 'LXI H,0065H (FCB+9)' -> ('LXI H,0065H', 'FCB+9')
    e.g., 'JZ GO_DEFB' -> ('JZ', 'GO_DEFB')"""

    comment = comment.strip()
    if not comment:
        return None, None

    # Check for trailing comment in parens
    extra_comment = None
    match = re.match(r'^(.*?)\s*\(([^)]+)\)\s*$', comment)
    if match:
        comment = match.group(1).strip()
        extra_comment = match.group(2).strip()

    return comment, extra_comment

def is_branch_instruction(mnemonic):
    """Check if mnemonic is a jump/call that takes a label."""
    branch_ops = ['JMP', 'JZ', 'JNZ', 'JC', 'JNC', 'JP', 'JM', 'JPE', 'JPO',
                  'CALL', 'CZ', 'CNZ', 'CC', 'CNC', 'CP', 'CM', 'CPE', 'CPO',
                  'LDA', 'STA', 'LHLD', 'SHLD']
    op = mnemonic.split()[0] if mnemonic else ''
    return op in branch_ops

def convert_line(line):
    """Convert a single line from hex format to mnemonic format."""

    # Preserve blank lines
    if not line.strip():
        return line

    # Preserve comment-only lines
    stripped = line.lstrip()
    if stripped.startswith(';'):
        return line

    # Preserve DEFB/DEFW lines
    if 'DEFB ' in stripped or 'DEFW ' in stripped or 'DEFS ' in stripped:
        return line

    # Preserve labels (lines starting with non-whitespace and containing :)
    if stripped and not stripped[0].isspace() and ':' in stripped.split()[0]:
        return line

    # Preserve ORG and END directives
    if stripped.startswith('ORG ') or stripped.startswith('END'):
        return line

    # Check for hex code with comment
    # Pattern: whitespace + hex/labels + ; + comment
    match = re.match(r'^(\s+)([^;]+);\s*(.*)$', line)
    if not match:
        # No semicolon - could be hex-only line or other
        return line

    indent = match.group(1)
    hex_part = match.group(2).strip()
    comment = match.group(3).strip()

    # Skip if no hex part or comment is empty
    if not hex_part or not comment:
        return line

    # Check if comment looks like a mnemonic (starts with uppercase letter)
    if not comment[0].isupper():
        return line

    # Extract mnemonic and any extra comment
    mnemonic, extra_comment = extract_mnemonic_and_operand(comment)

    if not mnemonic:
        return line

    # For branch instructions, use label from hex code, not comment
    if is_branch_instruction(mnemonic):
        label = extract_label_from_hex(hex_part)
        if label:
            # Replace operand with actual label from hex
            op = mnemonic.split()[0]
            mnemonic = f"{op} {label}"

    # Build output line
    if extra_comment:
        result = f"{indent}{mnemonic:<16}; {extra_comment}"
    else:
        result = f"{indent}{mnemonic}"

    return result.rstrip()

def convert_file(input_path, output_path):
    """Convert entire file."""
    with open(input_path, 'r') as f:
        lines = f.readlines()

    output_lines = []
    for line in lines:
        # Remove trailing newline for processing
        line = line.rstrip('\n\r')
        converted = convert_line(line)
        output_lines.append(converted)

    with open(output_path, 'w') as f:
        for line in output_lines:
            f.write(line + '\n')

    print(f"Converted {len(output_lines)} lines")
    print(f"Output: {output_path}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.8hx> <output.asm>")
        sys.exit(1)

    convert_file(sys.argv[1], sys.argv[2])
