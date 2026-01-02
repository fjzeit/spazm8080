#!/bin/bash
# Sync source files from CP/M disk image to repo
# Usage: ./scripts/sync-from-disk.sh [disk_image]

DISK="${1:-../lolos/drivea.dsk}"
FORMAT="ibm-3740"
SRC_DIR="$(dirname "$0")/../src"

if [ ! -f "$DISK" ]; then
    echo "Error: Disk image not found: $DISK"
    exit 1
fi

mkdir -p "$SRC_DIR"

echo "Syncing sources from $DISK..."

# List .ASM files and extract them
for f in $(cpmls -f "$FORMAT" "$DISK" 2>/dev/null | grep -i '\.asm$'); do
    # Remove user prefix if present (0:)
    name="${f#*:}"
    lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    echo "  0:$name -> $SRC_DIR/$lower"
    cpmcp -f "$FORMAT" "$DISK" "0:$name" "$SRC_DIR/$lower"
done

echo "Done."
