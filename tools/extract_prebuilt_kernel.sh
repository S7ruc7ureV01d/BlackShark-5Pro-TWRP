#!/usr/bin/env bash
# Extract the stock GKI kernel from the boot_b backup into the device tree.
# Only used to satisfy the build system; it is NOT packed into recovery.img
# (BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
python3 "$ROOT/tools/mkbootimg/unpack_bootimg.py" --boot_img "$ROOT/backups/stock/partitions/boot_b.img" --out "$TMP" >/dev/null
install -Dm644 "$TMP/kernel" "$ROOT/device/blackshark/katyusha/prebuilt/kernel"
echo "kernel: $(strings -n 20 "$TMP/kernel" | grep -m1 '^Linux version 5' | cut -d' ' -f3)"
