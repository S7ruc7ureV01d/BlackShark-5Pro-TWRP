#!/usr/bin/env bash
# Copy the device tree into the TWRP source checkout (which must live at a path
# without spaces). Usage: tools/sync_tree.sh [twrp-src-dir]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$HOME/Projects/twrp-12.1}"
[ -f "$ROOT/device/blackshark/katyusha/prebuilt/kernel" ] || "$ROOT/tools/extract_prebuilt_kernel.sh"
mkdir -p "$SRC/device/blackshark"
rsync -a --delete "$ROOT/device/blackshark/katyusha/" "$SRC/device/blackshark/katyusha/"
echo "synced to $SRC/device/blackshark/katyusha"
