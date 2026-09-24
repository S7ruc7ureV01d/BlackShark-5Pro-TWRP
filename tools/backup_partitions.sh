#!/usr/bin/env bash
# Dump device partitions over adb (root via Magisk) into the project's backups dir.
# Each image is verified by comparing on-device sha256 with host sha256.
# Usage: tools/backup_partitions.sh [partition ...]   (default: all except super/userdata)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/backups/stock/partitions"
SUMS="$ROOT/backups/stock/SHA256SUMS"
LOG="$ROOT/backups/stock/backup.log"
SKIP_RE='^(super|userdata|sd[a-f])$'
mkdir -p "$OUT"

if [ $# -gt 0 ]; then
  parts=("$@")
else
  mapfile -t parts < <(adb shell 'su -c "ls /dev/block/by-name/"' | tr -d '\r' | grep -Ev "$SKIP_RE" | sort)
fi

for p in "${parts[@]}"; do
  dst="$OUT/$p.img"
  if [ -s "$dst" ] && grep -q "  $p.img\$" "$SUMS" 2>/dev/null; then
    echo "skip $p (already verified)"; continue
  fi
  adb exec-out "su -c 'dd if=/dev/block/by-name/$p bs=4M 2>/dev/null'" > "$dst.part"
  dev_sum=$(adb shell "su -c 'sha256sum /dev/block/by-name/$p'" | tr -d '\r' | awk '{print $1}')
  host_sum=$(sha256sum "$dst.part" | awk '{print $1}')
  if [ "$dev_sum" != "$host_sum" ]; then
    echo "MISMATCH $p dev=$dev_sum host=$host_sum" | tee -a "$LOG"
    rm -f "$dst.part"; exit 1
  fi
  mv "$dst.part" "$dst"
  echo "$host_sum  $p.img" >> "$SUMS"
  echo "ok $p $(stat -c%s "$dst") $host_sum" | tee -a "$LOG"
done
