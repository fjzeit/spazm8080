#!/bin/bash
# Sync source files from repo to CP/M disk image
# Usage: ./scripts/sync-to-disk.sh [disk_image]

DISK="${1:-$(dirname "$0")/../work.dsk}"
FORMAT="ibm-3740"
SRC_DIR="$(dirname "$0")/../src"

if [ ! -f "$DISK" ]; then
    echo "Error: Disk image not found: $DISK"
    exit 1
fi

echo "Syncing sources to $DISK..."

# Copy all .asm files to user 0
for f in "$SRC_DIR"/*.asm; do
    if [ -f "$f" ]; then
        base=$(basename "$f" | tr '[:lower:]' '[:upper:]')
        echo "  $f -> 0:$base"
        cpmcp -f "$FORMAT" "$DISK" "$f" "0:$base"
    fi
done

echo "Done. Files on disk:"
cpmls -f "$FORMAT" "$DISK"
